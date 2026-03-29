# bs_laymo — 自動運転タクシーアプリ

> GitHub: https://github.com/BeetleStudios/bs_laymo  
> フレームワーク: QBX + ox_lib  
> UI: React (JSX) + Vite

Waymo 風の自動運転タクシーサービスを FiveM 上で実現した lb-phone カスタムアプリです。目的地選択・料金見積り・乗車・NPC 自動運転・評価まで一通りの機能を備えた中規模実装例です。

---

## フォルダ構成

```
fxmanifest.lua
config.lua              ← 料金・車両・運転パラメータ設定
client/
  main.lua              ← アプリ登録・乗車リクエスト・車両スポーン・料金計算
  autopilot.lua         ← NPC 自動運転制御（経路追従・スタック検出・リルート）
  nui.lua               ← NUIコールバック登録（位置情報・乗車・料金等）
server/
  main.lua              ← 残高チェック・課金・車鍵付与・サージ料金
ui/
  src/
    App.jsx             ← 画面遷移型 UI
```

---

## 学べるパターン

### 1. アプリ登録（シンプルパターン）

```lua
-- client/main.lua
local resourceName = GetCurrentResourceName()

exports["lb-phone"]:AddCustomApp({
    identifier = Config.AppIdentifier,     -- "laymo"
    name       = Config.AppName,
    developer  = Config.AppDeveloper,
    ui         = resourceName .. "/ui/dist/index.html",
    icon       = "https://cfx-nui-" .. resourceName .. "/ui/dist/icon.png",
    fixBlur    = true
})
```

### 2. Client→UI メッセージヘルパー

```lua
-- client/main.lua
local function SendAppMessage(data)
    exports["lb-phone"]:SendCustomAppMessage(Config.AppIdentifier, data)
end

-- 使用例: 乗車状態の更新
SendAppMessage({
    type    = "rideUpdate",
    state   = "arriving",
    vehicle = vehicleName,
    tier    = tierName,
    price   = estimatedPrice,
    eta     = etaSeconds,
})
```

### 3. UI 側のメッセージバスパターン（Vanilla JS スタイル）

```javascript
// App.jsx
window.addEventListener('message', (e) => {
    switch(e.data?.type) {
        case 'rideUpdate':
            setRideState(e.data.state);
            setVehicle(e.data.vehicle);
            break;
        case 'etaUpdate':
            setEta(e.data.eta);
            break;
        case 'tripProgress':
            setProgress(e.data.progress);
            break;
    }
});
```

### 4. Server 通信パターン（requestId で応答を紐付け）

```lua
-- Client→Server イベント + requestId によるコールバック擬似実装

-- client/main.lua
local function checkBalance(amount, callback)
    local requestId = math.random(100000, 999999)
    TriggerServerEvent("laymo:checkBalance", requestId, amount)
    -- レスポンスを一時イベントで受け取る
    local evt = AddEventHandler("laymo:checkBalance:response:" .. requestId, function(canAfford)
        RemoveEventHandler(evt)
        callback(canAfford)
    end)
end

-- server/main.lua
RegisterServerEvent("laymo:checkBalance", function(requestId, amount)
    local src = source
    local balance = getPlayerBalance(src)
    TriggerClientEvent("laymo:checkBalance:response:" .. requestId, src, balance >= amount)
end)
```

### 5. NUIコールバック一覧

| コールバック名 | 用途 | 戻り値 |
|---------------|------|--------|
| `getPlayerLocation` | 現在地取得 | `{x, y, z, street}` |
| `getWaypoint` | マップウェイポイント取得 | `{exists, x, y, z, street}` |
| `requestRide` | 乗車リクエスト | `{success}` |
| `cancelRide` | キャンセル | `{success}` |
| `endRide` | 到着・終了 | `{success}` |
| `getRideStatus` | 現在の乗車状態 | `{state, ride}` |
| `getPriceEstimate` | 料金見積り | `{price, distance, eta, surge}` |
| `getVehicleTiers` | 車両ティア一覧 | `[{id, name, multiplier}, ...]` |
| `getPopularDestinations` | 人気目的地 | `[{id, name, icon, coords}, ...]` |
| `getRideHistory` | 乗車履歴 | `[{...}, ...]` |
| `submitRating` | 評価送信 | `stars (1–5)` |
| `setWaypoint` | ウェイポイント設定 | `{x, y}` |

---

## 特徴的な実装

### 料金計算式

```lua
-- (基本料金 + 距離料金) × ティア倍率 × サージ倍率
local price = (Config.BasePrice + (miles * Config.PricePerMile))
              * tierMultiplier
              * surgeMultiplier
price = math.ceil(price / 5) * 5  -- 5単位で丸め
```

### NPC 自動運転（autopilot.lua）

```lua
-- 目的地に向かって NPC を運転させる
TaskVehicleDriveToCoordLongrange(
    driver,     -- ped
    vehicle,    -- vehicle entity
    destX, destY, destZ,
    Config.DriveSpeed,
    Config.DrivingStyle,
    5.0         -- 目的地到達半径
)

-- スタック検出: 一定時間移動がなければリルート
CreateThread(function()
    while isRiding do
        local pos = GetEntityCoords(vehicle)
        Wait(Config.StuckCheckInterval)
        local newPos = GetEntityCoords(vehicle)
        if #(pos - newPos) < Config.StuckThreshold then
            -- リルート処理
            rerouteVehicle(vehicle, driver, destination)
        end
    end
end)
```

### 段階的減速（目的地近く）

```lua
local dist = #(vehicleCoords - destCoords)
if dist < 28.0 then
    SetVehicleMaxSpeed(vehicle, 4.0)  -- ほぼ停車
elseif dist < 45.0 then
    SetVehicleMaxSpeed(vehicle, 8.0)
elseif dist < 80.0 then
    SetVehicleMaxSpeed(vehicle, 12.0)
end
```

### 車鍵連携（複数対応）

```lua
-- qbx_vehiclekeys / qb-vehiclekeys を自動検出
if GetResourceState('qbx_vehiclekeys') == 'started' then
    exports.qbx_vehiclekeys:GiveKeys(source, plate)
elseif GetResourceState('qb-vehiclekeys') == 'started' then
    exports['qb-vehiclekeys']:GiveKeys(source, plate)
end
```

---

## 依存リソース

- `qbx_core` または `qb-core`
- `ox_lib`（lib.callback, lib.notify 等）
- `qbx_vehiclekeys` または `qb-vehiclekeys`（オプション）

---

## 関連ドキュメント

- [factionapp — ESX + Vanilla JS 実装例](factionapp.md)
- [slrn_groups — マルチフレームワーク + React TS 実装例](slrn-groups.md)
- [Lua ↔ UI 通信パターン](../lb-phone/lua-ui-communication.md)
