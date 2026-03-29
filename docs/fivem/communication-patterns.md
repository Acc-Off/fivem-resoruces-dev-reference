# FiveM 通信パターン

FiveM の各コンポーネント間の通信手法を網羅したリファレンスです。

---

## 通信レイヤーの全体像

```
┌─────────────────────────────────────────────────┐
│  NUI（React / ブラウザ）                        │
└──────────────┬──────────────────────────────────┘
  fetchNui    ↑|↓  SendNUIMessage / SendCustomAppMessage
              ↑|↓  RegisterNUICallback
┌─────────────┴───────────────────────────────────┐
│  Client Script                                  │◄─── exports ───► 隣リソース Client
│  TriggerEvent（ローカル）                        │
└──────────────┬──────────────────────────────────┘
  TriggerClientEvent ↑  TriggerServerEvent ↓
  lib.callback ↕（双方向）
  State Bags ↕（自動同期）
┌─────────────┴───────────────────────────────────┐
│  Server Script                                  │◄─── exports ───► 隣リソース Server
│  TriggerEvent（ローカル）                        │
└──────────────┬──────────────────────────────────┘
         PerformHttpRequest ↓（Server 専用）
       外部 Web API / Discord
         SetHttpHandler ↑
```

---

## クイックリファレンス

| # | 手法 | 方向 | 返り値 | 備考 |
|---|------|------|--------|------|
| 1 | `SendNUIMessage` / `SendCustomAppMessage` | Client → NUI | なし | lb-phoneは後者を使う |
| 2 | `RegisterNUICallback` + `fetchNui` | NUI → Client | あり（cb） | |
| 3 | `TriggerEvent` + `AddEventHandler` | 同一環境内の全リソース | なし | ネット不使用 |
| 4 | `RegisterNetEvent` | — | — | ネットイベント受信の宣言（必須） |
| 5 | `TriggerServerEvent` | Client → Server | なし | `source` 自動セット |
| 6 | `TriggerClientEvent` | Server → Client | なし | 送り先を引数で指定 |
| 7 | `lib.callback` (ox_lib) | Client ↔ Server（双方向） | あり（await） | ox_lib推奨 |
| 8 | `State Bags` | Server/Client ↔ 双方（自動） | リアクティブ | |
| 9 | `RegisterCommand` | チャット/コンソール → Server/Client | なし | ACE権限管理 |
| 10 | `PerformHttpRequest` | Server → 外部API | あり（cb） | **Server専用** |
| 11 | `exports` | 同環境リソース間 | あり（同期） | Client↔Client / Server↔Server |
| 12 | `SetHttpHandler` | 外部クライアント → Server | あり（HTTP） | ポート共有・URLはリソース名 |

---

## 1. Client → NUI

> **注意**: lb-phone 環境では `SendNUIMessage` が動作しない。必ず `SendCustomAppMessage` を使う。

```lua
-- 通常の FiveM NUI
SendNUIMessage({ action = "updateBalance", data = { amount = 1000 } })

-- lb-phone カスタムアプリ（`SendNUIMessage` の代わりに必用）
exports["lb-phone"]:SendCustomAppMessage("identifier", {
    action = "updateData",
    data   = { balance = 1500 }
})
```

```javascript
// 受信（バニラJS）
window.addEventListener('message', (event) => {
    if (event.data?.action === 'updateData') {
        console.log(event.data.data.balance)
    }
})

// 受信（lb-phone onNuiEvent）
onNuiEvent('updateData', (data) => { setBalance(data.balance) })

// 受信（React useNuiEvent フック）
useNuiEvent('updateData', (data) => { setBalance(data.balance) })
```

---

## 2. NUI → Client（NUIコールバック）

```lua
-- client.lua
RegisterNUICallback('fetchData', function(body, cb)
    -- body: NUI から送られたデータ
    cb({ success = true, result = GetPlayerName(PlayerId()) })
end)

-- 注意: cb() を必ず呼ばないと NUI がハングする
```

```javascript
// NUI側（fetchNui が利用可能な場合）
const result = await fetchNui('fetchData', { key: 'value' })
console.log(result.result)

// 素のfetch
const resp = await fetch(`https://cfx-nui-${GetParentResourceName()}/fetchData`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ key: 'value' }),
})
const result = await resp.json()
```

---

## 3. Client → Server

```lua
-- client.lua
RegisterNetEvent('myapp:server:createItem') -- 送信前に宣言は不要（送信側）

TriggerServerEvent('myapp:server:createItem', { name = 'sword', qty = 1 })

-- server.lua（受信側は RegisterNetEvent が必須）
RegisterNetEvent('myapp:server:createItem')
AddEventHandler('myapp:server:createItem', function(data)
    local pid = source  -- 送信したプレイヤーのサーバーID（先頭でキャプチャ）
    -- DB操作等
end)
```

> **`source` について**
> `AddEventHandler` 内の `source` は引数ではなく、ランタイムが自動でセットする**暗黙のグローバル変数**。
> 非同期処理（`Citizen.Await` / `Wait`）をまたぐと値が変わるため、**必ず先頭で `local pid = source` として保存**すること。
>
> | 発火した関数 | ハンドラが動く場所 | `source` の値 |
> |-------------|------------------|--------------|
> | `TriggerServerEvent`（Client → Server） | Server | 送信プレイヤーの ServerID ✅ |
> | `TriggerClientEvent`（Server → Client） | Client | `nil` |
> | `TriggerEvent`（ローカル） | Server / Client | `nil` |
>
> → **`source` に意味のある値が入るのは `TriggerServerEvent` を受信したサーバー側のみ。**
> フレームワークの callback 内（lib.callback 等）では `source` は**明示的な第1引数**として渡される（仕組みが異なる）。

---

## 4. Server → Client

```lua
-- server.lua
TriggerClientEvent('myapp:client:itemCreated', source, { id = 1, name = 'sword' })
-- source = -1 で全員に送信

-- client.lua（受信）
RegisterNetEvent('myapp:client:itemCreated')
AddEventHandler('myapp:client:itemCreated', function(data)
    print('アイテム作成: ' .. data.name)
end)
```

---

## 5. lib.callback — 返り値付き非同期（双方向）

FiveM 標準にはないが、フレームワーク/ライブラリが提供する「往復通信」パターン。

### ox_lib（推奨）— Client → Server

```lua
-- server.lua
lib.callback.register('myapp:getBalance', function(source, data)
    local row = MySQL.single.await('SELECT balance FROM users WHERE id = ?', { source })
    return row.balance
end)

-- client.lua（第2引数 false = サーバーを呼び出す）
local balance = lib.callback.await('myapp:getBalance', false, { currency = 'cash' })
print('残高: ' .. balance)
```

### ox_lib — Server → Client（逆向き）

```lua
-- client.lua（提供側。source 引数は不要）
lib.callback.register('myapp:getPosition', function()
    local coords = GetEntityCoords(PlayerPedId())
    return { x = coords.x, y = coords.y, z = coords.z }
end)

-- server.lua（第2引数に対象プレイヤーの source を指定）
local result = lib.callback.await('myapp:getPosition', source, {})
print(result.x, result.y, result.z)
```

> **`lib.callback.await` 第2引数**: `false` = サーバーを呼ぶ / 数値（playerId）= 指定クライアントを呼ぶ

### ESX（Client → Server のみ）

```lua
-- server.lua
ESX.RegisterServerCallback('myapp:getBalance', function(source, cb, data)
    cb({ balance = 1000 })
end)

-- client.lua
ESX.TriggerServerCallback('myapp:getBalance', function(result)
    print(result.balance)
end, someData)
```

### QBCore（Client → Server のみ）

```lua
-- server.lua
QBCore.Functions.CreateCallback('myapp:getBalance', function(source, cb, data)
    cb({ balance = 1000 })
end)

-- client.lua
QBCore.Functions.TriggerCallback('myapp:getBalance', function(result)
    print(result.balance)
end, someData)
```

> ESX・QBCore は Server → Client の Callback を持たない。逆向きには ox_lib か手動実装を使う。
> **Qbox（qbx_core）** は ox_lib ベースのため、独自 Callback API は不要（`lib.callback` をそのまま使う）。

### 手動 requestId パターン（フレームワーク不要・双方向）

```lua
-- client.lua（Client → Server の例）
local requestId = tostring(math.random(100000, 999999))
TriggerServerEvent('myapp:server:getBalance', requestId, someData)

AddEventHandler('myapp:client:getBalanceResult_' .. requestId, function(result)
    print(result.balance)
end)

-- server.lua
RegisterNetEvent('myapp:server:getBalance')
AddEventHandler('myapp:server:getBalance', function(requestId, data)
    local pid = source
    TriggerClientEvent('myapp:client:getBalanceResult_' .. requestId, pid, { balance = 1000 })
end)
```

### まとめ

| 方式 | 方向 | 書き方 | プレイヤー識別 | 備考 |
|------|------|--------|----------------|------|
| ox_lib | Client → Server | `await(..., false)` | `source` ✅ | 最も推奨 |
| ox_lib | Server → Client | `await(..., playerId)` | 引数で指定 ✅ | 逆向きも可 |
| ESX / QBCore | Client → Server のみ | コールバック形式 | `source` ✅ | フレームワーク依存 |
| 手動 requestId | 双方向 | イベント + ID | `source` ✅ | フレームワーク不要 |

---

## 6. State Bags（自動同期）

State Bagsはエンティティ・プレイヤーにキー/バリューを関連付けて、Server↔Client間で自動同期します。

```lua
-- Server: 書き込み
Player(source).state:set('job', 'police', true)  -- 第3引数trueで全クライアントに送信

-- Client: 読み取り
local job = Player(source).state.job   -- Server側
local job = LocalPlayer.state.job      -- Client側（自分）

-- Client: 変更を監視
AddStateBagChangeHandler('job', nil, function(bagName, key, value, reserved, replicated)
    print('ジョブ変更: ' .. tostring(value))
end)
```

詳細: [State Bags リファレンス](state-bags.md)

---

## 7. PerformHttpRequest（Server → 外部API）

```lua
-- server.lua（外部WebAPIの呼び出し）
PerformHttpRequest('https://api.example.com/webhook', function(statusCode, response, headers)
    if statusCode == 200 then
        local data = json.decode(response)
        print(data.message)
    end
end, 'POST', json.encode({ player = source, action = 'joined' }), {
    ['Content-Type'] = 'application/json'
})
```

**Serverでのみ使用可能。** Clientからは呼び出せません。

---

## 8. RegisterCommand — コマンド経由の実行

```lua
-- server.lua（チャット/コンソールで `/giveitem sword 3` を入力）
RegisterCommand('giveitem', function(source, args, rawCommand)
    local pid = source  -- チャット実行時: プレイヤーID / コンソール実行時: 0
    local item  = args[1]
    local amount = tonumber(args[2]) or 1
    print(pid, item, amount)
end, true)  -- true = ACE permission チェックあり
```

```lua
-- client.lua（チャット入力でクライアント側処理）
RegisterCommand('openphone', function(source, args)
    -- クライアントコマンド。source は常に 0（意味なし）
    SetNuiFocus(true, true)
end, false)
```

> **入力場所と実行場所は独立している**
>
> | 書いた場所 | 実行される場所 | `source` の値 |
> |-----------|-------------|--------------|
> | `server.lua` | サーバー上 | チャット: プレイヤーID / コンソール: `0` |
> | `client.lua` | プレイヤーのクライアント | 常に `0`（コンソールからは実行不可） |
>
> チャットで入力しても `server.lua` のハンドラが動く。「入力場所」と「実行場所」は別。

---

## 9. exports — リソース間 API

**方向**: 同一環境内（Client↔Client / Server↔Server）、**同期**（返り値あり即座に返る）

```lua
-- リソース A: server.lua（提供側）
exports('getPlayerData', function(playerId)
    return { name = GetPlayerName(playerId), money = 500 }
end)

-- リソース B: server.lua（利用側）
local data = exports['リソースA']:getPlayerData(source)
print(data.name)
```

```lua
-- Client 側も同様（client.lua 間）
local result = exports['リソースA']:getSomeData()
```

> **制約**: Client の export を Server から呼ぶことは不可（逆も不可）。同一環境内のみ。
> `source` は自動識別されないため、引数として手動で渡す必要がある。

---

## プレイヤー識別まとめ

| 手法 | プレイヤー識別方法 |
|------|------------------|
| `SendNUIMessage` | クライアント自身のみ（識別不要） |
| `RegisterNUICallback` | `GetPlayerServerId(PlayerId())` でサーバーID取得可 |
| `AddEventHandler`（TriggerServerEvent 受信） | 暗黙グローバル **`source`**（先頭で `local pid = source`） |
| `TriggerEvent`（ローカル） | `source` はセットされない（`nil`） |
| `TriggerServerEvent` | サーバー側ハンドラの **`source`**（自動） |
| `TriggerClientEvent` | 送信時の第2引数で送り先を指定 |
| lib.callback | Client→Server: `source`（自動）/ Server→Client: 引数で指定 |
| `State Bags` | `Player(src).state` で個別管理 |
| `RegisterCommand` | サーバーコマンドの **`source`**（コンソール実行時は `0`） |
| `PerformHttpRequest` | Server 専用。`source` を引数に含めて外部へ送信 |
| `exports` | 引数として手動で渡す（自動識別なし） |
| `SetHttpHandler` | HTTP ヘッダ・リクエスト IP から手動で判定 |

---

## セキュリティ注意点

- **`TriggerServerEvent` は誰でも呼べる**。サーバー側では必ずプレイヤーの権限・状態を検証すること
- **`source` の保存**: `local pid = source` をハンドラ先頭で必ず行う（非同期処理後は別の値になる）
- **`exports`**: 外部から直接呼ばれることはないが、引数バリデーションは行うこと
- **NUICallback のデータ**: NUI からのデータは信頼しない。クライアント側で再検証すること
- **`SetHttpHandler`**: 外部から誰でもリクエストを送れる。APIキー・Origin・接続プレイヤーIP を必ず検証すること

---

## 10. SetHttpHandler — 外部HTTP受信（Server 専用）

**方向**: 外部クライアント（ブラウザ・curl・別サーバー）→ FiveM Server

FiveM リソースごとの**組み込み HTTP サーバー**。`RegisterNUICallback` と異なり、NUI 外部（外部ブラウザ・別サーバー・curl 等）からアクセスできる。

### URL・ポート・TLS

```
http(s)://<サーバーホスト>:<FiveMポート>/<リソース名>/[任意のパス]
例: https://my-server.example.com:30120/my-resource/api/data
```

- **パスの先頭はリソース名が固定**（変更不可）。それ以降は `request.path` で取得可
- FiveM の HTTP ハンドラは FiveM サーバーのポートを**そのまま共有**（デフォルト 30120）
- TLS はネイティブ非対応。**リバースプロキシ**（nginx / Caddy / Cloudflare）による HTTPS 終端が推奨

| TLS 方式 | 内容 |
|---------|------|
| **リバースプロキシ** | nginx / Caddy が HTTPS を終端し、localhost:30120 へ HTTP で転送（推奨） |
| **`endpoint_add_https`** | `server.cfg` に証明書を設定（公式サポートだが情報が少ない） |

### 最小実装

```lua
-- server.lua
SetHttpHandler(function(request, response)
    -- request.method  : "GET" / "POST" 等
    -- request.path    : "/my-resource/api/data"
    -- request.headers : ヘッダテーブル
    -- request.body    : リクエストボディ（コールバック形式）

    if request.method == 'GET' then
        response.writeHead(200, { ['Content-Type'] = 'application/json' })
        response.send(json.encode({ status = 'ok' }))
    else
        response.writeHead(405)
        response.send('Method Not Allowed')
    end
end)
```

> **セキュリティ**: 外部から誰でもリクエストを送れる。APIキー・Origin ヘッダ・IP を必ず検証すること。

---

## 8. SetHttpHandler（外部クライアント → Server）

```lua
-- server.lua
SetHttpHandler(function(request, response)
    if request.path == '/status' then
        response.writeHead(200, { ['Content-Type'] = 'application/json' })
        response.write(json.encode({ status = 'ok', players = #GetPlayers() }))
        response.send()
    end
end)
-- URL: http://<server>:<port>/<resource-name>/status
```

NUI（ブラウザ）からもこのエンドポイントに直接HTTPリクエストを送れます。  
詳細: [HTTP・サーバー内部](http-and-server.md)

---

## 9. exports（リソース間）

```lua
-- リソース A の server.lua
exports('getPlayerBalance', function(source)
    return GetBalance(source)
end)

-- リソース B の server.lua
local balance = exports['resource-a']:getPlayerBalance(source)
```

**同一環境内（Client↔Client / Server↔Server）のみ。** Cross-environment呼び出しは不可。

---

## 10. RegisterCommand

```lua
-- server.lua（ACE権限あり）
RegisterCommand('give', function(source, args, rawCommand)
    local target = tonumber(args[1])
    local amount = tonumber(args[2])
    GiveMoney(target, amount)
end, true)  -- 第3引数 true = ACE権限が必要

-- client.lua（ACE権限なし）
RegisterCommand('menu', function(source, args)
    OpenMenu()
end, false)
```

---

## 関連ドキュメント

- [State Bags](state-bags.md)
- [HTTP・サーバー内部](http-and-server.md)
- [Lua↔UI通信（lb-phone）](../lb-phone/lua-ui-communication.md)
