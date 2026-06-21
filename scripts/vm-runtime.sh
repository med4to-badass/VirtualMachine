#!/usr/bin/env bash
# Runtime de uma VM simulada via Linux namespaces (sem KVM, sem Docker daemon)
# Chamado pelo vm-up.sh com variáveis de ambiente injetadas
set -euo pipefail

VM_NAME="${VM_NAME:-vm}"
VM_CPUS="${VM_CPUS:-2}"
VM_RAM="${VM_RAM:-6144}"
GPU_VF="${GPU_VF:-vf0}"
GPU_MEM="${GPU_MEM:-4096}"
LOG_DIR="${LOG_DIR:-/tmp/vm-logs}"
SHARED_DIR="${SHARED_DIR:-/tmp/vm-shared}"

mkdir -p "$LOG_DIR" "$SHARED_DIR/gpu"

LOG="$LOG_DIR/${VM_NAME}.log"

log() { echo "[$(date '+%H:%M:%S')] [$VM_NAME] $*" | tee -a "$LOG"; }

log "Iniciando..."
log "vCPUs: $VM_CPUS | RAM: ${VM_RAM} MiB | GPU VF: $GPU_VF (${GPU_MEM} MiB VRAM)"

# Registra VF como em uso
echo "${VM_NAME}:em_uso:${GPU_MEM}MiB" > "$SHARED_DIR/gpu/${GPU_VF}.status"
log "GPU VF $GPU_VF alocada → $SHARED_DIR/gpu/${GPU_VF}.status"

# Simula hostname isolado
hostname "$VM_NAME" 2>/dev/null || true

# Loop de heartbeat (simula VM rodando)
while true; do
  MEM_FREE=$(awk '/MemAvailable/{print $2}' /proc/meminfo 2>/dev/null || echo "?")
  CPU_IDLE=$(awk '/cpu /{idle=$5; total=$2+$3+$4+$5+$6+$7+$8; printf "%.0f", (idle/total)*100; exit}' /proc/stat 2>/dev/null || echo "?")
  GPU_STATUS=$(cat "$SHARED_DIR/gpu/${GPU_VF}.status" 2>/dev/null || echo "sem info")
  log "heartbeat | CPU idle: ${CPU_IDLE}% | MemFree host: ${MEM_FREE}kB | GPU: $GPU_STATUS"
  sleep 10
done
