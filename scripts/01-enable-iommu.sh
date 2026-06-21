#!/usr/bin/env bash
# Habilita IOMMU no GRUB (necessário para GPU passthrough / SR-IOV)
set -euo pipefail

GRUB_FILE="/etc/default/grub"

# Detecta CPU
if grep -q "GenuineIntel" /proc/cpuinfo; then
  IOMMU_PARAM="intel_iommu=on iommu=pt"
else
  IOMMU_PARAM="amd_iommu=on iommu=pt"
fi

# Faz backup
cp "$GRUB_FILE" "${GRUB_FILE}.bak"

# Injeta parâmetros se ainda não existirem
if ! grep -q "iommu" "$GRUB_FILE"; then
  sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"${IOMMU_PARAM} /" "$GRUB_FILE"
  echo "[OK] Parâmetros IOMMU adicionados: $IOMMU_PARAM"
else
  echo "[INFO] IOMMU já configurado em $GRUB_FILE"
fi

update-grub
echo "Reinicie o sistema para aplicar."
