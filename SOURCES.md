# 参照リポジトリ一覧 (Sources)

このリポジトリのドキュメントは以下のオープンソースリポジトリを分析・参照して作成されました。  
コードを実際に使用・改変する場合は各リポジトリのライセンスを確認してください。

---

## テンプレート / Boilerplates

### Ox TypeScript Boilerplate
- **リポジトリ**: https://github.com/communityox/fivem-typescript-boilerplate
- **作者**: communityox (Overextended)
- **ライセンス**: GPL-3.0
- **概要**: FiveM汎用のTypeScriptボイラープレート。esbuild（client/server）+ Vite（NUI）の2段階ビルドシステム。CI/CD対応。
- **特徴**:
  - `$BROWSER` / `$CLIENT` / `$SERVER` ラベルによる環境別コード除去
  - `@communityox/fx-utils` による `fxmanifest.lua` 自動生成
  - ox_lib lokale統合
- **分析ドキュメント**: [docs/templates/ox-typescript-boilerplate.md](docs/templates/ox-typescript-boilerplate.md)

### lb-phone App Template（公式）
- **リポジトリ**: https://github.com/lbphone/lb-phone-app-template
- **作者**: lbphone (lb-scripts)
- **ライセンス**: 要確認（商用スクリプト作者提供）
- **概要**: lb-phone公式カスタムアプリテンプレート。4バリアント提供。
  - `lb-reactts` — React + TypeScript（推奨）
  - `lb-reactjs` — React + JavaScript
  - `lb-vanillajs` — Vanilla JS
  - `lb-vuejs` — Vue.js
- **特徴**:
  - `fetchNui` / `useNuiEvent` のカスタムフック・ユーティリティ付属
  - `componentsLoaded` 待機パターンのボイラープレート
  - `window.components.*` グローバルAPIの TypeScript型定義 (`components.d.ts`)
- **分析ドキュメント**: [docs/lb-phone/app-registration.md](docs/lb-phone/app-registration.md), [docs/templates/lb-phone-official.md](docs/templates/lb-phone-official.md)

### mps-lb-phone-apptemplate-reactts（MPS統合版）
- **リポジトリ**: https://github.com/Maximus7474/mps-lb-phone-apptemplate-reactts
- **作者**: Maximus7474
- **ライセンス**: All Rights Reserved（商用利用不可 — 参考用のみ）
- **概要**: 上記2つのテンプレートを統合した実践的な出発点。React + TypeScript + ox_lib対応。
- **特徴**:
  - `triggerServerCallback<T>()` Promise形式カスタムコールバックシステム
  - ox_lib `lib.callback` 統合
  - PermissionsシステムのUIレイヤー実装例
  - Tailwind CSS統合
- **分析ドキュメント**: [docs/lb-phone/app-registration.md](docs/lb-phone/app-registration.md), [docs/templates/mps-integrated.md](docs/templates/mps-integrated.md)

---

## lb-phone カスタムアプリ実装例

### bs_laymo — 自律型乗車サービスアプリ
- **リポジトリ**: https://github.com/BeetleStudios/bs_laymo
- **作者**: Seamus McMasters (Beetle Studios)
- **ライセンス**: 要確認
- **概要**: Waymo/Uber風の自律型乗車サービスアプリ（lb-phone用）。NPCドライバー・動的料金計算・リアルタイムトラッキング実装。
- **フレームワーク**: QBX Core + ox_lib + oxmysql
- **使用技術**: React + TypeScript, Vite, esbuild
- **ポイント**:
  - lb-phone `AddCustomApp` の実践的な使い方
  - ox_lib callback を使ったclient↔server非同期通信
  - Zustand状態管理 + React Query
- **分析ドキュメント**: [docs/examples/bs-laymo.md](docs/examples/bs-laymo.md)

### factionapp — ファクション管理アプリ
- **リポジトリ**: https://github.com/Panturien/factionapp
- **作者**: Panturien
- **ライセンス**: 要確認
- **概要**: lb-phone用ファクション/ギャング管理アプリ。オンラインメンバー確認・通話・SMS・MOTD投稿機能。
- **特徴**:
  - シンプルなHTML/CSS/JS UIの実装例（フレームワーク不使用）
  - `onServerUse` コールバックパターン
  - ESX / QBCore / スタンドアロン 対応
- **分析ドキュメント**: [docs/examples/factionapp.md](docs/examples/factionapp.md)

### slrn_groups — グループ管理アプリ
- **リポジトリ**: https://github.com/solareon/slrn_groups
- **作者**: solareon
- **ライセンス**: GPL-3.0
- **概要**: lb-phone用グループ/チーム管理アプリ。ox_libベースのフレームワーク非依存実装。
- **フレームワーク**: フレームワーク非依存（ox_lib必須）
- **使用技術**: React + TypeScript, Vite
- **ポイント**:
  - ox_lib permissionsシステムの実装例
  - GitHub Actions CI/CD（lint + build）
  - マルチフレームワーク対応のブリッジパターン
- **分析ドキュメント**: [docs/examples/slrn-groups.md](docs/examples/slrn-groups.md)

---

## FiveM電話スクリプト

### FiveM-phone — マルチフレームワーク電話スクリプト
- **リポジトリ**: https://github.com/Greigh/FiveM-phone
- **作者**: Greigh
- **ライセンス**: 要確認
- **概要**: 複数のFiveM電話スクリプト（lb-phone・qb-phone等）に対応したマルチフレームワーク統合スクリプト。
- **ポイント**:
  - フレームワーク検出+ブリッジの実装パターン
  - lb-phone Integration レイヤーの書き方
- **分析ドキュメント**: [docs/examples/fivem-phone.md](docs/examples/fivem-phone.md)

---

## C# 実装例（FiveM リソース開発）

FiveM リソースを C# で開発する際のアーキテクチャ・パターン参考用。いずれも TypeScript/Lua ではなく C# で記述されており、Server / Client スクリプトの C# 実装・ASP.NET Core の活用・`SetHttpHandler` との統合などを学べます。

### simple-livemap
- **リポジトリ**: https://github.com/charming-byte/simple-livemap
- **作者**: charming-byte
- **ライセンス**: 要確認
- **言語**: C# (.NET / Mono)
- **概要**: FiveM サーバーのプレイヤー位置情報をブラウザ上のライブマップで表示するリソース。ASP.NET Core の MVC/DI パイプラインを FiveM の `SetHttpHandler` に接続するために、Kestrel を自前の `IServer` 実装に差し替えるアーキテクチャが特徴。
- **注目ポイント**:
  - `SetHttpHandler` + ASP.NET Core の統合パターン（`IServer` 差し替え）
  - FiveM C# リソースの `BaseScript` 継承パターン
  - State Bags / `AddStateBagChangeHandler` の C# 利用例
- **参考**: [docs/fivem/http-and-server.md](docs/fivem/http-and-server.md)（`@citizenfx/http-wrapper` + Koa の統合セクションで参照）

### vMenu
- **リポジトリ**: https://github.com/TomGrobbe/vMenu
- **作者**: TomGrobbe
- **ライセンス**: MIT
- **言語**: C# (.NET / Mono)
- **概要**: FiveM サーバー向けの包括的なサーバーサイドメニューシステム。C# で実装された大規模 FiveM リソースの代表的な実装例。パーミッションシステム・設定管理・NUI 通信・ネイティブラッパーの活用などが学べる。
- **注目ポイント**:
  - 大規模 C# FiveM リソースのプロジェクト構成
  - `BaseScript` 継承 + `EventHandler` 属性パターン
  - MenuAPI（独自 NUI メニューシステム）の C# ↔ NUI 通信
  - `Exports` / `TriggerServerEvent` の C# 実装

### FiveMRpServerResources
- **リポジトリ**: https://github.com/ossianhanning/FiveMRpServerResources
- **作者**: ossianhanning
- **ライセンス**: 要確認
- **言語**: C# (.NET / Mono)
- **概要**: FiveM RP サーバー向けの複数リソースをまとめたコレクション。銀行・ジョブ・インベントリ等、典型的な RP サーバー機能が C# で実装されており、実用的な C# FiveM リソース群として参考になる。
- **注目ポイント**:
  - RP サーバー典型機能（銀行・インベントリ等）の C# 実装パターン
  - Server ↔ Client の C# イベント通信構成
  - DB 連携（SQL）の C# 実装

---

## lb-phone 本体

lb-phone本体は商用制品のため、コードは含みません。内部構造の分析ノートのみ掲載しています。

- **販売元**: https://lbscripts.com/
- **バージョン**: v2.6.0（分析時点）
- **分析ドキュメント**: [docs/lb-phone/internals.md](docs/lb-phone/internals.md)（内部構造・フレームワークブリッジ・コールバックシステム）, [docs/lb-phone/api-reference.md](docs/lb-phone/api-reference.md)（公式API完全リファレンス）

---

## 参照方法の注記

各分析ドキュメントは元リポジトリのコードを **研究・参照目的** で分析したものです。  
実際の開発に利用する場合は、必ず元リポジトリのライセンスを確認し、適切な帰属表示を行ってください。
