# Blazor WASM を FiveM NUI として使う

## 概要

**Blazor WebAssembly（Blazor WASM）** を使うと、FiveM の NUI（ui_page）層を TypeScript/React ではなく **C# で記述** できます。  
通常の NUI は HTML/JavaScript 環境（CEF）のため C# では書けませんが、.NET Runtime を WebAssembly にコンパイルすることで C# コードをブラウザ上で実行できます。

---

## アーキテクチャ

```
┌────────────────────────────────────────────┐
│  Blazor WASM (C# → WebAssembly)            │
│  - Razor コンポーネント（.razor ファイル）  │
│  - @code ブロックで UI ロジックを記述       │
│  - .NET Runtime が WASM として実行          │
└──────────────────┬─────────────────────────┘
                   │ JSImport / JSExport
                   │（JavaScriptとの相互呼び出し）
    ┌──────────────┴──────────────────────────┐
    │   FiveM NativeCode / C# Client Script   │
    │   - SendNUIMessage → JS Interop → Blazor │
    │   - [NuiCallbackHandler] で受信          │
    └─────────────────────────────────────────┘
```

---

## メリット

| メリット | 詳細 |
|---------|------|
| **C# で全スタック統一** | バックエンド（Server/Client）とフロントエンド（NUI）を同一言語で実装 |
| **コンパイル時型安全** | TypeScript より厳密な型検査。モデルクラスを NUI・Client・Server で共有可能 |
| **.NET エコシステム** | LINQ・DI・async/await・Newtonsoft.Json など C# の全機能が NUI でも使える |
| **共通モデル** | `Shared` プロジェクトで `DTO` クラスを定義し、両端で同じ型を使用できる |

---

## デメリット・制限

| 項目 | 詳細 |
|------|------|
| **ランタイムサイズ** | .NET Runtime WASM が 3〜5MB（初回ロード時の負荷が大きい） |
| **初期化遅延** | `blazor.web.js` のロードと WASM 初期化が完了するまで UI が表示されない |
| **CEF 互換性** | FiveM の CEF（Chromium バージョン固定）での WebAssembly サポートが完全でない可能性あり |
| **デバッグ難度** | WASM デバッグは JavaScript より複雑（Source Maps 依存） |
| **パフォーマンス** | Blazor の DOM interop オーバーヘッドが JS ネイティブより若干大きい |

---

## プロジェクト構成

```
my-resource/
├── fxmanifest.lua
├── Client/
│   └── ClientScript.cs                ← C# Client スクリプト
├── Server/
│   └── ServerScript.cs                ← C# Server スクリプト
├── Shared/
│   └── Models/
│       └── BalanceResult.cs           ← NUI・Client・Server で共有するモデル
└── ui/
    ├── MyApp.BlazorWasm.csproj
    ├── wwwroot/
    │   └── index.html
    ├── App.razor
    ├── Program.cs
    └── Interop/
        └── NuiInterop.cs              ← JS ↔ C# 橋渡し
```

---

## 実装パターン

### App.razor（メインコンポーネント）

```razor
@page "/"
@inject NuiInterop NuiInterop

<div class="container">
    <h1>@Title</h1>
    <p>残高: @Balance 円</p>
    <button @onclick="UpdateBalance">更新</button>
    @if (IsLoading)
    {
        <span>読み込み中...</span>
    }
</div>

@code {
    private string Title = "My App";
    private int Balance = 0;
    private bool IsLoading = false;

    protected override async Task OnInitializedAsync()
    {
        // NUI からの message イベントをリッスン開始
        await NuiInterop.ListenAsync("updateBalance", OnBalanceUpdate);
    }

    private void OnBalanceUpdate(JsonElement data)
    {
        Balance = data.GetProperty("balance").GetInt32();
        StateHasChanged();
    }

    private async Task UpdateBalance()
    {
        IsLoading = true;
        var result = await NuiInterop.FetchNuiAsync("getBalance", new { });
        Balance = result.GetProperty("balance").GetInt32();
        IsLoading = false;
    }
}
```

### Program.cs（Blazor WASM エントリポイント）

```csharp
using Microsoft.AspNetCore.Components.WebAssembly.Hosting;

var builder = WebAssemblyHostBuilder.CreateDefault(args);
builder.RootComponents.Add<App>("#app");

// NUI Interop を DI に登録
builder.Services.AddSingleton<NuiInterop>();

await builder.Build().RunAsync();
```

### NuiInterop.cs（JS ↔ C# 橋渡し）

```csharp
using System.Text.Json;
using Microsoft.JSInterop;

/// <summary>
/// FiveM NUI の fetchNui / useNuiEvent を C# から呼び出す橋渡しクラス。
/// </summary>
public class NuiInterop
{
    private readonly IJSRuntime _jsRuntime;

    public NuiInterop(IJSRuntime jsRuntime)
    {
        _jsRuntime = jsRuntime;
    }

    /// <summary>
    /// NUI コールバックを呼び出す（NUI → C# Client Script）。
    /// </summary>
    public async Task<JsonElement> FetchNuiAsync(string eventName, object data)
    {
        var json = JsonSerializer.Serialize(data);
        // JavaScript 側の fetchNui を呼び出す
        var result = await _jsRuntime.InvokeAsync<JsonElement>("fetchNui", eventName, json);
        return result;
    }

    /// <summary>
    /// C# Client Script からの SendNUIMessage をリッスンする。
    /// </summary>
    public async Task ListenAsync(string action, Action<JsonElement> callback)
    {
        // window.addEventListener("message", ...) を JS 経由でセット
        var dotnetRef = DotNetObjectReference.Create(new MessageHandler(action, callback));
        await _jsRuntime.InvokeVoidAsync("registerNuiListener", dotnetRef);
    }
}

/// <summary>
/// JS からコールバックされる受信ハンドラ（JSInvokable）。
/// </summary>
public class MessageHandler
{
    private readonly string _action;
    private readonly Action<JsonElement> _callback;

    public MessageHandler(string action, Action<JsonElement> callback)
    {
        _action = action;
        _callback = callback;
    }

    [JSInvokable]
    public void OnMessage(JsonElement data)
    {
        if (data.TryGetProperty("action", out var actionProp)
            && actionProp.GetString() == _action)
        {
            _callback(data);
        }
    }
}
```

### wwwroot/index.html（JS グルーコード）

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8" />
    <title>My App</title>
    <base href="/" />
    <link rel="stylesheet" href="css/app.css" />
</head>
<body>
    <div id="app">Loading...</div>

    <!-- Blazor WASM ランタイム読み込み -->
    <script src="_framework/blazor.webassembly.js"></script>

    <script>
        // C# の NuiInterop.ListenAsync から登録されるハンドラを保持
        let nuiListeners = [];

        // window.addEventListener("message", ...) の橋渡し
        window.registerNuiListener = function(dotnetRef) {
            const handler = (event) => {
                dotnetRef.invokeMethodAsync('OnMessage', event.data);
            };
            window.addEventListener('message', handler);
            nuiListeners.push(handler);
        };

        // lb-phone の componentsLoaded を待ってからアプリ表示
        const devMode = !window?.invokeNative;
        if (devMode) {
            document.getElementById('app').style.visibility = 'visible';
        } else {
            window.addEventListener('message', (event) => {
                if (event.data === 'componentsLoaded') {
                    document.getElementById('app').style.visibility = 'visible';
                }
            });
        }
    </script>
</body>
</html>
```

### .csproj 構成

```xml
<Project Sdk="Microsoft.NET.Sdk.BlazorWebAssembly">
  <PropertyGroup>
    <!-- .NET 7 以降を推奨（JSImport/JSExport の安定版） -->
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.AspNetCore.Components.WebAssembly"
                      Version="8.*" />
    <PackageReference Include="Microsoft.AspNetCore.Components.WebAssembly.DevServer"
                      Version="8.*" PrivateAssets="all" />
  </ItemGroup>
</Project>
```

---

## JSImport / JSExport（.NET 7 以降の新方式）

.NET 7 以降では `[JSImport]` / `[JSExport]` 属性を使うより低レイヤーな相互呼び出しが可能です。

```csharp
// JavaScript 関数を C# から呼び出す
[JSImport("globalThis.fetchNui")]
internal static partial Task<string> FetchNuiJs(string eventName, string dataJson);

// C# メソッドを JavaScript から呼び出す
[JSExport]
internal static void OnNuiMessage(string json)
{
    var data = JsonSerializer.Deserialize<JsonElement>(json);
    // 処理...
}
```

> `IJSRuntime` の DotNetObjectReference 経由より低オーバーヘッドで動作しますが、.NET 7+ 限定です。

---

## 採用判断の目安

| 状況 | 推奨 |
|------|------|
| C# で全レイヤーを統一したい | Blazor WASM を検討 |
| Server/Client と NUI でモデルクラスを共有したい | Blazor WASM が有利 |
| 複雑な UI ロジック・状態管理が必要 | Blazor WASM を検討 |
| 初回ロード速度を最優先にしたい | TypeScript/React を使う |
| 軽量なシンプル UI で十分 | TypeScript/React を使う |
| FiveM の CEF バージョンで WASM が動作しない場合 | TypeScript/React を使う |

**現時点での推奨**:  
NUI は **TypeScript/React** で実装し、Server/Client スクリプトを C# にするのが実績・情報量ともに多く安全な選択です。Blazor WASM の FiveM CEF 上での動作検証が十分に行われるまでは、TypeScript/React を推奨します。

---

## 関連ドキュメント

- [C# 開発者向け概要](overview.md) — 環境構築・BaseScript パターン・NUI との通信
- [Lua → C# パターン変換集](lua-to-csharp.md) — 17 セクションの変換パターン
- [ASP.NET Core + FiveM IServer パターン](../fivem/http-and-server.md) — SetHttpHandler とのブリッジ実装
