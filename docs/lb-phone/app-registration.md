# アプリ登録（AddCustomApp）

lb-phoneにカスタムアプリを登録するための完全リファレンスです。

---

## 基本パターン

`lb-phone` が起動してから登録します。`client/main.lua` に記述します。

```lua
CreateThread(function()
    -- lb-phone が started になるまで待機（必須）
    while GetResourceState('lb-phone') ~= 'started' do
        Wait(500)
    end
    Wait(500)  -- 念のためもう少し待機

    local success, err = exports["lb-phone"]:AddCustomApp({
        identifier  = GetCurrentResourceName(),  -- リソース名と一致させると管理が楽
        name        = "My App",
        description = "アプリの説明",
        developer   = "Developer Name",
        defaultApp  = true,
        ui          = GetCurrentResourceName() .. "/ui/dist/index.html",
        icon        = "https://cfx-nui-" .. GetCurrentResourceName() .. "/ui/dist/icon.png",
        fixBlur     = true,
    })

    if not success then
        print("[myapp] AddCustomApp failed: " .. tostring(err))
    end
end)
```

---

## パラメータ全リファレンス

| パラメータ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| `identifier` | string | ✅ | アプリの一意ID。リソース名と一致させること |
| `name` | string | ✅ | アプリ一覧に表示される名前 |
| `description` | string | ✅ | アプリストアでの説明文 |
| `developer` | string | — | 開発者名（省略可） |
| `defaultApp` | boolean | — | `true` = インストール不要で最初から使える |
| `ui` | string | — | UIのパス or URL（UIなしアプリは省略可） |
| `icon` | string | — | アイコン画像のURL |
| `fixBlur` | boolean | — | `true` = フォントぼやけ修正（CSS は em/rem 単位を使うこと） |
| `landscape` | boolean | — | `true` = 横画面表示 |
| `keepOpen` | boolean | — | `true` = アプリを閉じてもUIを維持（UIなしアプリ向け） |
| `size` | number | — | アプリサイズ（バイト。ストア表示用） |
| `price` | number | — | 購入価格（0 = 無料） |
| `images` | string[] | — | アプリストアのスクリーンショットURL一覧 |
| `onUse` | function | — | アプリを開いたときに呼ばれる（クライアント側） |
| `onClose` | function | — | アプリを閉じたときに呼ばれる |
| `onDelete` | function | — | アンインストールされたときに呼ばれる |

---

## 登録方式2: config.lua に直接記述（UIなし）

lb-phone本体の設定ファイルに直接書く方式。外部リソース化しない小さなフック向け。

```lua
-- lb-phone/config/config.lua
Config.CustomApps = {
    ["app_identifier"] = {
        name        = "App Name",
        description = "App Description",
        developer   = "Developer",
        defaultApp  = true,
        game        = false,      -- true = ゲームセクションに表示
        size        = 59812,
        icon        = "https://...",
        price       = 0,
        landscape   = false,
        keepOpen    = true,       -- UIなしの場合はこちらを使う
        onUse = function()
            -- アプリを開いたとき（クライアント）
        end,
        onServerUse = function(source)
            -- アプリを開いたとき（サーバー）
        end,
    }
}
```

この方式は **lb-phone本体の改変** が必要なため、外部リソース（方式1）の方が管理しやすい。

---

## アイコンパスについて

FiveM の NUI では `cfx-nui://` スキームを使ってリソース内のファイルを参照できます。

```lua
-- 正しい書き方
icon = "https://cfx-nui-" .. GetCurrentResourceName() .. "/ui/dist/icon.png"

-- fxmanifest.lua の files にアイコンパスを含める必要がある
files { "ui/dist/**" }
```

---

## fixBlur について

`fixBlur = true` にすると、lb-phone側でフォントのぼやけ補正が行われます。  
この場合、CSS のフォントサイズ・スペーシング等は **`px` ではなく `em` / `rem`** を使う必要があります。

```css
/* fixBlur=true のとき */
.my-text {
    font-size: 1rem;      /* ✅ */
    padding: 0.5em;       /* ✅ */
    /* font-size: 16px;   ❌ px は避ける */
}
```

---

## 関連ドキュメント

- [Lua↔UI通信](lua-ui-communication.md)
- [グローバルUI API](global-ui-api.md)
- [lb-phone公式API リファレンス](api-reference.md)
