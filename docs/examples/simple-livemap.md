# simple-livemap — C# + ASP.NET Core + SetHttpHandler 実装例

> GitHub: https://github.com/charming-byte/simple-livemap  
> 言語: C# (.NET Framework 4.8.1)  
> UI: React + TypeScript + react-leaflet

FiveM 向けのリアルタイムプレイヤー位置表示マップです。**FiveM サーバースクリプトを C# で実装する構成** と **ASP.NET Core + SetHttpHandler の統合パターン** を学べる代表的な実装例です。

---

## フォルダ構成

```
simple-livemap-main/
  server/
    ServerMain.cs          ← エントリポイント（ServerScript 継承）
    LiveMapScript.cs       ← Tick ごとにプレイヤー位置を取得して SSE 配信
    HttpServer.cs          ← SetHttpHandler → OWIN → ASP.NET Core ブリッジ
    Startup.cs             ← ASP.NET Core DI 設定・ルーティング
    LiveMap.Server.csproj
  ui/
    src/
      App.tsx
      hooks/usePlayers.ts  ← SSE でポジション受信
      components/
        PlayerMarker/      ← react-leaflet-drift-marker でスムーズ移動
        TileLayerWrapper/  ← GTA5 座標系カスタム CRS
    vite.config.ts
  fxmanifest.lua
```

---

## 学べるパターン

### 1. FiveM C# スクリプトの基本構造

```csharp
// FiveM サーバースクリプトは ServerScript（または ClientScript）を継承
public class ServerMain : ServerScript
{
    public ServerMain()
    {
        // コンストラクタで Tick に初期化処理を登録
        Tick += OnFirstTick;
    }

    private async Task OnFirstTick()
    {
        // 初回のみ実行 → 自身を登録解除してから後続処理
        Tick -= OnFirstTick;
        StartWebServer();
    }
}
```

### 2. Native API の使い方（C#）

```csharp
using CitizenFX.Core;
using CitizenFX.Core.Native;

// プレイヤーの Ped エンティティを取得
int ped = API.GetPlayerPed(player.Handle);

// エンティティの存在確認
bool exists = API.DoesEntityExist(ped);

// ワールド座標の取得
Vector3 coords = API.GetEntityCoords(ped);

// リソース名・パスの取得
string resourceName = API.GetCurrentResourceName();
string resourcePath  = API.GetResourcePath(resourceName);

// ServerScript.Players でプレイヤー一覧を取得
var playerList = Players
    .Where(p => API.DoesEntityExist(API.GetPlayerPed(p.Handle)))
    .Select(p => new MapPlayer(p))
    .ToList();
```

### 3. ★ SetHttpHandler + ASP.NET Core IServer 差し替えパターン

FiveM には `SetHttpHandler` という Native API があり、C# リソース内で HTTP リクエストを処理できます。  
このプロジェクトでは **Kestrel（TCP リスナー）を使わず** ASP.NET Core の MVC/DI パイプラインを SetHttpHandler に接続する **`IServer` 差し替えパターン** を採用しています。

```csharp
// ServerMain.cs — WebHostBuilder で IServer を差し替え
var host = new WebHostBuilder()
    .ConfigureServices(services =>
    {
        // ★ Kestrel の代わりに自前の HttpServer を IServer として登録
        //    これにより Kestrel の TCP bind は一切行われない
        services.AddSingleton<IServer, HttpServer>();
    })
    .UseStartup<Startup>()
    .Build();
host.Start();
```

```csharp
// HttpServer.cs — IServer 実装（Kestrel の代替）
public Task StartAsync<TContext>(
    IHttpApplication<TContext> application, CancellationToken ct)
{
    // TCP ポートは開かない。SetHttpHandler がトランスポートになる
    SetHttpHandler(new Action<dynamic, dynamic>(async (req, res) =>
    {
        // FiveM の req/res を OWIN 環境辞書に変換
        var owinEnv = new Dictionary<string, object>
        {
            ["owin.RequestMethod"]      = req.method,
            ["owin.RequestPath"]        = req.path.Split('?')[0],
            ["owin.RequestPathBase"]    = "/" + resourceName,
            ["owin.RequestQueryString"] =
                req.path.Contains('?') ? req.path.Split('?', 2)[1] : "",
        };
        // ASP.NET Core の MVC パイプラインに流し込む
        var ctx = application.CreateContext(
            new FeatureCollection(new FxOwinFeatureCollection(owinEnv)));
        await application.ProcessRequestAsync(ctx);
    }));
    return Task.CompletedTask; // ← TCP bind はここで何もしない
}
```

| 項目 | 実態 |
|------|------|
| プロセス | **インプロセス**（FiveM の Mono ランタイム内） |
| Kestrel | **使われない**（`IServer` を DI で差し替えて排除） |
| 新しい TCP ポート | 開かない（FiveM の 30120 を共有） |
| ASP.NET Core | MVC / DI / ミドルウェアのパイプライン部分だけ借用 |
| トランスポート | `SetHttpHandler` が担う |

### 4. ASP.NET Core DI・ルーティング設定

```csharp
// Startup.cs
public void ConfigureServices(IServiceCollection services)
{
    // SSE サービスを DI に登録
    services.AddServerSentEvents<IServerSentEventsService, ServerSentEventsService>(
        options =>
        {
            options.KeepaliveMode     = ServerSentEventsKeepaliveMode.Always;
            options.KeepaliveInterval = 20;
        });
    services.AddMvc().SetCompatibilityVersion(CompatibilityVersion.Version_2_2);
    services.AddSingleton(sp =>
        new LiveMapScript(sp.GetService<ServerSentEventsService>()));
}

public void Configure(IApplicationBuilder app, IHostingEnvironment env)
{
    // 静的ファイル配信（マップタイル画像等）
    app.ServeMapTiles(new ServeMapTilesOptions(ServerMain.Self.WebRoot, allowedOrigins));
    // SSE エンドポイント
    app.MapServerSentEvents<ServerSentEventsService>("/sse", ...);
    app.UseMvc();
}
```

### 5. Server-Sent Events（SSE）によるリアルタイム Push

```csharp
// サーバー側（C#）— SSE 送信
if (_sseService.GetClients().Count > 0)
{
    var json = JsonConvert.SerializeObject(playerList, SerializerSettings);
    await _sseService.SendEventAsync(new ServerSentEvent
    {
        Type = "positions",
        Data = [json],
    });
}
```

```typescript
// フロントエンド側（React）— SSE 受信
import { useSSE } from 'react-hooks-sse';

const usePlayers = () => {
    const state = useSSE<State, Message>(
        'positions',       // サーバーの Type と一致させる
        { players: [] },
        {
            stateReducer(_, action) { return { players: action.data }; },
            parser(input: string) { return JSON.parse(input) as Message; },
        }
    );
    return { players: state.players };
};
```

### 6. GTA5 マップ座標系 → Leaflet カスタム CRS

```typescript
// GTA5 のワールド座標を Leaflet タイルマップに投影
const center_x = 117.3;
const center_y = 172.8;
const scale_x  = 0.02072;
const scale_y  = 0.0205;

const CustomCRS = L.extend({}, L.CRS.Simple, {
    projection:     L.Projection.LonLat,
    transformation: new L.Transformation(scale_x, center_x, -scale_y, center_y),
    infinite: true,
});

// ★ マーカー位置は [y, x] の順（Leaflet は lat/lng 順のため）
<ReactLeafletDriftMarker
    position={[player.position.y, player.position.x]}
    duration={1250}   // スムーズ移動アニメーション (ms)
/>
```

### 7. csproj 構成（C# FiveM リソース）

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <!-- FiveM の Mono ランタイムは Full .NET が必要（.NET Core 不可） -->
    <TargetFramework>net481</TargetFramework>
    <!-- *.net.dll の命名規則に従う -->
    <AssemblyName>LiveMap.Server.net</AssemblyName>
    <OutputType>Library</OutputType>
    <LangVersion>latest</LangVersion>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="CitizenFX.Core.Server" Version="*" />
    <PackageReference Include="Lib.AspNetCore.ServerSentEvents" Version="*" />
  </ItemGroup>
</Project>
```

### 8. fxmanifest.lua — C# DLL のみ、ui_page なし

```lua
fx_version 'cerulean'
game 'gta5'

-- C# DLL のみ登録。ui_page は設定しない（HTTP サーバーとして直接提供）
server_script 'server/LiveMap.Server.net.dll'
```

---

## このリポジトリで学べること

- **C# による FiveM サーバースクリプト**の基本構造（`ServerScript` 継承・`Tick` 処理・Native API）
- **ASP.NET Core を FiveM HTTP ハンドラに接続する IServer 差し替えパターン**（新規 TCP ポート不要）
- **Server-Sent Events（SSE）**による一方向リアルタイム Push 通信
- **Vite プロキシ**を使った FiveM HTTP ハンドラへの開発時接続
- **GTA5 座標系の Leaflet カスタム CRS** 変換・`react-leaflet-drift-marker` によるスムーズ移動
