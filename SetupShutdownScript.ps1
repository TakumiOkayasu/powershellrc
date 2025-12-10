#Requires -RunAsAdministrator
<#
.SYNOPSIS
    SSH-Agentシャットダウンスクリプトのセットアップ（Windows Pro/Home共通）

.DESCRIPTION
    このスクリプトは、Windows ProとHomeの両方で動作するように、
    レジストリを使用してシャットダウン時にSSH-Agentを停止するスクリプトを登録します。

    安全性のため、以下の機能を実装：
    - レジストリの自動バックアップ
    - 既存設定の確認と警告
    - エラー時の自動ロールバック
    - 詳細なログ出力

.PARAMETER ScriptPath
    SSHAgentKill.ps1の絶対パス

.PARAMETER Force
    既存の設定を上書きする場合に指定

.EXAMPLE
    .\SetupShutdownScript.ps1

.EXAMPLE
    .\SetupShutdownScript.ps1 -ScriptPath "C:\prog\powershellrc\SSHAgentKill.ps1"

.EXAMPLE
    .\SetupShutdownScript.ps1 -Force
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ScriptPath,

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
            Write-Log "バックアップ対象のキーが存在しません（新規作成）" -Level Info
            return $true
        }
    } catch {
        Write-Log "バックアップエラー: $($_.Exception.Message)" -Level Warning
        return $false
    }
}

# レジストリリストア関数
function Restore-RegistryKey {
    param(
        [string]$BackupPath
    )

    try {
        if (Test-Path $BackupPath) {
            Write-Log "レジストリをロールバック中..." -Level Warning
            $result = reg import $BackupPath 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-Log "ロールバック完了" -Level Success
                return $true
            } else {
                Write-Log "ロールバック失敗: $result" -Level Error
                return $false
            }
        }
    } catch {
        Write-Log "ロールバックエラー: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# レジストリ設定検証関数
function Test-RegistryConfiguration {
    param(
        [string]$RegScriptPath,
        [string]$ExpectedScriptPath
    )

    try {
        if (-not (Test-Path $RegScriptPath)) {
            Write-Log "検証失敗: レジストリキーが存在しません" -Level Error
            return $false
        }

        $props = Get-ItemProperty -Path $RegScriptPath -ErrorAction Stop

        if ($props.Script -ne $ExpectedScriptPath) {
            Write-Log "検証失敗: スクリプトパスが一致しません" -Level Error
            return $false
        }

        if ($props.IsPowershell -ne 1) {
            Write-Log "検証失敗: PowerShellフラグが正しく設定されていません" -Level Error
            return $false
        }

        Write-Log "設定検証: OK" -Level Success
        return $true

    } catch {
        Write-Log "検証エラー: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# メイン処理開始
Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  SSH-Agent シャットダウンスクリプト セットアップ            ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

try {
    # スクリプトパスの検出と検証
    if (-not $ScriptPath) {
        $currentDir = Split-Path -Parent $MyInvocation.MyCommand.Path
        $defaultPath = Join-Path $currentDir "SSHAgentKill.ps1"

        if (Test-Path $defaultPath) {
            $ScriptPath = $defaultPath
            Write-Log "スクリプトを自動検出: $ScriptPath" -Level Success
        } else {
            Write-Log "SSHAgentKill.ps1が見つかりません" -Level Error
            Write-Log "使用例: .\SetupShutdownScript.ps1 -ScriptPath 'C:\Path\To\SSHAgentKill.ps1'" -Level Info
            exit 1
        }
    }

    # スクリプトの存在確認
    if (-not (Test-Path $ScriptPath)) {
        Write-Log "スクリプトが見つかりません: $ScriptPath" -Level Error
        exit 1
    }

    # 絶対パスに変換
    $ScriptPath = (Resolve-Path $ScriptPath).Path
    Write-Log "対象スクリプト: $ScriptPath" -Level Info

    # OS情報の表示
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    Write-Log "OS: $($osInfo.Caption)" -Level Info

    # レジストリパス定義
    $regBasePath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Shutdown"
    $regPath = "$regBasePath\0"
    $regScriptPath = "$regPath\0"

    # バックアップファイルパス
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupDir = Join-Path $env:TEMP "RegistryBackup"
    if (-not (Test-Path $backupDir)) {
        New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
    }
    $backupFile = Join-Path $backupDir "ShutdownScripts_$timestamp.reg"

    # 既存設定の確認
    if (Test-Path $regScriptPath) {
        $existingConfig = Get-ItemProperty -Path $regScriptPath -ErrorAction SilentlyContinue

        if ($existingConfig -and $existingConfig.Script) {
            Write-Host "`n" -NoNewline
            Write-Log "既存の設定が見つかりました！" -Level Warning
            Write-Host "  現在のスクリプト: " -NoNewline -ForegroundColor Yellow
            Write-Host $existingConfig.Script -ForegroundColor White
            Write-Host "  新しいスクリプト: " -NoNewline -ForegroundColor Yellow
            Write-Host $ScriptPath -ForegroundColor White

            if (-not $Force) {
                Write-Host "`n既存の設定を上書きしますか? (Y/N): " -ForegroundColor Yellow -NoNewline
                $response = Read-Host

                if ($response -ne 'Y' -and $response -ne 'y') {
                    Write-Log "操作をキャンセルしました" -Level Info
                    Write-Log "上書きする場合は -Force パラメータを使用してください" -Level Info
                    exit 0
                }
            } else {
                Write-Log "Forceパラメータが指定されているため、上書きします" -Level Warning
            }
        }
    }

    # レジストリのバックアップ
    Write-Host ""
    $backupSuccess = Backup-RegistryKey -Path $regBasePath -BackupPath $backupFile

    if (-not $backupSuccess) {
        Write-Log "バックアップに失敗しましたが、続行しますか? (Y/N): " -Level Warning
        Write-Host "続行する場合は 'Y' を入力: " -ForegroundColor Yellow -NoNewline
        $response = Read-Host

        if ($response -ne 'Y' -and $response -ne 'y') {
            Write-Log "操作を中止しました" -Level Info
            exit 0
        }
    }

    # レジストリ設定開始
    Write-Host ""
    Write-Log "レジストリキーを設定中..." -Level Info

    # トランザクション的な処理のため、エラー時にロールバックできるようにする
    $rollbackNeeded = $false

    try {
        # ベースパスの作成
        if (-not (Test-Path $regBasePath)) {
            Write-Log "ベースパスを作成: $regBasePath" -Level Info
            New-Item -Path $regBasePath -Force -ErrorAction Stop | Out-Null
        }

        # メインキーの作成
        if (-not (Test-Path $regPath)) {
            Write-Log "メインキーを作成: $regPath" -Level Info
            New-Item -Path $regPath -Force -ErrorAction Stop | Out-Null
        }

        # GPO情報の設定
        Write-Log "GPO情報を設定中..." -Level Info
        Set-ItemProperty -Path $regPath -Name "GPO-ID" -Value "LocalGPO" -Type String -Force -ErrorAction Stop
        Set-ItemProperty -Path $regPath -Name "SOM-ID" -Value "Local" -Type String -Force -ErrorAction Stop
        Set-ItemProperty -Path $regPath -Name "FileSysPath" -Value "C:\Windows\System32\GroupPolicy\Machine" -Type String -Force -ErrorAction Stop
        Set-ItemProperty -Path $regPath -Name "DisplayName" -Value "ローカル グループ ポリシー" -Type String -Force -ErrorAction Stop
        Set-ItemProperty -Path $regPath -Name "GPOName" -Value "ローカル グループ ポリシー" -Type String -Force -ErrorAction Stop

        # スクリプト設定キーの作成
        if (-not (Test-Path $regScriptPath)) {
            Write-Log "スクリプト設定キーを作成: $regScriptPath" -Level Info
            New-Item -Path $regScriptPath -Force -ErrorAction Stop | Out-Null
        }

        # スクリプト詳細の設定
        Write-Log "スクリプト詳細を設定中..." -Level Info
        Set-ItemProperty -Path $regScriptPath -Name "Script" -Value $ScriptPath -Type String -Force -ErrorAction Stop
        Set-ItemProperty -Path $regScriptPath -Name "Parameters" -Value "" -Type String -Force -ErrorAction Stop
        Set-ItemProperty -Path $regScriptPath -Name "IsPowershell" -Value 1 -Type DWord -Force -ErrorAction Stop
        Set-ItemProperty -Path $regScriptPath -Name "ExecTime" -Value 0 -Type QWord -Force -ErrorAction Stop

        # 設定の検証
        Write-Host ""
        Write-Log "設定を検証中..." -Level Info
        if (-not (Test-RegistryConfiguration -RegScriptPath $regScriptPath -ExpectedScriptPath $ScriptPath)) {
            throw "設定の検証に失敗しました"
        }

        # 成功
        Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "║  セットアップが正常に完了しました！                         ║" -ForegroundColor Green
        Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Green

        Write-Host "【設定内容】" -ForegroundColor Cyan
        Write-Host "  レジストリパス: " -NoNewline -ForegroundColor White
        Write-Host $regScriptPath -ForegroundColor Yellow
        Write-Host "  スクリプト    : " -NoNewline -ForegroundColor White
        Write-Host $ScriptPath -ForegroundColor Yellow
        Write-Host "  バックアップ  : " -NoNewline -ForegroundColor White
        Write-Host $backupFile -ForegroundColor Yellow

        Write-Host "`n【重要】変更を有効にするには、以下のいずれかを実行してください：" -ForegroundColor Yellow
        Write-Host "  1. システムを再起動する" -ForegroundColor White
        Write-Host "  2. グループポリシーを更新: " -NoNewline -ForegroundColor White
        Write-Host "gpupdate /force" -ForegroundColor Cyan

        # 設定詳細の表示
        Write-Host "`n現在の設定詳細を表示しますか? (Y/N): " -ForegroundColor Yellow -NoNewline
        $confirm = Read-Host
        if ($confirm -eq 'Y' -or $confirm -eq 'y') {
            Write-Host "`n【登録された設定】" -ForegroundColor Cyan
            Get-ItemProperty -Path $regScriptPath | Format-List Script, Parameters, IsPowershell, ExecTime
        }

    } catch {
        $rollbackNeeded = $true
        throw
    }

} catch {
    Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║  エラーが発生しました                                       ║" -ForegroundColor Red
    Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Red

    Write-Log "エラー詳細: $($_.Exception.Message)" -Level Error
    Write-Log "発生場所: $($_.InvocationInfo.ScriptLineNumber) 行目" -Level Error

    # ロールバック処理
    if ($rollbackNeeded -and $backupSuccess -and (Test-Path $backupFile)) {
        Write-Host "`nレジストリをロールバックしますか? (Y/N): " -ForegroundColor Yellow -NoNewline
        $response = Read-Host

        if ($response -eq 'Y' -or $response -eq 'y') {
            Restore-RegistryKey -BackupPath $backupFile
        } else {
            Write-Log "ロールバックをスキップしました" -Level Warning
            Write-Log "手動でロールバックする場合: reg import `"$backupFile`"" -Level Info
        }
    }

    exit 1
}
