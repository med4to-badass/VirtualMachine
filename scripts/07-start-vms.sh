#!/usr/bin/env bash
# Inicia VM1 e VM2
set -euo pipefail

for VM in vm1 vm2; do
  echo "Iniciando $VM..."
  virsh start "$VM"
done

sleep 3
echo ""
echo "=== Status ==="
virsh list --all
