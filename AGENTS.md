> 製作人最新要求（2026-11-03）：單一卡牌／技能改動只跑專用測試與相關畫面驗收。全量回歸、黃金對局重錄及千場模擬留到正式整版發布，或製作人明確要求時才跑；不要每個小改動都執行。

# AGENTS.md — 羊皮紙戰記（five-lane-lords）

- **先讀 `docs/交接給Codex.md`**（現況、程式地圖、工作流程、陷阱、待辦），再讀 `docs/企劃書.md`（v6.9；最上方的版本紀錄是製作人一路下的決定）。
- 照交接文件第 7 節的待辦做，一次一項、一項一個 commit；標「問」的先問製作人，不要自己決定。
- Godot 4.7.1。測試：`godot_console --headless --path . -s smoke_test.gd`（回傳 0 才算完成）；新規則用 `check()` 加測試，數值從 `balance.gd` 讀。
- 有畫面改動：不加 `--headless` 跑一次測試重拍 preview 圖，戰鬥中途用 `tools/capture_battle.gd` 截圖，看過再交。新增中文字：`python tools/build_font.py` 後重新 import。
- 動到平衡：`python tools/autobalance.py --total 1000 --rounds 1 --dry-run` 只跑一次並回報（約 8 分鐘）；不要反覆長批次自己調數字。不加 `--dry-run` 會自動改費用，製作人要求時才用。
- 停模擬只停命令列含 `random_sim.gd`／`autobalance.py` 的程序；不要關掉所有 Godot（製作人的編輯器會一起被關）。
- 數值：部隊、箭樓、領主的攻擊／血量／射程／移速／攻擊間隔必須是 `B.TIERS` 的 S–E 檔次值（同檔同數值，測試會擋）；調強弱用費用、冷卻或換檔次。
- Git 基線（v1）：ff32c1c；每個改動一個 commit。
- 名詞：「墨水」已改名「金幣」（程式內部變數仍叫 ink）。牌組＝常駐農田（`Battle.FARM_SLOT`）＋領主（`B.LORDS` 四選一，Q 技能）＋自選 8 張。
- 美術：雙方共用一套圖，藍方由 `game.gd` 的 `recolor_blue()` 把紅色換成藍色，不要整張染色；新素材 prompt 存進 `assets/manuscript-v1/`。
- 新增卡牌／領主照 `docs/新增卡牌指南.md`；只改程式結構時黃金對局（`tools/golden_matches.json`）必須不變，有意改玩法才用 `tools/make_golden.gd` 重錄。
- 不要改回去的設計見交接文件第 5 節。
