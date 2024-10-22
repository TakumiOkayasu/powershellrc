# SSH-Agent���N������X�N���v�g
$ErrorActionPreference = "Stop"

try {
    # SSH-Agent�̃T�[�r�X��Ԃ��m�F
    $service = Get-Service -Name "ssh-agent" -ErrorAction SilentlyContinue
    
    if ($null -eq $service) {
        Write-Error "SSH-Agent�T�[�r�X��������܂���"
        exit 1
    }
    
    # �T�[�r�X����~���Ă���ꍇ�͋N��
    if ($service.Status -ne "Running") {
        Start-Service "ssh-agent"
        Write-Host "SSH-Agent���N�����܂���"
    }
    else {
        Write-Host "SSH-Agent�͊��ɋN�����Ă��܂�"
    }
    
    # ���ϐ�SSH_AUTH_SOCK��ݒ�
    $SSH_AUTH_SOCK = "$env:USERPROFILE\.ssh\agent.sock"
    [System.Environment]::SetEnvironmentVariable('SSH_AUTH_SOCK', $SSH_AUTH_SOCK, [System.EnvironmentVariableTarget]::User)
}
catch {
    Write-Error "�G���[���������܂���: $_"
    exit 1
}
