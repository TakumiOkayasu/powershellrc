# setup.ps1
# タスクスケジューラーにタスクを登録するセットアップスクリプト
# 管理者権限チェック
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "このスクリプトは管理者権限で実行する必要があります"
    Break
}

try {
    # スクリプトパスの設定
    $startScriptPath = Join-Path $PSScriptRoot "SSHAgentStart.ps1"
    $killScriptPath = Join-Path $PSScriptRoot "SSHAgentKill.ps1"

    # スクリプトの存在確認
    if (-not (Test-Path $startScriptPath) -or -not (Test-Path $killScriptPath)) {
        throw "必要なスクリプトファイルが見つかりません"
    }

    # タスクスケジューラーへの接続
    $taskScheduler = New-Object -ComObject Schedule.Service
    $taskScheduler.Connect()
    $taskFolder = $taskScheduler.GetFolder("\")

    # 起動タスクの作成
    $taskStart = $taskScheduler.NewTask(0)
    $taskStart.RegistrationInfo.Description = "Start SSH-Agent on startup"
    $taskStart.Settings.Enabled = $true
    $taskStart.Settings.AllowHardTerminate = $true

    # 権限設定
    $taskStart.Principal.RunLevel = 1  # 最高権限
    $taskStart.Principal.LogonType = 3

    # トリガー設定（起動時）
    $triggerStart = $taskStart.Triggers.Create(9) # 9 = At startup
    $triggerStart.Enabled = $true

    # アクション設定
    $execStart = $taskStart.Actions.Create(0)
    $execStart.Path = "powershell.exe"
    $execStart.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$startScriptPath`""

    # タスク登録
    $taskFolder.RegisterTaskDefinition(
        "Start SSH-Agent",
        $taskStart,
        6, # 既存のタスクを置き換え
        $null,
        $null,
        0
    )
    
    Write-Host "Start SSH-Agent タスクを正常に作成しました"
}
catch {
    Write-Error "エラーが発生しました: $_"
    Write-Error $_.Exception.Message
    Exit 1
}
