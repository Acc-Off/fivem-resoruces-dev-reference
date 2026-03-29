# mps-lb-phone-apptemplate-reactts（MPS 統合テンプレート）

> GitHub: https://github.com/Maximus7474/mps-lb-phone-apptemplate-reactts

Ox TypeScript Boilerplate と lb-phone 公式テンプレートを統合した実践的なテンプレートです。[Maximus7474](https://github.com/Maximus7474) 作。TypeScript による Client/Server/UI の統一管理、カスタムコールバックシステム、マルチフレームワークブリッジを備えています。lb-phone カスタムアプリ開発の出発点として最適なテンプレートです。

---

## リポジトリ構成

```
src/
  client/
    add_application/     ← lb-phone アプリ登録（TypeScript 化）
      data.ts            ← アプリメタデータ・AddCustomApp コール
      index.ts           ← lb-phone 起動待ち + 登録実行
    account/             ← アカウント関連 NUIコールバック群
    transfer/            ← 送金・近接共有 NUIコールバック群
    utils/
      callbacks.ts       ← triggerServerCallback<T>() — Promise ベース
  server/
    user/                ← 認証・残高・履歴 ロジック
    transfer/            ← 送金処理
    utils/
      callbacks.ts       ← RegisterServerCallback + onNet ハンドラ
  common/
    types/               ← User, Transfer, Callback 共有型定義
bridge/
  utils.lua              ← フレームワーク検出関数
  esx/server.lua         ← ESX 銀行操作 exports
  qbe/server.lua         ← QBCore 対応
  qbx/server.lua         ← QBX 対応
sql/
  tables.sql             ← DB テーブル定義
web/
  src/
    components/          ← PageLayout, Footer, ProfilePicture, AuthProvider
    hooks/               ← useAuth, useNuiEvent
    pages/               ← Home 等
    utils/               ← fetchNui, debugData
scripts/
  build.js               ← esbuild + @communityox/fx-utils
static/
  config.json            ← アプリメタデータ（Identifier, AppName 等）
locales/
  en.json
```

---

## アプリ登録（TypeScript 化）

`src/client/add_application/data.ts`:

```typescript
// fxmanifest から ui_page を動的取得することでパスの不一致を防ぐ
const url = GetResourceMetadata(GetCurrentResourceName(), 'ui_page', 0);

export const appConfig: AppConfig = {
    identifier: Config.Identifier,
    name:       Config.AppName,
    developer:  Config.Developer,
    defaultApp: true,
    fixBlur:    true,
    // 開発サーバー URL か本番パスかを自動判別
    ui:   url.includes('http') ? url : `${GetCurrentResourceName()}/${url}`,
    icon: url.includes('http')
        ? `${url}/public/icon.png`
        : `https://cfx-nui-${GetCurrentResourceName()}/dist/web/icon.png`,
    onClose: () => { exports['lb-phone'].DisableWalkableCam(); },
};
```

`src/client/add_application/index.ts`:

```typescript
// lb-phone が起動するまで待機
async function waitForResourceStarted(resource: string): Promise<void> {
    return new Promise((resolve) => {
        const check = setInterval(() => {
            if (GetResourceState(resource) === 'started') {
                clearInterval(check);
                resolve();
            }
        }, 500);
    });
}

async function loadApplication() {
    await waitForResourceStarted('lb-phone');
    exports['lb-phone'].AddCustomApp(appConfig);
}

loadApplication();
// リロード対応: lb-phone 再起動時にも再登録
on('onResourceStart', (resource: string) => {
    if (resource === 'lb-phone') loadApplication();
});
```

---

## カスタムコールバックシステム（Client ↔ Server）

型安全な Promise ベースの Client→Server 通信を実現します。

### Client 側（`src/client/utils/callbacks.ts`）

```typescript
const pendingCallbacks = new Map<string, (res: CallbackResponse) => void>();

function generateUUID(): string {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
        const r = Math.random() * 16 | 0;
        return (c === 'x' ? r : (r & 0x3 | 0x8)).toString(16);
    });
}

export function triggerServerCallback<T>(name: string, data?: unknown): Promise<T> {
    return new Promise((resolve, reject) => {
        const id = generateUUID();
        pendingCallbacks.set(id, (res) => {
            if (res.success) resolve(res.data as T);
            else reject(new Error(res.error));
        });
        emitNet('myResource:server:triggerCallback', name, id, data);
    });
}

onNet('myResource:client:callbackResponse', (requestId: string, response: CallbackResponse) => {
    const cb = pendingCallbacks.get(requestId);
    if (cb) {
        cb(response);
        pendingCallbacks.delete(requestId);
    }
});
```

### Server 側（`src/server/utils/callbacks.ts`）

```typescript
const registeredCallbacks = new Map<string, ServerCallbackHandler>();

export function RegisterServerCallback<T>(
    name: string,
    handler: (source: number, data: unknown) => Promise<T>
) {
    registeredCallbacks.set(name, handler);
}

onNet('myResource:server:triggerCallback', async (name: string, requestId: string, data: unknown) => {
    const src = (global as any).source as number;
    const callback = registeredCallbacks.get(name);
    if (!callback) return;
    try {
        const result = await callback(src, data);
        emitNet('myResource:client:callbackResponse', src, requestId, { success: true, data: result });
    } catch (err) {
        emitNet('myResource:client:callbackResponse', src, requestId, { success: false, error: String(err) });
    }
});
```

### 使用例

```typescript
// Client: 型安全な非同期 Server 呼び出し
const balance = await triggerServerCallback<number>('getBalance', { playerId: PlayerId() });

// Server: コールバック登録
RegisterServerCallback<number>('getBalance', async (source, data) => {
    const player = getPlayerData(source);
    return player.balance;
});
```

---

## マルチフレームワークブリッジ（Lua）

各フレームワーク固有の処理は `bridge/` 以下の Lua ファイルにまとめ、冒頭のガード節で不要なファイルを無効化します。

```lua
-- bridge/esx/server.lua
if GetResourceState('es_extended') ~= 'started' then return end
if not IsDuplicityVersion() then return end  -- Server 専用

local ESX = exports.es_extended:getSharedObject()

exports('GetBankBalance', function(source)
    return ESX.GetPlayerFromId(source).getAccount('bank').money
end)

exports('RemoveMoney', function(source, amount)
    ESX.GetPlayerFromId(source).removeAccountMoney('bank', amount)
end)
```

ビルド時に `scripts/build.js` で fxmanifest へ自動追記されます:

```javascript
client_scripts: [outfiles.client, 'bridge/utils.lua', 'bridge/**/client.lua'],
server_scripts: [outfiles.server, 'bridge/utils.lua', 'bridge/**/server.lua'],
```

---

## React UI 構成（web/）

### React Router + AuthProvider

```tsx
// web/src/index.tsx
import { HashRouter } from 'react-router-dom';
import { AuthProvider } from './components/provider/AuthProvider';

createRoot(document.getElementById('root')!).render(
    <HashRouter>
        <AuthProvider>
            <App />
        </AuthProvider>
    </HashRouter>
);
```

### AuthProvider（fetchNui ベース全状態管理）

```tsx
// web/src/components/provider/AuthProvider.tsx
export function AuthProvider({ children }) {
    const [user, setUser] = useState<User | null>(null);

    const login = async (credentials: LoginData) => {
        const result = await fetchNui<AuthResult>('login', credentials);
        if (result.success) setUser(result.user);
    };

    return (
        <AuthContext.Provider value={{ user, login, logout, register }}>
            {children}
        </AuthContext.Provider>
    );
}

// 各コンポーネントから
const { user, login } = useAuth();
```

---

## DB 統合（oxmysql）

```typescript
import { oxmysql as MySQL } from '@communityox/oxmysql';

// 単一行取得
const user = await MySQL.single<User>(
    'SELECT * FROM users WHERE identifier = ?',
    [identifier]
);

// 挿入
const insertId = await MySQL.insert(
    'INSERT INTO users (identifier, name, balance) VALUES (?, ?, ?)',
    [identifier, name, 0]
);
```

パスワードハッシュには FiveM 組み込みの native を使用:

```typescript
const hash  = GetPasswordHash(plainPassword);
const valid = VerifyPasswordHash(plainPassword, storedHash);
```

---

## 追加依存パッケージ

Ox Boilerplate との差分:

| パッケージ | 用途 |
|-----------|------|
| `@communityox/oxmysql` | MySQL クライアント |
| `react-router-dom` | SPA ルーティング |
| `lucide-react` | アイコンセット |
| React 19 | (Ox Boilerplate は v18 → v19 に更新) |

---

## 通信フロー全体図

```
[Web UI]
  │ fetchNui(event)              useNuiEvent(action)
  ▼                                    ▲
[Client TS]   triggerServerCallback()  │ SendCustomAppMessage()
  │                                    │
  │ emitNet()                          │ SendNUIMessage()
  ▼                                    │
[Server TS]   RegisterServerCallback() │
  │                                    │
  └── DB (oxmysql) ───────────────────┘
```

---

## 関連ドキュメント

- [テンプレート選択ガイド](../getting-started/03-choose-template.md)
- [Ox TypeScript Boilerplate](ox-typescript-boilerplate.md)
- [lb-phone 公式テンプレート](lb-phone-official.md)
- [FiveM 通信パターン](../fivem/communication-patterns.md)
