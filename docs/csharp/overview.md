# C# による FiveM リソース開発

FiveM リソースは Lua だけでなく **C#（.NET / Mono）** でも実装できます。このセクションでは C# 開発者が FiveM に参入する際のアーキテクチャ・制約・開発フローを整理します。

---

## アーキテクチャ概要

FiveM C# リソースは **CitizenFX.Core** ライブラリを介して FiveM ランタイム（Mono）上で動作します。

```
FxServer (FiveM ゲームサーバー)
├── Mono ランタイム
│   ├── Server スクリプト (C#)       ← ServerScript
│   └── Client スクリプト (C#)       ← ClientScript  ← 各プレイヤーのゲーム内で実行
└── CEF (Chromium Embedded Framework)
    └── NUI (HTML / TypeScript / React)  ← UI レイヤー（C# では書けない）
```

NUI は CEF 上の JavaScript 環境のため、**UI は TypeScript/React で記述し、バックエンドを C# にする**のが基本パターンです。

---

## 3 層の責務分担

| レイヤー | 言語 | 主な責務 |
|---------|------|---------|
| **NUI** | TypeScript / React | 画面表示・ユーザー入力・リアルタイム更新 |
| **Client スクリプト** | C# | ゲーム世界連携（座標取得・アニメーション・ペド操作） |
| **Server スクリプト** | C# | 認証・DB 操作・残高管理・最終検証 |

---

## 基本的なプロジェクト構成

```
my-resource/
├── fxmanifest.lua
├── Client/
│   ├── ClientScript.cs          ← ClientScript クラス
│   └── bin/net452/my-resource.Client.dll
├── Server/
│   ├── ServerScript.cs          ← ServerScript クラス
│   └── bin/net452/my-resource.Server.dll
└── ui/                          ← NUI (TypeScript/React)
    └── dist/
```

```lua
-- fxmanifest.lua
fx_version 'cerulean'
game 'gta5'

client_script 'Client/bin/net452/my-resource.Client.dll'
server_script 'Server/bin/net452/my-resource.Server.dll'

ui_page 'ui/dist/index.html'
files { 'ui/dist/**' }
```

---

## BaseScript 継承パターン

```csharp
// Client/ClientScript.cs
using CitizenFX.Core;
using CitizenFX.Core.Native;

public class ClientScript : BaseScript
{
    public ClientScript()
    {
        // コンストラクタでイベントハンドラを登録
        EventHandlers["onClientResourceStart"] += new Action<string>(OnResourceStart);
        Tick += OnTick;
    }

    private void OnResourceStart(string resourceName)
    {
        if (GetCurrentResourceName() != resourceName) return;
        Debug.WriteLine("クライアントスクリプト開始");
    }

    private async Task OnTick()
    {
        // フレームごとの処理（重い処理は Delay で間引く）
        await Delay(1000);
    }

    // イベントハンドラ（属性で登録）
    [EventHandler("myResource:doSomething")]
    private void OnDoSomething(string param)
    {
        Debug.WriteLine($"受信: {param}");
    }
}
```

```csharp
// Server/ServerScript.cs
using CitizenFX.Core;

public class ServerScript : BaseScript
{
    public ServerScript()
    {
        EventHandlers["playerConnecting"] += new Action<Player, string, dynamic, dynamic>(OnPlayerConnecting);
    }

    private void OnPlayerConnecting(
        [FromSource] Player player, string playerName, dynamic setKickReason, dynamic deferrals)
    {
        Debug.WriteLine($"{playerName} が接続しました");
    }
}
```

---

## NUI との通信

### C# → NUI

```csharp
// Client スクリプトから NUI へ送信
// lb-phone アプリの場合は SendNUIMessage ではなく
// exports["lb-phone"].SendCustomAppMessage を使うこと
var data = new { action = "updateBalance", balance = 5000 };
SendNUIMessage(Newtonsoft.Json.JsonConvert.SerializeObject(data));
```

### NUI → C#（NUI コールバック）

```csharp
[NuiCallbackHandler("getData")]
private object GetData(IDictionary<string, object> data, CallbackDelegate cb)
{
    var playerId = data["playerId"]?.ToString();
    // 処理...
    return new { status = "ok", result = someData };
}
```

---

## SetHttpHandler の活用

C# リソースで HTTP エンドポイントを設けたい場合、ASP.NET Core の MVC/DI パイプラインを FiveM の `SetHttpHandler` に接続する **`IServer` 差し替えパターン** が使えます。

詳細なコード例は [FiveM HTTP & サーバーサイド通信](../fivem/http-and-server.md)（C# IServer 差し替えパターンセクション）を参照してください。

**参考実装**: [charming-byte/simple-livemap](https://github.com/charming-byte/simple-livemap) — ASP.NET Core + SetHttpHandler 統合の C# 実装例

---

## 開発環境の準備

### 必要なもの

- Visual Studio 2022 または Rider
- .NET Framework 4.5.2（`net452` ターゲット）
- NuGet パッケージ:
  - `CitizenFX.Core.Client`
  - `CitizenFX.Core.Server`
  - （必要に応じて）`Newtonsoft.Json`

### NuGet パッケージ設定

```xml
<!-- MyResource.Client.csproj -->
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net452</TargetFramework>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="CitizenFX.Core.Client" Version="*" />
    <PackageReference Include="Newtonsoft.Json" Version="13.*" />
  </ItemGroup>
</Project>
```

---

## 参考リソース

### C# 実装の大規模リポジトリ

| リポジトリ | 特徴 |
|-----------|------|
| [TomGrobbe/vMenu](https://github.com/TomGrobbe/vMenu) | 大規模 C# FiveM リソース・パーミッション・NUI 統合 |
| [charming-byte/simple-livemap](https://github.com/charming-byte/simple-livemap) | ASP.NET Core の `IServer` 差し替え・SetHttpHandler 統合 |
| [ossianhanning/FiveMRpServerResources](https://github.com/ossianhanning/FiveMRpServerResources) | RP サーバー典型機能（銀行・ジョブ等）の C# 実装集 |

---

## 次のステップ

- [Lua → C# パターン変換集](lua-to-csharp.md) — Lua でよく使うコードを C# に書き換えるパターンを網羅
