# slrn_groups — グループ管理アプリ

> GitHub: https://github.com/solareon/slrn_groups  
> フレームワーク: マルチフレームワーク対応（ESX / QB / QBX / ND / OX）  
> UI: React (TSX) + Vite + Tailwind CSS + Zustand

プレイヤーがグループを作成・参加・管理し、グループジョブをこなす lb-phone カスタムアプリです。マルチフレームワーク対応・TypeScript UI・`lib.callback` による型安全な通信・`OxClass` ベースのサーバーモデルを備えた、モダンな中〜大規模実装例です。

---

## フォルダ構成

```
fxmanifest.lua
bridge/
  esx.lua              ← `GetPlayerName` の ESX 実装
  nd.lua               ← ND Framework 実装
  ox.lua               ← ox_core 実装
  qb.lua               ← QBCore 実装
  qbx.lua              ← QBX 実装
client/
  functions.lua        ← ブリップ作成・削除ヘルパー
  main.lua             ← アプリ登録・NUIコールバック・イベントハンドラ
server/
  api.lua              ← グループ操作 API + exports 公開
  groups.lua           ← OxClass ベースのグループクラス定義
  main.lua             ← lib.callback 登録
  utils.lua            ← 通知・export 登録ヘルパー
ui/
  src/
    store/             ← Zustand ストア（グループ状態管理）
    components/        ← React コンポーネント
    pages/
```

---

## 学べるパターン

### 1. アプリ登録（onUse でデータ初期化）

```lua
-- client/main.lua
local identifier = 'slrn_groups'

exports['lb-phone']:AddCustomApp({
    identifier  = identifier,
    name        = 'Groups',
    description = 'Group app to do stuff together',
    developer   = 'solareon',
    defaultApp  = true,
    fixBlur     = true,
    ui          = GetCurrentResourceName() .. "/ui/dist/index.html",
    icon        = "https://cfx-nui-" .. GetCurrentResourceName() .. "/ui/dist/icon.svg",
    images = {
        "https://cfx-nui-" .. GetCurrentResourceName() .. "/ui/dist/screenshot-light.png",
        "https://cfx-nui-" .. GetCurrentResourceName() .. "/ui/dist/screenshot-dark.png"
    },

    -- アプリが開かれるたびにサーバーから最新データを取得して UI に送信
    onUse = function()
        lib.callback('slrn_groups:server:getSetupAppData', false, function(setupAppData)
            Wait(100)
            sendCustomAppMessage('setupApp', setupAppData)
            if setupAppData.groupStatus == 'IN_PROGRESS' then
                sendCustomAppMessage('startJob', {})
            end
        end)
    end,
})
```

### 2. SendCustomAppMessage ヘルパー

```lua
-- client/main.lua
local function sendCustomAppMessage(action, data)
    exports['lb-phone']:SendCustomAppMessage(identifier, {
        action = action,   -- UI 側で e.data.action でフィルタ
        data   = data
    })
end

local function sendNotification(message, title)
    exports['lb-phone']:SendNotification({
        app     = identifier,
        title   = title or nil,
        content = message,
    })
end
```

### 3. NUIコールバック + lib.callback（完全なフロー）

```lua
-- client/main.lua: UI → Client → Server → Client → UI
RegisterNuiCallback('joinGroup', function(data, cb)
    -- lib.callback.await で Server の処理結果を同期的に待つ
    local message = lib.callback.await('slrn_groups:server:joinGroup', false, data)
    sendNotification(message)
    cb({})   -- UI にレスポンスを返す（必須）
end)

-- server/main.lua: Server コールバック登録
lib.callback.register('slrn_groups:server:joinGroup', function(source, data)
    if api.isPasswordCorrect(data.id, data.pass) then
        api.pNotifyGroup(data.id, 'Groups', GetPlayerName(source) .. ' has joined!')
        api.AddMember(data.id, source)
        return 'You joined the group'
    else
        return 'Invalid Password'
    end
end)
```

### 4. マルチフレームワークブリッジパターン

各ブリッジファイルは**冒頭でリソース存在チェック**を行い、該当フレームワークが起動していない場合は即 `return` で無効化します。

```lua
-- bridge/esx.lua
if GetResourceState('es_extended') ~= 'started' then return end
if not IsDuplicityVersion() then return end

local ESX = exports.es_extended:getSharedObject()

function GetPlayerName(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    return xPlayer.getName()
end
```

```lua
-- bridge/qbx.lua
if GetResourceState('qbx_core') ~= 'started' then return end
if not IsDuplicityVersion() then return end

function GetPlayerName(source)
    local playerData = exports.qbx_core:GetPlayer(source).PlayerData
    return playerData.charinfo.firstname .. ' ' .. playerData.charinfo.lastname
end
```

```lua
-- bridge/nd.lua
if GetResourceState('NDFramework') ~= 'started' then return end
if not IsDuplicityVersion() then return end

function GetPlayerName(source)
    local character = NDFramework.GetPlayer(source):GetCharacter()
    return character.GetFirstName() .. ' ' .. character.GetLastName()
end
```

fxmanifest で全ブリッジを読み込むと、起動しているフレームワークのみ有効化されます:

```lua
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@ox_lib/init.lua',
    'bridge/*.lua',        -- 全ブリッジを読み込む
    'server/*.lua',
}
```

### 5. OxClass ベースのサーバーモデル（server/groups.lua）

```lua
local groups = lib.class('groups')

function groups:constructor(id, name, password, leader, ScriptCreated)
    self.id           = id
    self.name         = name
    self.private.password = password or lib.string.random('1111111')  -- デフォルトランダム
    self.leader       = leader
    self.ScriptCreated = ScriptCreated
    self.members      = {{ name = GetPlayerName(leader), playerId = leader }}
    self.stage        = {}
    self.status       = 'WAITING'  -- 'WAITING' | 'IN_PROGRESS' | 'DONE'
end

function groups:addMember(source)
    table.insert(self.members, {
        name     = GetPlayerName(source),
        playerId = source
    })
    -- 全メンバーに通知
    self:notifyAll('memberJoined', { name = GetPlayerName(source) })
end
```

### 6. Export の二重登録（qb-phone 互換）

```lua
-- server/utils.lua
-- exports と "qb-phone" 互換 exports の両方を登録
function utils.exportHandler(exportName, func)
    -- qb-phone 互換（AddEventHandler 経由）
    AddEventHandler(('__cfx_export_qb-phone_%s'):format(exportName), function(setCB)
        setCB(func)
    end)
    -- 標準 exports
    exports(exportName, func)
end

-- 使用例
utils.exportHandler('CreateGroup', function(name, leader)
    return api.CreateGroup(name, leader)
end)
```

`fxmanifest.lua` の `provide 'qb-phone'` と組み合わせることで、qb-phone を使うリソースが `exports['qb-phone']:CreateGroup()` で呼び出せるようになります。

---

## React UI 実装（Zustand + useNuiEvent）

```typescript
// ui/src/store/groupStore.ts
import { create } from 'zustand';

interface GroupStore {
    groups:      Group[];
    myGroup:     Group | null;
    setGroups:   (groups: Group[]) => void;
    setMyGroup:  (group: Group | null) => void;
}

export const useGroupStore = create<GroupStore>((set) => ({
    groups:    [],
    myGroup:   null,
    setGroups: (groups) => set({ groups }),
    setMyGroup: (group) => set({ myGroup: group }),
}));
```

```tsx
// ui/src/pages/Home.tsx
import { useNuiEvent } from '../hooks/useNuiEvent';
import { useGroupStore } from '../store/groupStore';

export function Home() {
    const { setGroups, setMyGroup } = useGroupStore();

    // Lua (SendCustomAppMessage) からのデータ受信
    useNuiEvent<SetupAppData>('setupApp', (data) => {
        setGroups(data.availableGroups);
        setMyGroup(data.myGroup);
    });

    // ...
}
```

---

## State Bags による近接共有

```typescript
// Server: プレイヤーに状態を付与
Player(source).state.set('slrn_groups-user', {
    groupId:    group.id,
    groupName:  group.name,
    role:       'member',
}, true);  // replicated: 全 Client に同期

// Client: 他プレイヤーの状態を読む
const svId = GetPlayerServerId(targetPed);
const groupData = Player(svId).state['slrn_groups-user'];
if (groupData?.groupId === myGroupId) {
    // 同じグループのメンバー
}
```

---

## 依存リソース

- `ox_lib`（lib.callback, lib.class, lib.string 等）
- いずれか1つのフレームワーク: `es_extended` / `qb-core` / `qbx_core` / `NDFramework` / `ox_core`
- `oxmysql`（データ永続化）

---

## このアプリが示すこと

| 点 | 内容 |
|---|------|
| マルチフレームワーク | 5つのフレームワークに対応するブリッジパターン |
| lib.callback | `lib.callback.await` による同期的なサーバー通信 |
| OxClass | Lua でのオブジェクト指向モデリング |
| Zustand | React での軽量状態管理 |
| onUse 初期化 | アプリ起動時にサーバーから最新データをプッシュするパターン |
| export 互換 | provide + 二重登録で旧リソースとの互換性を保つ |

---

## 関連ドキュメント

- [bs_laymo — QBX + React JS 実装例](bs-laymo.md)
- [factionapp — ESX + Vanilla JS 実装例](factionapp.md)
- [FiveM 通信パターン](../fivem/communication-patterns.md)
- [State Bags](../fivem/state-bags.md)
