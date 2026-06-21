#!/usr/bin/env bash
# GPU Share Broker — divide VRAM entre as VFs e monitora uso
set -euo pipefail

GPU_TOTAL_MEM="${GPU_TOTAL_MEM:-8192}"
GPU_VF_COUNT="${GPU_VF_COUNT:-2}"
SHARED_DIR="${SHARED_DIR:-/tmp/vm-shared}"
LOG_DIR="${LOG_DIR:-/tmp/vm-logs}"

mkdir -p "$SHARED_DIR/gpu" "$LOG_DIR"
LOG="$LOG_DIR/gpu-broker.log"

log() { echo "[$(date '+%H:%M:%S')] [gpu-broker] $*" | tee -a "$LOG"; }

VF_MEM=$(( GPU_TOTAL_MEM / GPU_VF_COUNT ))

log "GPU Share Broker iniciado"
log "VRAM total: ${GPU_TOTAL_MEM} MiB | VFs: $GPU_VF_COUNT | ${VF_MEM} MiB por VF"

for i in $(seq 0 $(( GPU_VF_COUNT - 1 ))); do
  VF_FILE="$SHARED_DIR/gpu/vf${i}.status"
  if [ ! -f "$VF_FILE" ]; then
    echo "vf${i}:livre:${VF_MEM}MiB" > "$VF_FILE"
  fi
  log "VF vf${i}: $(cat "$VF_FILE")"
done

# Monitor contínuo
while true; do
  log "--- status das VFs ---"
  for f in "$SHARED_DIR/gpu"/vf*.status; do
    [ -f "$f" ] && log "  $(basename "$f"): $(cat "$f")"
  done
  sleep 10
done
