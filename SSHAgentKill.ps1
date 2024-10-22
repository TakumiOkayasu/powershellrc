# SSH-Agent���~����X�N���v�g
$ErrorActionPreference = "Stop"

try {
    # SSH-Agent�̃T�[�r�X��Ԃ��m�F
    $service = Get-Service -Name "ssh-agent" -ErrorAction SilentlyContinue
    
    if ($null -eq $service) {
        Write-Error "SSH-Agent�T�[�r�X��������܂���"
        exit 1
    }
    
    # �T�[�r�X���N�����Ă���ꍇ�͒�~
    if ($service.Status -eq "Running") {
        Stop-Service "ssh-agent"
        Write-Host "SSH-Agent���~���܂���"
    }
    else {
        Write-Host "SSH-Agent�͊��ɒ�~���Ă��܂�"
    }
}
catch {
    Write-Error "�G���[���������܂���: $_"
    exit 1
}
