param(
    [Parameter(Mandatory=$true)]
    [string]$IsoPath,
    [string]$VMFolder = "$env:USERPROFILE\VirtualMachines",
    [int]$DiskSizeGB = 60,
    [int]$RamMB = 6144,
    [int]$CPUs = 2
)

$ErrorActionPreference = "Stop"
$vboxManage = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"

Write-Host "=== Verificando ISO ===" -ForegroundColor Cyan
if (-not (Test-Path $IsoPath)) { Write-Error "ISO nao encontrado: $IsoPath"; exit 1 }
Write-Host "[OK] ISO: $IsoPath" -ForegroundColor Green

Write-Host "=== Verificando VirtualBox ===" -ForegroundColor Cyan
if (-not (Test-Path $vboxManage)) {
    Write-Host "Baixando VirtualBox..." -ForegroundColor Yellow
    $installer = "$env:TEMP\VBoxInstaller.exe"
    Invoke-WebRequest -Uri "https://download.virtualbox.org/virtualbox/7.1.4/VirtualBox-7.1.4-165100-Win.exe" -OutFile $installer -UseBasicParsing
    Start-Process -FilePath $installer -ArgumentList "--silent" -Wait
    if (-not (Test-Path $vboxManage)) { Write-Error "Falha ao instalar VirtualBox"; exit 1 }
    Write-Host "[OK] VirtualBox instalado" -ForegroundColor Green
} else {
    Write-Host "[OK] VirtualBox ja instalado" -ForegroundColor Green
}

New-Item -ItemType Directory -Force -Path $VMFolder | Out-Null

function CriarVM {
    param([string]$Nome, [string]$DiskPath)

    Write-Host "=== Criando $Nome ===" -ForegroundColor Cyan

    $existe = & $vboxManage list vms 2>&1 | Select-String $Nome
    if ($existe) {
        Write-Host "Removendo VM antiga..." -ForegroundColor Yellow
        & $vboxManage unregistervm $Nome --delete 2>&1 | Out-Null
    }

    & $vboxManage createvm --name $Nome --ostype Windows11_64 --register --basefolder $VMFolder
    & $vboxManage modifyvm $Nome --memory $RamMB --cpus $CPUs --vram 128 --graphicscontroller vmsvga --accelerate3d on --firmware efi --boot1 dvd --boot2 disk --boot3 none --nic1 nat --nictype1 virtio --mouse usbtablet
    & $vboxManage createmedium disk --filename $DiskPath --size ($DiskSizeGB * 1024) --format VDI
    & $vboxManage storagectl $Nome --name "SATA" --add sata --controller IntelAhci --portcount 2
    & $vboxManage storageattach $Nome --storagectl "SATA" --port 0 --device 0 --type hdd --medium $DiskPath
    & $vboxManage storageattach $Nome --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium $IsoPath

    Write-Host "[OK] $Nome criada" -ForegroundColor Green
}

CriarVM -Nome "vm1" -DiskPath "$VMFolder\vm1.vdi"
CriarVM -Nome "vm2" -DiskPath "$VMFolder\vm2.vdi"

Write-Host "=== Iniciando vm1 ===" -ForegroundColor Cyan
& $vboxManage startvm vm1 --type gui

Write-Host ""
Write-Host "Pronto! vm1 abriu para instalacao do Windows." -ForegroundColor Green
Write-Host "Quando terminar de instalar, rode:" -ForegroundColor Yellow
Write-Host '  & "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" startvm vm2 --type gui' -ForegroundColor Gray
