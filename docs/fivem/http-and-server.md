# HTTP & サーバーサイド通信

FiveM リソースから HTTP 通信を行うための仕組みをまとめます。

---

## 全体構造

```
外部クライアント / NUI / ブラウザ
    │
    │ HTTP リクエスト (TCP port 30120)
    ▼
HttpServerManager（FxServer 組み込み）
    │
    │ 先頭バイトのプロトコル判定
    ├─ HTTP/1.x → HTTP パイプライン
    └─ TLS ClientHello (0x16 ...) → TLSServer → 復号 → HTTP パイプライン
    │
    │ URL の先頭パスでリソースへディスパッチ
    ▼
SetHttpHandler のコールバック  ← ここがリソースの管轄
    │
    ├─ Lua: request/response を直接操作
    ├─ Node.js: @citizenfx/http-wrapper → Koa/Express ミドルウェアへ
    └─ C#: 自前 IServer 実装 → OWIN 環境辞書 → ASP.NET Core MVC へ
```

**ゲームの通信（UDP）と HTTP（TCP）はプロトコルレベルで別物**です。同じポート番号 `30120` でも OS が別々のソケットとして管理します。

---

## SetHttpHandler — 外部からの HTTP 受信

`SetHttpHandler` は FiveM ゲームサーバーポート（既定: `30120`）に乗り入れて HTTP リクエストを受け取る API です。

### Lua での基本利用

```lua
SetHttpHandler(function(req, res)
    -- req.method, req.path, req.headers

    if req.path == '/api/data' and req.method == 'GET' then
        res.writeHead(200, { ['Content-Type'] = 'application/json' })
        res.write(json.encode({ status = 'ok' }))
        res.send()
    else
        res.writeHead(404)
        res.send()
    end
end)
```

### リクエストボディの読み取り（Lua）

Lua では body の到着が非同期になるため、`setDataHandler` で収集してから処理します。

```lua
SetHttpHandler(function(req, res)
    local body = ''

    req:setDataHandler(function(data)
        body = body .. data
    end)

    req:setCancelHandler(function()
        body = ''
    end)

    CreateThread(function()
        while body == '' do Wait(0) end

        local data = json.decode(body)
        res.writeHead(200, { ['Content-Type'] = 'application/json' })
        res.write(json.encode({ received = data }))
        res.send()
    end)
end)
```

### URL パターン

`SetHttpHandler` はリソース名でルーティングされます。

```
http://server:30120/{resourceName}/{path}
```

例:
```
http://127.0.0.1:30120/my-app/api/users
https://username-abc.users.cfx.re/my-app/api/data   ← Nucleus 経由
```

`fxmanifest.lua` に `ui_page` を設定した場合、UI ファイルも同じポート経由でアクセスされます:
```
http://127.0.0.1:30120/my-app/ui/dist/index.html
```

---

## PerformHttpRequest — 外部 API へのリクエスト送信

外部の API や Web サービスに HTTP リクエストを送る native。Server / Client どちらからでも使用可能です。

```lua
-- GET リクエスト
PerformHttpRequest(
    'https://api.example.com/data',
    function(statusCode, body, headers)
        if statusCode == 200 then
            local data = json.decode(body)
            print('レスポンス:', data.value)
        end
    end,
    'GET'
)

-- POST リクエスト（JSON ボディ）
PerformHttpRequest(
    'https://api.example.com/users',
    function(statusCode, body, headers)
        print('ステータス:', statusCode)
    end,
    'POST',
    json.encode({ name = 'John', age = 25 }),
    { ['Content-Type'] = 'application/json', ['Authorization'] = 'Bearer TOKEN' }
)
```

**注意事項**:
- `PerformHttpRequest` は**非同期**——コールバック前にLuaは次の処理に進む
- Client 側で使うと**プレイヤーのPCからリクエストが発生**するため、センシティブな処理は Server 側で行う
- `localhost` へのリクエストは既定でブロックされる場合がある

---

## @citizenfx/http-wrapper (Node.js)

Node.js リソースでは `@citizenfx/http-wrapper` を使い、Koa / Express ライクなミドルウェアパターンで `SetHttpHandler` をラップできます。

> **参考実装**: [lbphone/lb-upload](https://github.com/lbphone/lb-upload) — Koa + @citizenfx/http-wrapper で multipart アップロードを受信し、クラウドストレージへ転送する公式実装例

```typescript
import { createApp } from '@citizenfx/http-wrapper';
import Router from '@koa/router';
import koaBody from 'koa-body';

const app = createApp();  // SetHttpHandler をラップ
const router = new Router();

// JSON API エンドポイント
router.get('/api/data', async (ctx) => {
    ctx.body = { status: 'ok', time: Date.now() };
});

// multipart ファイルアップロード受信
router.post('/upload', koaBody({ multipart: true }), async (ctx) => {
    const file = ctx.request.files?.file;
    if (!file) {
        ctx.status = 400;
        return;
    }
    // ファイル処理...
    ctx.body = { url: 'https://...' };
});

app.use(router.routes());
app.use(router.allowedMethods());
```

```lua
-- fxmanifest.lua
server_script 'server/dist/index.js'  -- ビルド済み JS を FiveM が Node.js として実行
```

### C# での IServer 差し替えパターン

ASP.NET Core を FiveM 内で動かす際は、Kestrel（TCP リスナー）を `SetHttpHandler` ベースの自前 `IServer` に差し替えることができます。これにより TCP ポートを新たに開かずに ASP.NET Core の MVC/DI パイプライン全体が利用できます。

```csharp
// DI で Kestrel を排除し、自前 IServer を注入
new WebHostBuilder()
    .ConfigureServices(services =>
    {
        services.AddSingleton<IServer, FiveMHttpServer>();
    })
    .UseStartup<Startup>()
    .Build().Start();
```

```csharp
// FiveMHttpServer : IServer
public Task StartAsync<TContext>(IHttpApplication<TContext> application, CancellationToken ct)
{
    // TCP ポートは一切開かない
    SetHttpHandler(new Action<dynamic, dynamic>(async (req, res) =>
    {
        // FiveM の req/res を OWIN 環境辞書に変換して ASP.NET Core パイプラインへ流す
        var env = new Dictionary<string, object>
        {
            ["owin.RequestMethod"]      = req.method,
            ["owin.RequestPath"]        = req.path.Split('?')[0],
            ["owin.RequestPathBase"]    = "/" + resourceName,
            ["owin.RequestQueryString"] = req.path.Contains('?') ? req.path.Split('?', 2)[1] : "",
        };
        var context = application.CreateContext(/* ... */);
        await application.ProcessRequestAsync(context);
    }));
    return Task.CompletedTask;  // TCP bind なし
}
```

実装例: [simple-livemap](https://github.com/SaltyKid/simple-livemap)（ASP.NET Core + FiveM `SetHttpHandler` 統合）

---

## ポートに関する制約

FiveM リソースから**独自のポートを開くことはできません**。

```
FxServer プロセス
├── Lua/JS/C# リソース  → SetHttpHandler → ポート 30120 を共有
└── txAdmin 子プロセス  → OS に直接 TCP bind → ポート 40120（独自）
```

txAdmin がポート 40120 を使えるのは、FiveM リソースではなく **OS レベルで直接 TCP ソケットを bind する独立 Node.js 子プロセス**だからです。`net.createServer()` を直接呼び出せる環境が必要です。

独自ポートが必要な場合は、FiveM の**外**でサイドカーサービスを起動し、`PerformHttpRequest` 経由で通信するアーキテクチャが必要です。

---

## TCP ポート 30120 の多重化（内部動作）

ポート 30120（TCP）には複数プロトコルが到着するため、`HttpServerManager` が先頭バイトのパターンマッチでルーティングします。

```cpp
// HttpServerManager.cpp（FiveM ソースコードより）

// ① HTTP/1.x 行末に "HTTP/" があるか確認
auto httpMatcher = [](const std::vector<uint8_t>& bytes) {
    auto firstR = std::find(bytes.begin(), bytes.end(), '\r');
    if (firstR != bytes.end() && *(firstR + 1) == '\n') {
        std::string match(firstR - 8, firstR);
        if (match.find("HTTP/") == 0) return Match;
    }
};

// ② TLS ClientHello 検出: 先頭 0x16、offset 5 が 0x01
if (bytes.size() >= 6) {
    return (bytes[0] == 0x16 && bytes[5] == 1) ? Match : NoMatch;
}
```

| 先頭バイト列 | 判定 | ルーティング先 |
|---|---|---|
| `GET / HTTP/1.1\r\n` 等 | HTTP リクエスト行 | HttpServerImpl（HTTP/1.1） |
| `0x16 ... 0x01 ...` | TLS ClientHello | TLSServer → 復号後 HTTPS |
| その他 | 非 HTTP | 別ハンドラまたは切断 |

**UDP との分離**: FxServer は同じ `30120` でも `endpoint_add_tcp` と `endpoint_add_udp` を別々のソケットとして管理します。ゲームの ENet パケット（UDP）と HTTP（TCP）が混ざることはありません。

```
endpoint_add_tcp "0.0.0.0:30120"   ← HTTP/HTTPS（TCP）
endpoint_add_udp "0.0.0.0:30120"   ← ゲーム通信（UDP/ENet）
```

---

## TLS (HTTPS) サポート

FxServer には組み込みの TLS サポートがあります。TLS は SetHttpHandler に対して**透過的**です——リソース側からは平文 HTTP か TLS かを区別できません。

| 項目 | 内容 |
|------|------|
| 証明書ファイル名 | `server-tls.crt`（**変更不可**・ハードコード） |
| 秘密鍵ファイル名 | `server-tls.key`（**変更不可**・ハードコード） |
| 形式 | PEM 形式 |
| 配置場所 | `server.cfg` と同じディレクトリ |
| HTTP/2 有効化 | `set sv_netHttp2 true` を server.cfg に追記 |

TLS 内部フロー:
```cpp
// 平文・TLS 両方が同じ m_httpHandler を経由する
m_httpServer->RegisterHandler(m_httpHandler);    // 平文 HTTP/1.1
m_http2Server->RegisterHandler(m_httpHandler);   // h2（TLS復号後）

// TLS サーバーが ALPN で http/1.1 か h2 を決定
tlsServer->SetProtocolList({ "h2", "http/1.1" });
```

**実用上の注意**:
- Let's Encrypt 証明書を使う場合、自動更新のたびに `server-tls.crt` / `server-tls.key` を上書きコピーする仕組みが必要
- FxServer 再起動なしに証明書をホットリロードする仕組みはない
- これらの手間から、**Nucleus または Cloudflare Tunnel / nginx リバースプロキシ**が実質的に使われてきた背景がある

---

## Nucleus（cfx.re リバーストンネル）

FxServer 起動時に `cfx.re` へ認証し、リバース TCP トンネルを確立する仕組みです。ngrok に近い動作です。

```
[ブラウザ]
    │ HTTPS → username-abc.users.cfx.re
    ▼
[Nucleus (cfx.re インフラ)]   ← FxServer が先に TCP 接続を張っておく
    │ rpToken で認証済みトンネル経由でリレー
    ▼
[FxServer の SetHttpHandler]
```

- TCP の方向は **FxServer → cfx.re のアウトバウンド**（ファイアウォールで 30120 を開放しなくても NUI から到達可能）
- Nucleus が通るのは **HTTP（TCP）のみ**。ゲームの UDP 通信は Nucleus を経由しない
- `X-Cfx-Source-Ip` ヘッダで元の接続元 IP が FxServer に渡される

---

## 参考リンク

- [citizenfx/fivem — HttpServerManager.cpp](https://github.com/citizenfx/fivem/blob/master/code/components/citizen-server-net/src/HttpServerManager.cpp)
- [lbphone/lb-upload](https://github.com/lbphone/lb-upload) — Koa + @citizenfx/http-wrapper によるファイルアップロード公式実装
- [SaltyKid/simple-livemap](https://github.com/SaltyKid/simple-livemap) — ASP.NET Core IServer 差し替えパターンの C# 実装例
