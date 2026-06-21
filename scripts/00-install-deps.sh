#!/usr/bin/env bash
# Instala dependências para KVM + GPU Share (SR-IOV / vGPU)
set -euo pipefail

apt-get update -y
apt-get install -y \
  qemu-kvm \
  libvirt-daemon-system \
  libvirt-clients \
  bridge-utils \
  virt-manager \
  cpu-checker \
  ovmf \
  swtpm \
  virtinst \
  numactl \
  hugepages \
  linux-headers-$(uname -r) \
  dkms \
  pciutils \
  lshw

# Habilita e inicia libvirt
systemctl enable --now libvirtd

# Verifica KVM
kvm-ok && echo "[OK] KVM disponível"

# Verifica IOMMU
if grep -q "iommu=on\|intel_iommu=on\|amd_iommu=on" /proc/cmdline; then
  echo "[OK] IOMMU ativo"
else
  echo "[AVISO] IOMMU não está ativo — adicione ao GRUB e reinicie (veja scripts/01-enable-iommu.sh)"
fi

echo "Instalação concluída."
