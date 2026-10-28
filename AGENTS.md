# AGENTS.md — 羊皮紙戰記（five-lane-lords）

- 企劃與任務清單：`docs/企劃書.md`（v4.1：墨水上限 50＋8 張牌組輪轉；卡牌分部隊／建築／法術；農田像向日葵自己產墨水、沒有上限；農民是部隊，經過農田時停下耕地加速；部隊只往前走不回頭；雙方領主完全由 AI 接管；16:9）。照「第三部：實作任務」的順序做，一次一個任務。
- 目前程式還是 v1（金幣、農田收入、WASD 操作領主、計時出兵、1280×950、部隊會回頭追擊）；會在 T0–T4 逐步被取代。
- Godot 4.7.1；測試：`godot_console --headless --path . -s smoke_test.gd`（回傳 0 才算完成）。新規則要在 smoke_test.gd 用 `check()` 加檢查。
- 有畫面改動時，不加 `--headless` 跑一次會重拍 `preview.png`，看過再交。
- 不要改回去的設計：領主由 `game.gd` 統一繪製、`layout_formations` 只影響畫面、城門停點不變量（企劃書第 7 節）、戰鬥中按 R 不重開、農田不設數量上限。
- 新美術素材的 prompt 要存進 `assets/manuscript-v1/` 的 json/txt。
- 遇到企劃書「待製作人決定的事」先問，不要自己決定。
