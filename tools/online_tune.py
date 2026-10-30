"""Online cost tuning: a small cost step after every single match.

    python tools/online_tune.py --matches 500 [--step 0.04] [--apply]

Random-deck, random-lord AI matches run in batches of --workers at once (each batch uses the costs
as they stand); after each match, in seed order, every card held by only the winner gains --step
gold and every card held by only the loser loses --step (draws change nothing; home cards like the
farm and the tombstone are not tuned). Costs are kept as decimals and rounded for play, so many
small steps add up to a whole gold.

The result is not the last, noisy cost but its expected value: the average of each card's cost
over the matches after the burn-in (--burn, default the first half). The report
(docs/線上調費報告.md) lists start, expected cost, spread and win rates; --apply writes the rounded
expected costs into balance.gd. Matches run in a frozen copy of the committed code (git HEAD), so
edits in the working tree during the run do not mix in.
"""
import argparse, io, json, math, os, shutil, statistics, subprocess, sys, tarfile, tempfile, time
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import autobalance as ab  # card table reading and writing

ROOT = ab.ROOT
REPORT = os.path.join(ROOT, "docs", "線上調費報告.md")
HOME_CARDS = {"farm", "grave"}  # fixed F-slot cards, never in the chosen eight
MIN_COST, MAX_COST = 1.0, 30.0


def make_sandbox(path):
    if os.path.exists(path):
        shutil.rmtree(path)
    os.makedirs(path)
    files = subprocess.run(["git", "ls-files", "*.gd", "project.godot"], cwd=ROOT, capture_output=True, text=True, check=True).stdout.split()
    archive = subprocess.run(["git", "archive", "HEAD"] + files, cwd=ROOT, capture_output=True, check=True).stdout
    tarfile.open(fileobj=io.BytesIO(archive)).extractall(path)


def play(job):
    sandbox, seed, out = job
    cmd = ["godot_console", "--headless", "--path", sandbox, "-s", "tools/random_sim.gd", "--", f"--start={seed}", "--count=1", f"--out={out}"]
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", shell=(os.name == "nt"))
    if r.returncode != 0 or "SCRIPT ERROR" in r.stdout + r.stderr:
        raise RuntimeError(f"match {seed} failed:\n{r.stdout[-1500:]}\n{r.stderr[-1500:]}")
    return json.loads(open(out, encoding="utf-8").readline())


def rounded(x):
    return int(math.floor(x + 0.5))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--matches", type=int, default=500)
    p.add_argument("--step", type=float, default=0.04, help="gold per match per card (+ winner only, - loser only)")
    p.add_argument("--burn", type=float, default=0.5, help="share of matches before the averaging starts")
    p.add_argument("--workers", type=int, default=max(1, (os.cpu_count() or 2) - 1))
    p.add_argument("--seed", type=int, default=700_000)
    p.add_argument("--sandbox", default=os.path.join(tempfile.gettempdir(), "five_lane_online_tune"))
    p.add_argument("--apply", action="store_true", help="write the rounded expected costs into balance.gd")
    args = p.parse_args()

    make_sandbox(args.sandbox)
    runs = os.path.join(args.sandbox, "runs")
    os.makedirs(runs)
    real_balance = ab.BALANCE
    ab.BALANCE = os.path.join(args.sandbox, "balance.gd")
    cards = ab.read_cards()
    names = {k: v[0] for k, v in cards.items()}
    start = {k: float(v[1]) for k, v in cards.items() if k not in HOME_CARDS}
    cost = dict(start)
    history = {k: [] for k in cost}
    outcomes = {k: [] for k in cost}  # (match number, 1 win / 0 loss) when only one side held the card
    draws = 0
    t0 = time.time()
    done = 0
    seed = args.seed
    with ThreadPoolExecutor(args.workers) as pool:
        while done < args.matches:
            batch = min(args.workers, args.matches - done)
            jobs = [(args.sandbox, seed + i, os.path.join(runs, f"m{seed + i}.jsonl")) for i in range(batch)]
            for r in pool.map(play, jobs):  # results come back in seed order
                done += 1
                w = r["winner"]
                if w < 0:
                    draws += 1
                else:
                    a, b = set(r["decks"][0]), set(r["decks"][1])
                    for side, own, other in ((0, a, b), (1, b, a)):
                        for k in own - other:
                            if k not in cost:
                                continue
                            won = w == side
                            cost[k] = min(MAX_COST, max(MIN_COST, cost[k] + (args.step if won else -args.step)))
                            outcomes[k].append((done, 1 if won else 0))
                for k in cost:
                    history[k].append(cost[k])
            seed += batch
            ab.write_costs({k: rounded(v) for k, v in cost.items()})
            moved = sorted(cost, key=lambda k: -abs(cost[k] - start[k]))[:4]
            print(f"{done}/{args.matches} matches, {time.time() - t0:.0f} s; biggest moves: " +
                  ", ".join(f"{names[k]} {start[k]:g}->{cost[k]:.2f}" for k in moved), flush=True)

    burn = int(args.matches * args.burn)
    rows = []
    for k in cost:
        tail = history[k][burn:]
        mean = statistics.fmean(tail)
        spread = statistics.pstdev(tail)
        first = [o for n, o in outcomes[k] if n <= burn]
        second = [o for n, o in outcomes[k] if n > burn]
        rate = lambda xs: f"{sum(xs) / len(xs):.0%}（{len(xs)}）" if xs else "—"
        rows.append((rounded(mean) - start[k], k, start[k], mean, spread, rounded(mean), rate(first), rate(second)))
    rows.sort(key=lambda r: (-abs(r[0]), -r[3]))
    text = [f"# 線上調費報告\n\n{time.strftime('%Y-%m-%d %H:%M')}：{args.matches} 場隨機牌組＋隨機領主的 AI 對戰；每場後只有贏方帶的牌 +{args.step:g}、只有輸方帶的牌 −{args.step:g} 金幣"
            f"（平手 {draws} 場不調）。每批 {args.workers} 場同時進行。期望費用＝第 {burn + 1}–{args.matches} 場的費用平均；常駐牌（農田、墓碑）不調。總耗時 {(time.time() - t0) / 60:.0f} 分鐘。\n\n"
            "| 卡牌 | 原費用 | 期望費用（平均） | 標準差 | 建議費用 | 前半勝率（場次） | 後半勝率（場次） |\n|---|---|---|---|---|---|---|\n"]
    for delta, k, s, mean, spread, new, r1, r2 in rows:
        text.append(f"| {names[k]} | {s:g} | {mean:.2f} | {spread:.2f} | **{new}**{'（' + ('+' if delta > 0 else '') + str(int(delta)) + '）' if delta else ''} | {r1} | {r2} |\n")
    text.append("\n後半勝率越接近 50%，代表費用已經接近平衡點；標準差大表示這張牌的結果起伏大，建議費用的把握較低。\n")
    open(REPORT, "w", encoding="utf-8").write("".join(text))
    print("".join(text))
    if args.apply:
        ab.BALANCE = real_balance
        changes = {k: new for delta, k, s, mean, spread, new, r1, r2 in rows if delta}
        if changes:
            ab.write_costs(changes)
        print("applied to balance.gd:", changes)
    print("report:", REPORT)


if __name__ == "__main__":
    sys.exit(main())
