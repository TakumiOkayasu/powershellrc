# Stop ssh-agent service if running
if (Get-Service -Name "ssh-agent" -ErrorAction SilentlyContinue) {
    Stop-Service -Name "ssh-agent"
}
