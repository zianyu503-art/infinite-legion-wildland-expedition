# 手機與網頁版商店簡介（繁中 / English）

公開遊玩／Play now: <https://zianyu503-art.github.io/infinite-legion-wildland-expedition/>

## 中文版

### 應用名稱
**《無盡軍勢：荒原遠征》**

### 副標題
無限草原動作戰鬥 × 軍隊養成 × 城堡征服

### 短版介紹
《無盡軍勢：荒原遠征》是可直接開玩、可切換中英的 2D 俯視角戰鬥遊戲。角色在無限草原探索、擊潰敵軍、招募士兵、佔領城堡，並挑戰「腐沼蟒皇・薩迦」三階段世界 Boss。

### 詳細介紹
- 遊戲採程序式無限地圖，區域與事件持續生成，離開畫面中心後仍能回到先前地圖並保持探索進度。
- 初始為出生房屋安全區，玩家需推進防線後進入野外，擊敗七類蠻族敵人與各類特殊據點。
- 每 45 秒自動存檔，支援讀檔後快速接續。
- 8 種士兵可招募與培養：劍士、醫者、弓兵、滾石兵、法師、重甲兵、牧師、大砲。
- 3 職業可選擇：弓箭手、法師、戰士；每次遠征選定一職，並可透過「英雄技能」進階控制輸出與控場。
- 世界 Boss「腐沼蟒皇・薩迦」有 18 節蛇身、11 狀態 FSM、3 階段、5 大主動技能，含地圖標誌與發現→交戰→擊敗後破巢轉變流程。
- 內建中文/英文即時切換（可由標題/暫停按鈕切換），同一局存檔可跨兩語系閱讀。
- 輕量程式化音效與特效，啟動快速；可用滑鼠鍵盤，也可用虛擬搖桿觸控。

### 玩法與操作（關鍵）
#### 桌機
- `Enter / 點擊開始`：進入遊戲
- `WASD`：移動
- 滑鼠左鍵：一般攻擊
- 滑鼠右鍵：等級 10 解鎖技能
- `E`：靠近據點招募士兵（含 Shift 一次購買 5 名）
- `C`：開啟能力升級
- `1 / 2 / 3 / 4`：全軍命令（跟隨、防守、攻擊、撤退）
- `M`：開關大地圖
- `Esc`：暫停
- `H`：新手指南顯示開關

#### 手機 / 觸控
- 左側虛擬搖桿：移動
- 右側虛擬搖桿：瞄準與持續射擊
- 上方功能鈕：開關說明、地圖、能力、招募、軍令與暫停
- 下方技能鈕：釋放英雄技能
- 會自動偵測觸控設備，使用鍵鼠時會自動切回桌機輸入；直向手機會提示轉成橫向。
- 可由支援的手機瀏覽器加入主畫面，作為 PWA 獨立啟動。

### 已完成圖片與素材（全部取自實際遊戲）
- 應用圖標：`assets/app/app_icon.png`
- 截圖 1（英文標題）：`output/marketing/title-en-mobile.png`
- 截圖 2（公開網址手機實玩）：`output/marketing/public-mobile-live.png`
- 截圖 3（英文蟒皇觸控戰鬥）：`output/marketing/python-boss-touch-en.png`
- 截圖 4（中文蟒皇觸控戰鬥）：`output/marketing/python-boss-touch-zh.png`
- 截圖 5（直向旋轉提示）：`output/marketing/rotate-device-zh.png`

圖標以遊戲實際蟒皇戰鬥畫面為唯一角色參考，保留深綠蟒首、黃色蛇眼、紫色面部節點、分節蛇身與同款盤蛇巢環；沒有換成另一隻蛇或不同角色造型。

### 隱私聲明
- 遊戲存檔只放在本機瀏覽器／裝置儲存空間，不會由遊戲上傳個資。
- 無第三方帳號登入、無分析追蹤 SDK、無社群綁定，不收集通訊錄、定位、麥克風或相機資料。
- 公開版由 GitHub Pages 提供靜態檔案；主機可能依 GitHub 隱私政策處理一般網頁連線紀錄，但遊戲本身沒有加入分析或追蹤程式。

## English Version

### App Name
**Infinite Legion: Wildland Expedition**

### Play Now
<https://zianyu503-art.github.io/infinite-legion-wildland-expedition/>

### Subtitle
Infinite Top-Down Action Combat × Army Building × Castle Conquest

### Short Description
An instant-play, bilingual (Chinese/English) top-down 2D action strategy game. Explore a procedural wildland, recruit troops, capture castles, and take on the **Corrupt Python Emperor · Saga** world boss.

### Long Description
- The game runs on an endless procedurally generated map. Move beyond the starting safe house, clear barbarian camps, and keep pushing toward stronger threats.
- A full 2D action combat loop: light attacks, timed special abilities, crowd control, and army command coordination.
- Recruit and upgrade eight soldier units (Swordsman, Healer, Ranger, Boulder Trooper, Mage, Heavy Guard, Priest, Cannon).
- Three playable heroes (Archer / Mage / Warrior) with leveling and ability progression.
- Every run is auto-saved every 45 seconds; quick load keeps progression intact.
- World Boss system: **Corrupt Python Emperor · Saga** has 18 body segments, 11 state-machine behaviors, 3 phases, and 5 active skills, with visible map markers and progression from discovery to clear/defeat state.
- Built for keyboard/mouse and touch screens. Touch controls automatically activate on mobile/virtual-touch devices; switching input style is seamless.
- All in-game text can be switched between Traditional Chinese and English.

### Controls (Cross-Device)
- Desktop: `WASD`, left/right mouse buttons, `E`, `C`, `1/2/3/4`, `M`, `Esc`, `H`.
- Mobile: left stick move, right stick aim + hold-to-fire, top utility buttons (Guide / Map / Abilities / Recruit / Orders / Pause), dedicated Skill button. Portrait screens show a rotate-to-landscape prompt.
- Supported mobile browsers can install the game as a standalone PWA through Add to Home Screen / Install App.

### Finished Store Assets (Captured from the Real Game)
- App icon: `assets/app/app_icon.png`
- Screenshots:
  - `output/marketing/title-en-mobile.png`
  - `output/marketing/public-mobile-live.png`
  - `output/marketing/python-boss-touch-en.png`
  - `output/marketing/python-boss-touch-zh.png`
  - `output/marketing/rotate-device-zh.png`

### Privacy Note
- No account system, no ads, no in-app purchases.
- The game collects no personal data; save and gameplay data remain in the device/browser. GitHub Pages may process ordinary web request logs under GitHub's privacy policy, but the game includes no analytics or tracking SDK.
