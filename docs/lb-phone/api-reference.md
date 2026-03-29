# lb-phone 公式 API リファレンス

> ソース: https://docs.lbscripts.com/phone/exports/  
> バージョン: v2.6.0  
> 最終確認: 2026-03-29

---

## 目次

- [カスタムアプリ登録](#カスタムアプリ登録)
- [クライアント Exports](#クライアント-exports)
- [クライアント Events](#クライアント-events)
- [サーバー Exports](#サーバー-exports)
- [サーバー Events](#サーバー-events)
- [State Bags](#state-bags)

---

## カスタムアプリ登録

### 方式1: 外部リソースから export で登録（推奨）

```lua
-- client.lua
CreateThread(function()
    while GetResourceState("lb-phone") ~= "started" do Wait(500) end
    Wait(500)

    local success, err = exports["lb-phone"]:AddCustomApp({
        identifier  = "myapp",
        name        = "My App",
        description = "説明文",
        ui          = GetCurrentResourceName() .. "/ui/dist/index.html",
        icon        = "https://cfx-nui-" .. GetCurrentResourceName() .. "/ui/dist/icon.png",
        developer   = "開発者名",
        defaultApp  = true,
        fixBlur     = true,
        landscape   = false,
        images      = {},
        price       = 0,
        onUse       = function() end,
        onClose     = function() end,
        onDelete    = function() end,
    })
end)
```

### 方式2: config.lua に直接記述（UIなし向け）

```lua
-- lb-phone/config/config.lua
Config.CustomApps = {
    ["app_identifier"] = {
        name        = "App Name",
        description = "App Description",
        developer   = "Developer",
        defaultApp  = true,
        game        = false,
        size        = 59812,
        icon        = "https://...",
        price       = 0,
        landscape   = false,
        keepOpen    = true,
        onUse = function() end,
        onServerUse = function(source) end,
    }
}
```

---

## クライアント Exports

### カスタムアプリ

```lua
-- アプリ追加 / 削除
local ok, err = exports["lb-phone"]:AddCustomApp({ ... })
local ok, err = exports["lb-phone"]:RemoveCustomApp("identifier")

-- UI へメッセージ送信（SendNUIMessage の代わりに必ずこれを使う）
exports["lb-phone"]:SendCustomAppMessage("identifier", data)

-- コンポーネント表示
exports["lb-phone"]:ShowComponent({ component = "gallery" }, function(...) end)
exports["lb-phone"]:SetCameraComponent()   -- カメラURLを返す
exports["lb-phone"]:SetContactModal(phoneNumber)
```

### 電話の操作

```lua
local num   = exports["lb-phone"]:GetEquippedPhoneNumber()
exports["lb-phone"]:ToggleOpen(open, noFocus)   -- open=nil でトグル
local open  = exports["lb-phone"]:IsOpen()
local onScr = exports["lb-phone"]:IsPhoneOnScreen()
local dis   = exports["lb-phone"]:IsDisabled()
exports["lb-phone"]:ToggleDisabled(disabled)
exports["lb-phone"]:ToggleHomeIndicator(show)
exports["lb-phone"]:ToggleLandscape(landscape)
exports["lb-phone"]:ReloadPhone()
exports["lb-phone"]:SetPhoneVariation(variation)
```

### 通知

```lua
exports["lb-phone"]:SendNotification({
    app       = "Settings",
    title     = "タイトル",
    content   = "内容",       -- OPTIONAL
    thumbnail = "url",        -- OPTIONAL
    avatar    = "url",        -- OPTIONAL
    showAvatar = false,       -- OPTIONAL
})
```

### Misc

```lua
local config  = exports["lb-phone"]:GetConfig()
local towers  = exports["lb-phone"]:GetCellTowers()      -- vector3[]
local fmt     = exports["lb-phone"]:FormatNumber(num)
exports["lb-phone"]:SaveToGallery(link)
local has     = exports["lb-phone"]:HasPhoneItem(number)
local settings = exports["lb-phone"]:GetSettings()
local bat      = exports["lb-phone"]:GetBattery()          -- 0-100
exports["lb-phone"]:SetBattery(battery)
```

### カメラ

```lua
exports["lb-phone"]:EnableWalkableCam(selfieMode)
exports["lb-phone"]:DisableWalkableCam()
exports["lb-phone"]:ToggleSelfieCam(selfieMode)
exports["lb-phone"]:ToggleCameraFrozen()
exports["lb-phone"]:ToggleFlashlight(flashlight)
exports["lb-phone"]:SetServiceBars(bars)   -- 0-4 or false でリセット
```

### アプリ操作

```lua
exports["lb-phone"]:OpenApp("app_identifier", data)
exports["lb-phone"]:CloseApp({ app = "app_identifier", closeCompletely = false })
exports["lb-phone"]:SetAppHidden("app_identifier", true)
exports["lb-phone"]:SetAppInstalled("app_identifier", true)
exports["lb-phone"]:PostBirdy({ content = "投稿", attachments = {}, hashtags = {} })
exports["lb-phone"]:AddContact({ number = "...", firstname = "John", lastname = "Doe" })
```

### 電話発信

```lua
-- UIあり通常発信
exports["lb-phone"]:CreateCall({ number = "...", videoCall = false, hideNumber = false })
exports["lb-phone"]:CreateCall({ company = "police" })
local inCall = exports["lb-phone"]:IsInCall()

-- UIなしカスタム電話番号（ペイフォン等）
local ok, reason = exports["lb-phone"]:CreateCustomNumber("555-0000", {
    onCall  = function(incomingCall)
        incomingCall.accept()
        incomingCall.deny()
        incomingCall.setName("name")
        local ended = incomingCall.hasEnded()
    end,
    onEnd     = function() end,
    onAction  = function(action) end,  -- "mute"|"unmute"|"enable_speaker"|"disable_speaker"
    onKeypad  = function(key) end,
})
exports["lb-phone"]:RemoveCustomNumber("555-0000")
exports["lb-phone"]:EndCustomCall()
```

### バリデーター（AddCheck）

```lua
-- CheckEvent: "openPhone" | "playNativePhoneSound"
local id = exports["lb-phone"]:AddCheck("openPhone", function() return true end)
exports["lb-phone"]:RemoveCheck(id)
```

### コールバック（クライアント）

```lua
exports["lb-phone"]:RegisterClientCallback("event", function(...)
    return result
end)

local data = exports["lb-phone"]:AwaitCallback("event", ...)
exports["lb-phone"]:TriggerCallback("event", function(...) end, ...)
```

---

## クライアント Events

```lua
-- 電話番号変更
RegisterNetEvent("lb-phone:numberChanged", function(newNumber) end)

-- 電話開閉
RegisterNetEvent("lb-phone:phoneToggled", function(open) end)

-- 画面表示状態
RegisterNetEvent("lb-phone:setOnScreen", function(onScreen) end)

-- HUD 非表示（撮影中）
RegisterNetEvent("lb-phone:toggleHud", function(hudDisabled) end)

-- バッテリー切れ
RegisterNetEvent("lb-phone:phoneDied", function() end)

-- 設定更新
RegisterNetEvent("lb-phone:settingsUpdated", function(newSettings) end)

-- SNS 新規投稿
RegisterNetEvent("lb-phone:birdy:newPost",       function(post) end)
RegisterNetEvent("lb-phone:trendy:newPost",      function(post) end)
RegisterNetEvent("lb-phone:instapic:newPost",    function(post) end)
RegisterNetEvent("lb-phone:pages:newPost",       function(post) end)
RegisterNetEvent("lb-phone:marketplace:newPost", function(post) end)
```

---

## サーバー Exports

### Misc

```lua
local config  = exports["lb-phone"]:GetConfig()
local towers  = exports["lb-phone"]:GetCellTowers()
local fmt     = exports["lb-phone"]:FormatNumber(phoneNumber)
local ok      = exports["lb-phone"]:ContainsBlacklistedWord(source, text)
```

### ユーザー操作

```lua
exports["lb-phone"]:FactoryReset(phoneNumber)
local phoneNum = exports["lb-phone"]:GetEquippedPhoneNumber(source)   -- source or identifier
local source   = exports["lb-phone"]:GetSourceFromNumber(phoneNumber)
local has      = exports["lb-phone"]:HasPhoneItem(source, phoneNumber)
local settings = exports["lb-phone"]:GetSettings(phoneNumber)
local airplane = exports["lb-phone"]:HasAirplaneMode(phoneNumber)
```

### 通知

```lua
-- 特定プレイヤーへ通知（target: source or phoneNumber）
exports["lb-phone"]:SendNotification(target, {
    app       = "Mail",
    title     = "件名",
    content   = "内容",
    thumbnail = "url",          -- OPTIONAL
    avatar    = "url",          -- OPTIONAL
    showAvatar = false,         -- OPTIONAL
    customData = {
        buttons = {
            { title = "読む",   event = "mail:openMail",   data = { id = 1 } },
            { title = "削除",   event = "mail:deleteMail", data = { id = 1 }, server = false },
        }
    }
})

-- 全員通知（"all" or "online"）
exports["lb-phone"]:NotifyEveryone("online", {
    app     = "Settings",
    title   = "タイトル",
    content = "内容",
})

-- 緊急通知
exports["lb-phone"]:EmergencyNotification(source, {
    title   = "Emergency Alert",
    content = "テスト",
    icon    = "warning",   -- "warning" | "danger"
})
```

### 連絡先

```lua
exports["lb-phone"]:AddContact(phoneNumber, {
    number    = "01234567890",
    firstname = "John",
    lastname  = "Doe",      -- OPTIONAL
    avatar    = "url",      -- OPTIONAL
    email     = "...",      -- OPTIONAL
    address   = "...",      -- OPTIONAL
})
```

### ウォレット

```lua
-- amount: 正=収入, 負=支出
exports["lb-phone"]:AddTransaction(phoneNumber, amount, title, image)
```

### メッセージ / SMS

```lua
local result = exports["lb-phone"]:SendMessage(from, to, message, attachments, cb, channelId)
-- result: { channelId, messageId }
exports["lb-phone"]:SentMoney(from, to, amount)
exports["lb-phone"]:SendCoords(from, to, coords)   -- coords: vector2
```

### メール

```lua
local ok, reason = exports["lb-phone"]:CreateMailAccount(address, password)
local email      = exports["lb-phone"]:GetEmailAddress(phoneNumber)
local ok, id     = exports["lb-phone"]:SendMail({
    to          = "user@example.com",
    sender      = "sender@example.com",   -- OPTIONAL
    subject     = "件名",
    message     = "本文",
    attachments = { "url" },              -- OPTIONAL
    actions     = {                        -- OPTIONAL
        { label = "ラベル", data = { event = "eventName", isServer = true, data = {} } }
    }
})
exports["lb-phone"]:DeleteMail(id)
```

### DarkChat

```lua
exports["lb-phone"]:SendDarkChatMessage(username, channel, message, cb)
exports["lb-phone"]:SendDarkChatLocation(username, channel, coords, cb)
local ok, reason = exports["lb-phone"]:CreateDarkChatChannel(channel, password)
exports["lb-phone"]:DeleteDarkChatChannel(channel, deleteMessages)
exports["lb-phone"]:AddUserToDarkChatChannel(username, channel)
exports["lb-phone"]:RemoveUserFromDarkChatChannel(username, channel)
```

### AirShare（AirDropライクな共有）

```lua
exports["lb-phone"]:AirShare(sender, target, shareType, shareData)
-- shareType: "image" | "contact" | "location" | "note" | "voicememo"
```

### ソーシャルメディア

```lua
local username   = exports["lb-phone"]:GetSocialMediaUsername(phoneNumber, app)
-- app: "instapic" | "birdy" | "trendy" | "darkchat" | "mail"

exports["lb-phone"]:ToggleVerified(app, username, verified)
local isVerified = exports["lb-phone"]:IsVerified(app, username)

local ok, id     = exports["lb-phone"]:PostBirdy(username, content, attachments, replyTo, hashtags, source)
local post       = exports["lb-phone"]:GetBirdyPost(id)
```

### 通話（サーバー）

```lua
local callId = exports["lb-phone"]:CreateCall({
    phoneNumber = "Payphone",
    source      = src
}, targetNumber, {
    requirePhone = false,
    hideNumber   = true,
    company      = "police",
})
local call   = exports["lb-phone"]:GetCall(callId)
exports["lb-phone"]:EndCall(source)
local inCall, callId, call = exports["lb-phone"]:IsInCall(source)
```

### クリプト

```lua
exports["lb-phone"]:AddCrypto(source, coin, amount)
exports["lb-phone"]:RemoveCrypto(source, coin, amount)
exports["lb-phone"]:AddCustomCoin(id, name, symbol, image, currentPrice, prices, change24h, permissions)
-- permissions: { buy = true, sell = true, transfer = true }
```

### コールバック（サーバー）

lb-phone独自のコールバックシステム。レート制限・スパム防止が内蔵されています。

```lua
exports["lb-phone"]:RegisterCallback("myapp:getData", function(source, ...)
    return result
end, {
    preventSpam   = true,   -- 処理中の二重呼び出し防止
    rateLimit     = 10,     -- 1分間に最大10回
    defaultReturn = nil,    -- タイムアウト時の戻り値
})

-- phoneNumberも自動取得するバリアント
exports["lb-phone"]:BaseCallback("myapp:action", function(source, phoneNumber, ...)
    return result
end)

-- AddCheck（サーバー側バリデーション）
-- CheckEvent: "createDarkChatChannel" | "joinDarkChatChannel" | "sendDarkchatMessage"
--           | "startInstaPicLive" | "joinInstaPicLive" | "postInstaPicStory"
--           | "buyCrypto" | "sellCrypto" | "transferCrypto"
--           | "postInstaPic" | "postBirdy" | "postTrendy"
local id = exports["lb-phone"]:AddCheck("postBirdy", function(source, ...)
    return true
end)
exports["lb-phone"]:RemoveCheck(id)
```

---

## サーバー Events

```lua
-- 電話番号変更
AddEventHandler("lb-phone:numberChanged", function(source, newNumber) end)

-- 電話番号生成
AddEventHandler("lb-phone:phoneNumberGenerated", function(source, phoneNumber) end)

-- ファクトリーリセット
AddEventHandler("lb-phone:factoryReset", function(source, phoneNumber) end)

-- ギャラリー削除
AddEventHandler("lb-phone:deletedFromGallery", function(source, phoneNumber, link) end)

-- SMS送信
AddEventHandler("lb-phone:messages:messageSent", function(message)
    -- message: { channelId, messageId, sender, recipient, message, attachments? }
end)

-- 通話関連
AddEventHandler("lb-phone:newCall",      function(call) end)
AddEventHandler("lb-phone:callAnswered", function(call) end)
AddEventHandler("lb-phone:callEnded",    function(call, source) end)

-- SNS 投稿
AddEventHandler("lb-phone:birdy:newPost",       function(post) end)
AddEventHandler("lb-phone:trendy:newPost",       function(post) end)
AddEventHandler("lb-phone:instapic:newPost",     function(post) end)
AddEventHandler("lb-phone:pages:newPost",        function(post) end)
AddEventHandler("lb-phone:marketplace:newPost",  function(post) end)

-- メール送信
AddEventHandler("lb-phone:mail:mailSent", function(mailData) end)

-- ウォレット取引
AddEventHandler("lb-phone:onAddTransaction", function(transactionType, phoneNumber, amount, company, logo)
    -- transactionType: "received" | "paid"
end)

-- 会社メッセージ
AddEventHandler("lb-phone:newCompanyMessage", function(message)
    -- message: { company, sender, sentByEmployee, message, coords?, anonymous }
end)
```

---

## State Bags

### Phone（電話本体）

| キー | 型 | 説明 |
|------|----|------|
| `phoneOpen` | boolean | 電話が開いているか |
| `phoneNumber` | string | 電話番号（例: `01234567890`） |
| `phoneName` | string | 電話名（例: `"Loaf's Phone"`） |
| `flashlight` | boolean | フラッシュライト ON/OFF |

### Calls（通話）

| キー | 型 | 説明 |
|------|----|------|
| `speakerphone` | boolean | スピーカーフォン有効か |
| `mutedCall` | boolean | 通話をミュート中か |
| `otherMutedCall` | boolean | 相手がミュート中か |
| `onCallWith` | number | 通話相手の source |
| `callAnswered` | boolean | 通話が応答済みか |

### Misc

| キー | 型 | 説明 |
|------|----|------|
| `instapicIsLive` | boolean | InstaPic ライブ配信中か |

---

## 重要な注意事項

- `SendNUIMessage` はlb-phone環境では**使用不可**。`SendCustomAppMessage` を使うこと
- `AddCustomApp` は `lb-phone` の `started` 後に呼び出すこと（`Wait(500)` も推奨）
- UIは `componentsLoaded` メッセージ受信後に `renderApp()` を呼ぶこと
- `body { visibility: hidden; }` はCSSに必須（lb-phoneが表示を制御する）
