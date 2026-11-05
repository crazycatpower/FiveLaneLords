import os, sys, math, json, re, time, subprocess
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BALANCE = os.path.join(ROOT, "balance.gd")
RUNS = os.path.join(ROOT, "tools", "autobalance_runs")
REPORT = os.path.join(ROOT, "docs", "部隊單位全體100場以上平衡性微調報告.md")
MIN_COST, MAX_COST = 1, 30
WORKERS = 10
PER_MATCH_DELTA = 0.16
TARGET_GAMES_PER_UNIT = 100

def round_half_up(val):
    return int(math.floor(val + 0.5))

def read_cards():
    cards = {}
    for line in open(BALANCE, encoding="utf-8"):
        m = re.match(r'\t"(\w+)":\{"name":"([^"]+)".*?"type":"(\w+)".*?"cost":(\d+)', line)
        if m:
            kind, name, ctype, cost = m.group(1), m.group(2), m.group(3), int(m.group(4))
            series = ""
            m_s = re.search(r'"series":"(\w+)"', line)
            if m_s: series = m_s.group(1)
            summon_only = '"summon_only":true' in line
            cards[kind] = {
                "name": name,
                "type": ctype,
                "cost": cost,
                "series": series,
                "summon_only": summon_only
            }
    return cards

def write_costs(new_costs):
    text = open(BALANCE, encoding="utf-8").read()
    for kind, cost in new_costs.items():
        pattern = r'(\t"%s":\{"name":"[^"]+".*?"type":"\w+".*?"cost":)\d+' % kind
        text, n = re.subn(pattern, lambda m: m.group(1) + str(cost), text, count=1)
        assert n == 1, kind
    open(BALANCE, "w", encoding="utf-8", newline="").write(text)

def run_worker(args):
    start, count, out, cap, must_have = args
    cmd = ["godot_console", "--headless", "--path", ROOT, "-s", "tools/random_sim.gd", "--",
           f"--start={start}", f"--count={count}", f"--out={out}", f"--cap={cap}"]
    if must_have: cmd.append(f"--must-have-lords={must_have}")
    result = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", shell=(os.name == "nt"))
    if result.returncode != 0 or "SCRIPT ERROR" in result.stdout + result.stderr:
        raise RuntimeError(f"worker {start} failed:\n{result.stdout[-2000:]}\n{result.stderr[-2000:]}")
    return out

def play_batch(batch_idx, matches, workers, cap, seed_base, must_have=""):
    os.makedirs(RUNS, exist_ok=True)
    per = math.ceil(matches / workers)
    jobs = []
    for w in range(workers):
        count = min(per, matches - w * per)
        if count <= 0: break
        jobs.append((seed_base + w * per, count, os.path.join(RUNS, f"tune_{batch_idx}_w{w}.jsonl"), cap, must_have))
    with ThreadPoolExecutor(len(jobs)) as pool:
        files = list(pool.map(run_worker, jobs))
    results = []
    for path in files:
        for line in open(path, encoding="utf-8"):
            if line.strip(): results.append(json.loads(line))
    return results

def main():
    print(f"--- 啟動部隊單位全體平衡微調 ---")
    print(f"目標：全體部隊單位非鏡像場次均 >= {TARGET_GAMES_PER_UNIT} 場")
    print(f"每場勝負調整費率：{PER_MATCH_DELTA} 金幣")
    
    cards = read_cards()
    playable_units = [k for k, v in cards.items() if v["type"] == "unit" and not v["summon_only"]]
    print(f"共有 {len(playable_units)} 種可登場部隊單位卡牌。")
    
    start_costs = {k: v["cost"] for k, v in cards.items()}
    float_costs = {k: float(v["cost"]) for k, v in cards.items()}
    
    # Tracking
    unit_games = {u: 0 for u in playable_units}
    unit_wins = {u: 0.0 for u in playable_units}
    
    all_results = []
    batch_idx = 0
    current_seed = 20261104
    t_start = time.time()
    
    # 1. Main loop until every unit reaches >= 100 matches
    while True:
        min_g = min(unit_games.values())
        min_units = [u for u, g in unit_games.items() if g == min_g]
        print(f"\n[進度] 當前部隊最低場次：{min_g}/{TARGET_GAMES_PER_UNIT} 場 (最低者: {min_units[:3]} 等 {len(min_units)} 種)")
        
        if min_g >= TARGET_GAMES_PER_UNIT:
            print(f"所有 {len(playable_units)} 種部隊單位皆已達標 (>= {TARGET_GAMES_PER_UNIT} 場)！")
            break
            
        batch_idx += 1
        
        # Decide targeted lords if needed to help lagging units catch up
        lagging = [u for u in playable_units if unit_games[u] < TARGET_GAMES_PER_UNIT]
        lagging_series = {cards[u]["series"] for u in lagging}
        
        must_have = ""
        # If all lagging units are from dark or magic series, focus lord pool to speed up drafting
        if lagging_series == {"dark"}:
            must_have = "underworld,vampire"
        elif lagging_series == {"magic"}:
            must_have = "mage,rune"
        elif "dark" in lagging_series and "magic" in lagging_series and "normal" not in lagging_series and "" not in lagging_series:
            must_have = "underworld,vampire,mage,rune"
        elif "dark" in lagging_series and "magic" not in lagging_series:
            must_have = "underworld,vampire"
        elif "magic" in lagging_series and "dark" not in lagging_series:
            must_have = "mage,rune"
            
        batch_size = 50 if min_g >= 80 else 70
        print(f">> 執行批次 #{batch_idx}: 規模 {batch_size} 場, 聚焦領主={must_have or '全部隨機'}...")
        t0 = time.time()
        
        batch_res = play_batch(batch_idx, batch_size, WORKERS, 900.0, current_seed, must_have)
        current_seed += batch_size + 10
        all_results.extend(batch_res)
        
        # Process batch results
        for r in batch_res:
            w = r["winner"]
            a = set(r["decks"][0])
            b = set(r["decks"][1])
            
            # Non-mirror units
            for u in playable_units:
                in_a = u in a
                in_b = u in b
                if in_a ^ in_b:
                    unit_games[u] += 1
                    side = 0 if in_a else 1
                    if w < 0:
                        unit_wins[u] += 0.5
                    elif w == side:
                        unit_wins[u] += 1.0
                        float_costs[u] = min(float(MAX_COST), float_costs[u] + PER_MATCH_DELTA)
                    else:
                        float_costs[u] = max(float(MIN_COST), float_costs[u] - PER_MATCH_DELTA)
        
        print(f"批次 #{batch_idx} 完成 ({time.time() - t0:.1f} 秒). 累計總對局數: {len(all_results)} 場.")
        
    t_elapsed = time.time() - t_start
    print(f"\n全部模擬結束！總計進行 {len(all_results)} 場對局，耗時 {t_elapsed:.1f} 秒。")
    print(f"部隊最低場次: {min(unit_games.values())} 場，最高場次: {max(unit_games.values())} 場。")
    
    # 2. Compute final costs
    cost_changes = {}
    for u in playable_units:
        final_int = max(MIN_COST, min(MAX_COST, round_half_up(float_costs[u])))
        if final_int != start_costs[u]:
            cost_changes[u] = final_int
            
    print(f"\n費用調整結果 ({len(cost_changes)} 張卡牌調整):")
    for u, new_c in cost_changes.items():
        print(f"  {cards[u]['name']} ({u}): {start_costs[u]} -> {new_c} (浮點={float_costs[u]:.2f}, 勝率={unit_wins[u]/unit_games[u]:.1%}, 場次={unit_games[u]})")
        
    if cost_changes:
        print("\n寫入 balance.gd 更新卡牌成本...")
        write_costs(cost_changes)
        
    # 3. Compute general statistics
    stat_all = {k: [0.0, 0] for k in cards if k not in ["farm", "grave", "crystal"]}
    lords = {}
    red = [0, 0]
    draws = 0
    lengths = []
    breaches = []
    farms_lost = []
    skills = []
    
    for r in all_results:
        w = r["winner"]
        if w < 0: draws += 1
        else:
            red[0] += (w == 0)
            red[1] += 1
            lengths.append(r["t"])
        if r.get("breach", -1) >= 0:
            breaches.append(r["breach"])
        farms_lost.extend(r.get("farms_lost_early", []))
        skills.extend(r.get("skills", []))
        
        score = [0.5, 0.5] if w < 0 else [1.0 if w == 0 else 0.0, 1.0 if w == 1 else 0.0]
        a, b = set(r["decks"][0]), set(r["decks"][1])
        for side, own, other in ((0, a, b), (1, b, a)):
            for kind in own - other:
                if kind in stat_all:
                    stat_all[kind][0] += score[side]
                    stat_all[kind][1] += 1
        la, lb = r["lords"]
        if la != lb:
            for side, lord in ((0, la), (1, lb)):
                s = lords.setdefault(lord, [0.0, 0])
                s[0] += score[side]
                s[1] += 1
                
    lengths.sort()
    breaches.sort()
    
    totals = {k: dict(samples=0, plays=0, first=[], damage=0.0, spent=0.0, damage_avail=True) for k in cards}
    for result in all_results:
        for side in result.get("card_stats", []):
            for kind, value in side.items():
                if kind not in totals: continue
                row = totals[kind]
                row["samples"] += 1
                row["plays"] += value["plays"]
                if value["first_play"] is not None:
                    row["first"].append(value["first_play"])
                if value["damage"] is None:
                    row["damage_avail"] = False
                else:
                    row["damage"] += value["damage"]
                row["spent"] += value["spent"]
                
    card_details = {}
    for kind, v in totals.items():
        card_details[kind] = {
            "samples": v["samples"],
            "plays_per_match": v["plays"] / v["samples"] if v["samples"] else None,
            "first_play": sum(v["first"]) / len(v["first"]) if v["first"] else None,
            "damage_per_gold": v["damage"] / v["spent"] if v["damage_avail"] and v["spent"] else None,
        }
        
    # 4. Generate Markdown report
    lines = []
    lines.append("# 部隊單位全體 100 場以上平衡性微調報告\n")
    lines.append(f"**測試規模**：共進行 {len(all_results)} 場對局，達成全體 27 種部隊單位**非鏡像對局皆 $\\ge 100$ 場**。10 執行緒平行運算耗時 {t_elapsed:.1f} 秒。")
    lines.append(f"**微調規則**：每場勝負累積 $\\pm {PER_MATCH_DELTA}$ 金幣浮點權重，浮點四捨五入結算整數費用。")
    lines.append(f"**戰局總體指標**：平局率 {draws/len(all_results):.1%}（{draws} 場），完賽中位時長 {lengths[len(lengths)//2]:.1f} 秒，紅方勝率 {red[0]/red[1]:.1%}。")
    lines.append(f"**戰局節奏**：前 3 分鐘每方平均被拆農田 {sum(farms_lost)/len(farms_lost):.2f} 座；首破城門中位時間 {breaches[len(breaches)//2]:.1f} 秒；每方平均施放技能 {sum(skills)/len(skills):.2f} 次。\n")
    
    lines.append("## 領主勝率分佈（對抗數據）")
    lord_names = {
        "mage": "法師領主", "adventure": "邊境領主", "lion": "紅獅領主",
        "rune": "符文領主", "harvest": "豐收領主", "iron": "鐵壁領主",
        "underworld": "冥府領主", "vampire": "吸血領主"
    }
    for l_id, val in sorted(lords.items(), key=lambda kv: -kv[1][0]/kv[1][1] if kv[1][1] else 0):
        rate = val[0]/val[1] if val[1] else 0.5
        lines.append(f"- **{lord_names.get(l_id, l_id)}** ({l_id})：勝率 {rate:.1%}（{val[1]} 場非鏡像）")
        
    lines.append("\n## 部隊單位微調結算表（全部 >= 100 場）\n")
    lines.append("| 部隊名稱 (Card ID) | 原始費用 | 浮點累積 | 非鏡像勝率 | 樣本場次 | 每場出牌 | 每金幣傷害 | 首出牌時間 | 費用微調 |")
    lines.append("|---|---|---|---|---|---|---|---|---|")
    
    # Sort units by win rate
    sorted_units = sorted(playable_units, key=lambda u: -(unit_wins[u]/unit_games[u] if unit_games[u] else 0.5))
    for u in sorted_units:
        info = cards[u]
        rate = unit_wins[u] / unit_games[u] if unit_games[u] else 0.5
        g = unit_games[u]
        fc = float_costs[u]
        sc = start_costs[u]
        
        det = card_details.get(u, {})
        ppm = f"{det['plays_per_match']:.2f}" if det.get('plays_per_match') is not None else "—"
        dpg = f"{det['damage_per_gold']:.2f}" if det.get('damage_per_gold') is not None else "—"
        fp = f"{det['first_play']:.1f} 秒" if det.get('first_play') is not None else "—"
        
        change_text = ""
        final_int = round_half_up(fc)
        if final_int != sc:
            diff = final_int - sc
            diff_sign = f"+{diff}" if diff > 0 else f"{diff}"
            change_text = f"**{sc} → {final_int}** ({diff_sign})"
            
        lines.append(f"| {info['name']} (`{u}`) | {sc} | {fc:.2f} | **{rate:.1%}** | **{g}** | {ppm} | {dpg} | {fp} | {change_text} |")
        
    lines.append("\n## 非部隊卡牌（建築與法術）參照數據\n")
    lines.append("| 卡牌名稱 (Card ID) | 當前費用 | 非鏡像勝率 | 樣本場次 | 每場出牌 | 每金幣傷害 | 首出牌時間 |")
    lines.append("|---|---|---|---|---|---|---|")
    non_units = [k for k in cards if cards[k]["type"] != "unit" and k not in ["farm", "grave", "crystal"]]
    for kind in sorted(non_units, key=lambda k: -(stat_all.get(k, [0, 0])[0]/stat_all.get(k, [0, 1])[1] if stat_all.get(k, [0, 0])[1] else 0.5)):
        info = cards[kind]
        s = stat_all.get(kind, [0.0, 0])
        rate = s[0] / s[1] if s[1] else 0.5
        g = s[1]
        det = card_details.get(kind, {})
        ppm = f"{det['plays_per_match']:.2f}" if det.get('plays_per_match') is not None else "—"
        dpg = f"{det['damage_per_gold']:.2f}" if det.get('damage_per_gold') is not None else "—"
        fp = f"{det['first_play']:.1f} 秒" if det.get('first_play') is not None else "—"
        lines.append(f"| {info['name']} (`{kind}`) | {info['cost']} | {rate:.1%} | {g} | {ppm} | {dpg} | {fp} |")
        
    lines.append("\n## 深度平衡性調整分析\n")
    lines.append("### 1. 本次調費結算與影響")
    if cost_changes:
        for u, new_c in cost_changes.items():
            diff = new_c - start_costs[u]
            lines.append(f"- **{cards[u]['name']}**：費用自 **{start_costs[u]} 金** 調整為 **{new_c} 金**（浮點累積 {float_costs[u]:.2f}，非鏡像勝率 {unit_wins[u]/unit_games[u]:.1%}，樣本 {unit_games[u]} 場）。")
    else:
        lines.append("- 全體部隊單位在 100+ 場大樣本測試下，成本浮點均未跨過 $\\pm 0.5$ 四捨五入閾值，現有費用結構穩定。")
        
    lines.append("\n### 2. 高勝率部隊表現")
    top_3 = sorted_units[:3]
    for u in top_3:
        lines.append(f"- **{cards[u]['name']}** (`{u}`)：勝率 **{unit_wins[u]/unit_games[u]:.1%}**（樣本 {unit_games[u]} 場，浮點 {float_costs[u]:.2f}）。")
        
    lines.append("\n### 3. 低勝率部隊表現")
    bottom_3 = sorted_units[-3:]
    for u in bottom_3:
        lines.append(f"- **{cards[u]['name']}** (`{u}`)：勝率 **{unit_wins[u]/unit_games[u]:.1%}**（樣本 {unit_games[u]} 場，浮點 {float_costs[u]:.2f}）。")

    open(REPORT, "w", encoding="utf-8").write("\n".join(lines))
    print(f"\n報告已完整寫入: {REPORT}")

if __name__ == "__main__":
    main()
