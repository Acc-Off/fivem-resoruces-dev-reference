---
name: fivem-resources-dev-reference
description: FiveM リソース開発（lb-phone カスタムアプリを含む）に関する質問・実装・コード生成を支援するナレッジベーススキル。以下のトピックに関する質問が来たら必ずこのスキルを参照すること: FiveM Lua/TypeScript/C# リソース開発, lb-phone カスタムアプリ (AddCustomApp, SendCustomAppMessage, useNuiEvent, fetchNui, fixBlur), Client↔Server↔NUI 通信パターン (TriggerServerEvent, TriggerClientEvent, RegisterNUICallback, lib.callback, State Bags, SetHttpHandler, PerformHttpRequest), ox_lib, ESX, QBCore, fxmanifest.lua, Vite+React NUI, Blazor WASM NUI, fivem-typescript-boilerplate.
---

# FiveM リソース開発 ナレッジベース

FiveM リソース開発および lb-phone カスタムアプリ開発のドキュメントを集めたナレッジベースです。

---

## docs/ の場所

このファイル（SKILL.md）と同じディレクトリに `docs/` フォルダがあります。

このファイルのパスはシステムプロンプトの `<file>` タグで確認できます。そのパスを基に `docs/` の絶対パスを構築し、`read_file` で読み込んでください。

例: SKILL.md が `C:\Users\foo\.copilot\skills\fivem-resources-dev-reference\SKILL.md` のとき
→ docs は `C:\Users\foo\.copilot\skills\fivem-resources-dev-reference\docs\`

---

## ドキュメントマップ

質問のトピックに応じて以下のファイルを `read_file` で読み込んで回答してください。複数のトピックにまたがる場合は複数ファイルを並列で読んでください。

### lb-phone カスタムアプリ

| トピック | docs/ 以下のパス |
|---------|----------------|
| アプリの概要・3層アーキテクチャ | `getting-started/01-overview.md` |
| プロジェクト構成・fxmanifest・Vite 設定 | `getting-started/02-project-setup.md` |
| テンプレート選択・比較 | `getting-started/03-choose-template.md` |
| AddCustomApp 全パラメータ・登録タイミング | `lb-phone/app-registration.md` |
| Lua ↔ UI 通信（SendCustomAppMessage / fetchNui / useNuiEvent） | `lb-phone/lua-ui-communication.md` |
| window.* グローバル API（components.* 等） | `lb-phone/global-ui-api.md` |
| CSS 変数・ダークモード・fixBlur | `lb-phone/themes-and-css.md` |
| Client/Server Exports・Events・State Bags 公式 API | `lb-phone/api-reference.md` |
| lb-phone 内部構造・フレームワークブリッジ | `lb-phone/internals.md` |

### FiveM 全般

| トピック | docs/ 以下のパス |
|---------|----------------|
| Client↔Server↔NUI 通信パターン12種（source変数・各フレームワーク Callback・セキュリティ等） | `fivem/communication-patterns.md` |
| State Bags（GlobalState・Player state・Entity state・変更ハンドラ） | `fivem/state-bags.md` |
| SetHttpHandler・PerformHttpRequest・TLS・HTTP ラッパー | `fivem/http-and-server.md` |

### テンプレート

| トピック | docs/ 以下のパス |
|---------|----------------|
| lb-phone-app-template（公式）構成・パターン | `templates/lb-phone-official.md` |
| fivem-typescript-boilerplate（Ox・esbuild+Vite+React） | `templates/ox-typescript-boilerplate.md` |
| mps-lb-phone-apptemplate-reactts（統合版・DB・ブリッジ） | `templates/mps-integrated.md` |

### 実装例（lb-phone カスタムアプリ）

| トピック | docs/ 以下のパス |
|---------|----------------|
| bs_laymo（自動運転タクシー・NPC 制御・料金計算） | `examples/bs-laymo.md` |
| factionapp（ESX ファクション管理・Vanilla JS） | `examples/factionapp.md` |
| slrn_groups（マルチフレームワーク・React TS・lib.callback） | `examples/slrn-groups.md` |
| FiveM-phone（マルチフレームワーク自動検出・Vanilla JS） | `examples/fivem-phone.md` |

### 実装例（C# FiveM リソース）

| トピック | docs/ 以下のパス |
|---------|----------------|
| simple-livemap（C# + ASP.NET Core + SetHttpHandler + SSE） | `examples/simple-livemap.md` |
| vMenu（大規模 C# FiveM リソース・権限設計・Convar） | `examples/vmenu.md` |
| FiveMRpServerResources（C# RP 機能集・セッション管理） | `examples/fivemrpserverresources.md` |

### C# 開発者向け

| トピック | docs/ 以下のパス |
|---------|----------------|
| C# FiveM リソース開発の概要・環境構築・アーキテクチャ | `csharp/overview.md` |
| Lua → C# パターン集（イベント・NUI・Exports・非同期） | `csharp/lua-to-csharp.md` |
| Blazor WASM を FiveM NUI として使う | `csharp/blazor-wasm.md` |

---

## ソースコード参照が必要な場合

ドキュメントだけでは不足で **実際のソースコードを確認したい**（コード例・型定義・実装パターン等）ときは、以下の手順でリポジトリを取得してください。

### 1. 取得先の確認

SKILL.md と同じディレクトリにある `scripts/fetch-repo.ps1` を使います。  
まず引数なしで実行し、利用可能なキー名を確認してください。

> **注意**: スクリプトは日本語コメントを含むため、`pwsh`（PowerShell 7+）で実行してください。  
> `powershell.exe`（Windows PowerShell 5.x）では文字化けします。

```powershell
# キー名一覧を表示
pwsh -File .\scripts\fetch-repo.ps1
```

### 2. 対象リポジトリを1件取得

```powershell
# 例: bs_laymo のソースを取得
pwsh -File .\scripts\fetch-repo.ps1 bs_laymo

# 例: lb-phone 公式テンプレートを取得
pwsh -File .\scripts\fetch-repo.ps1 lb-phone-app-template
```

取得先は `temp_repos/<キー名>/` です（SKILL.md 起点の相対パス）。

### 3. 既存リポジトリを最新化

```powershell
# -Pull スイッチで git pull を実行
pwsh -File .\scripts\fetch-repo.ps1 bs_laymo -Pull
```

### キー名とリポジトリの対応表

| キー名 | 内容 |
|--------|------|
| `fivem-typescript-boilerplate` | Ox TypeScript Boilerplate (esbuild + Vite + React) |
| `lb-phone-app-template` | lb-phone 公式カスタムアプリテンプレート |
| `mps-integrated` | MPS 統合版テンプレート (React + TS + ox_lib + DB) |
| `bs_laymo` | 自動運転タクシーアプリ (QBX + ox_lib + React TS) |
| `factionapp` | ファクション管理アプリ (ESX / QBCore / Vanilla JS) |
| `slrn_groups` | グループ管理アプリ (フレームワーク非依存 + React TS) |
| `fivem-phone` | マルチフレームワーク電話スクリプト (Vanilla JS) |
| `simple-livemap` | C# + ASP.NET Core IServer + SetHttpHandler + SSE |
| `vmenu` | 大規模 C# FiveM リソース・権限設計・Convar |
| `fivemrpserverresources` | C# RP 機能集 (銀行・インベントリ等)・セッション管理 |

### 注意事項

- `temp_repos/` は `.gitignore` で除外されているため、取得したソースはリポジトリに含まれません。
- 各リポジトリのライセンスを確認してから利用してください（`SOURCES.md` 参照）。
- スクリプトの実行には `git` コマンドが PATH に通っている必要があります。
