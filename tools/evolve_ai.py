"""Evolve the AI's strategy weights against the current hand-written AI.

    python tools/evolve_ai.py --generations 8 --children 10 --seeds 18

Every generation the parent and N mutated children each play the same seeds against the default AI
(enemy_ai.gd with no params). Matches are mirrored: both sides get the same random deck and lord,
and every seed is played twice, the candidate once as red and once as blue, so only the strategy
differs. The next parent is the average of the best three (robust to lucky scores). The final parent
is then checked on fresh seeds.

Writes tools/evolved_ai.json (the weights) and docs/AI演化報告.md. Game files are not changed.
"""
import argparse, json, math, os, random, subprocess, time
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RUNS = os.path.join(ROOT, "tools", "evolve_runs")
PROJECT = ROOT  # where the Godot workers run; --project points them at a frozen copy
OUT = os.path.join(ROOT, "tools", "evolved_ai.json")
REPORT = os.path.join(ROOT, "docs", "AI演化報告.md")

# name: (default, low, high, mutation sigma, integer, description). Defaults must match enemy_ai.gd
# (normal difficulty), so the first parent is exactly the hand-written AI.
GENES = {
    "hoard":            (1.0,   0.0,  1.0,  0.35, False, "紅獅／豐收：要放技能時是否停手存錢（≥0.5 存）"),
    "skill_after":      (45.0,  0.0,  180.0, 25.0, False, "紅獅／豐收：幾秒後開始想放技能"),
    "harvest_max_farms": (7.0,  2.0,  15.0, 2.0,  False, "豐收：農田少於等於幾塊才放豐年祭"),
    "iron_gate_share":  (0.6,   0.2,  1.0,  0.1,  False, "鐵壁：城門總血量低於幾成就想放技能"),
    "iron_hoard":       (1.0,   0.0,  1.0,  0.35, False, "鐵壁：想放技能時是否停手存錢"),
    "save_from":        (30.0,  0.0,  50.0, 5.0,  False, "金幣多少以上才為技能停手存錢"),
    "spend_at":         (35.0,  15.0, 50.0, 5.0,  False, "金幣多少以上就把卡手的牌用掉"),
    "wave_at":          (25.0,  8.0,  50.0, 5.0,  False, "金幣多少以上開始進攻"),
    "wave_time":        (6.0,   2.0,  16.0, 2.0,  False, "一波進攻持續幾秒"),
    "defend_reach":     (4.5,   2.0,  7.0,  0.6,  False, "敵兵離城門幾欄內才防守"),
    "farm_goal":        (6.0,   2.0,  12.0, 1.5,  True,  "優先種田種到幾塊"),
    "farm_score":       (800.0, 400.0, 1000.0, 60.0, False, "種田優先度"),
    "farmer_score":     (740.0, 400.0, 1000.0, 60.0, False, "派農民耕田優先度"),
    "raid_score":       (700.0, 400.0, 1000.0, 60.0, False, "燒／拆敵方農田優先度"),
    "raid_min_farms":   (4.0,   1.0,  8.0,  1.2,  True,  "敵方農田幾塊以上才去拆"),
    "guard_score":      (690.0, 400.0, 1000.0, 60.0, False, "農田路先蓋箭樓／稻草人的優先度"),
    "guard_after":      (20.0,  0.0,  120.0, 15.0, False, "幾秒後開始蓋防守建築"),
    "ram_score":        (720.0, 400.0, 1000.0, 60.0, False, "攻城槌優先度"),
    "ram_reserve":      (10.0,  0.0,  25.0, 4.0,  False, "出攻城槌後要留多少金幣"),
    "ram_escort":       (250.0, 0.0,  800.0, 100.0, False, "那一路要有多少血量的我方部隊才出攻城槌"),
    "healer_score":     (690.0, 400.0, 1000.0, 60.0, False, "草藥婆優先度"),
    "wave_score":       (600.0, 400.0, 1000.0, 60.0, False, "進攻出兵優先度"),
    "mill_score":       (650.0, 400.0, 1000.0, 60.0, False, "磨坊優先度"),
    "mill_min_farms":   (3.0,   1.0,  8.0,  1.0,  True,  "農田幾塊以上才蓋磨坊"),
    "harvest_score":    (670.0, 400.0, 1000.0, 60.0, False, "豐收（法術）優先度"),
    "harvest_min":      (2.0,   1.0,  5.0,  0.8,  True,  "範圍內至少幾塊田才放豐收"),
    "repair_below":     (0.6,   0.2,  0.95, 0.1,  False, "建築血量低於幾成就覆蓋修補"),
    "atk_gate":         (0.4,   0.0,  1.5,  0.15, False, "選進攻路：敵方城門受損的權重"),
    "atk_foes":         (0.8,   0.0,  2.0,  0.2,  False, "選進攻路：避開敵兵的權重"),
    "atk_recent":       (140.0, 0.0,  400.0, 40.0, False, "選進攻路：避免連續打同一路的權重"),
}


def defaults():
    return {k: g[0] for k, g in GENES.items()}


def clean(params):
    """Clamp and round for the game (integers stay integers)."""
    out = {}
    for k, v in params.items():
        d, lo, hi, _, integer, _ = GENES[k]
        v = min(hi, max(lo, v))
        out[k] = float(round(v)) if integer else round(v, 4)
    return out


def mutate(parent, rng):
    child = dict(parent)
    for k in rng.sample(list(GENES), rng.randint(2, 5)):
        child[k] = child[k] + rng.gauss(0, GENES[k][3])
    return clean(child)


def run_worker(job):
    params_path, start, count, out, base_path = job
    cmd = ["godot_console", "--headless", "--path", PROJECT, "-s", "tools/random_sim.gd", "--",
           "--mirror", f"--cand={params_path}", f"--start={start}", f"--count={count}", f"--out={out}"]
    if base_path: cmd.append(f"--base={base_path}")
    result = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", shell=(os.name == "nt"))
    if result.returncode != 0 or "SCRIPT ERROR" in result.stdout + result.stderr:
        raise RuntimeError(f"worker failed:\n{result.stdout[-1500:]}\n{result.stderr[-1500:]}")
    score, games, skills = 0.0, 0, 0
    for line in open(out, encoding="utf-8"):
        r = json.loads(line)
        side = r["cand_side"]
        games += 1
        score += 0.5 if r["winner"] < 0 else (1.0 if r["winner"] == side else 0.0)
        skills += r["skills"][side]
    return score, games, skills


def evaluate(candidates, seed_start, seeds, workers, tag, base_path=""):
    """Every candidate plays the same seeds (both sides) against base_path's weights
    ("" = the hand-written AI). Returns [(score, games, skills)]."""
    os.makedirs(RUNS, exist_ok=True)
    jobs, owner = [], []
    chunks = max(1, workers // len(candidates)) if len(candidates) < workers else 1
    per = math.ceil(seeds / chunks)
    for i, params in enumerate(candidates):
        path = os.path.join(RUNS, f"{tag}_c{i}.json")
        json.dump(params, open(path, "w", encoding="utf-8"))
        for c in range(chunks):
            count = min(per, seeds - c * per)
            if count <= 0: break
            jobs.append((path, seed_start + c * per, count, os.path.join(RUNS, f"{tag}_c{i}_{c}.jsonl"), base_path))
            owner.append(i)
    totals = [[0.0, 0, 0] for _ in candidates]
    with ThreadPoolExecutor(workers) as pool:
        for i, (score, games, skills) in zip(owner, pool.map(run_worker, jobs)):
            totals[i][0] += score
            totals[i][1] += games
            totals[i][2] += skills
    return totals


def changed(params, reference):
    rows = []
    for k, (d, lo, hi, sigma, integer, desc) in GENES.items():
        v, r = params[k], reference[k]
        if abs(v - r) > 1e-9:
            rows.append((abs(v - r) / (hi - lo), k, r, v, desc))
    rows.sort(reverse=True)
    return rows


def rate_text(total):
    rate = total[0] / total[1]
    se = math.sqrt(rate * (1 - rate) / total[1])
    return f"**{rate:.1%}**（95% 信賴區間 {max(0, rate - 1.96 * se):.0%}–{min(1, rate + 1.96 * se):.0%}，{total[1]} 場）"


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--generations", type=int, default=8)
    p.add_argument("--children", type=int, default=10)
    p.add_argument("--seeds", type=int, default=18, help="seeds per candidate per generation (x2 games)")
    p.add_argument("--validate", type=int, default=100, help="fresh seeds for the final check (x2 games)")
    p.add_argument("--workers", type=int, default=max(1, (os.cpu_count() or 2) - 1))
    p.add_argument("--rng", type=int, default=7)
    p.add_argument("--project", default=ROOT, help="run the matches in this copy of the project (frozen code)")
    p.add_argument("--base", default="", help="opponent weights (JSON); default: the hand-written AI")
    p.add_argument("--start", default="", help="first parent (JSON); default: --base, else the hand-written AI")
    p.add_argument("--out", default=OUT, help="where to write the evolved weights")
    p.add_argument("--round", type=int, default=1, help="round number; rounds after 1 append to the report")
    p.add_argument("--seed-base", type=int, default=100_000)
    p.add_argument("--validate-seed", type=int, default=900_000)
    p.add_argument("--validate-only", action="store_true", help="skip the generations: check --start against --base and append to the report")
    args = p.parse_args()
    global PROJECT
    PROJECT = os.path.abspath(args.project)
    rng = random.Random(args.rng)
    base_path = os.path.abspath(args.base) if args.base else ""
    start = args.start or args.base
    parent = clean(json.load(open(start, encoding="utf-8"))) if start else clean(defaults())
    first = dict(parent)
    opponent = f"第 {args.round - 1} 輪演化出的 AI（`{os.path.basename(args.base)}`）" if args.base else "現有的手寫 AI"
    if args.validate_only:
        reference = clean(json.load(open(args.base, encoding="utf-8"))) if args.base else clean(defaults())
        earlier = open(REPORT, encoding="utf-8").read() if os.path.exists(REPORT) else "# AI 演化報告\n"
        note = f"\n第 {args.round} 輪依製作人指示提前結束，直接驗證 `{os.path.basename(start)}`。\n"
        validate(args, parent, reference, opponent, base_path, [earlier, note], time.time())
        return
    header = (f"\n## 第 {args.round} 輪（{time.strftime('%Y-%m-%d %H:%M')}）\n\n對手：{opponent}。每代 1 個親代＋{args.children} 個突變，"
              f"各打 {args.seeds} 組種子 × 紅藍各一場；雙方同牌組、同領主，只比打法。下一代親代＝前三名的平均。\n\n"
              "| 代 | 親代勝率 | 最佳子代勝率 | 前三名平均 | 秒 |\n|---|---|---|---|---|\n")
    earlier = open(REPORT, encoding="utf-8").read() if args.round > 1 and os.path.exists(REPORT) else "# AI 演化報告\n"
    log = [earlier, header]
    t_all = time.time()
    for gen in range(args.generations):
        t0 = time.time()
        children = [mutate(parent, rng) for _ in range(args.children)]
        pool = [parent] + children
        results = evaluate(pool, args.seed_base + gen * 1000, args.seeds, args.workers, f"r{args.round}g{gen}", base_path)
        rates = [r[0] / r[1] for r in results]
        order = sorted(range(len(pool)), key=lambda i: -rates[i])
        top = [pool[i] for i in order[:3]]
        parent = clean({k: sum(t[k] for t in top) / len(top) for k in GENES})
        line = f"| {gen + 1} | {rates[0]:.0%} | {rates[order[0]]:.0%} | {sum(rates[i] for i in order[:3]) / 3:.0%} | {time.time() - t0:.0f} |\n"
        print(line.strip(), flush=True)
        log.append(line)
        json.dump(parent, open(args.out, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        open(REPORT, "w", encoding="utf-8").write("".join(log))
    validate(args, parent, first, opponent, base_path, log, t_all)


def validate(args, parent, reference, opponent, base_path, log, t_all):
    """Final checks on seeds no generation has seen: against this round's opponent, and (after
    round 1) against the hand-written AI too, so progress across rounds is visible."""
    summary = f"\n### 第 {args.round} 輪驗證（沒用過的 {args.validate} 組種子 × 紅藍各一場）\n\n"
    final = evaluate([parent], args.validate_seed, args.validate, args.workers, f"r{args.round}v", base_path)[0]
    summary += f"- 對 {opponent}：{rate_text(final)}；每場平均放技能 {final[2] / final[1]:.2f} 次。\n"
    if base_path:
        plain = evaluate([parent], args.validate_seed + 50_000, args.validate, args.workers, f"r{args.round}v0", "")[0]
        summary += f"- 對現有的手寫 AI：{rate_text(plain)}。\n"
    summary += f"- 總耗時 {(time.time() - t_all) / 60:.0f} 分鐘。\n\n### 第 {args.round} 輪改變最多的參數\n\n| 參數 | 本輪起點 | 演化後 | 意思 |\n|---|---|---|---|\n"
    for _, k, r, v, desc in changed(parent, reference)[:15]:
        summary += f"| {k} | {r:g} | {v:g} | {desc} |\n"
    log.append(summary)
    open(REPORT, "w", encoding="utf-8").write("".join(log))
    print(summary, flush=True)


if __name__ == "__main__":
    main()
