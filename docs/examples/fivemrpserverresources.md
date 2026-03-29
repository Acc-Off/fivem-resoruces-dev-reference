# FiveMRpServerResources — C# RP サーバー機能集の設計参考

> GitHub: https://github.com/ossianhanning/FiveMRpServerResources  
> 言語: C# (.NET / Mono)  
> 構成: 複数の C# プロジェクトコレクション

FiveM RP サーバー向けの複数機能をまとめた C# プロジェクト集です。銀行・ジョブ・インベントリ・チャット・スポーンなどの典型的な RP サーバー機能が C# で実装されており、**Client/Server の責務分離・イベント通信設計・セッション管理**のパターンを学べます。

---

## プロジェクト構成

| プロジェクト | 種類 | 主な機能 |
|------------|------|---------|
| **RPClient** | Client | ゲームプレイ拡張・UI・コマンド・職業ロジック |
| **RPServer** | Server | セッション管理・コマンド・権限・イベント配信・ジョブ処理 |
| **Chat.Client / Chat.Server** | Client + Server | NUI チャットとサーバー中継 |
| **FiveMDefaults.Client / .Server** | Client + Server | スポーン・ハードキャップ・セッションホスト・スコアボード |
| Access.* | Web/DB | Web/DB 同期処理（補助的） |
| JsonLibrary | Util | シリアライズ補助 |

---

## 学べるパターン

### 1. エントリポイント集約 + 機能分割

`RPClient/Client.cs` で基盤処理（Tick/Event/NUI 登録）を持ち、実機能は `Classes/*` に分割して責務を整理しています。

```csharp
// Client.cs — 基盤処理の集約
public class Client : ClientScript
{
    public Client()
    {
        // Tick・イベント登録はここで一元化
        Tick += OnTick;
        EventHandlers["playerSpawned"] += new Action(OnPlayerSpawned);
    }

    private async Task OnTick()
    {
        // 毎フレーム必要な表示/UI 更新のみ OnTick に置く
        // AFK 判定などは別ループで分離
        await Delay(0);
    }
}
```

```csharp
// ClassLoader.cs — 機能の ON/OFF を管理
public static class ClassLoader
{
    public static void Init()
    {
        new JobHandler();       // 有効化
        new InventoryHandler(); // 有効化
        // new BankHandler();   // コメントアウトで無効化（段階的有効化）
    }
}
```

### 2. Tick ループの責務分離

```csharp
// 毎フレーム必要な処理だけを OnTick に
private async Task OnTick()
{
    // 入力処理・UI 更新・描画コールなど
    DrawMarkers();
    await Delay(0);
}

// AFK 判定のような重い処理は低頻度ループで分離
private async Task AfkCheckLoop()
{
    while (true)
    {
        CheckAfkStatus();
        await Delay(60_000);  // 1 分間隔
    }
}
```

### 3. NUI 運用の実践パターン（Chat.Client）

`Chat.Client/Chat.cs` は入力モード中のみフォーカスを持つ設計の良い参考例です。

```csharp
// NUI フォーカスを「入力中のみ」に制限する
[EventHandler("__cfx_nui:openChat")]
private void OnOpenChat()
{
    _chatOpen = true;
    SetNuiFocus(true, true);
    SendNUIMessage(new { action = "chatOpen" });
}

[EventHandler("__cfx_nui:closeChat")]
private void OnCloseChat()
{
    _chatOpen = false;
    SetNuiFocus(false, false);
    SendNUIMessage(new { action = "chatClose" });
}

// JSON メッセージ送信
private void SendChatMessage(string sender, string message)
{
    SendNUIMessage(JsonConvert.SerializeObject(new
    {
        action  = "addMessage",
        sender  = sender,
        message = message,
    }));
}
```

> **lb-phone への応用**: NUI フォーカス制御は「入力モード中のみ持つ」設計にすることで、ゲーム操作とのバッティングを防げます。

### 4. 近距離イベント発火（ローカルチャット）

```csharp
// クライアント — PointEvent を作成してサーバーへ送信
TriggerServerEvent("communication:server:localChat",
    Game.PlayerPed.Position, message, chatRange);
```

```csharp
// サーバー — 範囲内プレイヤーにのみ配信
[EventHandler("communication:server:localChat")]
private void OnLocalChat(
    [FromSource] Player source, Vector3 position, string message, float range)
{
    // AOE フィルタリングして対象プレイヤーにのみ送信
    foreach (var player in Players)
    {
        var playerPos = GetEntityCoords(GetPlayerPed(int.Parse(player.Handle)));
        if (Vector3.Distance(position, playerPos) <= range)
        {
            TriggerClientEvent(player, "communication:client:localChat",
                source.Name, message);
        }
    }
}
```

### 5. サーバー側の受信イベント責務分離

```csharp
// RPServer — 機能別クラスでイベントを受け口を分け、
// イベント名はドメイン接頭辞で整理
// Police.*, Communication.*, Jobs.* など

// 環境系
[EventHandler("Environment:server:setWeather")]
private void OnSetWeather([FromSource] Player source, string weather) { }

// ジョブ系
[EventHandler("Jobs:server:updateJob")]
private void OnUpdateJob([FromSource] Player source, string jobName, int grade) { }
```

### 6. セッション管理の設計

`Session.cs` がプレイヤー ID・権限・キャラクター情報を集約し、`SemaphoreSlim` でセッション単位の排他を意識しています。

```csharp
public class Session
{
    public string Identifier { get; private set; }
    public int ServerId { get; private set; }
    public string Character { get; set; }
    public List<string> Permissions { get; private set; }

    private readonly SemaphoreSlim _lock = new SemaphoreSlim(1, 1);

    // 権限更新時は DB 更新 + クライアントへ再通知
    public async Task UpdatePermissionsAsync(List<string> newPerms)
    {
        await _lock.WaitAsync();
        try
        {
            Permissions = newPerms;
            await SavePermissionsToDbAsync();
            TriggerClientEvent(ServerId.ToString(),
                "rp:client:permissionsUpdated", newPerms);
        }
        finally { _lock.Release(); }
    }
}
```

### 7. 接続・収容制御パターン

```csharp
// FiveMDefaults.Server/HardCap.cs
[EventHandler("playerConnecting")]
private void OnPlayerConnecting(
    [FromSource] Player player,
    string playerName,
    dynamic setKickReason,
    dynamic deferrals)
{
    deferrals.defer();
    // 収容上限チェック
    if (Players.Count() >= MaxPlayers)
    {
        deferrals.done("サーバーが満員です。しばらくお待ちください。");
        return;
    }
    deferrals.done(); // 接続許可
}

[EventHandler("playerDropped")]
private void OnPlayerDropped([FromSource] Player player, string reason)
{
    // セッション情報・状態の掃除
    SessionManager.Remove(player.Handle);
}
```

### 8. イベント配信の 3 パターン（再利用価値が高い）

`RPServer/SharedModels/EventModels.cs` で定義された汎用配信モデル:

```csharp
// 1. 特定プレイヤーへ
TriggerClientEvent(targetHandle, "EventName", payload);

// 2. 全プレイヤーへブロードキャスト
TriggerClientEvent(-1, "EventName", payload);

// 3. 範囲内プレイヤーへ（AOE 配信）
// TriggerEventForPlayersModel を使って複数対象を指定
var targets = Players
    .Where(p => Vector3.Distance(position, GetPlayerPosition(p)) <= range)
    .Select(p => p.Handle)
    .ToList();
foreach (var handle in targets)
    TriggerClientEvent(handle, "EventName", payload);
```

これは lb-phone 拡張で「通知」「対象配信」「既読同期」の土台として転用しやすいパターンです。

---

## lb-phone カスタムアプリへ活かせる具体ポイント

**クライアント側**:
- UI 状態管理（入力中/非入力中）と NUI フォーカス制御の厳密化
- Tick と低頻度ループの分離（描画・入力 vs 監視・AFK 判定）
- 機能を責務ごとにファイル分割（`ClassLoader` パターン）

**サーバー側**:
- イベント命名規則をドメイン接頭辞で統一（例: `Invoice.*`、`Transfer.*`）
- ブロードキャスト / 対象配信 / 範囲配信の使い分け
- セッション情報・権限変更の一元管理（`SemaphoreSlim` で排他）

**共通**:
- イベント payload を構造化（MsgPack 等）してイベント定義を明文化
- ログ粒度（Info/Debug/Error）を用途別に揃える

---

## このリポジトリで学べること

- **複数 C# プロジェクトで構成される大規模 FiveM リソース**のプロジェクト分割方針
- **Client/Server の責務を明確に分けた**イベント通信設計
- **NUI フォーカス制御**の実践パターン（入力中のみフォーカスを持つ）
- **近距離イベント発火（AOE 配信）**による通信量削減と没入感の両立
- **SemaphoreSlim によるセッション単位排他**の設計
- **playerConnecting / playerDropped** を使った接続管理・状態掃除
