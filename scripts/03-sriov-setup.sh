#!/usr/bin/env bash
# Configura SR-IOV para compartilhar 1 GPU física entre 2 VMs (Virtual Functions)
# Suporte: NVIDIA A-series (MIG/SR-IOV), Intel Arc/Data Center, AMD MI-series
# Uso: ./03-sriov-setup.sh <PCI_ADDR> <NUM_VFS>   ex: 0000:01:00.0 2
set -euo pipefail

PCI_ADDR="${1:-}"
NUM_VFS="${2:-2}"

if [[ -z "$PCI_ADDR" ]]; then
  echo "Uso: $0 <PCI_ADDR> [num_vfs=2]"
  exit 1
fi

SRIOV_FILE="/sys/bus/pci/devices/${PCI_ADDR}/sriov_numvfs"

if [[ ! -f "$SRIOV_FILE" ]]; then
  echo "[ERRO] Dispositivo $PCI_ADDR não suporta SR-IOV ou kernel não reconhece."
  exit 1
fi

MAX_VFS=$(cat "/sys/bus/pci/devices/${PCI_ADDR}/sriov_totalvfs")
echo "Máximo de VFs suportadas: $MAX_VFS"

if (( NUM_VFS > MAX_VFS )); then
  echo "[ERRO] Solicitado $NUM_VFS VFs mas o máximo é $MAX_VFS"
  exit 1
fi

echo "$NUM_VFS" > "$SRIOV_FILE"
echo "[OK] $NUM_VFS Virtual Functions criadas para $PCI_ADDR"

echo ""
echo "=== VFs disponíveis ==="
lspci | grep "Virtual Function" || lspci -s "${PCI_ADDR%.*}"

# Gera endereços das VFs (convenção: .1, .2, etc. do mesmo bus)
BUS_SLOT="${PCI_ADDR%.*}"
echo ""
echo "VFs criadas (para usar nos XMLs das VMs):"
for i in $(seq 1 "$NUM_VFS"); do
  VF_ADDR="${BUS_SLOT}.${i}"
  VF_INFO=$(lspci -s "$VF_ADDR" 2>/dev/null || echo "verificar com lspci")
  echo "  VM$i → $VF_ADDR  $VF_INFO"
done

echo ""
echo "Vincule cada VF ao vfio-pci:"
echo "  echo vfio-pci > /sys/bus/pci/devices/<VF_ADDR>/driver_override"
echo "  echo <VF_ADDR> > /sys/bus/pci/drivers/vfio-pci/bind"
