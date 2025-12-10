# powershellrc

PowerShellのプロンプト・コマンド・ファンクション、SSH-Agentの起動、停止のスクリプト群

## 機能

- **プロンプトカスタマイズ**: Git情報を含む高機能プロンプト
- **SSH-Agent管理**: 起動・停止スクリプト
- **GroupPolicy管理**: Windows Home用のgpedit.bat
- **自動更新**: CI/CDによるGroupPolicyパッケージリストの自動更新と通知

## CI/CD 自動更新機能

毎週月曜日午前9時（JST）に自動実行され、GroupPolicyパッケージリストを更新します。

### 機能
- GroupPolicyパッケージリストの自動更新（`List.txt`）
- 更新があった場合、GitHub Issueで通知
- 追加・削除されたパッケージの詳細を自動レポート

### 手動実行
GitHubリポジトリの「Actions」タブから手動で実行することも可能です。

## SSH-Agent シャットダウン時の自動停止設定

### 方法1: 自動セットアップスクリプト（推奨、Pro/Home共通）

**管理者権限**でPowerShellを開き、以下を実行：

```powershell
# このリポジトリのディレクトリで実行
.\SetupShutdownScript.ps1
```

スクリプトが自動的に`SSHAgentKill.ps1`を検出して設定します。

**カスタムパスを指定する場合:**
```powershell
.\SetupShutdownScript.ps1 -ScriptPath "C:\Custom\Path\SSHAgentKill.ps1"
```

**削除する場合:**
```powershell
.\RemoveShutdownScript.ps1
```

**特徴:**
- Windows ProとHomeの両方で動作
- 自動的にスクリプトを検出
- レジストリベースで確実に動作
- 簡単にアンインストール可能

---

### 方法2: ローカルグループポリシーエディター（Windows Pro/Enterprise）

1. Win + R キーを押して「gpedit.msc」と入力し、ローカルグループポリシーエディターを開きます
2. コンピューターの構成 → Windows の設定 → スクリプト（スタートアップ/シャットダウン）
3. 右側の「シャットダウン」をダブルクリック
4. 「追加」をクリック
5. 「スクリプト名」に以下を入力：
   ```
   powershell.exe
   ```
6. 「スクリプトのパラメータ」に以下を入力：
   ```
   -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Path\To\SSHAgentKill.ps1"
   ```
   （パスは実際のスクリプトの場所に変更してください）
7. 「OK」をクリックして設定を保存

### 方法3: レジストリエディタ（手動設定、Pro/Home共通）

**管理者権限**でPowerShellを開き、以下を実行：

```powershell
# レジストリキーを作成（存在しない場合）
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Shutdown\0"
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force
    New-ItemProperty -Path $regPath -Name "GPO-ID" -Value "LocalGPO" -PropertyType String
    New-ItemProperty -Path $regPath -Name "SOM-ID" -Value "Local" -PropertyType String
    New-ItemProperty -Path $regPath -Name "FileSysPath" -Value "C:\Windows\System32\GroupPolicy\Machine" -PropertyType String
    New-ItemProperty -Path $regPath -Name "DisplayName" -Value "ローカル グループ ポリシー" -PropertyType String
    New-ItemProperty -Path $regPath -Name "GPOName" -Value "ローカル グループ ポリシー" -PropertyType String
}

# スクリプトの設定
$scriptPath = $regPath + "\0"
if (-not (Test-Path $scriptPath)) {
    New-Item -Path $scriptPath -Force
}
New-ItemProperty -Path $scriptPath -Name "Script" -Value "C:\Path\To\SSHAgentKill.ps1" -PropertyType String -Force
New-ItemProperty -Path $scriptPath -Name "Parameters" -Value "" -PropertyType String -Force
New-ItemProperty -Path $scriptPath -Name "IsPowershell" -Value 1 -PropertyType DWord -Force
New-ItemProperty -Path $scriptPath -Name "ExecTime" -Value 0 -PropertyType QWord -Force

Write-Host "シャットダウンスクリプトを登録しました。再起動後に有効になります。"
```

**注**: スクリプトパスを実際の`SSHAgentKill.ps1`の場所に変更してください。

### 方法4: タスクスケジューラ（代替手段、Pro/Home共通）

PowerShellで以下を**管理者権限**で実行：

```powershell
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"C:\Path\To\SSHAgentKill.ps1`""
$trigger = New-ScheduledTaskTrigger -AtLogon
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName "SSH-Agent-Shutdown" -Action $action -Trigger $trigger -Settings $settings -Principal $principal
```

**注**: ログオフ時に実行されます。完全なシャットダウン前実行には方法1、2、または3が推奨されます。

### 方法5: gpedit.bat（Windows Home用）

Windows Homeエディションでグループポリシーエディターを使用する場合：

1. **管理者権限**でgpedit.batを実行
2. グループポリシーエディターがインストールされます
3. その後、方法1の手順に従ってください

## ファイル構成

| ファイル | 説明 |
|---------|------|
| `profile.ps1` | PowerShellプロファイルのメインファイル |
| `prompt.ps1` | カスタムプロンプト設定（Git情報表示など） |
| `aliases.ps1` | コマンドエイリアス定義 |
| `function.ps1` | カスタム関数定義 |
| `SSHAgentStart.ps1` | SSH-Agent起動スクリプト |
| `SSHAgentKill.ps1` | SSH-Agent停止スクリプト |
| `SetupShutdownScript.ps1` | シャットダウンスクリプト自動セットアップ（Pro/Home共通） |
| `RemoveShutdownScript.ps1` | シャットダウンスクリプト削除ツール |
| `gpedit.bat` | グループポリシーエディターインストーラー（Windows Home用） |
| `bluetoothConnecting.ps1` | Bluetooth接続管理スクリプト |
| `registerAction.ps1` | アクション登録スクリプト |
| `List.txt` | GroupPolicyパッケージリスト（自動更新） |

## セットアップ

1. リポジトリをクローン：
   ```powershell
   git clone <repository-url> C:\Path\To\powershellrc
   ```

2. PowerShellプロファイルから読み込む：
   ```powershell
   # $PROFILE を編集
   notepad $PROFILE

   # 以下を追加
   . C:\Path\To\powershellrc\profile.ps1
   ```

3. SSH-Agent自動起動を有効化（オプション）：
   ```powershell
   # シャットダウン時の自動停止を設定（管理者権限）
   .\SetupShutdownScript.ps1

   # プロファイルにSSH-Agent起動を追加
   # $PROFILE に以下を追記
   . C:\Path\To\powershellrc\SSHAgentStart.ps1
   ```

## ライセンス

MITライセンス（詳細は各ファイルを参照）
