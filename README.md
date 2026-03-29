# FiveMリソース開発リファレンス

FiveM向けリソース開発のナレッジベースです。
lb-phone カスタムアプリ開発に関するドキュメントを多く含みますが、FiveM 全般の通信パターン・C# 開発・各種実装例も網羅しています。
GitHub Copilot 等のAIツールがコード生成時のコンテキストとして活用できる形式で整理されています。

---

## このリポジトリの目的

- **FiveM リソース開発者**（lb-phone カスタムアプリ開発者を含む）が実装時に参照できるドキュメントを提供する
- **AIコーディングアシスタント** がFiveM/lb-phone固有の知識を正確に理解・活用できるようにする
- **参考リポジトリの出典** を整理し、同種実装の発見を助ける

コード自体は含みません。実装例は [SOURCES.md](SOURCES.md) に記載された元リポジトリを参照してください。

---

## ディレクトリ構成

```
fivem-resources-dev-reference/
├── README.md                              # このファイル
├── SKILL.md                               # GitHub Copilot スキル定義（ドキュメントマップ・使い方）
├── SOURCES.md                             # 参照リポジトリ一覧（GitHub URL）
├── .github/
│   ├── copilot-instructions.md            # GitHub Copilot / AI向けマスター指示
│   └── workflows/
│       └── release.yml                    # main push 時にスキル ZIP を自動リリース
├── scripts/
│   └── fetch-repo.ps1                     # 参照リポジトリを1件ずつクローン／最新化するスクリプト
└── docs/
    ├── getting-started/                   # lb-phone カスタムアプリ 入門・プロジェクト立ち上げ
    │   ├── 01-overview.md                 # lb-phone カスタムアプリとは・アーキテクチャ概要
    │   ├── 02-project-setup.md            # fxmanifest・Vite設定・フォルダ構成
    │   └── 03-choose-template.md          # テンプレート選択ガイド（比較表・フローチャート）
    ├── lb-phone/                          # lb-phone カスタムアプリ開発詳細
    │   ├── app-registration.md            # AddCustomApp 全パラメータ・登録方法
    │   ├── lua-ui-communication.md        # Lua ↔ UI 通信パターン全般
    │   ├── global-ui-api.md               # window.* グローバル API（components.*等）
    │   ├── themes-and-css.md              # CSS変数・ダークモード・fixBlur
    │   ├── api-reference.md               # Client/Server Exports・Events・State Bags
    │   └── internals.md                   # lb-phone v2.6.0 内部構造・フレームワークブリッジ
    ├── fivem/                             # FiveM 全般
    │   ├── communication-patterns.md      # Client↔Server↔NUI 通信パターン12種
    │   ├── state-bags.md                  # State Bags（GlobalState・Player state等）
    │   └── http-and-server.md             # SetHttpHandler・PerformHttpRequest・TLS
    ├── templates/                         # テンプレートリポジトリ詳細
    │   ├── lb-phone-official.md           # lb-phone-app-template（公式）
    │   ├── ox-typescript-boilerplate.md   # fivem-typescript-boilerplate（Ox）
    │   └── mps-integrated.md              # mps-lb-phone-apptemplate-reactts（統合版）
    ├── examples/                          # 実装例リポジトリ詳細
    │   ├── bs-laymo.md                    # bs_laymo — 自動運転タクシーアプリ
    │   ├── factionapp.md                  # factionapp — ファクション管理アプリ
    │   ├── slrn-groups.md                 # slrn_groups — グループ管理アプリ
    │   ├── fivem-phone.md                 # FiveM-phone — マルチフレームワーク lb-phone アプリ集
    │   ├── simple-livemap.md              # simple-livemap — C# + ASP.NET Core + SetHttpHandler
    │   ├── vmenu.md                       # vMenu — 大規模 C# FiveM リソースの設計参考
    │   └── fivemrpserverresources.md      # FiveMRpServerResources — C# RP サーバー機能集
    └── csharp/                            # C# 開発者向け
        ├── overview.md                    # C# で FiveM リソースを開発するための概要・環境構築
        ├── lua-to-csharp.md               # Lua → C# パターン集（イベント・NUI・Exports 等）
        └── blazor-wasm.md                 # Blazor WASM を FiveM NUI として使う選択肢
```

---

## ドキュメント一覧

### 入門（lb-phone カスタムアプリ）

| ファイル | 内容 |
|---------|------|
| [docs/getting-started/01-overview.md](docs/getting-started/01-overview.md) | lb-phone カスタムアプリとは・3層アーキテクチャ概要 |
| [docs/getting-started/02-project-setup.md](docs/getting-started/02-project-setup.md) | fxmanifest・Vite設定・フォルダ構成 |
| [docs/getting-started/03-choose-template.md](docs/getting-started/03-choose-template.md) | テンプレート比較表・選択フローチャート |

### lb-phone カスタムアプリ開発

| ファイル | 内容 |
|---------|------|
| [docs/lb-phone/app-registration.md](docs/lb-phone/app-registration.md) | AddCustomApp 全パラメータ・登録タイミング |
| [docs/lb-phone/lua-ui-communication.md](docs/lb-phone/lua-ui-communication.md) | Lua ↔ UI 通信パターン全般 |
| [docs/lb-phone/global-ui-api.md](docs/lb-phone/global-ui-api.md) | window.* グローバル API（components.* 等） |
| [docs/lb-phone/themes-and-css.md](docs/lb-phone/themes-and-css.md) | CSS変数・ダークモード対応・fixBlur |
| [docs/lb-phone/api-reference.md](docs/lb-phone/api-reference.md) | Client/Server Exports・Events・State Bags 完全版 |
| [docs/lb-phone/internals.md](docs/lb-phone/internals.md) | lb-phone v2.6.0 内部構造・フレームワークブリッジ |

### FiveM 全般

| ファイル | 内容 |
|---------|------|
| [docs/fivem/communication-patterns.md](docs/fivem/communication-patterns.md) | Client↔Server↔NUI 通信パターン12種 |
| [docs/fivem/state-bags.md](docs/fivem/state-bags.md) | State Bags（GlobalState・Player state・Entity state） |
| [docs/fivem/http-and-server.md](docs/fivem/http-and-server.md) | SetHttpHandler・PerformHttpRequest・@citizenfx/http-wrapper |

### テンプレート詳細

| ファイル | 内容 |
|---------|------|
| [docs/templates/lb-phone-official.md](docs/templates/lb-phone-official.md) | lb-phone-app-template（公式）構成・パターン |
| [docs/templates/ox-typescript-boilerplate.md](docs/templates/ox-typescript-boilerplate.md) | fivem-typescript-boilerplate（esbuild+Vite+React） |
| [docs/templates/mps-integrated.md](docs/templates/mps-integrated.md) | mps-lb-phone-apptemplate-reactts（統合版・DB・ブリッジ） |

### 実装例（lb-phone カスタムアプリ）

| ファイル | 内容 |
|---------|------|
| [docs/examples/bs-laymo.md](docs/examples/bs-laymo.md) | bs_laymo — 自動運転タクシー・NPC 制御・料金計算 |
| [docs/examples/factionapp.md](docs/examples/factionapp.md) | factionapp — ESX ファクション管理・Vanilla JS・lb-phone SMS/通話 API |
| [docs/examples/slrn-groups.md](docs/examples/slrn-groups.md) | slrn_groups — マルチフレームワーク・React TS・lib.callback |
| [docs/examples/fivem-phone.md](docs/examples/fivem-phone.md) | FiveM-phone — マルチフレームワーク自動検出・Vanilla JS・コレクション型構成 |

### 実装例（C# FiveM リソース）

| ファイル | 内容 |
|---------|------|
| [docs/examples/simple-livemap.md](docs/examples/simple-livemap.md) | simple-livemap — C# + ASP.NET Core IServer 差し替え・SetHttpHandler・SSE |
| [docs/examples/vmenu.md](docs/examples/vmenu.md) | vMenu — 大規模 C# FiveM リソース・権限設計・Convar・KVP 永続化 |
| [docs/examples/fivemrpserverresources.md](docs/examples/fivemrpserverresources.md) | FiveMRpServerResources — C# RP 機能集・セッション管理・イベント設計 |

### C# 開発者向け

| ファイル | 内容 |
|---------|------|
| [docs/csharp/overview.md](docs/csharp/overview.md) | C# で FiveM リソースを開発するための概要・環境構築・アーキテクチャ |
| [docs/csharp/lua-to-csharp.md](docs/csharp/lua-to-csharp.md) | Lua → C# パターン集（イベント・NUI 通信・Exports・非同期・Blazor WASM） |
| [docs/csharp/blazor-wasm.md](docs/csharp/blazor-wasm.md) | Blazor WASM を FiveM NUI として使う — 実装パターン・採用判断・JSImport |


参照リポジトリの一覧は → [SOURCES.md](SOURCES.md)

---

## AIツールでの利用について

このリポジトリは GitHub Copilot や Cursor 等のAIコーディングアシスタントが  
LB Phone / FiveM固有の知識を正確に補完できるよう構造化されています。

- **GitHub Copilot (VS Code)**: `.github/copilot-instructions.md` が自動的に読み込まれます
- **GitHub Copilot スキル**: `SKILL.md` + `docs/` を ZIP 化した配布物を `.copilot/skills/` に展開すると、どのワークスペースでもスキルとして参照されます（詳細は Releases 参照）
- **その他のAIツール**: `docs/` 以下のファイルをコンテキストとして追加してください

### ソースコードの参照

ドキュメントだけでは不足な場合、`scripts/fetch-repo.ps1` で参照リポジトリをリポジトリ単位で取得できます。

```powershell
# 利用可能なキー名を確認
pwsh -File .\scripts\fetch-repo.ps1

# 指定リポジトリをクローン
pwsh -File .\scripts\fetch-repo.ps1 bs_laymo

# 既存リポジトリを最新化
pwsh -File .\scripts\fetch-repo.ps1 bs_laymo -Pull
```

取得先は `temp_repos/<キー名>/`（`.gitignore` で除外済み）。詳細は [SOURCES.md](SOURCES.md) のライセンス欄を確認してください。

---

## ライセンス・注意事項

- **lb-phone本体**は [lbscripts.com](https://lbscripts.com/) の商用製品です。本リポジトリはlb-phone本体のコードを含みません
- 各参照リポジトリのコードは各リポジトリのライセンスに従ってください（[SOURCES.md](SOURCES.md) 参照）
