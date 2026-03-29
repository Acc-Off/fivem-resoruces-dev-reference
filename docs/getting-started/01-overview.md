# lb-phone カスタムアプリとは

## 概要

**lb-phone** は FiveM（GTA V マルチプレイヤーフレームワーク）向けの商用スマートフォンスクリプトです。  
カスタムアプリ機能により、開発者が独自のアプリをlb-phoneのUIに組み込めます。

> lb-phone本体: https://lbscripts.com/

---

## アーキテクチャ

lb-phoneカスタムアプリは以下の3層で構成されます。

```
┌─────────────────────────────────────────┐
│  UI（NUI / ブラウザ）                   │  React / Vue / Vanilla JS
│  src/App.tsx など                        │  lb-phoneが iframe として内包
└────────────┬────────────────────────────┘
             │ fetchNui / SendCustomAppMessage
┌────────────┴────────────────────────────┐
│  Client Script（Lua / TypeScript）      │  FiveM クライアント
│  client/main.lua など                   │  NUIコールバック登録・状態管理
└────────────┬────────────────────────────┘
             │ TriggerServerEvent / lib.callback
┌────────────┴────────────────────────────┐
│  Server Script（Lua / TypeScript）      │  FiveM サーバー
│  server/main.lua など                   │  DB操作・権限チェック・外部API
└─────────────────────────────────────────┘
```

---

## 通常のFiveM NUIとの違い

| 項目 | 通常のNUI | lb-phone カスタムアプリ |
|------|-----------|----------------------|
| 表示方式 | `SetNuiFocus` + `SendNUIMessage` | lb-phoneが iframe で管理 |
| Lua→UIメッセージ | `SendNUIMessage` | **`SendCustomAppMessage`** |
| UI初期化 | 即時表示可 | **`componentsLoaded`** 待ちが必須 |
| テーマ | 独自実装 | lb-phoneのCSS変数を継承 |
| アイコン・一覧 | — | lb-phoneのアプリ一覧に表示 |

---

## リソース構成の例

最小構成のlb-phoneカスタムアプリは以下のようになります。

```
my-app/
├── fxmanifest.lua       # FiveM リソース定義
├── config.lua           # 設定値
├── client/
│   └── main.lua         # アプリ登録・NUIコールバック
├── server/
│   └── main.lua         # サーバー処理（DB・権限等）
└── ui/
    ├── package.json
    ├── vite.config.ts
    └── src/
        └── App.tsx       # React UIメインコンポーネント
```

ビルド後は `ui/dist/` に成果物が生成され、`fxmanifest.lua` の `files` に含めます。

---

## 開発の流れ

1. **テンプレートを選ぶ** → [テンプレート選択ガイド](03-choose-template.md)
2. **プロジェクト構成を整える** → [プロジェクト構成](02-project-setup.md)
3. **アプリを登録する** → [アプリ登録](../lb-phone/app-registration.md)
4. **UIとLua間の通信を実装する** → [Lua↔UI通信](../lb-phone/lua-ui-communication.md)
5. **lb-phoneのAPI（ポップアップ・カメラ等）を使う** → [グローバルUI API](../lb-phone/global-ui-api.md)

---

## 関連ドキュメント

- [lb-phone 公式API リファレンス](../lb-phone/api-reference.md)
- [テンプレート選択ガイド](03-choose-template.md)
- [参照リポジトリ一覧](../../SOURCES.md)
