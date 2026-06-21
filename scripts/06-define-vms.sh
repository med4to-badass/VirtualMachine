#!/usr/bin/env bash
# Registra as VMs no libvirt. Se KVM não estiver disponível, injeta emulação TCG.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KVM_AVAILABLE=false
[ -e /dev/kvm ] && KVM_AVAILABLE=true

for VM in vm1 vm2; do
  XML="$SCRIPT_DIR/configs/$VM/$VM.xml"
  WORK_XML="/tmp/${VM}_runtime.xml"
  NVRAM_TEMPLATE="/usr/share/OVMF/OVMF_VARS.fd"
  NVRAM_DEST="/var/lib/libvirt/qemu/nvram/${VM}_VARS.fd"

  cp "$XML" "$WORK_XML"

  if ! $KVM_AVAILABLE; then
    # Muda domain type para qemu (TCG) e remove hostdev de GPU (não disponível)
    sed -i 's/<domain type="kvm">/<domain type="qemu">/' "$WORK_XML"
    sed -i '/<hostdev/,/<\/hostdev>/d' "$WORK_XML"
    # Adiciona vídeo virtio para simular GPU
    sed -i 's/<model type="none"\/>/<model type="virtio" heads="1" primary="yes"\/>/' "$WORK_XML"
    echo "[AVISO] $VM: KVM indisponível — usando QEMU/TCG sem GPU passthrough"
  fi

  if [ ! -f "$NVRAM_DEST" ] && [ -f "$NVRAM_TEMPLATE" ]; then
    cp "$NVRAM_TEMPLATE" "$NVRAM_DEST"
    echo "[OK] NVRAM criado: $NVRAM_DEST"
  fi

  virsh define "$WORK_XML"
  echo "[OK] $VM definida no libvirt"
done

echo ""
echo "VMs registradas:"
virsh list --all
