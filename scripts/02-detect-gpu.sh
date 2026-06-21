#!/usr/bin/env bash
# Detecta GPU e grupo IOMMU para configurar passthrough ou SR-IOV
set -euo pipefail

echo "=== GPUs detectadas ==="
lspci | grep -E "VGA|3D|Display|NVIDIA|AMD|Intel Arc"

echo ""
echo "=== Grupos IOMMU ==="
for d in /sys/kernel/iommu_groups/*/devices/*; do
  n=$(basename "$(dirname "$(dirname "$d")")")
  printf "Grupo %s: " "$n"
  lspci -nns "$(basename "$d")" 2>/dev/null || echo "(não encontrado)"
done

echo ""
echo "=== Capacidade SR-IOV (NVIDIA / Intel) ==="
for dev in /sys/bus/pci/devices/*/sriov_totalvfs; do
  [ -f "$dev" ] || continue
  addr=$(echo "$dev" | awk -F'/' '{print $(NF-1)}')
  vfs=$(cat "$dev")
  name=$(lspci -s "$addr" 2>/dev/null | head -1)
  echo "  $addr ($name) — máx VFs: $vfs"
done

echo ""
echo "Para passthrough completo: use scripts/03-vfio-bind.sh"
echo "Para SR-IOV: use scripts/03-sriov-setup.sh"
