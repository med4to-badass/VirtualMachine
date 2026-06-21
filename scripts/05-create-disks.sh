#!/usr/bin/env bash
# Cria imagens de disco qcow2 para VM1 e VM2
set -euo pipefail

DISK_DIR="/var/lib/libvirt/images"
VM1_SIZE="${1:-50G}"
VM2_SIZE="${2:-50G}"

mkdir -p "$DISK_DIR"

echo "Criando disco VM1 (${VM1_SIZE})..."
qemu-img create -f qcow2 "$DISK_DIR/vm1.qcow2" "$VM1_SIZE"

echo "Criando disco VM2 (${VM2_SIZE})..."
qemu-img create -f qcow2 "$DISK_DIR/vm2.qcow2" "$VM2_SIZE"

echo ""
echo "Discos criados:"
ls -lh "$DISK_DIR"/*.qcow2
