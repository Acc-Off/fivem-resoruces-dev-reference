# Lua → C# パターン変換集

FiveM での Lua 開発から C# への移行時に、よく出てくる変換パターンをまとめています。

---

## 1. イベント処理

### Lua：イベント受信
```lua
AddEventHandler('myResource:doSomething', function(param1, param2)
    print("Received: " .. param1)
end)
```

### C#：イベント受信
```csharp
// BaseScript を継承したクラスのメソッドに属性を付与
[EventHandler("myResource:doSomething")]
private void OnDoSomething(dynamic param1, dynamic param2)
{
    Debug.WriteLine($"Received: {param1}");
}
```

---

## 2. サーバーへのイベント送信

### Lua：クライアント → サーバー
```lua
TriggerServerEvent('myResource:serverAction', playerId, amount)
```

### C#：クライアント → サーバー
```csharp
// BaseScript クラス内
TriggerServerEvent("myResource:serverAction", Game.Player.Handle, amount);
```

### Lua：サーバー → クライアント
```lua
TriggerClientEvent('myResource:clientAction', -1, data)
```

### C#：サーバー → クライアント
```csharp
// 特定プレイヤーへ
TriggerClientEvent("myResource:clientAction", new SourceList { Player.Server.Handle }, data);
// 全プレイヤーへ
TriggerClientEvent("myResource:clientAction", new SourceList(), data);
```

---

## 3. NUI コールバック

### Lua：Callback 登録
```lua
RegisterNUICallback("uploadFile", function(data, cb)
    local result = ProcessFile(data.file)
    cb({ success = true, url = result })
end)
```

### C#：Callback 登録
```csharp
[NuiCallbackHandler("uploadFile")]
private object UploadFile(IDictionary<string, dynamic> data, CallbackDelegate cb)
{
    var file = data["file"];
    var result = ProcessFile(file);
    return new { success = true, url = result };
}
```

---

## 4. Exports（他リソースとの連携）

### Lua：Export 定義
```lua
exports('GetPlayerBalance', function(playerId)
    return playerBalances[playerId] or 0
end)
```

### Lua：Export 呼び出し
```lua
local balance = exports['mylib']:GetPlayerBalance(playerId)
```

### C#：Export 定義
```csharp
[Export("GetPlayerBalance")]
public dynamic GetPlayerBalance(int playerId)
{
    return playerBalances.ContainsKey(playerId) ? playerBalances[playerId] : 0;
}
```

### C#：Export 呼び出し
```csharp
var exports = new ExportsManager();
var balance = (int)exports.Invoke("mylib:GetPlayerBalance", playerId);
```

---

## 5. 非同期処理・Delay

### Lua：非同期待機
```lua
TriggerEvent('myEvent', data)
Wait(1000)  -- 1秒待つ
print("Done")
```

### C#：非同期待機
```csharp
TriggerEvent("myEvent", data);
await Delay(1000);  // 1秒待つ（FiveM 独自の Task）
Debug.WriteLine("Done");
```

> `Delay()` は FiveM C# API でネイティブに提供される独自メソッドです。`Task.Delay()` ではなくこちらを使います。

---

## 6. ファイル・Config 読み込み

### Lua：設定ファイルの読み込み
```lua
local config = require 'config'
local dbHost = config.database.host
```

### C#：JSON Config 読み込み
```csharp
using Newtonsoft.Json.Linq;

// リソースのパス配下にある config.json を読み込む
var configPath = Path.Combine(
    GetResourcePath(GetCurrentResourceName()),
    "config.json"
);
var configContent = File.ReadAllText(configPath);
var config = JObject.Parse(configContent);
var dbHost = config["database"]["host"].ToString();
```

---

## 7. Database 操作（非同期）

### Lua：同期 DB 呼び出し（ox_lib 利用）
```lua
local result = MySQL.query.await('SELECT * FROM users WHERE id = ?', { userId })
if result then
    print(result[1].name)
end
```

### C#：非同期 DB 呼び出し（SqlConnection 直接接続）
```csharp
using System.Data.SqlClient;

using (var conn = new SqlConnection(connectionString))
{
    await conn.OpenAsync();
    var cmd = new SqlCommand(
        "SELECT * FROM users WHERE id = @id", conn);
    cmd.Parameters.AddWithValue("@id", userId);

    using var reader = await cmd.ExecuteReaderAsync();
    if (await reader.ReadAsync())
    {
        var name = reader["name"].ToString();
    }
}
```

> **注意**: SQL パラメータには必ずパラメータバインディング（`@param`）を使い、SQL インジェクションを防ぐこと。

---

## 8. API 呼び出し（REST）

### Lua：PerformHttpRequest
```lua
PerformHttpRequest('https://api.example.com/user/' .. userId, function(err, text, headers)
    if err == 200 then
        print(text)
    end
end, 'GET')
```

### C#：HttpClient
```csharp
using System.Net.Http;

using (var client = new HttpClient())
{
    var response = await client.GetAsync(
        $"https://api.example.com/user/{userId}");

    if (response.IsSuccessStatusCode)
    {
        var content = await response.Content.ReadAsStringAsync();
        Debug.WriteLine(content);
    }
}
```

---

## 9. Dictionary・Table 操作

### Lua：Table
```lua
local player = {
    id = 123,
    name = "John",
    balance = 5000
}
print(player.name)
player.balance = 6000
```

### C#：Dictionary または型クラス（推奨）
```csharp
// Dictionary を使う場合
var player = new Dictionary<string, object>
{
    { "id", 123 },
    { "name", "John" },
    { "balance", 5000 }
};
player["balance"] = 6000;

// 型クラスを使う場合（推奨）
public class Player
{
    public int Id { get; set; }
    public string Name { get; set; }
    public int Balance { get; set; }
}

var player = new Player { Id = 123, Name = "John", Balance = 5000 };
player.Balance = 6000;
```

---

## 10. コンソール出力・ログ

### Lua：print
```lua
print("Hello World")
print("Error: " .. error_msg)
```

### C#：Debug.WriteLine
```csharp
Debug.WriteLine("Hello World");
Debug.WriteLine($"Error: {errorMsg}");

// チャット欄への出力
TriggerEvent("chat:addMessage",
    new { args = new[] { "MyApp", "Hello World" } });
```

---

## 11. 文字列操作

### Lua：string ライブラリ
```lua
local str = "Hello, World!"
local lower = string.lower(str)
local sub = string.sub(str, 1, 5)  -- "Hello"
local formatted = string.format("Player %s has %d money", name, amount)
```

### C#：string メソッド
```csharp
var str = "Hello, World!";
var lower = str.ToLower();
var sub = str.Substring(0, 5);   // "Hello"
var formatted = $"Player {name} has {amount} money";
```

---

## 12. 数値・型変換

### Lua：型変換
```lua
local num = tonumber("123")
local str = tostring(num)
```

### C#：型変換
```csharp
var num = int.Parse("123");
// またはパース失敗を考慮する場合
if (int.TryParse("123", out int num)) { ... }

var str = num.ToString();
```

---

## 13. Callback・Async パターン

### Lua：コールバックチェーン
```lua
function FetchUser(userId, callback)
    TriggerServerEvent('getUser', userId, function(result)
        callback(result)
    end)
end

FetchUser(123, function(user)
    print(user.name)
end)
```

### C#：async/await
```csharp
public async Task<User> FetchUserAsync(int userId)
{
    // サーバーイベント呼び出し（Promise 化）
    var result = await TriggerServerEventAsync("getUser", userId);
    return JsonConvert.DeserializeObject<User>(result.ToString());
}

// 呼び出し
var user = await FetchUserAsync(123);
Debug.WriteLine(user.Name);
```

---

## 14. Timer・Interval

### Lua：SetTimeout / SetInterval
```lua
SetTimeout(2000, function()
    print("After 2 seconds")
end)

local timer = SetInterval(function()
    print("Every 1 second")
end, 1000)

ClearInterval(timer)
```

### C#：Task.Delay / Timer
```csharp
// SetTimeout 相当
_ = Task.Delay(2000).ContinueWith(_ =>
{
    Debug.WriteLine("After 2 seconds");
});

// SetInterval 相当（永続ループ）
var timer = new Timer(_ =>
{
    Debug.WriteLine("Every 1 second");
}, null, TimeSpan.Zero, TimeSpan.FromSeconds(1));

// キャンセル
timer.Dispose();
```

---

## 15. JSON シリアライズ

### Lua：json.encode / json.decode
```lua
local data = { name = "John", age = 30 }
local jsonStr = json.encode(data)

local parsed = json.decode('{"name":"John","age":30}')
print(parsed.name)
```

### C#：Newtonsoft.Json
```csharp
using Newtonsoft.Json;

var data = new { name = "John", age = 30 };
var jsonStr = JsonConvert.SerializeObject(data);

var parsed = JsonConvert.DeserializeObject<dynamic>(
    @"{""name"":""John"",""age"":30}");
Debug.WriteLine(parsed.name.ToString());
```

---

## 16. NUI との通信（重要）

### 前提：NUI は C# では書けない

FiveM の NUI は CEF（Chromium Embedded Framework）上の **HTML/CSS/JavaScript 環境** です。
`ui_page` は TypeScript/React で実装し、Server/Client スクリプトを C# で書くのが標準パターンです。

### アーキテクチャ

```
┌─────────────────────────────────┐
│  NUI (HTML / TypeScript / React) │  ← CEF ブラウザ上で実行
│  - UI 表示・ユーザー入力        │    (C# では書けない)
└──────────┬──────────────────────┘
           │ NUI Messaging (postMessage)
    ┌──────┴──────────────────────┐
    │   Client スクリプト (C#)    │  ← ゲーム世界との連携
    │   - 座標取得・アニメーション │
    └──────────┬──────────────────┘
               │ TriggerServerEvent / TriggerClientEvent
    ┌──────────┴──────────────────┐
    │   Server スクリプト (C#)    │  ← 認証・DB・最終検証
    └────────────────────────────┘
```

### パターン：Client (C#) → NUI

**C# 側（Client スクリプト）:**
```csharp
// NUI へメッセージ送信
// lb-phone アプリの場合は SendNUIMessage ではなく
// exports["lb-phone"].SendCustomAppMessage を使うこと
var data = new { action = "updateBalance", balance = 5000 };
SendNUIMessage(data);
```

**NUI 側（TypeScript/React）:**
```typescript
// lb-phone 提供の Hook でリッスン
useNuiEvent<{ balance: number }>("updateBalance", (data) => {
    setBalance(data.balance);
});

// または標準の addEventListener
window.addEventListener("message", (event) => {
    if (event.data?.action === "updateBalance") {
        setBalance(event.data.balance);
    }
});
```

### パターン：NUI → Server (C#)

**NUI 側（TypeScript/React）:**
```typescript
// NUI コールバックを呼び出し
const result = await fetchNui("uploadFile", {
    file: await fileToBase64(file),
});
```

**C# 側（Client または Server スクリプト）:**
```csharp
[NuiCallbackHandler("uploadFile")]
private object UploadFile(IDictionary<string, dynamic> data, CallbackDelegate cb)
{
    var fileBase64 = data["file"].ToString();
    var fileBytes = Convert.FromBase64String(fileBase64);

    // ファイル処理（DB 保存・クラウドアップロードなど）
    var url = ProcessAndUploadFile(fileBytes);
    return new { url = url };
}
```

### 各レイヤーの責務

| レイヤー | 言語 | 主な責務 |
|---------|------|---------|
| **NUI** | TypeScript / React | UI 表示・入力受け取り・リアルタイム更新 |
| **Client スクリプト** | C# | ゲーム世界連携（位置取得・アニメーション）・イベント送信 |
| **Server スクリプト** | C# | 認証・DB 操作・最終検証 |

---

## 17. Blazor WASM を NUI として使う選択肢

### 概要

Blazor WASM（WebAssembly）を使うと **NUI 側も C# で記述** できます。
ただし FiveM の NUI コンテキスト（CEF）での利用には注意が必要です。

### アーキテクチャ

```
┌────────────────────────────────┐
│  Blazor WASM (C#)              │  ← C# コードが WebAssembly で実行
│  - UI ロジック・コンポーネント │    (.NET Runtime in WASM)
└──────────┬─────────────────────┘
           │ JSImport / JSExport Interop
    ┌──────┴──────────────────────┐
    │   Server / Client (C#)      │
    │   - ビジネスロジック        │
    └─────────────────────────────┘
```

### メリット

- **C# で統一**：バックエンド・フロントエンド両方を C# で実装
- **型安全**：IntelliSense・コンパイル時型検査
- **.NET 機能全般**：LINQ・async/await・DI 等が使える
- **コード共有**：Server/Client と NUI で共通 Model クラスを使用可能

### デメリット・制限

| 項目 | 詳細 |
|------|------|
| **ランタイムサイズ** | .NET Runtime の WASM ファイルが 3〜5MB（初回ロード負荷） |
| **初期化遅延** | `blazor.web.js` のロード・初期化が DOM Ready 前に必要 |
| **CEF 互換性** | FiveM の CEF（Chromium）での WebAssembly サポートが完全でない可能性あり |
| **デバッグ難度** | WASM デバッグは JavaScript より複雑（Source Maps 依存） |

### 実装パターン（Blazor WASM）

**App.razor**
```csharp
@page "/"

<div class="container">
    <h1>@Title</h1>
    <p>Balance: @Balance</p>
    <button @onclick="UpdateBalance">更新</button>
</div>

@code {
    private string Title = "LB Phone Custom App";
    private int Balance = 0;

    private async Task UpdateBalance()
    {
        Balance = await FetchBalanceAsync();
    }
}
```

**NUI ↔ C# Interop（JSImport）**
```csharp
// Blazor WASM 内から fetchNui を呼び出す例
[JSImport("fetchNui", "nuiInterop")]
public static partial Task<string> FetchNui(string eventName, string dataJson);

// 使用例
var json = await FetchNui("getBalance", "{}");
var result = JsonSerializer.Deserialize<BalanceResult>(json);
```

### 採用判断の目安

| 状況 | 推奨 |
|------|------|
| C# で全レイヤーを統一したい | Blazor WASM を検討 |
| 複雑な UI ロジック・状態管理が必要 | Blazor WASM を検討 |
| 初期ロード時間を最小化したい | TypeScript/React を使う |
| 軽量なシンプル UI で十分 | TypeScript/React を使う |
| CEF の WASM 互換性が不明な場合 | TypeScript/React を使う |

**現時点での推奨**：NUI は **TypeScript/React** で実装し、Server/Client スクリプトを C# にするのが実績・情報量ともに多く安全です。Blazor WASM は将来の選択肢として検討してください。

---

## 参考

- [C# 開発者向け概要](overview.md) — 環境構築・プロジェクト構成・BaseScript パターン
- [CitizenFX.Core ドキュメント](https://docs.fivem.net/docs/scripting-reference/runtimes/csharp/) — 公式リファレンス
- [TomGrobbe/vMenu](https://github.com/TomGrobbe/vMenu) — 大規模 C# FiveM リソースの実装例
- [charming-byte/simple-livemap](https://github.com/charming-byte/simple-livemap) — ASP.NET Core + SetHttpHandler 統合例
