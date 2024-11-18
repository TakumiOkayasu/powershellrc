$script = @("$PWD\aliases.ps1", "$PWD\function.ps1", "$PWD\prompt.ps1")

# プロファイルディレクトリの確認
$PROFILE | Split-Path -Parent

# ディレクトリが存在しない場合は作成
if (!(Test-Path -Path ($PROFILE | Split-Path -Parent))) {
  New-Item -ItemType Directory -Path ($PROFILE | Split-Path -Parent) -Force
}

# シンボリックリンクが存在しない場合のみ作成
if (!(Test-Path $PROFILE)) {
  $profileName = Split-Path $PROFILE -Leaf
  New-Item -ItemType SymbolicLink -Path $PROFILE -Target (Join-Path $PWD $profileName) -Force
}

foreach ($s in $script) {
  if (Test-Path $s) {
    . $s
  }
}

Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
