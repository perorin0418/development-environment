[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$net = New-Object -ComObject WScript.Network
$drives = $net.EnumNetworkDrives()
$count = $drives.Count()
for ($i = 0; $i -lt $count; $i += 2) {
    Write-Output ($drives.Item($i) + "|" + $drives.Item($i + 1))
}
