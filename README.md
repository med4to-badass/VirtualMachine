# VirtualMachine — 2 VMs com GPU Share

Infraestrutura KVM/QEMU para rodar **2 VMs compartilhando 1 GPU física** via SR-IOV ou NVIDIA MIG.

## Arquitetura

```
Host (Linux + KVM)
├── GPU física (SR-IOV)
│   ├── VF 0 → vm1
│   └── VF 1 → vm2
├── vm1  (8 GiB RAM, 4 vCPUs, 50 GB disco, GPU VF 1)
└── vm2  (8 GiB RAM, 4 vCPUs, 50 GB disco, GPU VF 2)
```

## Requisitos do servidor

| Item | Mínimo |
|------|--------|
| CPU | Intel VT-d **ou** AMD-Vi (IOMMU) |
| RAM | 20 GB (8×2 VMs + host) |
| GPU | NVIDIA A-series (SR-IOV/MIG) **ou** Intel Arc/Data Center |
| OS  | Ubuntu 22.04 / Debian 12 |
| Kernel | 5.15+ |

## Passo a passo

### 1. Instalar dependências
```bash
sudo bash scripts/00-install-deps.sh
```

### 2. Habilitar IOMMU (requer reboot)
```bash
sudo bash scripts/01-enable-iommu.sh
sudo reboot
```

### 3. Detectar GPU e grupos IOMMU
```bash
sudo bash scripts/02-detect-gpu.sh
```
Anote o endereço PCI da GPU (ex: `0000:01:00.0`).

### 4a. Configurar SR-IOV (GPU compartilhada — **recomendado**)
```bash
# Cria 2 Virtual Functions
sudo bash scripts/03-sriov-setup.sh 0000:01:00.0 2

# Vincula VFs ao vfio-pci
sudo bash scripts/04-bind-vfs-to-vfio.sh 0000:01:00.1 0000:01:00.2
```

### 4b. NVIDIA MIG (A100/H100/A30 — alternativa ao SR-IOV)
```bash
sudo bash configs/gpu/nvidia-mig.sh 0
```

### 4c. Passthrough exclusivo (1 GPU por VM — sem compartilhamento)
```bash
sudo bash scripts/03-vfio-bind.sh 0000:01:00.0   # para vm1
# vm2 precisaria de uma segunda GPU
```

### 5. Criar discos
```bash
sudo bash scripts/05-create-disks.sh 50G 50G
```

### 6. Ajustar XMLs das VMs
Edite `configs/vm1/vm1.xml` e `configs/vm2/vm2.xml`:
- `<source file=...>` → caminho do disco
- `<hostdev>` → endereço PCI real da VF (`function="0x1"` para VM1, `"0x2"` para VM2)

### 7. Registrar e iniciar VMs
```bash
sudo bash scripts/06-define-vms.sh
sudo bash scripts/07-start-vms.sh
```

### 8. SR-IOV persistente no boot
```bash
sudo bash scripts/install-systemd-service.sh
# Edite /etc/systemd/system/gpu-sriov.service com PCI_ADDR correto
```

## Estrutura do repositório

```
.
├── configs/
│   ├── gpu/
│   │   └── nvidia-mig.sh        # Setup NVIDIA MIG
│   ├── vm1/
│   │   └── vm1.xml              # Definição libvirt VM1
│   └── vm2/
│       └── vm2.xml              # Definição libvirt VM2
├── scripts/
│   ├── 00-install-deps.sh       # Instala KVM, QEMU, libvirt
│   ├── 01-enable-iommu.sh       # Habilita IOMMU no GRUB
│   ├── 02-detect-gpu.sh         # Lista GPUs e grupos IOMMU
│   ├── 03-vfio-bind.sh          # Passthrough exclusivo
│   ├── 03-sriov-setup.sh        # Cria VFs na GPU
│   ├── 04-bind-vfs-to-vfio.sh  # Vincula VFs ao vfio-pci
│   ├── 05-create-disks.sh       # Cria qcow2 para VM1/VM2
│   ├── 06-define-vms.sh         # Registra VMs no libvirt
│   ├── 07-start-vms.sh          # Inicia as VMs
│   └── install-systemd-service.sh
└── systemd/
    └── gpu-sriov.service        # Serviço de boot para SR-IOV
```

## Troubleshooting

**IOMMU não ativo após reboot**
```bash
dmesg | grep -e IOMMU -e DMAR
cat /proc/cmdline | grep iommu
```

**VF não aparece após sriov_numvfs**
- GPU pode não ter firmware SR-IOV habilitado (cheque BIOS/vBIOS)
- NVIDIA requer driver `nvidia-pf` no host antes de criar VFs

**VM não vê a GPU**
```bash
virsh dumpxml vm1 | grep hostdev
lspci -v -s <VF_ADDR>
dmesg | grep vfio
```
