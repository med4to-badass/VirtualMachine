#!/usr/bin/env bash
# Liga GPU ao driver vfio-pci para passthrough (modo full passthrough — uma GPU por VM)
# Uso: ./03-vfio-bind.sh <PCI_ADDR>  ex: 0000:01:00.0
set -euo pipefail

PCI_ADDR="${1:-}"
if [[ -z "$PCI_ADDR" ]]; then
  echo "Uso: $0 <PCI_ADDR>"
  echo "Execute scripts/02-detect-gpu.sh para listar endereços"
  exit 1
fi

VENDOR_DEVICE=$(lspci -n -s "$PCI_ADDR" | awk '{print $3}')
VENDOR=$(echo "$VENDOR_DEVICE" | cut -d: -f1)
DEVICE=$(echo "$VENDOR_DEVICE" | cut -d: -f2)

echo "Desvinculando $PCI_ADDR ($VENDOR_DEVICE) do driver atual..."
DRIVER_PATH="/sys/bus/pci/devices/${PCI_ADDR}/driver"
if [ -L "$DRIVER_PATH" ]; then
  echo "$PCI_ADDR" > "${DRIVER_PATH}/unbind"
fi

echo "Carregando vfio-pci..."
modprobe vfio-pci

echo "$VENDOR $DEVICE" > /sys/bus/pci/drivers/vfio-pci/new_id
echo "[OK] $PCI_ADDR vinculado a vfio-pci"

# Persistência via /etc/modprobe.d
cat > /etc/modprobe.d/vfio.conf <<EOF
options vfio-pci ids=${VENDOR_DEVICE}
softdep nvidia pre: vfio-pci
softdep amdgpu pre: vfio-pci
EOF

update-initramfs -u
echo "Reinicie para garantir persistência."
