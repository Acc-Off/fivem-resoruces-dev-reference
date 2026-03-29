# State Bags

> 公式ドキュメント: https://docs.fivem.net/docs/scripting-manual/networking/state-bags/

State Bags（ステートバッグ）はエンティティやグローバルに任意のキー/バリューペアを関連付けて、Server↔Client間で**自動同期**するFiveMの仕組みです。

---

## State Bag の種類

| 種類 | アクセス方法 | 書き込み可能 | 読み取り可能 |
|------|-------------|-------------|-------------|
| **GlobalState** | `GlobalState.myKey` | Serverのみ | Server / 全Client |
| **Player state** | `Player(source).state.myKey` | Server ＋ そのプレイヤー自身 | Server / 全Client |
| **LocalPlayer state** | `LocalPlayer.state.myKey` | Client（自分のみ） | Client（自分のみ、既定） |
| **Entity state** | `Entity(handle).state.myKey` | Server ＋ エンティティオーナー Client | Server / 全Client |

---

## 基本的な読み書き

### 読み取り

```lua
-- GlobalState（Client / Server 両方で可能）
local enabled = GlobalState.moneyEnabled

-- Player state（Server側）
local job = Player(source).state.job

-- Player state（Client側・自分）
local job = LocalPlayer.state.job

-- Entity state
local vehicle = GetVehiclePedIsIn(ped, false)
local owner   = Entity(vehicle).state.owner
```

### 書き込み

```lua
-- GlobalState（Serverのみ）
GlobalState.moneyEnabled = true
GlobalState:set('moneyEnabled', true, false)
-- 第3引数 replicated:
--   false = Serverのみ更新（Clientに送らない）
--   true  = 全Clientに同期

-- Player state（Server側）
Player(source).state:set('job', 'police', true)
-- "true" = 全Clientに同期送信

-- Player state（Client側・自分のみ）
LocalPlayer.state:set('myKey', 'value', true)

-- Entity state（Server or エンティティオーナーClient）
Entity(vehicle).state:set('speed', 120, true)
```

---

## 変更ハンドラ

State Bagの値が変化したときにコールバックを受け取れます。

```lua
-- AddStateBagChangeHandler(keyFilter, bagFilter, handler)
-- keyFilter: 監視するキー名。nil で全キー
-- bagFilter: 監視する bag ID。nil で全 bag

-- 特定キーの変化を監視（nilを渡すと全エンティティが対象）
AddStateBagChangeHandler('job', nil, function(bagName, key, value, reserved, replicated)
    -- bagName: "player:1" など（下記フォーマット表を参照）
    -- key: "job"
    -- value: 新しい値（変化前の値はまだ bag に残っている点に注意）
    print(bagName .. ' のjobが変更: ' .. tostring(value))
end)

-- 特定プレイヤーのみ監視
local bagName = ('player:%d'):format(GetPlayerServerId(PlayerId()))
AddStateBagChangeHandler('job', bagName, function(bag, key, newValue)
    print('自分のジョブが変わった: ' .. tostring(newValue))
end)
```

### bagName のフォーマット

| フォーマット | 内容 |
|-------------|------|
| `player:SOURCE` | プレイヤー（SOURCE = server ID） |
| `entity:NETID` | ネットワークエンティティ |
| `localEntity:HANDLE` | ローカルエンティティ |

### bagName からエンティティ / プレイヤーを取得

```lua
-- bagName からプレイヤーを取得
local player = GetPlayerFromStateBagName(bagName)

-- bagName からエンティティを取得
local entity = GetEntityFromStateBagName(bagName)

-- 手動パース
local source = tonumber(bagName:match("player:(%d+)"))
```

---

## ユースケース

### プレイヤー状態の共有

```lua
-- Server: ジョブ設定
Player(source).state:set('job', { name = 'police', grade = 2 }, true)

-- Client: 他プレイヤーのジョブを読む
local otherPlayer = GetPlayerServerId(somePed)
local job = Player(otherPlayer).state.job
if job and job.name == 'police' then
    -- 警察官の処理
end
```

### エンティティへの追加情報

```lua
-- Server: 車両にデータを付与
local vehicle = GetVehiclePedIsIn(source, false)
Entity(vehicle).state:set('locked', true, true)
Entity(vehicle).state:set('owner', GetPlayerIdentifier(source, 0), true)

-- Client: 車両のデータを読む
local locked = Entity(vehicle).state.locked
```

### グローバル状態の管理

```lua
-- Server: サーバー全体の設定
GlobalState:set('economy', { multiplier = 1.5 }, true)

-- Client: どこからでも読める
local economy = GlobalState.economy
print('現在の倍率: ' .. economy.multiplier)
```

### 近接プレイヤーへの情報ブロードキャスト

State Bags は **近くにいるプレイヤーにデータを届ける近接共有** にも活用できる。
値をセットすれば範囲内の全Clientに自動伝播するため、`TriggerClientEvent` でプレイヤーを列挙する必要がない。

```lua
-- server.lua: プレイヤーのアクション状態を近接共有
Player(source).state:set('isCarrying', true, true)
```

```lua
-- client.lua: 他プレイヤーの状態変化を検知
AddStateBagChangeHandler('isCarrying', nil, function(bagName, key, value)
    local source = tonumber(bagName:match("player:(%d+)"))
    if source == GetPlayerServerId(PlayerId()) then return end  -- 自分は除外

    local player = GetPlayerFromServerId(source)
    local ped = GetPlayerPed(player)
    if value then
        -- アニメーション再生など
    end
end)
```

---

## lb-phone との連携

lb-phone は以下の State Bags を使用しています。詳細は [lb-phone API リファレンス](../lb-phone/api-reference.md#state-bags) を参照。

```lua
-- 電話が開いているか確認
local phoneOpen = Player(source).state.phoneOpen

-- 電話番号の取得
local phoneNumber = Player(source).state.phoneNumber

-- 通話中かどうか
local onCallWith = Player(source).state.onCallWith
```

---

## 注意事項

### ネストしたオブジェクトの直接変更は同期されない

State Bags のゲッター/セッターはネイティブとやり取りするため、**ネストしたオブジェクトのプロパティ変更は伝播しない**。

```lua
-- NG: 伝播しない
Entity(x).state.myObj.y = 'b'

-- OK: キー自体を更新する
Entity(x).state:set('myObj', { y = 'b' }, true)
```

### 同じキーを複数回読むのは非効率

```lua
-- 非効率（内部でデシリアライズが2回走る）
local y = Entity(x).state.myObj.y
local z = Entity(x).state.myObj.z

-- 推奨（1回取得してローカル変数に保持）
local myObj = Entity(x).state.myObj
local y, z = myObj.y, myObj.z
```

### その他の注意点

- **書き込み権限は厳密**: 他プレイヤーのPlayer stateをClientから書き込むことはできない
- **`replicated = true`** を付けないと全Clientに同期されない（意図的にServerのみで持ちたい場合は `false`）
- **変更ハンドラ内の旧値**: コールバック内で `value` は新しい値だが、**bag を読み取ると古い値が返る場合がある**（同一フレーム内）。次フレームで読み取るか、引数の `value` を直接使うこと
- State Bagsはネットワーク帯域を消費するため、頻繁に更新するデータには向かない
- 大きなオブジェクトの同期は避け、必要最低限のデータのみを格納する
