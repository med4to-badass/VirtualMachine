#!/usr/bin/env bash
# Registra as VMs no libvirt e cria os NVRAMs UEFI
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

for VM in vm1 vm2; do
  XML="$SCRIPT_DIR/configs/$VM/$VM.xml"
  NVRAM_TEMPLATE="/usr/share/OVMF/OVMF_VARS.fd"
  NVRAM_DEST="/var/lib/libvirt/qemu/nvram/${VM}_VARS.fd"

  if [ ! -f "$NVRAM_DEST" ]; then
    cp "$NVRAM_TEMPLATE" "$NVRAM_DEST"
    echo "[OK] NVRAM criado: $NVRAM_DEST"
  fi

  virsh define "$XML"
  echo "[OK] $VM definida no libvirt"
done

echo ""
echo "VMs registradas:"
virsh list --all
