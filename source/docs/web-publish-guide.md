# 免費公開網頁版（已完成）

## 直接遊玩

<https://zianyu503-art.github.io/infinite-legion-wildland-expedition/>

- 手機、平板與桌面瀏覽器可使用同一網址。
- 不需帳號、不需下載；觸控裝置會自動顯示雙虛擬搖桿。
- 手機請使用橫向；直向時遊戲會顯示旋轉提示。
- 介面會依裝置語言選擇繁體中文或英文，也可在標題／暫停畫面手動切換。
- 支援的瀏覽器可選擇「加入主畫面／安裝 App」，使用 1024×1024 蟒皇圖標以 PWA 方式啟動。

## 發布位置

- 公開成品倉庫：<https://github.com/zianyu503-art/infinite-legion-wildland-expedition>
- 發布來源：`main` 分支根目錄。
- 倉庫只包含 Godot 編譯後的 Web 成品；本機 GDScript 開發原始碼沒有放入公開倉庫。
- GitHub Pages 使用 HTTPS，WebAssembly、PCK、manifest 與 service worker 已逐一確認回傳 `200`。

## 已完成外網驗證

- 844×390 手機橫向視窗可正常載入。
- 自動偵測為 `touch`，不需要手動切換。
- 實際觸控開始遊戲、拖動左搖桿移動、拖動右搖桿攻擊均成功。
- PWA manifest、landscape 方向與 144／180／512 圖標已發布。
- 瀏覽器控制台 0 errors；僅有截圖時可能出現不影響遊玩的 WebGL `ReadPixels` 效能提示。

## 本機備份測試

```bash
cd '/Users/alex/Documents/New project 53'
python3 -m http.server 8060 --directory build/web --bind 127.0.0.1
```

接著開啟 <http://127.0.0.1:8060/>。一般使用者不需要執行這些指令，直接使用上方公開網址即可。
