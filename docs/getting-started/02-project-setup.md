# プロジェクト構成・fxmanifest

## 推奨ディレクトリ構成

```
my-app/
├── fxmanifest.lua       # FiveM リソース定義（必須）
├── config.lua           # 設定値（framework-agnostic）
├── sql.sql              # DBテーブル定義（MySQLを使う場合）
├── client/
│   ├── main.lua         # アプリ登録・メインロジック
│   └── functions.lua    # ヘルパー関数
├── server/
│   ├── main.lua         # イベントハンドラ・CBregistration
│   ├── db.lua           # DB操作
│   └── bridge.lua       # マルチフレームワーク対応ブリッジ
└── ui/
    ├── package.json
    ├── vite.config.ts
    ├── tsconfig.json
    ├── public/
    │   └── icon.png
    └── src/
        └── App.tsx
```

---

## fxmanifest.lua

### 最小構成

```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

description 'My FiveM Resource'
author 'Developer Name'
version '1.0.0'

shared_script 'config.lua'
client_scripts { 'client/*.lua' }
server_scripts { 'server/*.lua' }

ui_page 'ui/dist/index.html'
files { 'ui/dist/**' }

dependencies { 'lb-phone' }
```

### MySQL（oxmysql）を使う場合

```lua
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}
```

### ox_lib を使う場合

```lua
shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}
dependencies { 'lb-phone', 'ox_lib' }
```

### TypeScript（esbuild）ビルドを使う場合

TypeScript でビルドする場合は `fxmanifest.lua` を自動生成するツールを使う構成が多い。  
詳細は [Ox TypeScript Boilerplate](../templates/ox-typescript-boilerplate.md) を参照。

```lua
-- ビルド後の dist ファイルを指定する
client_script 'dist/client.js'
server_script 'dist/server.js'
ui_page 'dist/web/index.html'
files { 'dist/web/**' }
```

---

## Vite 設定（UI側）

```typescript
// ui/vite.config.ts
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig(({ command }) => ({
    plugins: [react()],
    // build時にlb-phoneが期待するパスに合わせる
    base: command === 'build' ? '/ui/dist' : undefined,
    // 一部ライブラリが require する global を置換
    define: { global: 'window' },
    server: {
        port: 3000,
        open: true,
    },
    build: {
        outDir: 'dist',
        emptyOutDir: true,
    },
}))
```

> **注意**: `base` の値はfxmanifestの `ui_page` パスに合わせること。
> `ui_page 'ui/dist/index.html'` の場合は `base: '/ui/dist'` とする。

---

## package.json の基本構成

```json
{
    "name": "my-app",
    "private": true,
    "type": "module",
    "scripts": {
        "dev": "vite",
        "build": "tsc && vite build",
        "watch": "vite build --watch"
    },
    "dependencies": {
        "react": "^18.3.1",
        "react-dom": "^18.3.1"
    },
    "devDependencies": {
        "@types/react": "^18.3.0",
        "@types/react-dom": "^18.3.0",
        "@vitejs/plugin-react": "^4.3.0",
        "typescript": "^5.8.0",
        "vite": "^5.4.0"
    }
}
```

---

## config.lua の例

```lua
Config = {}

Config.Identifier   = "myapp"          -- AddCustomApp の identifier と一致させること
Config.Name         = "My App"
Config.Description  = "アプリの説明"
Config.Developer    = "Developer Name"
Config.DefaultApp   = true             -- true = インストール不要で最初から使える

-- フレームワーク設定
Config.Framework    = "auto"           -- "esx" | "qb" | "qbx" | "auto"
```

---

## UI の CSS 基本設定

```css
/* lb-phone が表示タイミングを制御するため必須 */
body {
    visibility: hidden;
    margin: 0;
    padding: 0;
    overflow: hidden;
}
```

---

## 関連ドキュメント

- [アプリ登録](../lb-phone/app-registration.md) — `AddCustomApp` の全パラメータ
- [テンプレート選択ガイド](03-choose-template.md)
- [Ox TypeScript Boilerplate](../templates/ox-typescript-boilerplate.md)
