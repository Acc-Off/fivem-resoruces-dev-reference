# テンプレート選択ガイド

lb-phoneカスタムアプリ開発に使えるテンプレートは主に3種類あります。  
用途・スキルセットに合わせて選んでください。

## 比較表

| テンプレート | UI言語 | ビルドツール | 難易度 | 特徴 |
|------------|--------|------------|--------|------|
| [lb-phone公式](#lb-phone公式テンプレート) | React / Vue / Vanilla JS | Vite | ★☆☆ | lb-phone特化・シンプル |
| [Ox TypeScript Boilerplate](#ox-typescript-boilerplate) | React + TypeScript | esbuild + Vite | ★★☆ | 汎用TS・CI/CD対応 |
| [MPS統合版](#mps統合版テンプレート) | React + TypeScript | esbuild + Vite | ★★★ | ox_lib統合・実践的 |

---

## lb-phone公式テンプレート

> リポジトリ: https://github.com/lbphone/lb-phone-app-template

**こんな人向け:**
- lb-phone専用アプリを作りたい
- TypeScriptが不要、またはVueやVanillaJSで作りたい
- シンプルな構成で始めたい

**バリアント:**
- `lb-reactts` — React + TypeScript（推奨）
- `lb-reactjs` — React + JavaScript
- `lb-vanillajs` — Vanilla JavaScript（最もシンプル）
- `lb-vuejs` — Vue.js

**主な特徴:**
- `fetchNui` / `useNuiEvent` フックが付属
- `componentsLoaded` 待機パターンが実装済み
- TypeScript型定義（`components.d.ts`）が充実

詳細: [lb-phone公式テンプレート分析](../templates/lb-phone-official.md)

---

## Ox TypeScript Boilerplate

> リポジトリ: https://github.com/communityox/fivem-typescript-boilerplate

**こんな人向け:**
- Client / Server を含めた全体をTypeScriptで書きたい
- FiveM汎用の構成（lb-phone専用でなくてもよい）
- CI/CD・リンター（Biome）を整備したい

**主な特徴:**
- esbuild（client/server Lua相当 → JS）+ Vite（UI）の2段階ビルド
- `$CLIENT` / `$SERVER` / `$BROWSER` ラベルによる環境別コード除去
- `@communityox/fx-utils` による `fxmanifest.lua` 自動生成
- ox_lib lokale統合

**注意:** lb-phone固有のフック（`fetchNui`等）は含まれない。lb-phoneアプリとして使う場合はlb-phone公式テンプレートのユーティリティを追加する必要がある。

詳細: [Ox TypeScript Boilerplate分析](../templates/ox-typescript-boilerplate.md)

---

## MPS統合版テンプレート

> リポジトリ: https://github.com/Maximus7474/mps-lb-phone-apptemplate-reactts  
> ライセンス: All Rights Reserved（参考用のみ・商用利用不可）

**こんな人向け:**
- lb-phone × TypeScript × ox_libを全部そろえた状態で始めたい
- Promise形式のサーバーコールバックを使いたい
- 実際の開発パターンを参考にしたい

**主な特徴:**
- Ox TypeScript Boilerplate + lb-phone公式テンプレートを統合した構成
- `triggerServerCallback<T>()` — Promise形式カスタムコールバックシステム
- ox_lib `lib.callback` 統合
- Tailwind CSS統合
- パーミッションシステムのUIレイヤー実装例

**注意:** ライセンスがAll Rights Reservedのため、コードを直接コピーせずパターンのみ参考にすること。

詳細: [MPS統合版テンプレート分析](../templates/mps-integrated.md)

---

## どれを選ぶか フローチャート

```
TypeScript で全体（Client/Server/UI）を書きたい？
├─ Yes → oz_lib も使う？
│         ├─ Yes  → MPS統合版（参考のみ）or Ox Boilerplate + lb-phone公式を組み合わせ
│         └─ No   → Ox TypeScript Boilerplate
└─ No  → どのUIフレームワーク？
          ├─ React（JS）→ lb-phone公式 lb-reactjs
          ├─ Vue       → lb-phone公式 lb-vuejs
          └─ なし     → lb-phone公式 lb-vanillajs（最もシンプル）
```

---

## 実装例も参考に

実際に公開されているアプリの実装パターンも参考になります。

| アプリ | テンプレート相当 | 特徴 |
|--------|----------------|------|
| [bs_laymo](../examples/bs-laymo.md) | Ox Boilerplate的構成 + ox_lib | 複雑なゲームロジック（NPC AI等） |
| [slrn_groups](../examples/slrn-groups.md) | React + TypeScript + Vite + Tailwind | フレームワーク非依存・ox_lib |
| [factionapp](../examples/factionapp.md) | Vanilla JS（ビルドなし） | 最もシンプルな実装例 |
