#Requires -RunAsAdministrator
<#
.SYNOPSIS
    SSH-Agentシャットダウンスクリプトの削除

.DESCRIPTION
    SetupShutdownScript.ps1で設定したシャットダウンスクリプトを安全に削除します。
    Windows ProとHomeの両方で動作します。

    安全性のため、以下の機能を実装：
    - レジストリの自動バックアップ
    - 削除前の確認プロンプト
    - 削除対象の詳細表示
    - エラー時の詳細なログ出力

.PARAMETER Force
    確認プロンプトをスキップする場合に指定

.EXAMPLE
    .\RemoveShutdownScript.ps1

.EXAMPLE
    .\RemoveShutdownScript.ps1 -Force
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# エラーアクションプリファレンス
$ErrorActionPreference = 'Stop'

# ログ関数
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )

    $colors = @{
        'Info' = 'White'
        'Success' = 'Green'
        'Warning' = 'Yellow'
        'Error' = 'Red'
    }

    $prefix = @{
        'Info' = '[INFO]'
        'Success' = '[✓]'
        'Warning' = '[!]'
        'Error' = '[✗]'
    }

    Write-Host "$($prefix[$Level]) $Message" -ForegroundColor $colors[$Level]
}

# レジストリバックアップ関数
function Backup-RegistryKey {
    param(
        [string]$Path,
        [string]$BackupPath
    )

    try {
        Write-Log "レジストリをバックアップ中: $Path" -Level Info

        if (Test-Path $Path) {
            # レジストリキーをエクスポート
            $regPath = $Path -replace 'HKLM:\\', 'HKEY_LOCAL_MACHINE\'
            $result = reg export $regPath $BackupPath /y 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-Log "バックアップ完了: $BackupPath" -Level Success
                return $true
            } else {
                Write-Log "バックアップに失敗しました: $result" -Level Warning
                return $false
            }
        } else {
            Write-Log "バックアップ対象のキーが存在しません" -Level Warning
            return $false
        }
    } catch {
        Write-Log "バックアップエラー: $($_.Exception.Message)" -Level Warning
        return $false
    }
}

# メイン処理開始
Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  SSH-Agent シャットダウンスクリプト 削除                    ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

try {
    # レジストリパス定義
    $regBasePath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Shutdown"
    $regPath = "$regBasePath\0"
    $regScriptPath = "$regPath\0"

    # 現在の設定を確認
    Write-Log "現在の設定を確認中..." -Level Info

    if (-not (Test-Path $regPath)) {
        Write-Log "シャットダウンスクリプトは設定されていません" -Level Warning
        Write-Host "`nレジストリパス: " -NoNewline -ForegroundColor White
        Write-Host $regPath -ForegroundColor Yellow
        Write-Host "このパスは存在しません。" -ForegroundColor Gray
        exit 0
    }

    # 設定の詳細を取得
    $scriptConfig = $null
    if (Test-Path $regScriptPath) {
        $scriptConfig = Get-ItemProperty -Path $regScriptPath -ErrorAction SilentlyContinue
    }

    # 現在の設定を表示
    Write-Host "`n【現在の設定】" -ForegroundColor Cyan

    if ($scriptConfig -and $scriptConfig.Script) {
        Write-Host "  スクリプト    : " -NoNewline -ForegroundColor White
        Write-Host $scriptConfig.Script -ForegroundColor Yellow
        Write-Host "  パラメータ    : " -NoNewline -ForegroundColor White
        Write-Host $(if ($scriptConfig.Parameters) { $scriptConfig.Parameters } else { "(なし)" }) -ForegroundColor Yellow
        Write-Host "  PowerShell    : " -NoNewline -ForegroundColor White
        Write-Host $(if ($scriptConfig.IsPowershell -eq 1) { "はい" } else { "いいえ" }) -ForegroundColor Yellow
        Write-Host "  レジストリ    : " -NoNewline -ForegroundColor White
        Write-Host $regPath -ForegroundColor Yellow
    } else {
        Write-Host "  設定が見つかりませんでした" -ForegroundColor Gray
    }

    # 削除確認
    if (-not $Force) {
        Write-Host "`nこの設定を削除しますか? (Y/N): " -ForegroundColor Yellow -NoNewline
        $confirm = Read-Host

        if ($confirm -ne 'Y' -and $confirm -ne 'y') {
            Write-Log "操作をキャンセルしました" -Level Info
            exit 0
        }
    } else {
        Write-Log "Forceパラメータが指定されているため、確認をスキップします" -Level Warning
    }

    # バックアップファイルパス
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupDir = Join-Path $env:TEMP "RegistryBackup"
    if (-not (Test-Path $backupDir)) {
        New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
    }
    $backupFile = Join-Path $backupDir "ShutdownScripts_Backup_$timestamp.reg"

    # レジストリのバックアップ
    Write-Host ""
    $backupSuccess = Backup-RegistryKey -Path $regBasePath -BackupPath $backupFile

    if (-not $backupSuccess) {
        Write-Log "バックアップに失敗しましたが、削除を続行しますか? (Y/N): " -Level Warning
        Write-Host "続行する場合は 'Y' を入力: " -ForegroundColor Yellow -NoNewline
        $response = Read-Host

        if ($response -ne 'Y' -and $response -ne 'y') {
            Write-Log "操作を中止しました" -Level Info
            exit 0
        }
    }

    # 削除処理
    Write-Host ""
    Write-Log "レジストリキーを削除中..." -Level Info

    # 子キーから削除（安全のため）
    $deletedItems = @()

    try {
        # スクリプト設定キーを削除
        if (Test-Path $regScriptPath) {
            Write-Log "削除中: $regScriptPath" -Level Info
            Remove-Item -Path $regScriptPath -Recurse -Force -ErrorAction Stop
            $deletedItems += $regScriptPath
            Write-Log "削除完了: スクリプト設定キー" -Level Success
        }

        # メインキーを削除（他のスクリプトがない場合のみ）
        if (Test-Path $regPath) {
            $remainingKeys = Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue
            if ($remainingKeys.Count -eq 0) {
                Write-Log "削除中: $regPath" -Level Info
                Remove-Item -Path $regPath -Force -ErrorAction Stop
                $deletedItems += $regPath
                Write-Log "削除完了: メインキー" -Level Success
            } else {
                Write-Log "他のシャットダウンスクリプトが存在するため、メインキーは保持します" -Level Info
            }
        }

        # ベースパスを削除（空の場合のみ）
        if (Test-Path $regBasePath) {
            $remainingKeys = Get-ChildItem -Path $regBasePath -ErrorAction SilentlyContinue
            if ($remainingKeys.Count -eq 0) {
                Write-Log "削除中: $regBasePath (空のため)" -Level Info
                Remove-Item -Path $regBasePath -Force -ErrorAction Stop
                $deletedItems += $regBasePath
                Write-Log "削除完了: ベースパス" -Level Success
            }
        }

        # 成功メッセージ
        Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "║  シャットダウンスクリプトの削除が完了しました               ║" -ForegroundColor Green
        Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Green

        Write-Host "【削除されたレジストリキー】" -ForegroundColor Cyan
        foreach ($item in $deletedItems) {
            Write-Host "  - " -NoNewline -ForegroundColor White
            Write-Host $item -ForegroundColor Yellow
        }

        if ($backupSuccess) {
            Write-Host "`n【バックアップ】" -ForegroundColor Cyan
            Write-Host "  場所: " -NoNewline -ForegroundColor White
            Write-Host $backupFile -ForegroundColor Yellow
            Write-Host "  復元方法: " -NoNewline -ForegroundColor White
            Write-Host "reg import `"$backupFile`"" -ForegroundColor Cyan
        }

        Write-Host "`n【重要】変更を有効にするには、以下のいずれかを実行してください：" -ForegroundColor Yellow
        Write-Host "  1. システムを再起動する" -ForegroundColor White
        Write-Host "  2. グループポリシーを更新: " -NoNewline -ForegroundColor White
        Write-Host "gpupdate /force" -ForegroundColor Cyan

    } catch {
        throw "削除処理中にエラーが発生しました: $($_.Exception.Message)"
    }

} catch {
    Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║  エラーが発生しました                                       ║" -ForegroundColor Red
    Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Red

    Write-Log "エラー詳細: $($_.Exception.Message)" -Level Error
    Write-Log "発生場所: $($_.InvocationInfo.ScriptLineNumber) 行目" -Level Error

    if ($backupSuccess -and (Test-Path $backupFile)) {
        Write-Host "`n【復元方法】" -ForegroundColor Yellow
        Write-Host "バックアップから復元する場合: " -ForegroundColor White
        Write-Host "  reg import `"$backupFile`"" -ForegroundColor Cyan
    }

    exit 1
}
