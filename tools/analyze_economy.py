import json, collections, pathlib

def analyze(round_dirs):
    all_records = []
    for rd in round_dirs:
        p = pathlib.Path(rd) / "combined.jsonl"
        if p.exists():
            for line in p.read_text(encoding="utf-8").splitlines():
                if line.strip():
                    all_records.append(json.loads(line))
    
    if not all_records:
        print("No records found.")
        return

    print(f"Total records analyzed: {len(all_records)}")
    by_faction_goal = collections.defaultdict(list)
    by_lord_goal = collections.defaultdict(list)

    for r in all_records:
        by_faction_goal[(r["faction"], r["goal"])].append(r)
        by_lord_goal[(r["lord"], r["goal"])].append(r)

    print("\n=== FACTION x GOAL SUMMARY ===")
    print(f"{'Faction':<10} {'Goal':<5} {'N':<5} {'Win%':<7} {'Peak':<6} {'Mean':<6} {'60s':<5} {'120s':<5} {'180s':<5} {'Prod':<7} {'Spent':<6} {'Sec':<6}")
    print("-" * 75)
    for (fac, g), items in sorted(by_faction_goal.items()):
        n = len(items)
        wr = sum(x["score"] for x in items) / n
        peak = sum(x["peak"] for x in items) / n
        mean = sum(x["mean_count"] for x in items) / n
        c60 = sum(x["checkpoints"].get("60", 0) for x in items) / n
        c120 = sum(x["checkpoints"].get("120", 0) for x in items) / n
        c180 = sum(x["checkpoints"].get("180", 0) for x in items) / n
        prod = sum(x["produced"] for x in items) / n
        spent = sum(x.get("economy_spent", 0) for x in items) / n
        sec = sum(x["seconds"] for x in items) / n
        print(f"{fac:<10} {g:<5} {n:<5} {wr*100:5.1f}% {peak:6.2f} {mean:6.2f} {c60:5.2f} {c120:5.2f} {c180:5.2f} {prod:7.1f} {spent:6.1f} {sec:6.1f}")

    print("\n=== LORD x GOAL SUMMARY ===")
    print(f"{'Lord':<12} {'Goal':<5} {'N':<5} {'Win%':<7} {'Peak':<6} {'Mean':<6} {'Prod':<7} {'Spent':<6} {'Sec':<6}")
    print("-" * 65)
    for (lord, g), items in sorted(by_lord_goal.items()):
        n = len(items)
        wr = sum(x["score"] for x in items) / n
        peak = sum(x["peak"] for x in items) / n
        mean = sum(x["mean_count"] for x in items) / n
        prod = sum(x["produced"] for x in items) / n
        spent = sum(x.get("economy_spent", 0) for x in items) / n
        sec = sum(x["seconds"] for x in items) / n
        print(f"{lord:<12} {g:<5} {n:<5} {wr*100:5.1f}% {peak:6.2f} {mean:6.2f} {prod:7.1f} {spent:6.1f} {sec:6.1f}")

if __name__ == "__main__":
    import sys
    dirs = sys.argv[1:] if len(sys.argv) > 1 else ["five-lane-lords/.runtime/economy-study/round-0"]
    analyze(dirs)
