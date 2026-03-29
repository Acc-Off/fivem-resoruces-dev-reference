# vMenu — 大規模 C# FiveM リソースの設計参考

> GitHub: https://github.com/TomGrobbe/vMenu  
> 言語: C# (.NET Framework 4.6.2)  
> ライセンス: 再配布・販売条件が README に明示されているため、コード流用時は必ずライセンス確認を

FiveM 向けサーバーサイド管理メニューです。lb-phone アプリそのものではありませんが、**大規模 C# FiveM リソースの権限設計・設定管理・永続化パターン** を学べる代表的な実装例です。

---

## フォルダ構成

```
vMenu-master/
  SharedClasses/
    ConfigManager.cs          ← Convar 設定取得の共通 API
    PermissionsManager.cs     ← ACE 権限モデルの enum + 解決ロジック
  vMenu/                      ← クライアント側（メニュー・NUI・ローカル保存）
    vMenu.csproj              ← Target: net462, CitizenFX.Core.Client, MenuAPI.FiveM
  vMenuServer/                ← サーバー側（権限検証・BAN・同期・管理機能）
    vMenuServer.csproj        ← Target: net452, CitizenFX.Core.Server
  vMenu.sln
  appveyor.yml                ← CI: vMenu.sln ビルド → 成果物 zip
```

### 依存関係（クライアント）
- `CitizenFX.Core.Client`
- `MenuAPI.FiveM`（独自 NUI メニューシステム）
- `SharedClasses/*.cs` を `Compile Include` + `Link` で共有

### 依存関係（サーバー）
- `CitizenFX.Core.Server`
- 同様に `SharedClasses/*.cs` をリンク共有

---

## 学べるパターン

### 1. サーバーイベントの認可ガード（最重要パターン）

`MainServer.cs` はサーバーイベントの全受け口でこの流れを徹底しています。

```
① PermissionsManager.IsAllowed(...) で ACE 権限確認
② 権限なし → BanManager.BanCheater(source) で対処
③ 権限あり → 本処理を実行
```

lb-phone カスタムアプリへの応用例：

```csharp
// サーバーイベントハンドラの典型パターン
[EventHandler("myApp:server:deleteInvoice")]
private void OnDeleteInvoice([FromSource] Player player, int invoiceId)
{
    // ★ 業務ロジックより先に認可検証
    if (!PermissionsManager.IsAllowed(player, Permission.InvoiceDelete))
    {
        // 拒否 + 監査ログ（BAN は最終手段。業務アプリでは過剰になりやすい）
        AuditLog.Warn($"[UnauthorizedDelete] player={player.Handle} invoiceId={invoiceId}");
        return;
    }

    // 本処理
    DeleteInvoiceFromDb(invoiceId);
}
```

### 2. 権限を enum で体系化（階層権限モデル）

`PermissionsManager.cs` では `Permission` enum を軸に、個別権限・親権限・全体権限を解決します。

```csharp
// Permission enum の例（vMenu の実装を参考に自分のアプリ向けに設計）
public enum Permission
{
    // 全体
    Everything,

    // 請求書機能
    InvoiceMenu,   // メニュー表示
    InvoiceCreate,
    InvoiceCancel,
    InvoiceAdminAll,  // 他プレイヤーの請求書も操作可能

    // 送金機能
    TransferMenu,
    TransferSend,
    TransferReverse,
    TransferAdminAll,
}
```

推奨命名規則: `App.Feature.Action` + `App.Feature.All`（一括許可）

```csharp
// 個別権限または親権限のいずれかを持てば許可
public static bool IsAllowed(Player player, Permission permission)
{
    var permsToCheck = GetPermissionAndParentPermissions(permission);
    return permsToCheck.Any(p => player.IsAceAllowed(p.ToString()));
}
```

### 3. 設定値を Convar 経由で一元管理

`ConfigManager.cs` は `Setting` enum から型付き getter を提供し、設定取得窓口を一本化しています。

```csharp
// 設定値の種類を enum で管理（文字列キー直書きを排除）
public enum Setting
{
    vmenu_server_info_message,
    vmenu_max_players,
    vmenu_enable_weather_sync,
    // ...
}

// 型付き getter
public static bool GetSettingsBool(Setting setting)
{
    return API.GetConvar(setting.ToString(), "false") == "true";
}
public static int GetSettingsInt(Setting setting, int defaultVal = 0)
{
    return int.TryParse(API.GetConvar(setting.ToString(), defaultVal.ToString()), out int v)
        ? v : defaultVal;
}
```

lb-phone アプリへの応用: `config.lua` と別に「実行時切替が必要な設定」は Convar に寄せると運用が楽。

### 4. SharedClasses による Client/Server 共通実装

`SharedClasses` プロジェクトを `Compile Include` + `Link` でクライアント・サーバー双方に同一コードを取り込む手法。

```xml
<!-- vMenuClient.csproj -->
<ItemGroup>
    <Compile Include="..\SharedClasses\ConfigManager.cs">
        <Link>SharedClasses\ConfigManager.cs</Link>
    </Compile>
</ItemGroup>
```

モデルクラス・権限定義・設定定義を両端で共有できるため、定義のズレを防げます。

### 5. 永続化戦略（KVP）の活用と限界

`StorageManager.cs` や `BanManager.cs` はプレイヤーごとの保存データを KVP で管理しています。

```csharp
// KVP への保存（FiveM 組み込みのシンプルな Key-Value ストレージ）
API.SetResourceKvp($"player_{identifier}_appearance", json);
// KVP から読み込み
var json = API.GetResourceKvpString($"player_{identifier}_appearance");
```

KVP の適否:

| 用途 | 推奨 |
|------|------|
| プレイヤーごとの見た目・設定保存 | ✅ KVP（高速・シンプル） |
| BAN 記録・一時状態 | ✅ KVP |
| 請求・決済・残高など整合性が重要なデータ | ❌ DB を使う |
| 検索・集計が必要なデータ | ❌ DB を使う |

### 6. サーバー主導の状態同期

時間・天候同期は、サーバー側が Convar で状態を保持し、クライアントが Tick で追従する構造です。

```
サーバー: ループで状態更新（TimeLoop, WeatherLoop） → Convar に書き込み
クライアント: Tick ごとに Convar を読んで反映（EventManager）
```

lb-phone アプリでも、通知設定・アプリ状態同期を「サーバー主導の単一ソース」にする時に応用できます。

### 7. RPC キューパターン（非同期要求の追い越し防止）

```csharp
// RPC ID で応答を追跡（複数同時リクエストの取り違えを防ぐ）
private static readonly Dictionary<long, RPCData> PendingRPCs = new();

private static long SendRPC(string eventName, object[] args)
{
    long rpcId = Interlocked.Increment(ref _rpcCounter);
    PendingRPCs[rpcId] = new RPCData { Id = rpcId };
    TriggerServerEvent(eventName, rpcId, args);
    return rpcId;
}

[EventHandler("myApp:client:rpcResponse")]
private void OnRPCResponse(long rpcId, string jsonResult)
{
    if (PendingRPCs.TryGetValue(rpcId, out var rpc))
    {
        rpc.Complete(jsonResult);
        PendingRPCs.Remove(rpcId);
    }
}
```

---

## lb-phone カスタムアプリへ取り込む推奨パターン

vMenu から転用しやすい設計要素:

1. **サーバーイベント認可ガード層** — 認可・入力バリデーション・レート制限・監査ログを共通関数化
2. **権限名の階層設計** — `App.Feature.Action` + `App.Feature.All` で管理
3. **設定取得 API の統一** — enum + 型付き getter で文字列キー直書きを排除
4. **応答形式の標準化** — 成功/失敗レスポンス形式を統一（UI が処理しやすい）

注意: 権限失敗時の自動 BAN は業務アプリでは過剰になる可能性があります。「拒否 + 監査ログ + 管理者通知」を基本とし、BAN は最終手段にとどめることを推奨します。

---

## このリポジトリで学べること

- **大規模 C# FiveM リソース**のプロジェクト構成（Client + Server + SharedClasses）
- **ACE 権限体系を enum で管理**する権限モデル設計
- **Convar による設定一元管理**（文字列キー直書きの排除）
- **KVP を使ったプレイヤーデータ永続化**とその限界
- **MenuAPI による独自 NUI メニューシステム**の C# ↔ NUI 通信
- **CI ビルド（AppVeyor）**による C# FiveM リソースの自動ビルドパイプライン
