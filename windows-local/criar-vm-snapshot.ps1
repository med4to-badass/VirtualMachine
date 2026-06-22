param(
    [string]$VMName = "vm1",
    [string]$Dir = "C:\Users\AuraProject\VirtualMachines",
    [string]$ISO = "C:\Users\AuraProject\Documentos\Windows.iso",
    [int]$RamMB = 6144,
    [int]$DiskGB = 60,
    [string]$SnapshotName = "Windows11-Limpo"
)

$vmware     = "C:\Program Files\VMware\VMware Workstation\vmware.exe"
$vdisk      = "C:\Program Files\VMware\VMware Workstation\vmware-vdiskmanager.exe"
$vmrun      = "C:\Program Files\VMware\VMware Workstation\vmrun.exe"
$vmFolder   = "$Dir\$VMName"
$vmx        = "$vmFolder\$VMName.vmx"
$vmdk       = "$vmFolder\$VMName.vmdk"

Write-Host "=== Criando VM: $VMName ===" -ForegroundColor Cyan

# Limpa se existir
if (Test-Path $vmFolder) {
    & $vmrun stop "$vmx" hard 2>$null
    Remove-Item $vmFolder -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $vmFolder | Out-Null

# Cria disco virtual
Write-Host "Criando disco $($DiskGB)GB..."
& $vdisk -c -s "${DiskGB}GB" -a lsilogic -t 0 "$vmdk"

# Cria VMX
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
mks.enable3d = "TRUE"
svga.graphicsMemoryKB = "8388608"
sata0.present = "TRUE"
sata0:0.present = "TRUE"
sata0:0.fileName = "$VMName.vmdk"
sata0:1.present = "TRUE"
sata0:1.fileName = "$($ISO -replace '\\','\\')"
sata0:1.deviceType = "cdrom-image"
ethernet0.present = "TRUE"
ethernet0.connectionType = "nat"
ethernet0.virtualDev = "e1000e"
usb.present = "TRUE"
"@ | Set-Content $vmx

Write-Host "VM criada. Abrindo para instalacao do Windows..." -ForegroundColor Yellow
Start-Process $vmware -ArgumentList "`"$vmx`""

Write-Host ""
Write-Host "INSTRUCOES:" -ForegroundColor White
Write-Host "1. Instale o Windows normalmente na janela que abriu"
Write-Host "2. Quando terminar, DESLIGUE a VM de dentro do Windows"
Write-Host "3. Volte aqui e pressione ENTER para criar o snapshot"
Read-Host "Pressione ENTER quando a instalacao estiver concluida e a VM desligada"

Write-Host "Criando snapshot '$SnapshotName'..." -ForegroundColor Cyan
& $vmrun snapshot "$vmx" "$SnapshotName"

Write-Host ""
Write-Host "Snapshots disponiveis:" -ForegroundColor White
& $vmrun listSnapshots "$vmx"

Write-Host ""
Write-Host "Pronto! Para restaurar o estado limpo:" -ForegroundColor Green
Write-Host "  & `"$vmrun`" revertToSnapshot `"$vmx`" `"$SnapshotName`""
