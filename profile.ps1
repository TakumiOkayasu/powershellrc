$script = @("$Home\psrc\aliases.ps1", "$Home\psrc\function.ps1", "$Home\psrc\prompt.ps1")

foreach ($s in $script) {
  if (Test-Path $s) {
    . $s
  }
}
