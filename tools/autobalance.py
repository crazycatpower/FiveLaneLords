"""Automatic balance loop: random-deck AI matches, then nudge card costs toward 50% win rate.

    python tools/autobalance.py --total 10000 --rounds 5 --workers 11

Each round plays total/rounds matches (random 8-card decks, random lords; tools/random_sim.gd)
in parallel Godot processes, measures every card's win rate, and edits the "cost" of cards that
win too often (+) or too rarely (-) in balance.gd. Only costs change: stats stay on the S-E tiers.
Lord win rates are reported but not changed (lord stats are tier-locked; the producer decides).

A card's win rate only counts matches where exactly one side holds it, so mirrors don't dilute it.
Draws (time cap) count as half a win. Raw results go to tools/autobalance_runs/ (not committed);
the summary is written to docs/自動平衡報告.md.
"""
import argparse, json, math, os, re, subprocess, sys, time
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BALANCE = os.path.join(ROOT, "balance.gd")
RUNS = os.path.join(ROOT, "tools", "autobalance_runs")
REPORT = os.path.join(ROOT, "docs", "自動平衡報告.md")
MIN_COST, MAX_COST = 1, 30


def read_cards():
    """{kind: (name, cost)} for every card line in balance.gd (lines that carry a "type")."""
    cards = {}
    for line in open(BALANCE, encoding="utf-8"):
        m = re.match(r'\t"(\w+)":\{"name":"([^"]+)".*"type":"\w+","cost":(\d+)', line)
        if m: cards[m.group(1)] = (m.group(2), int(m.group(3)))
    return cards


def write_costs(new_costs):
    text = open(BALANCE, encoding="utf-8").read()
    for kind, cost in new_costs.items():
        pattern = r'(\t"%s":\{"name":"[^"]+".*?"type":"\w+","cost":)\d+' % kind
        text, n = re.subn(pattern, lambda m: m.group(1) + str(cost), text, count=1)
        assert n == 1, kind
    open(BALANCE, "w", encoding="utf-8", newline="").write(text)


def run_worker(args):
    start, count, out, cap = args
    cmd = ["godot_console", "--headless", "--path", ROOT, "-s", "tools/random_sim.gd", "--",
           f"--start={start}", f"--count={count}", f"--out={out}", f"--cap={cap}"]
    result = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", shell=(os.name == "nt"))
    if result.returncode != 0 or "SCRIPT ERROR" in result.stdout + result.stderr:
        raise RuntimeError(f"worker {start} failed:\n{result.stdout[-2000:]}\n{result.stderr[-2000:]}")
    return out


def play_round(index, matches, workers, cap, seed_base):
    os.makedirs(RUNS, exist_ok=True)
    per = math.ceil(matches / workers)
    jobs = []
    for w in range(workers):
        count = min(per, matches - w * per)
        if count <= 0: break
        jobs.append((seed_base + w * per, count, os.path.join(RUNS, f"round{index}_w{w}.jsonl"), cap))
    with ThreadPoolExecutor(len(jobs)) as pool:
        files = list(pool.map(run_worker, jobs))
    results = []
    for path in files:
        for line in open(path, encoding="utf-8"):
            if line.strip(): results.append(json.loads(line))
    return results


def analyse(results, cards):
    stat = {k: [0.0, 0] for k in cards if k != "farm"}  # kind -> [wins, games]
    lords = {}
    red = [0, 0]
    draws = 0
    lengths = []
    for r in results:
        w = r["winner"]
        if w < 0: draws += 1
        else:
            red[0] += w == 0
            red[1] += 1
            lengths.append(r["t"])
        score = [0.5, 0.5] if w < 0 else [1.0 if w == 0 else 0.0, 1.0 if w == 1 else 0.0]
        a, b = set(r["decks"][0]), set(r["decks"][1])
        for side, own, other in ((0, a, b), (1, b, a)):
            for kind in own - other:
                stat[kind][0] += score[side]
                stat[kind][1] += 1
        la, lb = r["lords"]
        if la != lb:
            for side, lord in ((0, la), (1, lb)):
                s = lords.setdefault(lord, [0.0, 0])
                s[0] += score[side]
                s[1] += 1
    lengths.sort()
    breaches = sorted(r["breach"] for r in results if r.get("breach", -1) >= 0)
    lost = [n for r in results for n in r.get("farms_lost_early", [])]
    skills = [n for r in results for n in r.get("skills", [])]
    return {
        "breach": breaches[len(breaches) // 2] if breaches else -1,
        "farms_lost": sum(lost) / len(lost) if lost else 0,
        "skills": sum(skills) / len(skills) if skills else 0,
        "cards": {k: (v[0] / v[1] if v[1] else 0.5, v[1]) for k, v in stat.items()},
        "lords": {k: (v[0] / v[1] if v[1] else 0.5, v[1]) for k, v in lords.items()},
        "red_rate": red[0] / red[1] if red[1] else 0.5,
        "draws": draws,
        "median": lengths[len(lengths) // 2] if lengths else 0,
        "matches": len(results),
    }


def adjust(analysis, cards, threshold, step):
    """Cost change per card: proportional to how far from 50% it is, at least 1, at most 25% of cost."""
    changes = {}
    for kind, (rate, games) in analysis["cards"].items():
        gap = rate - 0.5
        if abs(gap) < threshold or games < 50: continue
        cost = cards[kind][1]
        delta = max(1, round(abs(gap) * cost * step))
        delta = min(delta, max(1, round(cost * 0.25)))
        new = max(MIN_COST, min(MAX_COST, cost + (delta if gap > 0 else -delta)))
        if new != cost: changes[kind] = new
    return changes


def table(analysis, cards, changes):
    rows = ["| 卡牌 | 費用 | 勝率 | 場次 | 調整 |", "|---|---|---|---|---|"]
    for kind, (rate, games) in sorted(analysis["cards"].items(), key=lambda kv: -kv[1][0]):
        change = f"{cards[kind][1]} → {changes[kind]}" if kind in changes else ""
        rows.append(f"| {cards[kind][0]} | {cards[kind][1]} | {rate:.1%} | {games} | {change} |")
    lords = ", ".join(f"{k} {v[0]:.1%}（{v[1]}）" for k, v in sorted(analysis["lords"].items(), key=lambda kv: -kv[1][0]))
    head = (f"{analysis['matches']} 場；平手 {analysis['draws']}；決勝局中位數 {analysis['median']:.0f} 秒；"
            f"紅方勝率 {analysis['red_rate']:.1%}\n\n"
            f"前 3 分鐘每方平均被拆農田 {analysis['farms_lost']:.2f} 塊；第一次破門中位數 {analysis['breach']:.0f} 秒；每方平均發動領主技能 {analysis['skills']:.2f} 次\n\n領主勝率（雙方領主不同時）：{lords}\n")
    return head + "\n" + "\n".join(rows)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--total", type=int, default=10000)
    p.add_argument("--rounds", type=int, default=5)
    p.add_argument("--workers", type=int, default=max(1, (os.cpu_count() or 2) - 1))
    p.add_argument("--cap", type=float, default=900)
    p.add_argument("--threshold", type=float, default=0.03, help="ignore cards within this of 50%%")
    p.add_argument("--step", type=float, default=1.0, help="cost change = gap x cost x step (damped later)")
    p.add_argument("--dry-run", action="store_true", help="measure only, never edit balance.gd")
    p.add_argument("--adjust-last", action="store_true", help="the last round adjusts too (default: it only measures)")
    args = p.parse_args()

    per_round = args.total // args.rounds
    start_costs = {k: v[1] for k, v in read_cards().items()}
    log = [f"# 自動平衡報告\n\n{time.strftime('%Y-%m-%d %H:%M')}：共 {args.total} 場隨機牌組＋隨機領主的 AI 對戰，"
           f"分 {args.rounds} 輪，每輪 {per_round} 場。每輪後依卡牌勝率調整費用（只改費用，數值檔次不動）。"
           f"勝率只計算「只有一方帶這張牌」的對局；平手算半勝。\n"]
    for r in range(args.rounds):
        cards = read_cards()
        t0 = time.time()
        results = play_round(r, per_round, args.workers, args.cap, seed_base=1 + r * 1_000_000)
        analysis = analyse(results, cards)
        last = r == args.rounds - 1 and not args.adjust_last
        # Damp later rounds so costs settle instead of swinging.
        changes = {} if (args.dry_run or last) else adjust(analysis, cards, args.threshold, args.step / (1 + r))
        section = f"\n## 第 {r + 1} 輪（{time.time() - t0:.0f} 秒）\n\n" + table(analysis, cards, changes) + "\n"
        print(section, flush=True)
        log.append(section)
        if changes: write_costs(changes)
        open(REPORT, "w", encoding="utf-8").write("".join(log))
    final = {k: v[1] for k, v in read_cards().items()}
    diff = [f"| {read_cards()[k][0]} | {start_costs[k]} | {final[k]} |" for k in final if final[k] != start_costs[k]]
    log.append("\n## 費用總變動\n\n| 卡牌 | 原費用 | 新費用 |\n|---|---|---|\n" + "\n".join(diff) + "\n" if diff else "\n## 費用總變動\n\n無。\n")
    open(REPORT, "w", encoding="utf-8").write("".join(log))
    print("report:", REPORT)


if __name__ == "__main__":
    sys.exit(main())
