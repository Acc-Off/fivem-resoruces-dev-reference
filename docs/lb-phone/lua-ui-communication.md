# Lua ↔ UI 通信パターン

lb-phoneカスタムアプリにおけるLua（Client/Server）とUI（NUI）間の通信のすべてです。

---

## 全体像

```
┌─────────────────────────────────────────────┐
│  UI（NUI / ブラウザ）                       │
└──────────┬──────────────────────────────────┘
           │ fetchNui(event, data)          ↑ onNuiEvent / useNuiEvent
           ▼                               │
┌──────────┴──────────────────────────────────┐
│  Client Lua                                 │
│  RegisterNuiCallback(event, cb)             │ ← NUI → Lua
│  SendCustomAppMessage(id, {action, data})   │ → Lua → NUI
└──────────┬──────────────────────────────────┘
           │ lib.callback / TriggerServerEvent
           ▼
┌──────────────────────────────────────────────┐
│  Server Lua                                  │
└──────────────────────────────────────────────┘
```

---

## Lua → UI へのメッセージ送信

**`SendCustomAppMessage`** を使います。`SendNUIMessage` は lb-phone 環境では使用できません。

```lua
-- client/main.lua
exports["lb-phone"]:SendCustomAppMessage("myapp", {
    action = "updateData",
    data   = { balance = 1500, items = { ... } }
})
```

### UI側での受信

**React（`useNuiEvent` フック）:**
```typescript
import { useNuiEvent } from '../hooks/useNuiEvent'

function MyComponent() {
    const [balance, setBalance] = useState(0)

    useNuiEvent<{ balance: number }>('updateData', (data) => {
        setBalance(data.balance)
    })
    return <div>{balance}</div>
}
```

**Vanilla JS:**
```javascript
window.addEventListener('message', (event) => {
    // event.data.action で分岐する
    if (event.data?.action === 'updateData') {
        console.log(event.data.data.balance)
    }
})
```

**lb-phone公式テンプレートの `onNuiEvent`:**
```javascript
// lb-phone が globalThis に注入する関数
onNuiEvent('updateData', (data) => {
    console.log(data.balance)
})
```

---

## UI → Lua へのコールバック（NUIコールバック）

UIからLuaの処理を呼び出して結果を受け取るパターンです。

### Lua側（クライアント）

```lua
-- client/main.lua
RegisterNuiCallback("fetchBalance", function(data, cb)
    -- data: UI から送られたペイロード
    local balance = GetPlayerBalance()   -- 何らかの処理
    cb({ success = true, balance = balance })
end)
```

### UI側

**`fetchNui` ユーティリティ（lb-phone公式テンプレート付属）:**
```typescript
// 戻り値は Promise
const result = await fetchNui<{ success: boolean; balance: number }>(
    "fetchBalance",
    { playerId: 1 }
)
console.log(result.balance)
```

**素のフェッチ（lb-phone が自動で `fetchNui` を注入する）:**
```javascript
// lb-phone は globalThis.fetchNui を提供している
const result = await fetchNui('fetchBalance', { playerId: 1 })
```

---

## UI初期化パターン（必須）

lb-phone は `componentsLoaded` メッセージを送信するまでUIを表示しません。

```typescript
// main.tsx（またはindex.tsx）
function renderApp() {
    ReactDOM.createRoot(document.getElementById('root')!).render(<App />)
}

const devMode = !window?.['invokeNative']   // 開発サーバーかどうかを判定

if (devMode) {
    // 開発時（Vite dev server）は即時表示
    renderApp()
} else {
    // 本番（lb-phone内）は componentsLoaded 待ち
    window.addEventListener('message', (event) => {
        if (event.data === 'componentsLoaded') renderApp()
    })
}
```

```css
/* index.css：lb-phone が visibility を制御するため必須 */
body { visibility: hidden; }
```

---

## Client ↔ Server 通信

### ox_lib 推奨パターン

```lua
-- server/main.lua
lib.callback.register('myapp:getItems', function(source, data)
    local items = MySQL.query.await(
        'SELECT * FROM myapp_items WHERE owner = ?',
        { source }
    )
    return items
end)
```

```lua
-- client/main.lua
local items = lib.callback.await('myapp:getItems', false, { filter = 'all' })
```

### 素のFiveM（非推奨・互換用）

```lua
-- server/main.lua
RegisterNetEvent('myapp:server:getItems')
AddEventHandler('myapp:server:getItems', function(requestId, filter)
    local source = source
    local items  = GetItemsFromDB(source, filter)
    TriggerClientEvent('myapp:client:getItemsResult', source, requestId, items)
end)
```

```lua
-- client/main.lua（RequestIdパターン）
local requestId = tostring(math.random(100000, 999999))
local result    = nil

RegisterNetEvent('myapp:client:getItemsResult')
AddEventHandler('myapp:client:getItemsResult', function(rid, data)
    if rid == requestId then result = data end
end)

TriggerServerEvent('myapp:server:getItems', requestId, 'all')
while result == nil do Wait(0) end
-- result が使える
```

---

## NUIコールバック内で非同期処理を行う場合

NUIコールバックのハンドラは **同期関数** として呼ばれます。  
Luaの非同期処理を行う場合は `CreateThread` で包む必要があります。

```lua
RegisterNuiCallback("submitItem", function(data, cb)
    -- 直接 lib.callback.await などは呼べない（コルーチンが必要）
    CreateThread(function()
        local result = lib.callback.await('myapp:submitItem', false, data)
        cb({ success = result.success })
    end)
end)
```

---

## 関連ドキュメント

- [グローバルUI API](global-ui-api.md)
- [アプリ登録](app-registration.md)
- [FiveM通信パターン全般](../fivem/communication-patterns.md)
