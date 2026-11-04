import json, collections, pathlib

def main():
    p = pathlib.Path("five-lane-lords/.runtime/grave-study/dark_study_combined.jsonl")
    if not p.exists():
        print("No file found.")
        return
    rows = [json.loads(s) for s in p.read_text(encoding="utf-8").splitlines() if s.strip()]
    print(f"Total rows: {len(rows)}")

    # 1. Total Goal Analysis (lane_cap == 99)
    by_goal = collections.defaultdict(list)
    by_lord_goal = collections.defaultdict(list)

    # 2. Lane Cap Analysis (goal == 4)
    by_cap = collections.defaultdict(list)
    by_lord_cap = collections.defaultdict(list)

    for r in rows:
        if r.get("lane_cap") == 99:
            by_goal[r["goal"]].append(r)
            by_lord_goal[(r["lord"], r["goal"])].append(r)
        if r["goal"] == 4 and r.get("lane_cap") in [1, 2, 3, 4]:
            by_cap[r["lane_cap"]].append(r)
            by_lord_cap[(r["lord"], r["lane_cap"])].append(r)

    print("\n" + "="*80)
    print("=== PART 1: 全局墓碑目標數分析 (Total Grave Goal, lane_cap=99) ===")
    print("="*80)
    print(f"{'Goal':<6} {'N':<5} {'Win%':<7} {'Peak':<6} {'Mean':<6} {'1-Lane-Peak':<12} {'Prod':<7} {'Spent':<6} {'Sec':<6}")
    print("-" * 75)
    for g, items in sorted(by_goal.items()):
        n = len(items)
        wr = sum(x["score"] for x in items) / n
        peak = sum(x["peak"] for x in items) / n
        mean = sum(x["mean_count"] for x in items) / n
        lane_peak = sum(x.get("peak_in_one_lane", 0) for x in items) / n
        prod = sum(x["produced"] for x in items) / n
        spent = sum(x.get("economy_spent", 0) for x in items) / n
        sec = sum(x["seconds"] for x in items) / n
        print(f"{g:<6} {n:<5} {wr*100:5.1f}% {peak:6.2f} {mean:6.2f} {lane_peak:12.2f} {prod:7.1f} {spent:6.1f} {sec:6.1f}")

    print("\n--- 分領主 (Lord x Goal) ---")
    print(f"{'Lord':<12} {'Goal':<6} {'N':<5} {'Win%':<7} {'Peak':<6} {'1-Lane-Peak':<12} {'Prod':<7} {'Sec':<6}")
    print("-" * 70)
    for (lord, g), items in sorted(by_lord_goal.items()):
        n = len(items)
        wr = sum(x["score"] for x in items) / n
        peak = sum(x["peak"] for x in items) / n
        lane_peak = sum(x.get("peak_in_one_lane", 0) for x in items) / n
        prod = sum(x["produced"] for x in items) / n
        sec = sum(x["seconds"] for x in items) / n
        print(f"{lord:<12} {g:<6} {n:<5} {wr*100:5.1f}% {peak:6.2f} {lane_peak:12.2f} {prod:7.1f} {sec:6.1f}")

    print("\n" + "="*80)
    print("=== PART 2: 同路最多蓋幾座墓碑分析 (Max Graves Per Lane, Goal=4) ===")
    print("="*80)
    print(f"{'LaneCap':<9} {'N':<5} {'Win%':<7} {'Peak':<6} {'1-Lane-Peak':<12} {'Prod':<7} {'Spent':<6} {'Sec':<6}")
    print("-" * 70)
    for cap, items in sorted(by_cap.items()):
        n = len(items)
        wr = sum(x["score"] for x in items) / n
        peak = sum(x["peak"] for x in items) / n
        lane_peak = sum(x.get("peak_in_one_lane", 0) for x in items) / n
        prod = sum(x["produced"] for x in items) / n
        spent = sum(x.get("economy_spent", 0) for x in items) / n
        sec = sum(x["seconds"] for x in items) / n
        print(f"{cap:<9} {n:<5} {wr*100:5.1f}% {peak:6.2f} {lane_peak:12.2f} {prod:7.1f} {spent:6.1f} {sec:6.1f}")

    print("\n--- 分領主 (Lord x LaneCap) ---")
    print(f"{'Lord':<12} {'LaneCap':<9} {'N':<5} {'Win%':<7} {'Peak':<6} {'1-Lane-Peak':<12} {'Prod':<7} {'Sec':<6}")
    print("-" * 70)
    for (lord, cap), items in sorted(by_lord_cap.items()):
        n = len(items)
        wr = sum(x["score"] for x in items) / n
        peak = sum(x["peak"] for x in items) / n
        lane_peak = sum(x.get("peak_in_one_lane", 0) for x in items) / n
        prod = sum(x["produced"] for x in items) / n
        sec = sum(x["seconds"] for x in items) / n
        print(f"{lord:<12} {cap:<9} {n:<5} {wr*100:5.1f}% {peak:6.2f} {lane_peak:12.2f} {prod:7.1f} {sec:6.1f}")

if __name__ == "__main__":
    main()
