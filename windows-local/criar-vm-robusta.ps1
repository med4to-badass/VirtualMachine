<#
.SYNOPSIS
    Cria uma VM Windows 11 no VMware Workstation a prova de falhas.
    Valida ambiente, corrige conflitos conhecidos, gera VMX limpo e
    faz rollback automatico se algo falhar.

.EXEMPLO
    .\criar-vm-robusta.ps1
    .\criar-vm-robusta.ps1 -VMName vm2 -RamMB 8192
#>

param(
    [string]$VMName       = "vm1",
    [string]$Dir          = "C:\Users\AuraProject\VirtualMachines",
    [string]$ISO          = "C:\Users\AuraProject\Documentos\Windows.iso",
    [int]   $RamMB        = 6144,
    [int]   $DiskGB       = 60,
    [int]   $CPUs         = 2,
    [string]$SnapshotName = "Windows11-Limpo",
    [switch]$NoSnapshot
)

$ErrorActionPreference = "Stop"
$rollbackNeeded = $false
$vmFolder = Join-Path $Dir $VMName

function Etapa { param($m) Write-Host "`n=== $m ===" -ForegroundColor Cyan }
function Ok    { param($m) Write-Host "[OK]    $m" -ForegroundColor Green }
function Aviso { param($m) Write-Host "[AVISO] $m" -ForegroundColor Yellow }
function Falha { param($m) Write-Host "[ERRO]  $m" -ForegroundColor Red }

function Rollback {
    param($motivo)
    Falha $motivo
    if ($rollbackNeeded -and (Test-Path $vmFolder)) {
        Aviso "Revertendo: removendo $vmFolder"
        & $script:vmrun stop "$script:vmx" hard 2>$null | Out-Null
        Start-Sleep -Seconds 2
        Remove-Item $vmFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
    exit 1
}

# ─────────────────────────────────────────────────────────────────────────────
# 1. Localiza binarios do VMware (testa varios caminhos)
# ─────────────────────────────────────────────────────────────────────────────
Etapa "Verificando instalacao do VMware"

$basePaths = @(
    "C:\Program Files\VMware\VMware Workstation",
    "C:\Program Files (x86)\VMware\VMware Workstation"
)
$vmwareBase = $basePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $vmwareBase) {
    Falha "VMware Workstation nao encontrado."
    Write-Host "Baixe em: https://www.vmware.com/products/desktop-hypervisor/workstation-and-fusion" -ForegroundColor White
    exit 1
}

$vmware = Join-Path $vmwareBase "vmware.exe"
$vdisk  = Join-Path $vmwareBase "vmware-vdiskmanager.exe"
$vmrun  = Join-Path $vmwareBase "vmrun.exe"
foreach ($exe in @($vmware, $vdisk, $vmrun)) {
    if (-not (Test-Path $exe)) { Falha "Binario ausente: $exe"; exit 1 }
}
Ok "VMware em: $vmwareBase"

# ─────────────────────────────────────────────────────────────────────────────
# 2. Verifica conflito com Hyper-V (causa raiz de muitos erros de boot)
# ─────────────────────────────────────────────────────────────────────────────
Etapa "Verificando conflito com Hyper-V"

$hvLaunch = (& bcdedit /enum "{current}" | Select-String "hypervisorlaunchtype").ToString()
if ($hvLaunch -match "Auto") {
    Aviso "Hyper-V esta ATIVO - isso impede o VMware de usar virtualizacao."
    Write-Host "Para corrigir, rode como Admin e REINICIE:" -ForegroundColor White
    Write-Host "  bcdedit /set hypervisorlaunchtype off" -ForegroundColor Gray
    $resp = Read-Host "Deseja desativar agora? (S/N)"
    if ($resp -match '^[sS]') {
        & bcdedit /set hypervisorlaunchtype off | Out-Null
        Aviso "Hyper-V desativado. REINICIE O PC e rode este script de novo."
        exit 0
    } else {
        Aviso "Continuando, mas a VM pode falhar ao iniciar."
    }
} else {
    Ok "Hyper-V desativado (compativel com VMware)"
}

# ─────────────────────────────────────────────────────────────────────────────
# 3. Valida ISO
# ─────────────────────────────────────────────────────────────────────────────
Etapa "Verificando ISO"
if (-not (Test-Path $ISO)) { Falha "ISO nao encontrado: $ISO"; exit 1 }
$isoSize = (Get-Item $ISO).Length / 1GB
if ($isoSize -lt 3) { Aviso "ISO parece pequeno ($([math]::Round($isoSize,2)) GB) - pode estar corrompido." }
Ok "ISO: $ISO ($([math]::Round($isoSize,2)) GB)"

# ─────────────────────────────────────────────────────────────────────────────
# 4. Valida espaco em disco
# ─────────────────────────────────────────────────────────────────────────────
Etapa "Verificando espaco em disco"
$drive = (Split-Path $Dir -Qualifier)
$freeGB = (Get-PSDrive ($drive -replace ':','')).Free / 1GB
if ($freeGB -lt ($DiskGB + 5)) {
    Falha "Espaco insuficiente em $drive ($([math]::Round($freeGB,1)) GB livres, precisa de $($DiskGB+5) GB)"
    exit 1
}
Ok "Espaco livre: $([math]::Round($freeGB,1)) GB"

# ─────────────────────────────────────────────────────────────────────────────
# 5. Limpa instalacao anterior
# ─────────────────────────────────────────────────────────────────────────────
Etapa "Preparando pasta da VM"
$vmx  = Join-Path $vmFolder "$VMName.vmx"
$vmdk = Join-Path $vmFolder "$VMName.vmdk"

if (Test-Path $vmFolder) {
    Aviso "VM '$VMName' ja existe - removendo..."
    & $vmrun stop "$vmx" hard 2>$null | Out-Null
    Start-Sleep -Seconds 2
    Remove-Item $vmFolder -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $vmFolder | Out-Null
$rollbackNeeded = $true
Ok "Pasta criada: $vmFolder"

# ─────────────────────────────────────────────────────────────────────────────
# 6. Cria disco virtual
# ─────────────────────────────────────────────────────────────────────────────
Etapa "Criando disco virtual ${DiskGB}GB"
& $vdisk -c -s "${DiskGB}GB" -a lsilogic -t 0 "$vmdk" | Out-Null
if (-not (Test-Path $vmdk)) { Rollback "Falha ao criar disco virtual." }
Ok "Disco criado: $vmdk"

# ─────────────────────────────────────────────────────────────────────────────
# 7. Gera VMX com slots PCI fixos (evita 'No PCIe slot available')
# ─────────────────────────────────────────────────────────────────────────────
Etapa "Gerando arquivo de configuracao (VMX)"
$isoEsc = $ISO -replace '\\','\\'

$vmxContent = @"
.encoding = "UTF-8"
config.version = "8"
virtualHW.version = "19"
displayName = "$VMName"
guestOS = "windows11-64"
memsize = "$RamMB"
numvcpus = "$CPUs"
cpuid.coresPerSocket = "$CPUs"
firmware = "efi"
uefi.secureBoot.enabled = "FALSE"
vhv.enable = "TRUE"

# Bridges PCI (necessarias para alocacao de slots)
pciBridge0.present = "TRUE"
pciBridge4.present = "TRUE"
pciBridge4.virtualDev = "pcieRootPort"
pciBridge4.functions = "8"
pciBridge5.present = "TRUE"
pciBridge5.virtualDev = "pcieRootPort"
pciBridge5.functions = "8"
pciBridge6.present = "TRUE"
pciBridge6.virtualDev = "pcieRootPort"
pciBridge6.functions = "8"
pciBridge7.present = "TRUE"
pciBridge7.virtualDev = "pcieRootPort"
pciBridge7.functions = "8"

# Grafico / GPU 3D compartilhada
mks.enable3d = "TRUE"
svga.graphicsMemoryKB = "8388608"
svga.vramSize = "268435456"

# Armazenamento SATA (mais compativel que SCSI no Win11)
sata0.present = "TRUE"
sata0:0.present = "TRUE"
sata0:0.fileName = "$VMName.vmdk"
sata0:0.deviceType = "disk"
sata0:1.present = "TRUE"
sata0:1.fileName = "$isoEsc"
sata0:1.deviceType = "cdrom-image"

# Rede (slot PCI explicito evita erro de boot)
ethernet0.present = "TRUE"
ethernet0.connectionType = "nat"
ethernet0.virtualDev = "e1000e"
ethernet0.pciSlotNumber = "32"
ethernet0.addressType = "generated"
ethernet0.wakeOnPcktRcv = "FALSE"

# USB
usb.present = "TRUE"
ehci.present = "TRUE"

# Estabilidade
sound.present = "FALSE"
tools.syncTime = "TRUE"
cleanShutdown = "TRUE"
"@

Set-Content -Path $vmx -Value $vmxContent -Encoding ASCII
Ok "VMX gerado: $vmx"

# ─────────────────────────────────────────────────────────────────────────────
# 8. Inicia a VM
# ─────────────────────────────────────────────────────────────────────────────
Etapa "Iniciando VM no VMware"
try {
    Start-Process $vmware -ArgumentList "`"$vmx`""
    Ok "VMware aberto com '$VMName'"
} catch {
    Rollback "Falha ao abrir o VMware: $_"
}

Write-Host ""
Write-Host "──────────────────────────────────────────────" -ForegroundColor White
Write-Host " INSTRUCOES" -ForegroundColor White
Write-Host "──────────────────────────────────────────────" -ForegroundColor White
Write-Host " 1. Instale o Windows normalmente na janela"
Write-Host " 2. Ao terminar, DESLIGUE a VM pelo Windows"
Write-Host " 3. Volte aqui e pressione ENTER"
Write-Host ""

if ($NoSnapshot) {
    Ok "VM criada (modo sem snapshot). Concluido."
    exit 0
}

Read-Host "Pressione ENTER quando a VM estiver desligada para criar o snapshot"

# ─────────────────────────────────────────────────────────────────────────────
# 9. Cria snapshot do estado limpo
# ─────────────────────────────────────────────────────────────────────────────
Etapa "Criando snapshot '$SnapshotName'"

# Garante que a VM esta parada antes do snapshot
$state = (& $vmrun list) -join " "
if ($state -match [regex]::Escape($vmx)) {
    Aviso "VM ainda rodando - suspendendo..."
    & $vmrun stop "$vmx" soft 2>$null | Out-Null
    Start-Sleep -Seconds 5
}

& $vmrun snapshot "$vmx" "$SnapshotName"
$snaps = & $vmrun listSnapshots "$vmx"
if ($snaps -match [regex]::Escape($SnapshotName)) {
    Ok "Snapshot '$SnapshotName' criado"
} else {
    Aviso "Snapshot pode nao ter sido criado. Verifique manualmente."
}

Write-Host ""
Write-Host "Snapshots disponiveis:" -ForegroundColor White
& $vmrun listSnapshots "$vmx"

# ─────────────────────────────────────────────────────────────────────────────
# 10. Resumo
# ─────────────────────────────────────────────────────────────────────────────
Etapa "Concluido"
Write-Host "VM:       $VMName" -ForegroundColor Green
Write-Host "Pasta:    $vmFolder" -ForegroundColor Gray
Write-Host "Snapshot: $SnapshotName" -ForegroundColor Gray
Write-Host ""
Write-Host "Restaurar estado limpo:" -ForegroundColor Yellow
Write-Host "  & `"$vmrun`" revertToSnapshot `"$vmx`" `"$SnapshotName`""
Write-Host "Criar vm2 identica:" -ForegroundColor Yellow
Write-Host "  .\criar-vm-robusta.ps1 -VMName vm2"
