# SSH-Agentを停止するスクリプト
$ErrorActionPreference = "Stop"

try {
    # SSH-Agentのサービス状態を確認
    $service = Get-Service -Name "ssh-agent" -ErrorAction SilentlyContinue
    
    if ($null -eq $service) {
        Write-Error "SSH-Agentサービスが見つかりません"
        exit 1
    }
    
    # サービスが起動している場合は停止
    if ($service.Status -eq "Running") {
        Stop-Service "ssh-agent"
        Write-Host "SSH-Agentを停止しました"
    }
    else {
        Write-Host "SSH-Agentは既に停止しています"
    }
}
catch {
    Write-Error "エラーが発生しました: $_"
    exit 1
}
