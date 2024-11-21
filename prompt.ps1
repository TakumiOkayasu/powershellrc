Import-Module -Name Terminal-Icons
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

function prompt {
  $branch = ""

  if (git branch) {
    (git branch | select-string "^\*").ToString() | set-variable -name branch
    $branch = $branch.trim() -replace "^\* *", ""
  }

  $isRoot = (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
  $color  = if ($isRoot) {"Red"} else {"Green"}
  $marker = if ($isRoot) {"#"}   else {"$"}

  Write-Host "$env:USERNAME " -ForegroundColor $color -NoNewline
  Write-Host "$pwd " -ForegroundColor DarkCyan -NoNewline

  if ($branch -ne "") {
    Write-Host(" (") -NoNewline -ForegroundColor Yellow
    Write-Host($branch) -NoNewline -ForegroundColor Yellow
    Write-Host(")") -NoNewline -ForegroundColor Yellow
  }

  $marker_newline = "`n", $marker -join ''

  Write-Host $marker_newline -ForegroundColor $color -NoNewline

  return " "
}

