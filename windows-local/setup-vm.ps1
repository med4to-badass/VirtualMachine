# Setup automatico de 2 VMs Windows com GPU Share no VirtualBox
# Execute como Administrador no PowerShell
# Uso: .\setup-vm.ps1 -IsoPath "C:\Users\AuraProject\Documentos\Windows.iso"

param(
    [Parameter(Mandatory=$true)]
    [string]$IsoPath,

    [string]$VMFolder = "$env:USERPROFILE\VirtualMachines",
    [int]$DiskSizeGB = 60,
    [int]$RamMB = 6144,
    [int]$CPUs = 2
)

$ErrorActionPreference = "Stop"

function Write-Step { param($msg) Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "[AVISO] $msg" -ForegroundColor Yellow }

# ── 1. Verifica ISO ──────────────────────────────────────────────────────────
Write-Step "Verificando ISO"
if (-not (Test-Path $IsoPath)) {
    Write-Error "ISO nao encontrado: $IsoPath"
    exit 1
}
Write-OK "ISO encontrado: $IsoPath"

# ── 2. Instala VirtualBox se necessario ──────────────────────────────────────
Write-Step "Verificando VirtualBox"
$vboxManage = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"

if (-not (Test-Path $vboxManage)) {
    Write-Warn "VirtualBox nao encontrado. Baixando e instalando..."

    $vboxInstaller = "$env:TEMP\VBoxInstaller.exe"
    $vboxUrl = "https://download.virtualbox.org/virtualbox/7.1.4/VirtualBox-7.1.4-165100-Win.exe"

    Write-Host "Baixando VirtualBox..."
    Invoke-WebRequest -Uri $vboxUrl -OutFile $vboxInstaller -UseBasicParsing

    Write-Host "Instalando (silencioso)..."
    Start-Process -FilePath $vboxInstaller -ArgumentList "--silent" -Wait

    if (-not (Test-Path $vboxManage)) {
        Write-Error "Instalacao do VirtualBox falhou. Instale manualmente: https://www.virtualbox.org"
        exit 1
    }
    Write-OK "VirtualBox instalado"
} else {
    $ver = & $vboxManage --version 2>&1
    Write-OK "VirtualBox $ver ja instalado"
}

# ── 3. Cria pasta das VMs ────────────────────────────────────────────────────
Write-Step "Criando pasta das VMs"
New-Item -ItemType Directory -Force -Path $VMFolder | Out-Null
Write-OK "Pasta: $VMFolder"

# ── 4. Funcao para criar uma VM ──────────────────────────────────────────────
function New-WindowsVM {
    param([string]$Name, [string]$DiskPath)

    Write-Step "Criando $Name"

    # Remove VM anterior com mesmo nome se existir
    $existing = & $vboxManage list vms 2>&1 | Select-String $Name
    if ($existing) {
        Write-Warn "$Name ja existe — removendo..."
        & $vboxManage unregistervm $Name --delete 2>&1 | Out-Null
    }

    # Cria VM
    & $vboxManage createvm --name $Name --ostype Windows11_64 --register --basefolder $VMFolder

    # Configura hardware
    & $vboxManage modifyvm $Name `
        --memory $RamMB `
        --cpus $CPUs `
        --vram 128 `
        --graphicscontroller vmsvga `
        --accelerate3d on `
        --firmware efi `
        --boot1 dvd --boot2 disk --boot3 none `
        --nic1 nat `
        --nictype1 virtio `
        --audio-driver default `
        --usb-ehci on `
        --mouse usbtablet

    # Cria disco virtual
    & $vboxManage createmedium disk `
        --filename $DiskPath `
        --size ($DiskSizeGB * 1024) `
        --format VDI

    # Adiciona controladora SATA
    & $vboxManage storagectl $Name --name "SATA" --add sata --controller IntelAhci --portcount 2

    # Conecta disco
    & $vboxManage storageattach $Name `
        --storagectl "SATA" --port 0 --device 0 `
        --type hdd --medium $DiskPath

    # Conecta ISO
    & $vboxManage storageattach $Name `
        --storagectl "SATA" --port 1 --device 0 `
        --type dvddrive --medium $IsoPath

    Write-OK "$Name criada"
}

# ── 5. Cria as duas VMs ──────────────────────────────────────────────────────
$disk1 = "$VMFolder\vm1-windows.vdi"
$disk2 = "$VMFolder\vm2-windows.vdi"

New-WindowsVM -Name "vm1" -DiskPath $disk1
New-WindowsVM -Name "vm2" -DiskPath $disk2

# ── 6. Configura GPU Share (passthrough 3D compartilhado via VMSVGA) ─────────
Write-Step "Configurando GPU Share"

# Habilita aceleracao 3D em ambas as VMs (compartilham a GPU host via VMSVGA)
foreach ($vm in @("vm1", "vm2")) {
    & $vboxManage modifyvm $vm --accelerate3d on --vram 128
    Write-OK "$vm`: GPU share via VMSVGA habilitado"
}

# ── 7. Cria atalhos na Area de Trabalho ─────────────────────────────────────
Write-Step "Criando atalhos"
$desktop = [Environment]::GetFolderPath("Desktop")

foreach ($vm in @("vm1", "vm2")) {
    $shortcut = "$desktop\$vm.lnk"
    $wsh = New-Object -ComObject WScript.Shell
    $lnk = $wsh.CreateShortcut($shortcut)
    $lnk.TargetPath = $vboxManage -replace "VBoxManage.exe","VirtualBox.exe"
    $lnk.Arguments = "--startvm $vm"
    $lnk.IconLocation = $vboxManage -replace "VBoxManage.exe","VirtualBox.exe"
    $lnk.Save()
    Write-OK "Atalho criado: $shortcut"
}

# ── 8. Resumo ────────────────────────────────────────────────────────────────
Write-Step "Concluido!"
Write-Host ""
Write-Host "VMs criadas:" -ForegroundColor White
Write-Host "  vm1 -> $disk1" -ForegroundColor Gray
Write-Host "  vm2 -> $disk2" -ForegroundColor Gray
Write-Host ""
Write-Host "Para iniciar:" -ForegroundColor White
Write-Host '  & "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" startvm vm1' -ForegroundColor Gray
Write-Host '  & "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" startvm vm2' -ForegroundColor Gray
Write-Host ""
Write-Host "Ou use os atalhos na Area de Trabalho." -ForegroundColor Green
Write-Host ""
Write-Host "A janela do Windows vai abrir para instalacao." -ForegroundColor Yellow
Write-Host "Repita o processo de instalacao em vm1 e vm2 separadamente." -ForegroundColor Yellow
