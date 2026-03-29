# factionapp — ファクション管理アプリ

> GitHub: https://github.com/Panturien/factionapp  
> フレームワーク: ESX  
> UI: Vanilla JS + jQuery（Vite ビルドなし）

ESX ベースのファクション（ギャング・警察等）管理 lb-phone アプリです。メンバー一覧表示・在籍メンバーへの SMS/通話発信・MOTD（Message of the Day）の更新機能を持ちます。シンプルな Vanilla JS + HTML 構成のため、ビルドツール不要で動作する最も軽量な実装例です。

---

## フォルダ構成

```
fxmanifest.lua
client.lua              ← ESX 連携・NUIコールバック
server.lua              ← メンバー管理・MOTD・通話/SMS 統合
sql.sql                 ← jobs テーブルへの motd カラム追加
ui/
  index.html            ← 全 UI 定義（HTML + インライン CSS + インライン JS）
  script.js             ← jQuery + fetch で NUI 通信
  dev.js                ← ブラウザ開発用モックデータ
  fonts/css/app.css     ← スタイリング
```

---

## 学べるパターン

### 1. アプリ登録（Config.CustomApps 方式）

> **注意**: この方式は旧来の登録方法です。現在は `exports["lb-phone"]:AddCustomApp()` が推奨されます。

```lua
-- LB Phone 本体の config.lua に直接記述する方式
Config.CustomApps = {
    ["factionapp"] = {
        name        = "Faction App",
        description = "Manage your faction members",
        developer   = "開発者名",
        defaultApp  = true,
        game        = false,
        icon        = "https://cfx-nui-" .. GetCurrentResourceName() .. "/ui/icon.png",
        ui          = "factionapp/ui/index.html",
        price       = 0,
        landscape   = false,
        keepOpen    = true,
        onUse       = function() end,
        onServerUse = function(source) end
    }
}
```

推奨される `AddCustomApp` 方式に書き換えた場合:

```lua
-- client.lua
exports["lb-phone"]:AddCustomApp({
    identifier  = "factionapp",
    name        = "Faction App",
    description = "Manage your faction members",
    developer   = "開発者名",
    defaultApp  = true,
    ui          = GetCurrentResourceName() .. "/ui/index.html",
    icon        = "https://cfx-nui-" .. GetCurrentResourceName() .. "/ui/icon.png",
})
```

### 2. ビルドなし HTML 構成（fxmanifest.lua）

```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

client_script 'client.lua'
server_script 'server.lua'

ui_page 'ui/index.html'        -- ← 直接 HTML を指定
files {
    'ui/index.html',
    'ui/script.js',
    'ui/dev.js',
    'ui/fonts/**',
    'ui/css/**',
}
```

### 3. jQuery + fetch による NUI 通信

```javascript
// ui/script.js
async function nuiFetch(eventName, data) {
    const resp = await fetch(`https://${GetParentResourceName()}/${eventName}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    });
    return resp.json();
}

// アプリ起動時データ取得
const appData = await nuiFetch('apploaded', {});
renderMemberList(appData.members);
setMOTD(appData.motd);
```

```lua
-- client.lua
RegisterNuiCallback('apploaded', function(data, cb)
    ESX.TriggerServerCallback('factionapp:getAppData', function(result)
        cb(result)  -- members, motd, isBoss
    end)
end)
```

### 4. lb-phone API 活用（SMS / 通話）

```lua
-- server.lua: メンバーに SMS 送信
RegisterServerEvent('factionapp:messagePlayer', function(targetNumber, message)
    local src = source
    local myNumber = exports["lb-phone"]:GetEquippedPhoneNumber(src)
    exports["lb-phone"]:SendMessage(
        myNumber,      -- 送信者番号
        targetNumber,  -- 受信者番号
        message,       -- 本文
        nil, nil, nil
    )
end)

-- server.lua: メンバーに電話発信
RegisterServerEvent('factionapp:callPlayer', function(targetNumber)
    local src = source
    local myNumber = exports["lb-phone"]:GetEquippedPhoneNumber(src)
    exports["lb-phone"]:CreateCall(
        { phoneNumber = myNumber, source = src },
        targetNumber,
        { requirePhone = true, hideNumber = false }
    )
end)

-- server.lua: 通知送信
exports["lb-phone"]:SendNotification(source, {
    app     = "Messages",
    title   = "ファクション",
    content = "新しいメッセージがあります",
    icon    = iconUrl,
})
```

### 5. Vanilla JS から lb-phone コンポーネントを使う

```html
<!-- ui/index.html -->
<!-- lb-phone の components.js を直接ロード -->
<script src="https://cfx-nui-lb-phone/ui/components.js"></script>
```

```javascript
// コンテキストメニュー
SetContextMenu({
    title: "メンバー操作",
    buttons: [
        { title: "メッセージ送信", color: "green", cb: () => sendMessage(number) },
        { title: "電話する",       color: "blue",  cb: () => callPlayer(number) },
        { title: "キャンセル",     color: "red",   cb: () => {} },
    ]
});

// 連絡先モーダル（電話番号から直接）
fetchNui('SetContactModal', number, 'lb-phone');
```

### 6. スパム防止パターン

```lua
-- server.lua: NUI コールバックのレートリミット（5秒クールダウン）
local lastAction = {}

RegisterNetEvent('factionapp:handlePlayer', function(action, targetId)
    local src = source
    local now = GetGameTimer()
    if lastAction[src] and (now - lastAction[src]) < 5000 then
        return  -- クールダウン中は無視
    end
    lastAction[src] = now
    -- 実際の処理...
end)
```

---

## サーバー側データ構造

```lua
-- メモリ内ファクションデータ（起動時に構築）
FrakData[jobName][playerId] = {
    name   = playerName,
    label  = gradeLabel,      -- "Officer", "Captain" 等
    grade  = gradeNumber,
    number = phoneNumber,
    source = playerId
}

-- MOTD（MySQL + メモリキャッシュ）
MOTD[jobName] = { message = "今週の任務: ..." }
```

---

## このアプリが示すこと

| 点 | 内容 |
|---|------|
| ビルドなし実装 | Vite 不要・素の HTML/CSS/JS で lb-phone アプリが作れる |
| jQuery + fetch | fetch API と jQuery の組み合わせで NUI 通信 |
| lb-phone Server API | `SendMessage`・`CreateCall`・`SendNotification`・`GetEquippedPhoneNumber` の実践例 |
| コンポーネント利用 | `SetContextMenu` を Vanilla JS から呼ぶパターン |
| MOTD 管理 | MySQL とメモリキャッシュを組み合わせた永続化 |

---

## 依存リソース

- `es_extended` (ESX)
- `oxmysql` または esx-legacy 付属の MySQL 機能

---

## 関連ドキュメント

- [bs_laymo — QBX + React JS 実装例](bs-laymo.md)
- [slrn_groups — マルチフレームワーク + React TS 実装例](slrn-groups.md)
- [lb-phone グローバル UI API](../lb-phone/global-ui-api.md)
