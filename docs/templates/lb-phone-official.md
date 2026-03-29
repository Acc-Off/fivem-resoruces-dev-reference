# lb-phone-app-template（LB Phone 公式テンプレート）

> GitHub: https://github.com/lbphone/lb-phone-app-template

LB Phone 公式が提供するカスタムアプリ向けテンプレートです。React JS / React TS / Vue JS / Vanilla JS の4バリアントが用意されており、lb-phone アプリ開発の基本パターンを学ぶのに最適です。

---

## リポジトリ構成

```
fxmanifest.lua          ← リソース定義
config.lua              ← アプリメタデータ（識別子・名前・説明等）
client/
  client.lua            ← アプリ登録 + NUIコールバック + メインループ
  functions.lua         ← SendAppMessage ヘルパー関数
ui/                     ← Vite + React (または Vue / Vanilla) UI
  package.json
  vite.config.ts
  src/
    main.tsx
    App.tsx
```

---

## fxmanifest.lua

```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

shared_script 'config.lua'
client_script 'client/**.lua'

ui_page 'ui/dist/index.html'
files { 'ui/dist/**' }
```

---

## config.lua

```lua
Config = {}

Config.Identifier   = "myapp"          -- 一意識別子（英数字のみ）
Config.Name         = "My App"          -- 電話上の表示名
Config.Description  = "アプリの説明"
Config.Developer    = "開発者名"
Config.DefaultApp   = true             -- trueにするとデフォルトでインストール済み
```

---

## アプリ登録（client/client.lua）

```lua
local resourceName = GetCurrentResourceName()

-- lb-phoneが起動してから登録する
CreateThread(function()
    while GetResourceState('lb-phone') ~= 'started' do
        Wait(500)
    end
    Wait(500)

    exports["lb-phone"]:AddCustomApp({
        identifier  = Config.Identifier,
        name        = Config.Name,
        description = Config.Description,
        developer   = Config.Developer,
        defaultApp  = Config.DefaultApp,
        ui          = resourceName .. "/ui/dist/index.html",
        icon        = "https://cfx-nui-" .. resourceName .. "/ui/dist/icon.png",
        fixBlur     = true,
        onUse   = function() end,
        onClose = function() end,
    })
end)
```

---

## Lua ↔ UI 通信

### Lua → UI（SendCustomAppMessage）

```lua
-- client/functions.lua
function SendAppMessage(data)
    exports["lb-phone"]:SendCustomAppMessage(Config.Identifier, data)
end

-- 使用例
SendAppMessage({ type = "updateData", data = someTable })
```

### UI → Lua（fetchNui / RegisterNuiCallback）

```lua
-- client/client.lua
RegisterNuiCallback('getData', function(requestData, cb)
    -- requestData: UIから送られたデータ
    -- cb: UIにレスポンスを返すコールバック
    local result = { status = 'ok', items = someItems }
    cb(result)
end)
```

```tsx
// UI側 (React)
import { fetchNui } from '../utils/fetchNui';

const result = await fetchNui<{ status: string; items: Item[] }>('getData', {
    filter: 'active'
});
```

---

## UI 初期化（必須パターン）

```tsx
// src/main.tsx
const devMode = !window?.['invokeNative'];

function renderApp() {
    createRoot(document.getElementById('root')!).render(
        <React.StrictMode><App /></React.StrictMode>
    );
}

if (devMode) {
    renderApp();
} else {
    window.addEventListener('message', (event) => {
        if (event.data === 'componentsLoaded') renderApp();
    });
}
```

```css
/* src/index.css */
body {
    visibility: hidden;  /* lb-phone が制御するまで非表示 */
    margin: 0;
    padding: 0;
}
```

---

## Vite 設定（vite.config.ts）

```ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig(({ command }) => ({
    plugins: [react()],
    base: command === 'build' ? '/ui/dist' : undefined,  // 本番ビルド時は必須
    define: { global: 'window' },
    server: { port: 3000, open: true },
}));
```

---

## テーマ対応

lb-phone のテーマ（ライト/ダーク）に対応するには CSS 変数を使います。

```css
:root {
    --background-primary:   #f5f5f5;
    --background-highlight: rgb(220, 220, 220);
    --text-primary:         #000000;
    --text-secondary:       #8e8e93;
}

[data-theme='dark'] {
    --background-primary:   #000000;
    --background-highlight: rgb(20, 20, 20);
    --text-primary:         #f2f2f7;
    --text-secondary:       #6f6f6f;
}
```

テーマの読み取りと適用:

```tsx
const settings = await window.getSettings();
document.documentElement.setAttribute('data-theme', settings.display.theme);

// 設定変更のリスナー
window.onSettingsChange((settings) => {
    document.documentElement.setAttribute('data-theme', settings.display.theme);
});
```

---

## 関連ドキュメント

- [アプリ登録 — AddCustomApp パラメータ全解説](../lb-phone/app-registration.md)
- [Lua ↔ UI 通信パターン](../lb-phone/lua-ui-communication.md)
- [テーマと CSS 変数](../lb-phone/themes-and-css.md)
- [グローバル UI API](../lb-phone/global-ui-api.md)
