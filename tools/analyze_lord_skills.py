import json, collections, pathlib

def main():
    runs_dir = pathlib.Path("five-lane-lords/tools/autobalance_runs")
    files = list(runs_dir.glob("*.jsonl"))
    print(f"Found {len(files)} run files.")
    
    matches = []
    seen_seeds = set()
    for f in sorted(files, key=lambda x: x.stat().st_mtime, reverse=True):
        for line in f.read_text(encoding="utf-8").splitlines():
            if not line.strip(): continue
            try:
                r = json.loads(line)
                # Ensure unique match by seed or use all matches
                # If seed exists, use (seed, r.get('t', 0)) as key
                key = (r.get("seed"), r.get("t"), tuple(r.get("lords", [])))
                if key not in seen_seeds:
                    seen_seeds.add(key)
                    matches.append(r)
            except Exception:
                pass

    print(f"Total unique matches parsed: {len(matches)}")
    if not matches:
        return

    # Data structures:
    # lord -> {
    #   'total': int,
    #   'wins': float,
    #   'skill_counts': list of ints,
    #   'wins_with_skill': float,
    #   'games_with_skill': int,
    #   'wins_without_skill': float,
    #   'games_without_skill': int,
    #   'by_skill_num': defaultdict(list), # num -> [scores]
    #   'duration_with_skill': list,
    #   'duration_without_skill': list
    # }
    lord_data = collections.defaultdict(lambda: {
        'total': 0,
        'wins': 0.0,
        'wins_with_skill': 0.0,
        'games_with_skill': 0,
        'wins_without_skill': 0.0,
        'games_without_skill': 0,
        'by_skill_num': collections.defaultdict(list),
        'duration_with_skill': [],
        'duration_without_skill': [],
        'skill_total': 0
    })

    for m in matches:
        lords = m.get("lords", [])
        if len(lords) != 2: continue
        winner = m.get("winner", -1)
        skills = m.get("skills", [0, 0])
        dur = m.get("t", 0.0)

        # We evaluate each side
        for side in range(2):
            lord = lords[side]
            foe_lord = lords[1 - side]
            # Mirror match or different lord?
            # In general statistics, check both or non-mirror
            score = 0.5
            if winner == side: score = 1.0
            elif winner == 1 - side: score = 0.0

            sk = skills[side] if len(skills) > side else 0
            
            d = lord_data[lord]
            d['total'] += 1
            d['wins'] += score
            d['skill_total'] += sk
            d['by_skill_num'][sk].append(score)

            if sk > 0:
                d['games_with_skill'] += 1
                d['wins_with_skill'] += score
                d['duration_with_skill'].append(dur)
            else:
                d['games_without_skill'] += 1
                d['wins_without_skill'] += score
                d['duration_without_skill'].append(dur)

    print("\n" + "="*95)
    print("=== 各領主「使用技能 vs 未使用技能」對勝率的影響分析 ===")
    print("="*95)
    header = f"{'領主 (Lord)':<12} {'總場次':<6} {'總勝率':<7} {'技能率%':<8} {'場均技能':<8} {'施放技能勝率':<12} {'未施放勝率':<10} {'勝率差 (Δ)':<10} {'技能局時長':<10} {'未施放時長':<10}"
    print(header)
    print("-" * 95)

    for lord in sorted(lord_data.keys()):
        d = lord_data[lord]
        tot = d['total']
        if tot == 0: continue
        wr = d['wins'] / tot
        gw = d['games_with_skill']
        gwo = d['games_without_skill']
        rate = gw / tot
        avg_sk = d['skill_total'] / tot
        wr_w = (d['wins_with_skill'] / gw) if gw > 0 else 0.0
        wr_wo = (d['wins_without_skill'] / gwo) if gwo > 0 else 0.0
        diff = wr_w - wr_wo
        dur_w = (sum(d['duration_with_skill']) / len(d['duration_with_skill'])) if d['duration_with_skill'] else 0.0
        dur_wo = (sum(d['duration_without_skill']) / len(d['duration_without_skill'])) if d['duration_without_skill'] else 0.0

        sign = "+" if diff >= 0 else ""
        print(f"{lord:<12} {tot:<6} {wr*100:5.1f}%  {rate*100:6.1f}%   {avg_sk:6.2f}   {wr_w*100:5.1f}% ({gw:<4})  {wr_wo*100:5.1f}% ({gwo:<4}) {sign}{diff*100:5.1f}%     {dur_w:6.1f}s     {dur_wo:6.1f}s")

    print("\n" + "="*95)
    print("=== 技能施放次數階梯勝率 (Skill Frequency Breakdown: 0次 / 1次 / 2次 / 3次以上) ===")
    print("="*95)
    print(f"{'領主 (Lord)':<12} {'0次勝率 (場次)':<18} {'1次勝率 (場次)':<18} {'2次勝率 (場次)':<18} {'3+次勝率 (場次)':<18}")
    print("-" * 80)
    for lord in sorted(lord_data.keys()):
        d = lord_data[lord]
        res = []
        for tier in [0, 1, 2]:
            scs = d['by_skill_num'][tier]
            if scs:
                res.append(f"{sum(scs)/len(scs)*100:5.1f}% ({len(scs):<4})")
            else:
                res.append("  —  (0   )")
        # 3+
        scs3 = []
        for k, v in d['by_skill_num'].items():
            if k >= 3: scs3.extend(v)
        if scs3:
            res.append(f"{sum(scs3)/len(scs3)*100:5.1f}% ({len(scs3):<4})")
        else:
            res.append("  —  (0   )")
        print(f"{lord:<12} {res[0]:<18} {res[1]:<18} {res[2]:<18} {res[3]:<18}")

if __name__ == "__main__":
    main()
