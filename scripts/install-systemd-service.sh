#!/usr/bin/env bash
# Instala o serviço systemd de SR-IOV para rodar no boot
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SERVICE_SRC="$SCRIPT_DIR/systemd/gpu-sriov.service"
SERVICE_DEST="/etc/systemd/system/gpu-sriov.service"

cp "$SERVICE_SRC" "$SERVICE_DEST"
systemctl daemon-reload
systemctl enable gpu-sriov.service
echo "[OK] Serviço instalado e habilitado no boot."
echo "Edite $SERVICE_DEST para ajustar PCI_ADDR e NUM_VFS."
