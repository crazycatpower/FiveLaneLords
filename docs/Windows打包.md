# Windows 玩家版

輸出位置：專案旁的 `release/FiveLaneLords/FiveLaneLords.exe`。
單一 Windows x86_64 EXE，資源內嵌，不需要 Godot 安裝環境。
`export_presets.cfg` 排除企劃文件、測試、預覽圖和製作提示詞。

## 重建

使用 Godot 4.7.1，官方 Windows release 匯出模板放在
`.runtime/windows-templates/windows_release_x86_64.exe`。
新增中文字後先執行 `python tools/build_font.py`。
執行 `tools/build_windows.ps1` 重建 EXE 與 ZIP。

## 本次清理

移除已解壓的全平台模板下載檔、三份舊驗收副本的 `.godot`
匯入快取，以及 Python 快取，共 1,728,616,225 bytes（約 1.61 GiB）。
保留美術原稿、開發文件、存檔和既有備份。

## 驗收與限制

已直接啟動 release EXE，操作主選單、自由對戰及出牌，確認 AI 正常運作。
操作說明曾超框，已精簡過時的四領主文字、縮小字級並重新匯出。

發布前全量測試有 1107 項、19 項失敗（包含修正前的說明超框）：
8 個舊黃金對局基準、召喚物費用說明 2 項、舊生命/數值/技能預期及提示數量。
沒有為了讓測試變綠而重錄或覆蓋這些基準；完整紀錄保留在
`.runtime/release-smoke.log`。本包可供試玩，尚不宣稱全量回歸通過。
