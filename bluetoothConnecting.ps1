# 定期的にBluetoothデバイスをチェックするスクリプト
$deviceName = "YYK-520"
$volumeLevel = 40

function Set-AudioOutputAndVolume {
    # 出力デバイスを変更
    $defaultAudioDevice = Get-AudioDevice -List | Where-Object { $_.Name -like "*$deviceName*" }
    
    if ($defaultAudioDevice) {
        Set-AudioDevice -Index $defaultAudioDevice.Index
        Write-Host "出力デバイスを $deviceName に変更しました。"
        # 音量を設定
        Set-Volume -Level $volumeLevel
        Write-Host "音量を $volumeLevel に設定しました。"
    }
}

# Bluetoothデバイスが接続されているかを確認
function IsBluetoothDeviceConnected {
    $devices = Get-PnpDevice | Where-Object { $_.FriendlyName -like "*$deviceName*" -and $_.Status -eq "OK" }
    return $devices.Count -gt 0
}

# メインループ
while ($true) {
    if (IsBluetoothDeviceConnected) {
        Set-AudioOutputAndVolume
    }
    # 10秒ごとにチェック
    Start-Sleep -Seconds 10
}
