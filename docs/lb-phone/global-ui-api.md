# グローバル UI API（window.*）

lb-phoneはカスタムアプリのUIロード時に `globalThis`（window）へ以下の関数・変数を自動注入します。  
TypeScript型定義は lb-phone公式テンプレートの `components.d.ts` を参照してください。

> 型定義ファイル: https://github.com/lbphone/lb-phone-app-template/blob/main/lb-reactts/ui/src/components.d.ts

---

## コンテキスト変数

| 変数 | 型 | 説明 |
|------|-----|------|
| `window.resourceName` | `string` | カスタムアプリを登録したリソース名 |
| `window.appName` | `string` | `AddCustomApp` で指定した `identifier` |
| `window.settings` | `object` | 現在の電話設定（テーマ等） |
| `window.components` | `object` | UIコンポーネント群（後述） |

---

## NUI通信

| 関数 | 説明 |
|------|------|
| `fetchNui<T>(event, data?, mockData?)` | LuaのNUIコールバックを呼び出す（Promise） |
| `onNuiEvent(event, callback)` | Lua→UIのメッセージを受信（バニラJS用） |
| `useNuiEvent<T>(event, callback)` | Lua→UIのメッセージを受信（Reactフック） |

```typescript
// fetchNui の使用例
const result = await fetchNui<{ balance: number }>('getBalance', { playerId: localPlayer })

// onNuiEvent の使用例（バニラJS）
onNuiEvent('updateData', (data) => { console.log(data) })

// useNuiEvent の使用例（React）
useNuiEvent<MyData>('updateData', (data) => setState(data))
```

---

## 電話機能

| 関数 | 説明 |
|------|------|
| `getSettings()` | 電話の設定オブジェクトを取得 |
| `onSettingsChange(callback)` | 設定変更イベントをリッスン |
| `formatPhoneNumber(number)` | 電話番号を表示形式にフォーマット |
| `sendNotification(data)` | lb-phoneの通知を表示 |
| `createCall(options)` | 電話を発信する |
| `setApp(app)` | アクティブなアプリを切り替える |

```javascript
// 通知の表示
sendNotification({
    title: '通知タイトル',
    description: '通知の内容',
    app: 'myapp',            // アプリ識別子
    sound: true,
})

// 電話発信
createCall({ number: '1234567890', videoCall: false, hideNumber: false })
// 会社/組織として発信
createCall({ company: 'police' })

// 設定変更のリスナー
onSettingsChange((newSettings) => {
    console.log(newSettings.theme)   // 'default' | 'dark'
})
```

---

## components API

`components` オブジェクト経由でlb-phoneのUIコンポーネントを呼び出せます。

### setPopUp — ダイアログ

```typescript
components.setPopUp({
    title: '確認',
    description: '本当に削除しますか？',
    buttons: [
        { title: 'キャンセル', color: 'red',  cb: () => {} },
        { title: '削除',       color: 'blue', cb: () => handleDelete() },
    ]
})

// v2.7.1: inputs 配列で複数の入力フィールドを持つポップアップ
// （input 単体の場合は従来どおり input: { ... } を使用可）
components.setPopUp({
    title: '情報入力',
    inputs: [
        { label: '名前', placeholder: '例: John', onChange: (val) => setName(val) },
        { label: '金額', placeholder: '例: 1000',  onChange: (val) => setAmount(val) },
    ],
    buttons: [
        { title: 'キャンセル', color: 'red',  cb: () => {} },
        { title: '送信',       color: 'blue', cb: () => submitForm() },
    ]
})
```

### setContextMenu — コンテキストメニュー

```typescript
components.setContextMenu({
    title: 'メニュー',
    buttons: [
        { title: '編集', icon: 'edit', cb: () => openEditor() },
        { title: '削除', icon: 'trash', cb: () => deleteItem() },
    ]
})
```

### setGallery — メディアギャラリー

```typescript
components.setGallery({
    includeVideos: true,
    includeImages: true,
    allowExternal: true,
    multiSelect: false,
    onSelect(media) {
        console.log(media.src)   // 選択されたメディアのURL
    }
})
```

### setContactSelector — 連絡先選択

```typescript
components.setContactSelector({
    onSelect(contact) {
        console.log(contact.number, contact.firstname, contact.lastname)
    }
})
```

### setShareComponent — 共有

```typescript
components.setShareComponent({
    type: 'image',
    data: { isVideo: false, src: 'https://...' }
})
```

### その他のコンポーネント

```typescript
// 絵文字ピッカー
components.setEmojiPickerVisible({ onSelect: (emoji) => insertEmoji(emoji) })

// GIFピッカー
components.setGifPickerVisible({ onSelect: (gif) => insertGif(gif) })

// カラーピッカー
components.setColorPicker({
    onSelect(color) { setSelectedColor(color) },
    onClose(color)  { finalizeColor(color) }
})

// フルスクリーン画像表示
components.setFullscreenImage('https://example.com/image.jpg')

// ホームインジケーター表示/非表示
components.setHomeIndicatorVisible(true)
```

---

## メディアアップロード

```typescript
// ファイルをlb-phoneのメディアサーバーにアップロード
// type: 'Video' | 'Image' | 'Audio'
const url = await components.uploadMedia('Image', blob)

// ギャラリーに保存
const id = await components.saveToGallery(url)

// saveToGallery の全パラメータ
await components.saveToGallery(url, size?, type?, shouldLog?)
```

---

## ゲームレンダリング（カメラ）

```typescript
// ゲーム画面をcanvas要素にレンダリング
const gameRender = components.createGameRender(canvasElement)

gameRender.resizeByAspect(9 / 16)   // アスペクト比に合わせてリサイズ
gameRender.pause()                  // レンダリング一時停止
gameRender.resume()                 // レンダリング再開

// 写真撮影
const blob = await gameRender.takePhoto()

// 動画録画
const recorder = gameRender.startRecording((videoBlob) => {
    // 録画完了時のコールバック
    saveVideo(videoBlob)
})

gameRender.destroy()   // リソース解放
```

---

## マップコンポーネント（v2.7.0+）

`components.GameMap` は lb-phone の GTA マップをカスタムアプリの任意の DOM 要素に埋め込めるクラスです。  
Los Santos・Cayo Perico、および `Config.CustomMaps` で定義したカスタムマップタイルに対応しています。  
Leaflet.js をベースにしており、lb-phone 側から動的に `leaflet.js` と `leaflet.css` が読み込まれます。

> ⚠️ **公式ドキュメントは近日公開予定** とアナウンスされており、API は変更される可能性があります。

### インスタンス生成

```typescript
// コンテナ要素にマップを埋め込む
const map = new components.GameMap(containerElement, options?)
```

**オプション**

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `allowMoving` | `boolean` | ドラッグによる移動を許可するか（デフォルト: `true`） |
| `center` | `{ x: number, y: number }` | 初期表示中心（GTA ワールド座標） |
| `defaultZoom` | `number` | 初期ズームレベル |

### インスタンスメソッド

| メソッド | 戻り値 | 説明 |
|---------|--------|------|
| `setPosition(coords, zoom?)` | `boolean` | 表示位置を GTA 座標 `{x,y}` または `[x,y]` で指定。`zoom` も同時指定可 |
| `setZoom(zoom)` | `boolean` | ズームレベルを設定 |
| `getZoom()` | `number \| null` | 現在のズームレベルを取得 |
| `getMaps()` | `string[]` | 利用可能なマップ ID 一覧（例: `'losSantos'`, `'cayoPerico'`, `'customMap0'`） |
| `setMap(mapId)` | `boolean` | 表示マップを切り替え |
| `cycleMap()` | `string \| null` | 次のマップに切り替え（切り替え後の ID を返す） |
| `getStyles()` | `string[]` | 現在のマップで使用可能なスタイル名（例: `['render', 'game', 'print']`） |
| `setStyle(name)` | `boolean` | マップスタイルを切り替え |
| `cycleStyle()` | `string \| null` | 次のスタイルに切り替え |
| `setShowSelf(visible)` | `Promise<void>` | 自分の現在地を地図上に表示/非表示（`maps:updateCoords` イベントを内部でリクエスト） |
| `addLocation(data)` | `LocationObject` | マーカーを追加。戻り値の `id` で後から削除可 |
| `removeLocation(id)` | `boolean` | マーカーを ID で削除 |
| `refreshLayout()` | `void` | コンテナサイズ変更後に地図を再描画 |
| `destroy()` | `void` | リスナー解除・DOM 削除などクリーンアップ |

**`addLocation` のデータ形式**

```typescript
const loc = map.addLocation({
    title: 'LSPD',                           // ポップアップに表示するテキスト（任意）
    image: 'https://example.com/pin.png',   // カスタムアイコン URL（任意）
    coords: { x: 428.9, y: -984.5 }         // GTA ワールド座標
})
// loc: { id: number, title, image, coords }
map.removeLocation(loc.id)
```

### `components.getCustomMaps()`

`Config.CustomMaps` の配列を返します。

```typescript
const customMaps = components.getCustomMaps()
// 例: [{ label: "RDR2", url: "https://...", ... }]
```

### 使用例

```typescript
// React: useEffect でマップを作成・破棄
import { useEffect, useRef } from 'react'

export default function MapView() {
    const containerRef = useRef<HTMLDivElement>(null)

    useEffect(() => {
        if (!containerRef.current) return
        const map = new window.components.GameMap(containerRef.current, {
            allowMoving: true,
            defaultZoom: 3,
        })
        map.setShowSelf(true)               // 自分の位置を表示
        map.addLocation({
            title: '目的地',
            coords: { x: 428.9, y: -984.5 },
        })
        return () => map.destroy()
    }, [])

    return <div ref={containerRef} style={{ width: '100%', height: '400px' }} />
}
```

```javascript
// バニラ JS
const container = document.getElementById('map-container')
const map = new components.GameMap(container)

// 利用可能なマップを列挙してボタンに割り当てる
map.getMaps().forEach(id => {
    const btn = document.createElement('button')
    btn.textContent = id
    btn.onclick = () => map.setMap(id)
    document.body.appendChild(btn)
})
```

### `Config.CustomMaps`（Lua 側）

```lua
-- config/config.lua
Config.CustomMaps = {
    {
        label = "RDR2",
        url   = "https://s.rsg.sc/sc/images/games/RDR2/map/{layer}/{z}/{x}/{y}.jpg",
        center       = { 5000, 5000 },
        topLeft      = { -7168, 4096 },
        bottomRight  = { 5120, -5632 },
        resolution   = { 48841, 38666 },
        zoom = { default = 2, max = 8, min = 2 },
        styles = {
            { name = "game", background = "#384950" },
        }
    },
}
```

カスタムマップを定義すると Maps アプリでも切り替え可能になり、`components.GameMap` でも `getMaps()` に含まれます。

> ⚠️ **`Config.CustomMaps` を設定すると、既定マップ（Los Santos・Cayo Perico）は無効化されます。**  
> カスタムマップと既定マップを「追加」するのではなく「置き換え」です。  
> 有効なエントリが 1 件もない場合のみ既定マップにフォールバックします。

---

## 開発モード（devMode）の判定

ブラウザでの開発時と実際のゲーム内NUIを判定する方法。

```typescript
// window.invokeNative はゲーム内NUIにのみ存在する
const devMode = !window?.['invokeNative']

if (devMode) {
    // ブラウザ（Vite dev server）での動作
    // fetchNui はモックデータを返す
} else {
    // ゲーム内NUI
}
```

`fetchNui` の第3引数にモックデータを渡すと、devMode時に自動でそちらが返されます。

```typescript
const result = await fetchNui(
    'getBalance',
    {},
    { balance: 99999 }  // devMode時のモックデータ
)
```

---

## 関連ドキュメント

- [Lua↔UI通信](lua-ui-communication.md)
- [テーマとCSS](themes-and-css.md)
- [lb-phone公式API リファレンス](api-reference.md)
