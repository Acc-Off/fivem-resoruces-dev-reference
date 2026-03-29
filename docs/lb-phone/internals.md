# lb-phone 内部構造

lb-phone v2.6.0 の公開ファイル群を分析した内部構造メモです。  
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

---

## 関連ドキュメント

- [lb-phone公式API リファレンス](api-reference.md)
- [参照リポジトリ一覧](../../SOURCES.md)

### 参考リポジトリ（アップロード関連）
- [lbphone/lb-upload: A FiveM script that allows you to upload videos, image and audio files directly to the server.](https://github.com/lbphone/lb-upload)
- [lbphone/lb-presigned: A FiveM script to generate presigned URLs for uploading files to R2/S3](https://github.com/lbphone/lb-presigned)
- [Acc-Off/lb-presigned-lua: A FiveM script to generate presigned URLs for uploading files to AWS S3/Azure Blob for lb-phone/lb-tablet](https://github.com/Acc-Off/lb-presigned-lua)
- [Acc-Off/lb-presigned-with-metadata: A FiveM script to upload files to AWS S3/Azure Blob with metadata support for lb-phone/lb-tablet](https://github.com/Acc-Off/lb-presigned-with-metadata)
- [Acc-Off/lb-upload-azure-blob](https://github.com/Acc-Off/lb-upload-azure-blob)
