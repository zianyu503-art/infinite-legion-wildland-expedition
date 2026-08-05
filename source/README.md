# Infinite Legion: Wildland Expedition／《無盡軍勢：荒原遠征》

可直接遊玩的 Godot 4.6 俯視角 2D 動作戰鬥／軍隊養成遊戲，同時提供原生桌面版與已匯出的瀏覽器版。世界依固定種子以 Chunk 持續生成；玩家探索草原與稀疏分布的蟒蛇 Boss 巢穴、招募 12 種士兵、挑戰蟒蛇世界 Boss，並攻略 20／30／35／40／45／50 級科技城堡取得被動收入。角色、環境、UI、粒子特效與音效皆由程式產生。

## 直接啟動

已安裝 Godot 且 `godot` 位於 PATH 時：

```bash
cd '/Users/alex/Documents/New project 53'
godot --path .
```

本機也可直接使用目前安裝位置：

```bash
'/opt/homebrew/bin/godot' --path '/Users/alex/Documents/New project 53'
```

要在 Godot 編輯器開啟：

```bash
godot --editor --path '/Users/alex/Documents/New project 53'
```

## 瀏覽器版

**公開免費遊玩連結（手機／平板／電腦）：**

<https://zianyu503-art.github.io/infinite-legion-wildland-expedition/>

不需安裝、不需登入；手機請轉成橫向。支援的瀏覽器可從選單使用「加入主畫面／安裝 App」，之後會以獨立 PWA 視窗啟動。

專案內已附可直接供應的 Web 匯出檔。瀏覽器版已啟用 PWA 設定（含 manifest 與安裝流程），可於手機/平板直接全螢幕遊玩。

```bash
cd '/Users/alex/Documents/New project 53'
python3 -m http.server 8060 --directory build/web --bind 127.0.0.1
```

接著前往 <http://127.0.0.1:8060/>。

若你要在區網其他裝置連線，將 `--bind` 改為 `0.0.0.0` 即可讓同網段設備存取（需注意本機防火牆與網段安全）。

如需重新匯出 Web 版：

```bash
cd '/Users/alex/Documents/New project 53'
godot --headless --path . --export-release Web build/web/index.html
```

## 操作說明

- `Enter` / `Space` / 點擊「開始遠征」：從標題畫面開始。
- `1` / `2` / `3`：在職業畫面選擇弓箭手、法師或戰士。
- `W` `A` `S` `D`：八方向移動。
- 滑鼠：瞄準。
- 按住滑鼠左鍵：普通攻擊。
- 滑鼠右鍵：施放等級 10 解鎖的職業技能。
- `E` / `B`：靠近出生房屋或友方城堡時開關招募面板。
- `Shift` + 點擊「招募」：一次購買最多 5 名同兵種士兵。
- `C`：角色能力面板；點擊 `+` 消耗技能點升級。
- `1` / `2` / `3` / `4` / `5` / `6`：遊戲中命令軍隊跟隨、防守、攻擊、撤退、駐守、攻城。
- `M`：開關大地圖。
- `H`：顯示或隱藏新手指南。
- `Esc`：暫停、關閉面板或返回。
- `F`：切換全螢幕。
- `F5`：手動存檔。
- `F9`：快速讀檔。
- `L` 或標題畫面右上角按鈕：繁體中文 / English 切換。

- 地形特性：岩石與灌木可通行；樹木會阻擋地面單位，士兵會自動改道躲避樹木。
- `6`（攻城）：會先清除目標附近守軍，再對外牆／核心發起進攻。
- 蟒蛇 Boss 的主巢出生區與繞樹路徑已修正，不會再原地卡死；敵軍改為逐畫面平滑移動，戰鬥時不再走走停停。

### 手機／觸控

- 左搖桿：移動。
- 右搖桿：瞄準並持續攻擊。
- `技能`：施放等級 10 解鎖的職業技能。
- `說明`：顯示／隱藏觸控教學。
- `地圖`、`能力`、`招募`、`軍令`、`暫停`：開啟對應功能。
- 被蟒皇纏縛時，連點右側攻擊區掙脫。
- 觸控、鍵盤與滑鼠會依最後使用的輸入裝置自動切換；直向手機會提示轉成橫向。
- 開始按鈕與選角卡使用獨立觸碰事件；同一個 tap 不會穿透畫面自動選中法師，弓箭手、法師與戰士都可正常選擇。

## Web/English Quick Start

- Language auto-detect: `zh-*` locale -> Traditional Chinese, otherwise English.
- You can always toggle in game at title screen or in pause menu.
- Mobile devices: touch controls and two virtual joysticks are auto-enabled when touch input is detected.

## Play on Other Devices

- Public game URL: <https://zianyu503-art.github.io/infinite-legion-wildland-expedition/>
- No account or installation is required. On supported mobile browsers, use **Add to Home Screen / Install App** for the PWA experience.
- Exported web files are also available locally under `build/web/`.

## 免費外網連結（給手機/平板分享）

已完成部署與手機外網驗證，直接分享以下網址即可：

<https://zianyu503-art.github.io/infinite-legion-wildland-expedition/>

公開成品倉庫只包含編譯後網頁檔，不包含本機開發原始碼：<https://github.com/zianyu503-art/infinite-legion-wildland-expedition>。

## 玩法重點

1. 離開出生房屋的安全區，擊敗敵人取得金幣與經驗。
2. 每次升級獲得技能點；到達等級 10 解鎖職業特殊技能。
3. 回到出生房屋，或前往已佔領城堡，招募劍士、醫者、弓兵、滾石兵、法師、重甲兵、牧師、重型大砲、火槍手、突擊步槍手、坦克與火箭炮。
4. 使用數字鍵切換全軍命令；支援 `1`～`6` 分別為跟隨、防守、攻擊、撤退、駐守、攻城。
5. 攻城（`6`）會先清除目標附近敵方守軍，再鎖定外牆或主城，避免跳過防線。
6. 敵軍預判已保留，敵軍實際位移改為逐畫面更新，避免低頻 AI 決策造成跳動。
7. 岩石與灌木可通行，但樹木仍會阻擋；招募士兵會自動選擇繞行方向，若舊存檔中的士兵已嵌入樹幹也會自動脫離。
8. 軍隊上限為 `50 + floor(已擁有城堡等級總和 / 2)`，並以總已佔領城堡等級動態成長。
9. 清除營地可取得獎勵；營地經過一段時間後可能重新被佔據。
10. 將蠻族城堡生命降至零，再留在佔領範圍內數秒即可奪取。友方城堡會產生金幣、治療附近友軍，並成為招募與復活據點；40 級以上外牆會為玩家與招募士兵開啟友方通道，敵人仍會被擋在牆外。
11. 玩家死亡會損失目前金幣的 10%，數秒後在最近的友方據點復活。

## 世界 Boss：腐沼蟒皇・薩迦

強化版建議等級 10～14 並帶領完整混合部隊後挑戰。從出生房屋往右下方探索腐化草地與「蟒蛇 Boss 主巢」；主巢尚未被發現時，迷你地圖不會直接洩漏位置。發現後，小地圖與 `M` 大地圖會顯示綠色盤蛇／紫色巢環標誌；交戰時外圈閃爍，擊敗後則改為灰色破巢圖示。其他程序化 Boss 巢穴以 11×11 Chunk 大間距分布；靠近任何未清除巢穴時，都會由同一隻「腐沼蟒皇・薩迦」完整現身並開戰。同一時間只啟動一座巢穴，戰鬥中不會切換；擊破後會永久記錄該巢穴已清除，探索下一座未清除巢穴即可再次挑戰。

Boss 使用 18 節位置歷史蛇身、11 狀態 FSM、Utility AI 與威脅值系統，可在玩家與 12 種士兵之間選擇目標。強化版提高生命、基礎傷害、追擊速度、轉向與施招頻率；單次重擊仍保留生存下限，完整預警時間不縮短。空間雜湊、物件池、固定時間傷害 tick、掃掠碰撞與攻擊 ID 去重，分別負責大量單位查詢、特效重用、跨幀率一致性、高速命中，以及避免大砲同時撞到多節蛇身而重複傷害。

Boss 共有三個戰鬥階段，而且恰好只有以下五個主動技能：

- `絞蟒纏縛`：撲中瞬間先造成傷害，再持續擠壓。桌面版連點滑鼠左鍵、觸控版連點右側攻擊區掙脫；士兵會攻擊發光纏繞節點協助破壞掙脫值。
- `蛇影裂地衝`：鎖定預測位置後直線衝刺；誘導 Boss 撞上巨石、城牆或建築可使其暈眩。
- `腐牙噬咬`：前方扇形咬擊並疊加毒素，三層毒素會額外減速。
- `腐沼毒潭`：第一顆必定威脅預測位置，其餘投向士兵密集處；紫色毒潭落地與持續區域都會造成傷害並減速，但會保留逃生路線。
- `裂骨巨尾`：掃擊側面與後方的環形區域；貼近頭部內圈或離開橘紅色預警區可躲避。

擊敗 Boss 會播放完整死亡效果、清除剩餘毒潭，並一次性獲得 800～1200 金幣與 900～1400 經驗。發現、擊敗與獎勵領取狀態都會寫入存檔。

## 存檔與驗證

遊戲每 45 秒自動存檔，也可用 `F5` 儲存。檔名為：

```text
user://infinite_legion_save.json
```

執行內建 deterministic 測試：

```bash
cd '/Users/alex/Documents/New project 53'
godot --headless --path . -- --self-test
```

成功時終端會顯示 `SELF_TEST_PASS`。目前共有 **180** 項測試，涵蓋無限地圖／稀疏 Boss 巢穴、巢穴啟動與單一薩迦控制器、相鄰巢穴切換防抖、主巢標誌保留、巢穴清除／下一巢穴重生、主動巢穴存讀檔、友方城牆通道、敵我速度上限預判、六級科技城堡、12 兵種招募、重型大砲購買、蓄力／飛行／命中實戰比較、爆炸特效、場景隔離、觸控三職業選角與相容滑鼠去重、測試存檔保護與舊存檔升級、空地目標規則、UFO 光柱、城堡收入、雙語介面，以及 Boss 五技能全部可達且全部造成傷害、同幀傷害結算、單擊生存下限、11 狀態、18 節蛇身、三階段、部位傷害、投射物去重、死亡獎勵與安全存讀檔。

## 專案結構

- `project.godot`：Godot 專案與 GL Compatibility 設定。
- `main.tscn`：主場景。
- `scripts/main.gd`：遊戲迴圈、戰鬥、AI、UI、繪圖與測試。
- `scripts/python_boss.gd`：蟒蛇 Boss 的 FSM、Utility AI、分節身體、五技能、碰撞、狀態與存檔資料。
- `scripts/game_config.gd`：職業、兵種、敵人、Boss 與平衡資料。
- `scripts/world_generator.gd`：固定種子的 Chunk 世界生成；探索範圍無限，遠距舊區塊採有上限的串流歷史快取。
- `scripts/audio_manager.gd`：程序化音效。
- `scripts/save_manager.gd`：JSON 存讀檔與 Vector2 編解碼。
- `scripts/game_localization.gd`：繁體中文／英文介面與動態戰鬥文字。
- `build/web/`：可直接由 HTTP 伺服器供應的 Web 匯出成品。
- `assets/app/app_icon.png`：以真實遊戲內蟒皇造型製作的 1024×1024 App／PWA 圖標。
- `output/marketing/`：標題、觸控操作、蟒皇戰鬥、直向旋轉提示與公開網址實機截圖。
- `docs/mobile-store-listing.md`：繁中／英文商店簡介、控制說明、圖片清單與隱私文字。
- `assets/fonts/`：Web 版繁體中文所用 Noto Sans TC 字型與 SIL Open Font License 授權文字。

渲染器使用 GL Compatibility；Web 匯出使用 no-threads 模式，以便在一般本機 HTTP 伺服器直接執行。
