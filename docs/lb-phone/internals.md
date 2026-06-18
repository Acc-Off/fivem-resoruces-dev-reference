# lb-phone 内部構造

lb-phone v2.7.1 の公開ファイル群を分析した内部構造メモです。  
カスタムアプリ開発において、lb-phoneがどう動いているかを理解するための参考情報です。

> lb-phone本体は商用製品です。本ドキュメントはescrow暗号化を除いた公開ファイル部分の分析です。  
> コードを再配布するものではありません。

---

## ディレクトリ構成（公開部分）

```
lb-phone/
├── fxmanifest.lua
├── phone.sql
├── config/
│   ├── config.lua          # メイン設定（escrow_ignore）
│   ├── config.json         # アプリID等のJSON設定
│   ├── defaultSettings.json
│   ├── cellTowers.lua
│   ├── music.lua
│   └── locales/
├── shared/
│   ├── functions.lua       # 共通ユーティリティ（infoprint/debugprint等）
│   ├── checks.lua          # AddCheck/RemoveCheck/ValidateChecks
│   ├── upload.lua          # アップロード設定（UploadMethods）
│   ├── interval.lua        # Intervalクラス
│   └── media.lua           # メディアURLホワイトリスト検証
├── lib/
│   ├── client/
│   │   ├── registerCallbacks.lua   # RegisterClientCallback
│   │   ├── triggerCallbacks.lua    # TriggerCallback (client→server)
│   │   └── keybinds.lua
│   └── server/
│       ├── registerCallbacks.lua   # RegisterCallback（レート制限付き）
│       └── triggerCallbacks.lua    # TriggerClientCallback (server→client)
├── client/
│   ├── apps/
│   │   ├── default/        # 暗号化済みアプリ本体
│   │   └── framework/      # フレームワーク依存アプリ
│   └── custom/
│       ├── frameworks/     # フレームワークブリッジ（クライアント側）
│       └── functions/      # カスタム関数（animations等）
└── server/
    ├── apps/
    │   └── framework/      # フレームワーク依存サーバー処理
    └── custom/
        ├── frameworks/     # フレームワークブリッジ（サーバー側）
        └── functions/      # GetPresignedUrl/GiveVehicleKey等
```

---

## フレームワークブリッジの仕組み

lb-phoneは「フレームワークを問わず動作する」ことを目標に、フレームワーク依存処理を完全に分離しています。

### 設定

```lua
-- config/config.lua
Config.Framework = "auto"   -- "esx" | "qb" | "qbox" | "ox" | "vrp2" | "standalone" | "auto"
```

### ガードパターン（各フレームワークファイルの先頭）

```lua
-- client/custom/frameworks/esx/esx.lua
if Config.Framework ~= "esx" then return end
```

`GetResourceState()` でフレームワークリソースの起動状態を確認し、一致するもの以外は即 return。

### フレームワーク別ブリッジ構成

各フレームワークフォルダ（`client/custom/frameworks/{fw}/`）が以下を実装：

| ファイル | 役割 |
|---------|------|
| `{fw}.lua` | フレームワーク初期化・プレイヤーロード/ログアウトイベント待機 |
| `services.lua` | `GetJob()`, `GetJobGrade()`, `GetCompanyData()` |
| `item.lua` | アイテム確認処理 |
| `vehicles.lua` | 車両関連処理 |

### ESXの初期化パターン例

```lua
-- ESXオブジェクト取得（exports → イベントフォールバック）
local export_ok, obj = pcall(function()
    return exports.es_extended:getSharedObject()
end)

if export_ok and obj then
    ESX = obj
else
    -- フォールバック: イベントで取得
    TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
end
```

---

## コールバックシステム

lb-phone独自のコールバックシステム（`lib/` 配下）。`RegisterNetEvent` + `TriggerClientEvent` を隠蔽し、セキュリティ機能を付加しています。

### サーバー側登録

```lua
-- lib/server/registerCallbacks.lua が提供
exports["lb-phone"]:RegisterCallback("myapp:getData", function(source, ...)
    return result
end, {
    preventSpam   = true,   -- 処理中の二重呼び出し防止
    rateLimit     = 10,     -- 1分間に最大10回
    defaultReturn = nil,    -- タイムアウト時の戻り値
})
```

### クライアント側呼び出し

```lua
-- await 版（コルーチン内で使用）
local data = exports["lb-phone"]:AwaitCallback("myapp:getData", arg1, arg2)

-- コールバック版
exports["lb-phone"]:TriggerCallback("myapp:getData", function(data) end, arg1, arg2)
```

---

## アップロードシステム（shared/upload.lua）

lb-phoneは複数のアップロード方式をサポートしています。

```lua
-- config/config.lua
Config.UploadMethod = "LBPresigned"   -- 推奨
-- 他: "Cloudflare" | "Backblaze" | "S3" | "UploadThing" | "GCS" | "Custom"
```

### LBPresigned 方式の仕組み

```
lb-phone NUI
  └→ exports GeneratePresignedUrl を呼ぶ（外部リソース）
       └→ クラウドストレージの署名付きURL を取得
  └→ 署名付きURL に直接 PUT（FiveM サーバーを経由しない）
```

`GeneratePresignedUrl` を実装した外部リソース（`lb-presigned-lua` 等）が必要です。  

---

## Checksシステム（shared/checks.lua）

特定のアクション（電話を開く・SNS投稿等）にバリデーションを追加できる仕組み。

```lua
-- バリデーターを登録（戻り値が false/string の場合はアクションをブロック）
local checkId = exports["lb-phone"]:AddCheck("openPhone", function()
    if IsBlacklisted() then
        return false, "あなたは使用できません"
    end
    return true
end)

-- 解除
exports["lb-phone"]:RemoveCheck(checkId)
```

サーバー側でも同様に `AddCheck` を使える（異なるイベント名が対象）。

v2.7.1 で追加されたイベント:
- `postMarketplace`: `fun(source, post: { title, description, attachments, price })`
- `postPages`: `fun(source, post: { title, description, attachment?, price? })`

---

## SaltyChat 対応（voice.lua）

v2.7.1 で SaltyChat の `SaltyChat_TalkStateChanged` イベントを受信し、`IsTalking()` およびカメラマイクのトグルに自動対応します。

v2.7.1 で `SetCallMuted(muted, callId)` 関数も追加されました。これは `AddToCall`/`RemoveFromCall` をまとめて呼び出すユーティリティです。

---

## components.GameMap（v2.7.0+）

`window.components.GameMap` として lb-phone の地図機能をカスタムアプリの DOM 要素に直接埋め込めるクラスが追加されました。  
詳細は [グローバル UI API](global-ui-api.md#マップコンポーネントv270) を参照してください。

`ui/dist/assets/` に以下のファイルが新たに追加されています：
- `leaflet-*.js` — Leaflet 1.9.4（`GameMap` が動的にロード）
- `leaflet-*.css` — Leaflet スタイルシート
- `Maps-CX5VRGng.js` — React 向けマップコンポーネント（lb-phone 内部の Maps アプリが使用）

---

## カスタムアプリ iframe の生成・注入・イベント発火（v2.8.2 で確認）

カスタムアプリの UI が lb-phone 内でどう生成・初期化されるかの内部挙動。v2.8.2 のビルド済み JS（`AppProvider-*.js` / `index-n8LMBOiD.js`）を分析した内容。デバッグ時の混乱回避に重要。

### iframe は2つ存在しうる

同じ `cfx-nui-<resource>/ui/dist/index.html` が、状況により複数の iframe にロードされる:

| iframe | DOM 上の位置 | サイズ | `window.name`（eval時） | lb-phone の注入 |
|--------|-------------|--------|------------------------|----------------|
| 表示用（本物） | `lb-phone` の中（`... > app-canister-<id> > app-content > iframe`） | スマホサイズ（例 414×904） | `''`（空） | される |
| 裏（`ui_page` 由来と思われる） | FiveM root 直下 | 全画面（例 1920×1080） | リソース名が入る | されない |

この2つは `window.name` で判別できる（表示用は空文字、裏はリソース名）。公式テンプレの `if (window.name === '' || devMode)` 描画ガードは、この判別で裏 iframe での描画を避けている。

**デバッグ時の注意:** 両者は URL が同一なため DevTools のフレーム選択で区別できない。表示されていない裏 iframe を掴むと「`fetchNui` が undefined」「注入が来ない」と*見える*が、それは観測ミス。**`visible`（offsetWidth/Height）とサイズ、または `window.name` で本物を特定する**こと。また親フレームから別オリジンの子 `contentWindow` を覗くと、例外を投げず静かに falsy/空を返す（クロスオリジンの観測アーティファクト）ため、必ずそのフレーム自身のコンテキストで評価する。

### 注入と componentsLoaded の機序

- lb-phone はカスタムアプリ iframe の **`onLoad` ハンドラ内**で、`iframe.contentDocument.body` に `<script>` を `appendChild` して `globalThis.fetchNui` / `components` / `resourceName` 等を注入する（`contentDocument.body` が無ければ何もせず return・リトライなし。ただし通常の load 時点では body は存在し注入は成功する）。
- 注入されたスクリプトは iframe 内で `setTimeout(() => postMessage('componentsLoaded','*'), 250)` を実行する。**つまり `componentsLoaded` は「注入が走った」自己発火シグナル**であり、表示用 iframe にはアプリを開くたびに毎回届く（iframe は開くたびに新規生成され `script eval` から再実行される）。裏 iframe には届かない。
- `appOpen` / `appClose` は lb-phone が onUse / onClose 契機で iframe へ送る別経路の postMessage。

### v2.8.2 の既知の取りこぼし

クライアント高負荷時（DevTools CPU 6x slowdown で高再現）、注入と `componentsLoaded` は届くのに **`appOpen` だけが届かない**ことがある。`appOpen` 単独を初期化トリガにしていると、その処理（初期データ取得など）が走らない。対策はUI側で組む（[Lua ↔ UI 通信パターン](lua-ui-communication.md) を参照）。lb-phone 本体側のタイミング/race と見られる。

---

## 関連ドキュメント

- [lb-phone公式API リファレンス](api-reference.md)
- [Lua ↔ UI 通信パターン](lua-ui-communication.md)
- [参照リポジトリ一覧](../../SOURCES.md)

### 参考リポジトリ（アップロード関連）
- [lbphone/lb-upload: A FiveM script that allows you to upload videos, image and audio files directly to the server.](https://github.com/lbphone/lb-upload)
- [lbphone/lb-presigned: A FiveM script to generate presigned URLs for uploading files to R2/S3](https://github.com/lbphone/lb-presigned)
- [Acc-Off/lb-presigned-lua: A FiveM script to generate presigned URLs for uploading files to AWS S3/Azure Blob for lb-phone/lb-tablet](https://github.com/Acc-Off/lb-presigned-lua)
- [Acc-Off/lb-presigned-with-metadata: A FiveM script to upload files to AWS S3/Azure Blob with metadata support for lb-phone/lb-tablet](https://github.com/Acc-Off/lb-presigned-with-metadata)
- [Acc-Off/lb-upload-azure-blob](https://github.com/Acc-Off/lb-upload-azure-blob)
