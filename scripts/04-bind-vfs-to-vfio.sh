#!/usr/bin/env bash
# Vincula as Virtual Functions ao vfio-pci para uso nas VMs
# Uso: ./04-bind-vfs-to-vfio.sh <VF1_ADDR> <VF2_ADDR>
#      ex: ./04-bind-vfs-to-vfio.sh 0000:01:00.1 0000:01:00.2
set -euo pipefail

modprobe vfio-pci

for VF_ADDR in "$@"; do
  echo "Vinculando $VF_ADDR ao vfio-pci..."

  # Desvincula driver atual se existir
  DRIVER_LINK="/sys/bus/pci/devices/${VF_ADDR}/driver"
  if [ -L "$DRIVER_LINK" ]; then
    echo "$VF_ADDR" > "${DRIVER_LINK}/unbind"
  fi

  echo "vfio-pci" > "/sys/bus/pci/devices/${VF_ADDR}/driver_override"
  echo "$VF_ADDR" > /sys/bus/pci/drivers/vfio-pci/bind
  echo "[OK] $VF_ADDR → vfio-pci"
done

echo ""
echo "VFs prontas para passthrough nas VMs."
