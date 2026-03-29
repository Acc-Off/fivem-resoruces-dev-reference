# fivem-typescript-boilerplate（Ox TS Boilerplate）

> GitHub: https://github.com/communityox/fivem-typescript-boilerplate

Overextended（communityox）が提供する FiveM リソース向け TypeScript ボイラープレートです。Client / Server / React UI を TypeScript で統一管理でき、esbuild + Vite による高速ビルドを備えています。

---

## リポジトリ構成

```
src/
  client/
    index.ts         ← クライアントスクリプト（esbuild: IIFE形式）
  server/
    index.ts         ← サーバースクリプト（esbuild: CJS/Node22）
  common/            ← Client/Server 共通コード
web/
  src/               ← React 18 UI（Vite でビルド → dist/web/）
  public/
scripts/
  build.js           ← esbuild + @communityox/fx-utils ビルド制御
static/
  config.json        ← 実行時コンフィグ
locales/
  en.json            ← ox_lib ロケール定義
```

---

## ビルドシステム

| ターゲット | ツール | 出力形式 | 出力先 |
|-----------|--------|---------|--------|
| Client TS | esbuild | IIFE (es2021) | `dist/client.js` |
| Server TS | esbuild | CJS (Node22) | `dist/server.js` |
| Web UI | Vite | SPA | `dist/web/` |
| fxmanifest | @communityox/fx-utils | 自動生成 | `fxmanifest.lua` |

### ビルドコマンド

```bash
pnpm build      # 全体ビルド（fxmanifest も自動生成）
pnpm watch      # 開発用ウォッチモード
pnpm ui:dev     # UI 開発サーバー（port 3000）
```

---

## fxmanifest 自動生成（scripts/build.js）

`@communityox/fx-utils` の `createFxmanifest` を使い、ビルド後に `fxmanifest.lua` を自動生成します。

```javascript
import { createFxmanifest } from '@communityox/fx-utils';

createFxmanifest({
    client_scripts: ['dist/client.js'],
    server_scripts: ['dist/server.js'],
    ui_page:        'dist/web/index.html',
    files:          ['dist/web/**', 'static/config.json', 'locales/*.json'],
});
```

---

## NUI 通信パターン

このテンプレートは FiveM 標準の `SendNUIMessage` / `RegisterNUICallback` を使います。lb-phone カスタムアプリとして利用する場合は `SendCustomAppMessage` への差し替えが必要です（詳細→ [Lua ↔ UI 通信](../lb-phone/lua-ui-communication.md)）。

### Client → UI

```typescript
// src/client/index.ts
SendNUIMessage({ action: 'updateData', data: someData });
```

### UI → Client（fetchNui）

```typescript
// web/src/utils/fetchNui.ts
export async function fetchNui<T>(eventName: string, data?: unknown): Promise<T> {
    const options: RequestInit = {
        method: 'post',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    };
    const resourceName = (window as any).GetParentResourceName
        ? (window as any).GetParentResourceName()
        : 'nui-frame-app';
    const resp = await fetch(`https://${resourceName}/${eventName}`, options);
    return resp.json();
}
```

### UI イベントリスン（useNuiEvent）

```typescript
// web/src/hooks/useNuiEvent.ts
import { useEffect } from 'react';

export function useNuiEvent<T>(action: string, handler: (data: T) => void) {
    useEffect(() => {
        const listener = (event: MessageEvent) => {
            if (event.data?.action === action) {
                handler(event.data.data as T);
            }
        };
        window.addEventListener('message', listener);
        return () => window.removeEventListener('message', listener);
    }, [action, handler]);
}
```

---

## 環境検出

```typescript
// ブラウザ環境かゲーム内かを判別
export const IsBrowser: boolean = !(window as any).invokeNative;

// リソース名の取得（ブラウザ開発時はフォールバック）
export const ResourceName: string = (window as any).GetParentResourceName?.() ?? 'dev-resource';
```

---

## 条件付きコード除去

esbuild のラベルを使い、環境別にコードを除去できます。

```typescript
$BROWSER: {
    // ブラウザ専用コード（ゲーム内ビルドでは除去）
    console.log('Browser dev mode');
}

$CLIENT: {
    // クライアント専用コード
}

$SERVER: {
    // サーバー専用コード
}

$DEV: {
    // 開発時専用コード（本番ビルドでは除去）
}
```

---

## パスエイリアス（tsconfig.json）

```json
{
    "compilerOptions": {
        "paths": {
            "@common/*": ["./src/common/*"],
            "~/*": ["./*"]
        }
    }
}
```

---

## 主要依存パッケージ

| パッケージ | 用途 |
|-----------|------|
| `@citizenfx/client` | FiveM クライアント API 型定義 |
| `@citizenfx/server` | FiveM サーバー API 型定義 |
| `@communityox/ox_lib` | 共通ユーティリティ（callback・locale 等） |
| `@communityox/fx-utils` | fxmanifest 自動生成ビルドツール |
| `@nativewrappers/fivem` | ネイティブ関数ラッパー |
| `esbuild` | Client/Server TS バンドラー |
| `vite` | UI ビルドツール |
| `react` + `react-dom` | UI フレームワーク（v18） |
| `typescript` | 型チェック |
| `@biomejs/biome` | Linter / Formatter |

---

## lb-phone アプリへの応用

このテンプレートを lb-phone カスタムアプリのベースに使う場合の主な変更点:

1. `SendNUIMessage` → `exports["lb-phone"]:SendCustomAppMessage(identifier, data)` に変更
2. `CreateFxmanifest` の `ui_page` を `ui/dist/index.html` のように調整
3. アプリ登録コードを `src/client/index.ts` に追加（`AddCustomApp` 呼び出し）
4. `body { visibility: hidden }` を CSS に追加 + `componentsLoaded` 待ちの初期化パターンを実装

より統合されたテンプレートが欲しい場合は [MPS 統合テンプレート](mps-integrated.md)を検討してください。

---

## 関連ドキュメント

- [テンプレート選択ガイド](../getting-started/03-choose-template.md)
- [MPS 統合テンプレート](mps-integrated.md)
- [lb-phone 公式テンプレート](lb-phone-official.md)
