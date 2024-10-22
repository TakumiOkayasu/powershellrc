# Start ssh-agent if it's not already running
if (-not (Get-Service -Name "ssh-agent" -ErrorAction SilentlyContinue)) {
    Start-Service -Name "ssh-agent"
}

# Add your SSH key to the agent
ssh-add "$HOME\.ssh\github"
