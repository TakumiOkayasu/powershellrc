# SSH-Agentを起動するスクリプト
$ErrorActionPreference = "Stop"

try {
    # SSH-Agentのサービス状態を確認
    $service = Get-Service -Name "ssh-agent" -ErrorAction SilentlyContinue
    
    if ($null -eq $service) {
        Write-Error "SSH-Agentサービスが見つかりません"
        exit 1
    }
    
    # サービスが停止している場合は起動
    if ($service.Status -ne "Running") {
        Start-Service "ssh-agent"
        Write-Host "SSH-Agentを起動しました"
    }
    else {
        Write-Host "SSH-Agentは既に起動しています"
    }
    
    # 環境変数SSH_AUTH_SOCKを設定
    $SSH_AUTH_SOCK = "$env:USERPROFILE\.ssh\agent.sock"
    [System.Environment]::SetEnvironmentVariable('SSH_AUTH_SOCK', $SSH_AUTH_SOCK, [System.EnvironmentVariableTarget]::User)
}
catch {
    Write-Error "エラーが発生しました: $_"
    exit 1
}
