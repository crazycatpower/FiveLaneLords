# AGENTS.md — 羊皮紙戰記（five-lane-lords）

- **先讀 `docs/交接給Codex.md`**（現況、程式地圖、工作流程、陷阱、待辦），再讀 `docs/企劃書.md`（v6.2；最上方的版本紀錄是製作人一路下的決定）。
- 企劃書第三部 T0–T10 已全部完成。接下來照交接文件第 7 節的待辦做，一次一項；標「問」的先問製作人，不要自己決定。
- Godot 4.7.1。測試：`godot_console --headless --path . -s smoke_test.gd`（回傳 0 才算完成）；新規則用 `check()` 加測試，數值從 `balance.gd` 讀。
- 有畫面改動：不加 `--headless` 跑一次測試重拍 preview 圖，看過再交。新增中文字：`python tools/build_font.py` 後重新 import。
- 動到平衡：`tools/sim.gd` 只跑一次並回報，不要反覆長批次自己調數字。
- Git 基線（v1）：ff32c1c；每個改動一個 commit。
- 名詞：「墨水」已改名「金幣」（程式內部變數仍叫 ink）。牌組＝常駐農田（`Battle.FARM_SLOT`）＋領主（`B.LORDS` 三選一）＋自選 8 張。
- 美術：雙方共用一套圖，藍方由 `game.gd` 的 `recolor_blue()` 把紅色換成藍色，不要整張染色；新素材 prompt 存進 `assets/manuscript-v1/`。
- 不要改回去的設計見交接文件第 5 節。
