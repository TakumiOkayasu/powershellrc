$scripts = @("$PWD\aliases.ps1", "$PWD\function.ps1", "$PWD\prompt.ps1")

foreach ($s in $scripts) {
    if (Test-Path $s) {
        . $s
    }
}
