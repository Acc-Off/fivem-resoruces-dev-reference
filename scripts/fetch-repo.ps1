<#
.SYNOPSIS
    参照リポジトリを1件ずつ取得するスクリプト。
    SKILL.md の「ソースコード参照」手順から呼び出す想定。

.DESCRIPTION
    指定したキー名に対応する GitHub リポジトリを temp_repos/<key>/ へクローンする。
    既に存在する場合は git pull で最新化する。
    キー名を省略すると利用可能なリポジトリ一覧を表示する。

.PARAMETER RepoKey
    取得するリポジトリのキー名。省略すると一覧を表示して終了。

.PARAMETER Pull
    スイッチ。既にクローン済みのディレクトリに対して強制的に git pull を実行する。

.EXAMPLE
    # 一覧を表示
    .\scripts\fetch-repo.ps1

    # bs_laymo をクローン（または最新化）
    .\scripts\fetch-repo.ps1 bs_laymo

    # 既存ディレクトリを強制 pull する
    .\scripts\fetch-repo.ps1 bs_laymo -Pull
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string] $RepoKey,

    [switch] $Pull
)

# -----------------------------------------------------------------------
# リポジトリ定義テーブル
#   key              => @{ Url = "..."; Description = "..." }
# -----------------------------------------------------------------------
$Repos = [ordered]@{
    # ── テンプレート / Boilerplate ──────────────────────────────────────
    'fivem-typescript-boilerplate' = @{
        Url         = 'https://github.com/communityox/fivem-typescript-boilerplate'
        Description = 'Ox TypeScript Boilerplate (esbuild + Vite + React)'
    }
    'lb-phone-app-template'        = @{
        Url         = 'https://github.com/lbphone/lb-phone-app-template'
        Description = 'lb-phone 公式カスタムアプリテンプレート (4 バリアント)'
    }
    'mps-integrated'               = @{
        Url         = 'https://github.com/Maximus7474/mps-lb-phone-apptemplate-reactts'
        Description = 'MPS 統合版テンプレート (React + TS + ox_lib + DB)'
    }

    # ── lb-phone カスタムアプリ実装例 ───────────────────────────────────
    'bs_laymo'                     = @{
        Url         = 'https://github.com/BeetleStudios/bs_laymo'
        Description = '自動運転タクシーアプリ (QBX + ox_lib + React TS)'
    }
    'factionapp'                   = @{
        Url         = 'https://github.com/Panturien/factionapp'
        Description = 'ファクション管理アプリ (ESX / QBCore / Vanilla JS)'
    }
    'slrn_groups'                  = @{
        Url         = 'https://github.com/solareon/slrn_groups'
        Description = 'グループ管理アプリ (フレームワーク非依存 + React TS)'
    }
    'fivem-phone'                  = @{
        Url         = 'https://github.com/Greigh/FiveM-phone'
        Description = 'マルチフレームワーク電話スクリプト (Vanilla JS)'
    }

    # ── C# 実装例 ────────────────────────────────────────────────────────
    'simple-livemap'               = @{
        Url         = 'https://github.com/charming-byte/simple-livemap'
        Description = 'C# + ASP.NET Core IServer + SetHttpHandler + SSE'
    }
    'vmenu'                        = @{
        Url         = 'https://github.com/TomGrobbe/vMenu'
        Description = '大規模 C# FiveM リソース・権限設計・Convar'
    }
    'fivemrpserverresources'       = @{
        Url         = 'https://github.com/ossianhanning/FiveMRpServerResources'
        Description = 'C# RP 機能集 (銀行・インベントリ等)・セッション管理'
    }
}

# -----------------------------------------------------------------------
# キーなし → 一覧表示して終了
# -----------------------------------------------------------------------
if (-not $RepoKey) {
    Write-Host ''
    Write-Host '利用可能なリポジトリキー一覧:' -ForegroundColor Cyan
    Write-Host ('  {0,-35} {1}' -f 'キー名', '説明') -ForegroundColor Gray
    Write-Host ('  {0}' -f ('-' * 70)) -ForegroundColor Gray
    foreach ($key in $Repos.Keys) {
        Write-Host ('  {0,-35} {1}' -f $key, $Repos[$key].Description)
    }
    Write-Host ''
    Write-Host '使い方: .\scripts\fetch-repo.ps1 <キー名>' -ForegroundColor Yellow
    Write-Host '例    : .\scripts\fetch-repo.ps1 bs_laymo' -ForegroundColor Yellow
    Write-Host ''
    exit 0
}

# -----------------------------------------------------------------------
# キー存在チェック
# -----------------------------------------------------------------------
if (-not $Repos.Contains($RepoKey)) {
    Write-Error "不明なキー: '$RepoKey'"
    Write-Host "キー一覧を確認するには引数なしで実行してください。" -ForegroundColor Yellow
    exit 1
}

$repoInfo  = $Repos[$RepoKey]
$targetDir = Join-Path $PSScriptRoot '..' "temp_repos" $RepoKey
# パスを正規化（.. を解決）
$targetDir = [System.IO.Path]::GetFullPath($targetDir)

Write-Host ''
Write-Host "リポジトリ : $($repoInfo.Url)" -ForegroundColor Cyan
Write-Host "取得先     : $targetDir" -ForegroundColor Cyan
Write-Host ''

# -----------------------------------------------------------------------
# git が使えるか確認
# -----------------------------------------------------------------------
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error 'git コマンドが見つかりません。Git をインストールして PATH を通してください。'
    exit 1
}

# -----------------------------------------------------------------------
# クローン or プル
# -----------------------------------------------------------------------
if (Test-Path (Join-Path $targetDir '.git')) {
    # 既存リポジトリ
    if ($Pull) {
        Write-Host '既存のリポジトリを最新化しています...' -ForegroundColor Yellow
        Push-Location $targetDir
        git pull
        $exitCode = $LASTEXITCODE
        Pop-Location
        if ($exitCode -ne 0) {
            Write-Error "git pull が失敗しました (終了コード: $exitCode)"
            exit $exitCode
        }
        Write-Host '最新化が完了しました。' -ForegroundColor Green
    } else {
        Write-Host "既にクローン済みです: $targetDir" -ForegroundColor Yellow
        Write-Host "最新化するには -Pull スイッチを付けて実行してください。" -ForegroundColor Yellow
        Write-Host "例: .\scripts\fetch-repo.ps1 $RepoKey -Pull" -ForegroundColor Yellow
    }
} else {
    # 新規クローン
    $parentDir = Split-Path $targetDir -Parent
    if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    Write-Host 'クローンしています...' -ForegroundColor Yellow
    git clone $repoInfo.Url $targetDir
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        Write-Error "git clone が失敗しました (終了コード: $exitCode)"
        exit $exitCode
    }
    Write-Host 'クローンが完了しました。' -ForegroundColor Green
}

Write-Host ''
Write-Host "ソースコードの場所: $targetDir" -ForegroundColor Cyan
Write-Host ''
