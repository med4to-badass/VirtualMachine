param(
    [string]$VMName = "vm1",
    [string]$Dir = "C:\Users\AuraProject\VirtualMachines",
    [string]$ISO = "C:\Users\AuraProject\Documentos\Windows.iso",
    [int]$RamMB = 6144,
    [int]$DiskGB = 60,
    [string]$SnapshotName = "Windows11-Limpo"
)

$vmware  = "C:\Program Files\VMware\VMware Workstation\vmware.exe"
$vdisk   = "C:\Program Files\VMware\VMware Workstation\vmware-vdiskmanager.exe"
$vmrun   = "C:\Program Files\VMware\VMware Workstation\vmrun.exe"
$vmFolder = "$Dir\$VMName"
$vmx      = "$vmFolder\$VMName.vmx"
$vmdk     = "$vmFolder\$VMName.vmdk"

# ── Valida pre-requisitos ─────────────────────────────────────────────────────
foreach ($exe in @($vmware, $vdisk, $vmrun)) {
    if (-not (Test-Path $exe)) {
        Write-Host "[ERRO] Nao encontrado: $exe" -ForegroundColor Red
        exit 1
    }
}
if (-not (Test-Path $ISO)) {
    Write-Host "[ERRO] ISO nao encontrado: $ISO" -ForegroundColor Red
    exit 1
}

Write-Host "=== Criando VM: $VMName ===" -ForegroundColor Cyan

# ── Limpa instalacao anterior ─────────────────────────────────────────────────
if (Test-Path $vmFolder) {
    Write-Host "Removendo VM anterior..." -ForegroundColor Yellow
    & $vmrun stop "$vmx" hard 2>$null
    Start-Sleep -Seconds 2
    Remove-Item $vmFolder -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $vmFolder | Out-Null

# ── Cria disco virtual ────────────────────────────────────────────────────────
Write-Host "Criando disco ${DiskGB}GB..."
& $vdisk -c -s "${DiskGB}GB" -a lsilogic -t 0 "$vmdk"
if (-not (Test-Path $vmdk)) {
    Write-Host "[ERRO] Falha ao criar disco virtual." -ForegroundColor Red
    exit 1
}

# ── Detecta slot PCI livre automaticamente ────────────────────────────────────
# Slots reservados pelo VMware: 0=host bridge, 7=IDE, 15=PCI bridge, 17=SATA
# Usamos 32 para ethernet (seguro e padrao VMware)
$ethSlot   = 32
$sataSlot  = 24
$usbSlot   = 33
$svgaSlot  = 15

# ── Gera VMX ─────────────────────────────────────────────────────────────────
$isoEscaped = $ISO -replace '\\','\\'

@"
.encoding = "UTF-8"
config.version = "8"
virtualHW.version = "21"
displayName = "$VMName"
guestOS = "windows11-64"
memsize = "$RamMB"
numvcpus = "2"
cpuid.coresPerSocket = "2"
firmware = "efi"
uefi.secureBoot.enabled = "FALSE"

# Grafico / GPU
mks.enable3d = "TRUE"
svga.graphicsMemoryKB = "8388608"
svga.vramSize = "268435456"
pciBridge0.present = "TRUE"
pciBridge4.present = "TRUE"
pciBridge4.virtualDev = "pcieRootPort"
pciBridge4.functions = "8"

# Armazenamento SATA
sata0.present = "TRUE"
sata0.pciSlotNumber = "$sataSlot"
sata0:0.present = "TRUE"
sata0:0.fileName = "$VMName.vmdk"
sata0:0.deviceType = "disk"
sata0:1.present = "TRUE"
sata0:1.fileName = "$isoEscaped"
sata0:1.deviceType = "cdrom-image"

# Rede
ethernet0.present = "TRUE"
ethernet0.connectionType = "nat"
ethernet0.virtualDev = "e1000e"
ethernet0.pciSlotNumber = "$ethSlot"
ethernet0.addressType = "generated"
ethernet0.wakeOnPcktRcv = "FALSE"

# USB
usb.present = "TRUE"
usb.pciSlotNumber = "$usbSlot"
ehci.present = "TRUE"
ehci.pciSlotNumber = "34"

# Audio desativado (evita conflitos)
sound.present = "FALSE"

# Misc
tools.syncTime = "TRUE"
cleanShutdown = "TRUE"
softPowerOff = "FALSE"
"@ | Set-Content $vmx -Encoding UTF8

Write-Host "[OK] VMX gerado em: $vmx" -ForegroundColor Green

# ── Inicia VM ─────────────────────────────────────────────────────────────────
Write-Host "Abrindo VMware para instalacao do Windows..." -ForegroundColor Yellow
Start-Process $vmware -ArgumentList "`"$vmx`""

Write-Host ""
Write-Host "INSTRUCOES:" -ForegroundColor White
Write-Host "  1. Instale o Windows normalmente"
Write-Host "  2. Quando terminar, DESLIGUE a VM de dentro do Windows"
Write-Host "  3. Volte aqui e pressione ENTER"
Write-Host ""
Read-Host "Pressione ENTER quando a VM estiver desligada"

# ── Cria snapshot ─────────────────────────────────────────────────────────────
Write-Host "Criando snapshot '$SnapshotName'..." -ForegroundColor Cyan
& $vmrun snapshot "$vmx" "$SnapshotName"

Write-Host ""
Write-Host "Snapshots:" -ForegroundColor White
& $vmrun listSnapshots "$vmx"

Write-Host ""
Write-Host "VM pronta!" -ForegroundColor Green
Write-Host "Para restaurar estado limpo:" -ForegroundColor Yellow
Write-Host "  & `"$vmrun`" revertToSnapshot `"$vmx`" `"$SnapshotName`""
Write-Host "Para criar vm2 igual:"
Write-Host "  .\criar-vm-snapshot.ps1 -VMName vm2"
