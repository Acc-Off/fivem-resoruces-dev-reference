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
