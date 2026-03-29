# テーマとCSS

lb-phoneはダーク/ライトテーマを `data-theme` 属性で制御します。  
カスタムアプリもこの仕組みに従うことで、ユーザーの設定に自動追従できます。

---

## CSS変数（カラーパレット）

```css
:root {
    /* ライトテーマ（デフォルト） */
    --background-primary:   #f5f5f5;
    --background-secondary: #e0e0e0;
    --background-tertiary:  #d0d0d0;
    --text-primary:         #000000;
    --text-secondary:       #555555;
    --text-tertiary:        #888888;
    --accent:               #007AFF;
    --accent-dark:          #0056cc;
    --border:               rgba(0,0,0,0.1);
    --shadow:               rgba(0,0,0,0.15);
}

[data-theme='dark'] {
    /* ダークテーマ */
    --background-primary:   #000000;
    --background-secondary: #1c1c1e;
    --background-tertiary:  #2c2c2e;
    --text-primary:         #f2f2f7;
    --text-secondary:       #ebebf5;
    --text-tertiary:        #636366;
    --accent:               #0a84ff;
    --accent-dark:          #0060c8;
    --border:               rgba(255,255,255,0.1);
    --shadow:               rgba(0,0,0,0.5);
}
```

使用例:

```css
.my-card {
    background-color: var(--background-secondary);
    color: var(--text-primary);
    border: 1px solid var(--border);
}

.my-button {
    background-color: var(--accent);
    color: #ffffff;
}
```

---

## テーマの取得と変更検知

```typescript
// 現在の設定を取得
const settings = getSettings()
console.log(settings.theme)  // 'default' | 'dark'

// 設定変更を監視
onSettingsChange((newSettings) => {
    document.body.dataset.theme = newSettings.theme === 'dark' ? 'dark' : ''
})
```

---

## fixBlur と単位の使い分け

`AddCustomApp` で `fixBlur: true` を指定した場合、lb-phoneはフォントのぼやけ補正を行います。  
この場合、フォントサイズやスペーシングには必ず **`em` / `rem`** を使用してください。

```css
/* fixBlur=true のとき ✅ 正しい */
.text {
    font-size: 1rem;
    padding: 0.5em 1em;
    margin-bottom: 0.75rem;
    border-radius: 0.5rem;
}

/* ❌ px 単位はぼやける */
.text {
    font-size: 16px;
    padding: 8px 16px;
}
```

---

## 開発時のフォンフレーム再現（任意）

Vite dev server でlb-phoneの電話フレームに近い見た目を再現するためのCSS。

```css
/* 開発時のみ（body.dev-mode など条件付きで適用） */
#root {
    width: 390px;
    height: 844px;
    border-radius: 40px;
    overflow: hidden;
    position: relative;
}
```

---

## Tailwind CSSを使う場合

Tailwindを併用する場合、CSS変数を Tailwindのテーマに組み込むと統一感が出ます。

```javascript
// tailwind.config.js
module.exports = {
    theme: {
        extend: {
            colors: {
                'bg-primary':   'var(--background-primary)',
                'bg-secondary': 'var(--background-secondary)',
                'text-primary': 'var(--text-primary)',
                accent:         'var(--accent)',
            }
        }
    }
}
```

---

## 関連ドキュメント

- [グローバルUI API](global-ui-api.md)（`getSettings` / `onSettingsChange`）
- [アプリ登録](app-registration.md)（`fixBlur` パラメータ）
