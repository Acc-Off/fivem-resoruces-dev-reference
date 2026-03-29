# FiveM リソース開発ナレッジベース

このリポジトリはFiveM向けリソース開発の知識をまとめたナレッジベースです。
lb-phone カスタムアプリ開発のドキュメントを多く含みますが、FiveM 全般の通信パターン・C# 開発・各種実装例も網羅しています。
`docs/` フォルダ以下の各ドキュメントを参照してください。

---

## このリポジトリの構成

```
├── README.md                          リポジトリ概要
├── SOURCES.md                         参照リポジトリ一覧（GitHub URL）
├── SKILL.md                           GitHub Copilot スキル定義（別ワークスペースで使用）
├── .github/copilot-instructions.md    このファイル（AI向け指示）
└── docs/
    ├── getting-started/   入門・プロジェクト立ち上げ（lb-phone カスタムアプリ）
    ├── lb-phone/          lb-phone カスタムアプリ開発詳細
    ├── fivem/             FiveM 全般（通信パターン・State Bags・HTTPサーバー）
    ├── templates/         テンプレートリポジトリ詳細
    ├── examples/          実装例リポジトリ詳細（Lua シリーズ・C# シリーズ）
    └── csharp/            C# 開発者向け
```

---

## Client ↔ Server 通信パターン

### ox_lib 使用（推奨）

```lua
-- server/main.lua
lib.callback.register('myapp:getItems', function(source, data)
    local items = MySQL.query.await('SELECT * FROM items WHERE owner = ?', { source })
    return items
end)
```

```lua
-- client/main.lua（第2引数 false = サーバーを呼び出す）
local items = lib.callback.await('myapp:getItems', false, { filter = 'all' })
```

### 素のFiveM（RequestId パターン）

```lua
-- server/main.lua
RegisterNetEvent('myapp:server:getItems')
AddEventHandler('myapp:server:getItems', function(requestId, data)
    local pid = source
    TriggerClientEvent('myapp:client:getItemsResult', pid, requestId, { result = 'ok' })
end)
```

```lua
-- client/main.lua
local requestId = math.random(100000, 999999)
local result = nil
RegisterNetEvent('myapp:client:getItemsResult')
AddEventHandler('myapp:client:getItemsResult', function(rid, data)
    if rid == requestId then result = data end
end)
TriggerServerEvent('myapp:server:getItems', requestId, data)
while result == nil do Wait(0) end
```

---

## fxmanifest.lua の基本構成

```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

shared_script 'config.lua'
client_scripts { 'client/*.lua' }
server_scripts {
    '@oxmysql/lib/MySQL.lua',   -- MySQLを使う場合
    'server/*.lua'
}

-- UI を持つリソースの場合
ui_page 'ui/dist/index.html'
files { 'ui/dist/**' }

-- 依存リソースがある場合
-- dependencies { 'ox_lib' }
```

---

## マルチフレームワーク対応パターン

```lua
-- 冒頭でフレームワーク存在チェック。未対応なら即 return
if GetResourceState('es_extended') ~= 'started' then
    print('[myapp] ESX not found, skipping ESX bridge.')
    return
end

local ESX = exports['es_extended']:getSharedObject()
```

---

## 知識ドキュメントの詳細

### lb-phone カスタムアプリ

| ドキュメント | 内容 |
|-------------|------|
| [docs/getting-started/01-overview.md](../docs/getting-started/01-overview.md) | lb-phone カスタムアプリの概要・3層アーキテクチャ |
| [docs/getting-started/02-project-setup.md](../docs/getting-started/02-project-setup.md) | fxmanifest・Vite設定・フォルダ構成 |
| [docs/getting-started/03-choose-template.md](../docs/getting-started/03-choose-template.md) | テンプレート比較表・選択フロー |
| [docs/lb-phone/app-registration.md](../docs/lb-phone/app-registration.md) | AddCustomApp 全パラメータ・登録方法 |
| [docs/lb-phone/lua-ui-communication.md](../docs/lb-phone/lua-ui-communication.md) | Lua ↔ UI 通信パターン全般 |
| [docs/lb-phone/global-ui-api.md](../docs/lb-phone/global-ui-api.md) | window.* グローバル API（components.* 等） |
| [docs/lb-phone/themes-and-css.md](../docs/lb-phone/themes-and-css.md) | CSS変数・ダークモード・fixBlur |
| [docs/lb-phone/api-reference.md](../docs/lb-phone/api-reference.md) | Client/Server Exports・Events・State Bags 公式API完全版 |
| [docs/lb-phone/internals.md](../docs/lb-phone/internals.md) | lb-phone v2.6.0 内部構造・フレームワークブリッジ |

### FiveM 全般

| ドキュメント | 内容 |
|-------------|------|
| [docs/fivem/communication-patterns.md](../docs/fivem/communication-patterns.md) | Client↔Server↔NUI 通信パターン12種 |
| [docs/fivem/state-bags.md](../docs/fivem/state-bags.md) | State Bags（GlobalState・Player state・Entity state） |
| [docs/fivem/http-and-server.md](../docs/fivem/http-and-server.md) | SetHttpHandler・PerformHttpRequest・TLS |

### C# 開発者向け

| ドキュメント | 内容 |
|-------------|------|
| [docs/csharp/overview.md](../docs/csharp/overview.md) | C# で FiveM リソースを開発するための概要・環境構築 |
| [docs/csharp/lua-to-csharp.md](../docs/csharp/lua-to-csharp.md) | Lua → C# パターン集（イベント・NUI・Exports・非同期等） |
| [docs/csharp/blazor-wasm.md](../docs/csharp/blazor-wasm.md) | Blazor WASM を FiveM NUI として使う |

### テンプレート・実装例詳細

| ドキュメント | 内容 |
|-------------|------|
| [docs/templates/lb-phone-official.md](../docs/templates/lb-phone-official.md) | lb-phone-app-template（公式）構成・パターン |
| [docs/templates/ox-typescript-boilerplate.md](../docs/templates/ox-typescript-boilerplate.md) | fivem-typescript-boilerplate（esbuild+Vite+React） |
| [docs/templates/mps-integrated.md](../docs/templates/mps-integrated.md) | mps-lb-phone-apptemplate-reactts（統合版・DB・ブリッジ） |
| [docs/examples/bs-laymo.md](../docs/examples/bs-laymo.md) | bs_laymo — 自動運転タクシー・NPC制御・料金計算 |
| [docs/examples/factionapp.md](../docs/examples/factionapp.md) | factionapp — ESX ファクション管理・Vanilla JS |
| [docs/examples/slrn-groups.md](../docs/examples/slrn-groups.md) | slrn_groups — マルチフレームワーク・React TS・lib.callback |
| [docs/examples/fivem-phone.md](../docs/examples/fivem-phone.md) | FiveM-phone — マルチフレームワーク自動検出・Vanilla JS・コレクション型構成 |
| [docs/examples/simple-livemap.md](../docs/examples/simple-livemap.md) | simple-livemap — C# + ASP.NET Core IServer + SetHttpHandler + SSE |
| [docs/examples/vmenu.md](../docs/examples/vmenu.md) | vMenu — 大規模 C# FiveM リソース・権限設計・Convar |
| [docs/examples/fivemrpserverresources.md](../docs/examples/fivemrpserverresources.md) | FiveMRpServerResources — C# RP 機能集・セッション管理 |

参照リポジトリの一覧は [SOURCES.md](../SOURCES.md) を参照してください。
