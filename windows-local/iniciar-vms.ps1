# Inicia vm1 e vm2 simultaneamente
$vboxManage = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"

Write-Host "Iniciando vm1..." -ForegroundColor Cyan
Start-Process $vboxManage -ArgumentList "startvm vm1 --type gui"

Start-Sleep -Seconds 2

Write-Host "Iniciando vm2..." -ForegroundColor Cyan
Start-Process $vboxManage -ArgumentList "startvm vm2 --type gui"

Write-Host "VMs iniciadas!" -ForegroundColor Green
