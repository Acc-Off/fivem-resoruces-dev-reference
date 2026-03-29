# FiveM-phone — マルチフレームワーク lb-phone アプリコレクション

> GitHub: https://github.com/Greigh/FiveM-phone  
> 作者: Greigh  
> フレームワーク: ESX / QBCore / QBX（自動検出）  
> UI: Vanilla JS + HTML（Vite なし）

ESX・QBCore・QBX に対応したユニバーサルな lb-phone カスタムアプリのコレクションです。5 つのアプリが単体リソースとして独立して提供され、共通ライブラリ `shared/phone_framework.lua` でマルチフレームワーク対応を実現しています。

---

## 収録アプリ一覧

| アプリ | 説明 | DB 必要 | カテゴリ |
|--------|------|---------|---------|
| **invoicing** | 請求書の作成・管理（税・手数料・ビジネス対応） | ✅ | business |
| **notes** | メモアプリ（カテゴリ・検索・オートセーブ） | ✅ | productivity |
| **business_cards** | 名刺作成・共有 | ✅ | business |
| **calculator** | 計算機（履歴付き） | ❌ | utilities |
| **gallery** | 写真ストレージ管理 | ✅ | entertainment |

---

## フォルダ構成

```
FiveM-phone-main/
  shared/
    phone_framework.lua       ← 共通: マルチフレームワーク + lb-phone 統合ライブラリ
  invoicing/
    fxmanifest.lua
    config.lua
    sql.sql
    client/client.lua
    server/server.lua
    html/
      index.html              ← Vite ビルドなし、直接 HTML ファイル
      style.css
      script.js
  notes/          （同様の構成）
  business_cards/ （同様の構成）
  calculator/     （DB 不要、server.lua なし）
  gallery/        （同様の構成）
```

---

## 学べるパターン

### 1. shared/phone_framework.lua — マルチフレームワーク共通ライブラリ

全アプリから `require 'shared.phone_framework'` でロードされる抽象層。  
フレームワーク・電話システムを自動検出し、差異を吸収する。

```lua
-- フレームワーク自動検出（CreateThread 内）
CreateThread(function()
    if GetResourceState('es_extended') == 'started' then
        FrameworkType = 'ESX'
        Framework.ESX = exports['es_extended']:getSharedObject()
    elseif GetResourceState('qb-core') == 'started' then
        FrameworkType = 'QB'
        Framework.QBCore = exports['qb-core']:GetCoreObject()
    elseif GetResourceState('qbx_core') == 'started' then
        FrameworkType = 'QBX'
        Framework.QBX = exports.qbx_core
    end

    -- 電話システム自動検出
    if GetResourceState('lb-phone') == 'started' then
        PhoneType = 'LB'
    elseif GetResourceState('qb-phone') == 'started' then
        PhoneType = 'QB'
    end
end)
```

提供する共通関数:

| 関数 | 説明 |
|------|------|
| `PhoneApps.RegisterApp(config)` | 電話システム対応アプリ登録 |
| `PhoneApps.GetPlayerData()` | フレームワーク対応プレイヤーデータ取得 |
| `PhoneApps.FormatPlayerData(data)` | ESX/QB 形式の差異を統一形式に変換 |
| `PhoneApps.TriggerCallback(name, cb, ...)` | フレームワーク対応コールバック呼び出し |
| `PhoneApps.SendPhoneNotification(app, title, msg, duration)` | lb-phone 通知送信 |
| `PhoneApps.RegisterEvents(appName)` | フレームワーク・電話システム対応イベント登録 |

### 2. アプリ登録パターン（phone_framework.lua 経由）

```lua
-- nui:// スキームによる UI パス指定
PhoneApps.RegisterApp = function(appConfig)
    if PhoneType == 'LB' then
        exports['lb-phone']:AddCustomApp({
            identifier    = appConfig.identifier,
            name          = appConfig.name,
            description   = appConfig.description,
            developer     = appConfig.developer or "Greigh",
            version       = appConfig.version or "1.0.0",
            ui            = ("nui://%s/html/index.html"):format(appConfig.identifier),
            icon          = appConfig.icon,
            iconBackground = appConfig.color,
            size          = appConfig.size or 1024,
            price         = 0,
            category      = appConfig.category or "productivity",
        })
    end
end
```

> **注意**: `ui` に `nui://` スキームを使用（`GetCurrentResourceName()` + パス方式ではない）。`onUse` / `fixBlur` は未設定。

### 3. クライアント初期化パターン（Wait + RegisterEvents）

```lua
local PhoneApps = require 'shared.phone_framework'
local isNuiOpen = false

-- Wait(2000) で他リソースの起動を待機してから登録
CreateThread(function()
    Wait(2000)
    PhoneApps.RegisterApp(Config.PhoneApp)
    PhoneApps.RegisterEvents('invoicing')
end)

-- アプリ起動イベント（lb-phone → client）
RegisterNetEvent('invoicing:client:openApp', function()
    if isNuiOpen then return end
    isNuiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action     = "openApp",
        playerData = PhoneApps.FormatPlayerData(playerData),
        config     = Config,
    })
end)

-- NUI → Client（閉じる）
RegisterNUICallback('closeApp', function(data, cb)
    isNuiOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

-- NUI → Server（コールバック経由）
RegisterNUICallback('getInvoices', function(data, cb)
    PhoneApps.TriggerCallback('invoicing:server:getInvoices', function(invoices)
        cb(invoices)
    end)
end)
```

### 4. サーバー側のコールバックラッパー

`server.lua` は各アプリに直接フレームワーク検出コードを記述（`phone_framework.lua` はクライアント専用）。

```lua
local function CreateCallback(name, cb)
    if FrameworkType == 'ESX' then
        Framework.RegisterServerCallback(name, cb)
    elseif FrameworkType == 'QB' or FrameworkType == 'QBX' then
        Framework.Functions.CreateCallback(name, cb)
    end
end

-- 使用例：SQL は ox_lib / mysql-async 経由
CreateCallback('invoicing:server:getInvoices', function(source, cb)
    local Player = GetPlayerFromId(source)
    local identifier = GetPlayerIdentifier(Player)
    local invoices = MySQL.query.await(
        'SELECT * FROM invoices WHERE sender_citizenid = ?', { identifier })
    cb(invoices or {})
end)
```

### 5. UI（Vanilla JS）— componentsLoaded 未対応

```javascript
// lb-phone の componentsLoaded 待機は実装されていない
// 直接 'openApp' メッセージで起動する
window.addEventListener('message', function(event) {
    if (event.data?.action === 'openApp') {
        playerData = event.data.playerData;
        config     = event.data.config;
        openApp();
    }
});

// NUI コールバック呼び出し（fetch パターン）
async function loadInvoices() {
    const response = await fetch(
        `https://${GetParentResourceName()}/getInvoices`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({}),
    });
    const invoices = await response.json();
    renderInvoices(invoices);
}
```

### 6. fxmanifest.lua — 独自リソースとして独立

```lua
shared_scripts {
    '@ox_lib/init.lua',
    '../shared/phone_framework.lua',  -- ★ 親ディレクトリ参照
    'config.lua',
}

client_scripts { 'client/client.lua' }
server_scripts { 'server/server.lua' }

-- Vite ビルドなし、直接 HTML を指定
ui_page 'html/index.html'
files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/img/**',
}
```

---

## このリポジトリで学べること

- **マルチフレームワーク抽象化**: 単一ライブラリで ESX/QB/QBX を透過的に扱う設計
- **ビルドなし UI**: Vite を使わない Vanilla JS + HTML の最小構成
- **親ディレクトリ共有スクリプト**: 複数リソースで `shared/` を参照する `fxmanifest.lua` の書き方
- **電話システム自動検出**: lb-phone / qb-phone などを同一コードで動作させる切り替えパターン
