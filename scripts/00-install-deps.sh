#!/usr/bin/env bash
# Instala dependências para KVM + GPU Share (SR-IOV / vGPU)
# Detecta automaticamente se KVM está disponível
set -euo pipefail

IN_CONTAINER=false
if grep -q docker /proc/1/cgroup 2>/dev/null || [ -f /.dockerenv ]; then
  IN_CONTAINER=true
fi

KVM_AVAILABLE=false
if [ -e /dev/kvm ]; then
  KVM_AVAILABLE=true
fi

echo "=== Ambiente detectado ==="
echo "  Container: $IN_CONTAINER"
echo "  KVM disponível: $KVM_AVAILABLE"
echo ""

apt-get update -y
apt-get install -y \
  qemu-system-x86 \
  qemu-utils \
  libvirt-daemon-system \
  libvirt-clients \
  bridge-utils \
  ovmf \
  virtinst \
  cpu-checker \
  pciutils \
  lshw \
  numactl

if $KVM_AVAILABLE; then
  apt-get install -y qemu-kvm
  systemctl enable --now libvirtd
  echo "[OK] KVM habilitado"
else
  echo "[AVISO] KVM não disponível — VMs rodarão em modo QEMU/TCG (mais lento)"
  echo "         Em bare-metal com vmx/svm, execute: scripts/01-enable-iommu.sh e reinicie"
  if $IN_CONTAINER; then
    echo "         Para testar 2 VMs agora neste container, use: docker compose up (docker-compose.yml)"
  fi
fi

if $IN_CONTAINER; then
  echo ""
  echo "[INFO] Rodando em container Docker. GPU passthrough/SR-IOV não é possível aqui."
  echo "       Use o docker-compose.yml para simular as 2 VMs com GPU virtual (VirtIO)."
else
  if grep -q "iommu" /proc/cmdline; then
    echo "[OK] IOMMU ativo"
  else
    echo "[AVISO] IOMMU não ativo — execute scripts/01-enable-iommu.sh e reinicie"
  fi
fi

echo ""
echo "Instalação concluída."
