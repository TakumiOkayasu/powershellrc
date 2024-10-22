# setup.ps1
# �^�X�N�X�P�W���[���[�Ƀ^�X�N��o�^����Z�b�g�A�b�v�X�N���v�g
# �Ǘ��Ҍ����`�F�b�N
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "���̃X�N���v�g�͊Ǘ��Ҍ����Ŏ��s����K�v������܂�"
    Break
}

try {
    # �X�N���v�g�p�X�̐ݒ�
    $startScriptPath = Join-Path $PSScriptRoot "SSHAgentStart.ps1"
    $killScriptPath = Join-Path $PSScriptRoot "SSHAgentKill.ps1"

    # �X�N���v�g�̑��݊m�F
    if (-not (Test-Path $startScriptPath) -or -not (Test-Path $killScriptPath)) {
        throw "�K�v�ȃX�N���v�g�t�@�C����������܂���"
    }

    # �^�X�N�X�P�W���[���[�ւ̐ڑ�
    $taskScheduler = New-Object -ComObject Schedule.Service
    $taskScheduler.Connect()
    $taskFolder = $taskScheduler.GetFolder("\")

    # �N���^�X�N�̍쐬
    $taskStart = $taskScheduler.NewTask(0)
    $taskStart.RegistrationInfo.Description = "Start SSH-Agent on startup"
    $taskStart.Settings.Enabled = $true
    $taskStart.Settings.AllowHardTerminate = $true

    # �����ݒ�
    $taskStart.Principal.RunLevel = 1  # �ō�����
    $taskStart.Principal.LogonType = 3

    # �g���K�[�ݒ�i�N�����j
    $triggerStart = $taskStart.Triggers.Create(9) # 9 = At startup
    $triggerStart.Enabled = $true

    # �A�N�V�����ݒ�
    $execStart = $taskStart.Actions.Create(0)
    $execStart.Path = "powershell.exe"
    $execStart.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$startScriptPath`""

    # �^�X�N�o�^
    $taskFolder.RegisterTaskDefinition(
        "Start SSH-Agent",
        $taskStart,
        6, # �����̃^�X�N��u������
        $null,
        $null,
        0
    )
    
    Write-Host "Start SSH-Agent �^�X�N�𐳏�ɍ쐬���܂���"
}
catch {
    Write-Error "�G���[���������܂���: $_"
    Write-Error $_.Exception.Message
    Exit 1
}
