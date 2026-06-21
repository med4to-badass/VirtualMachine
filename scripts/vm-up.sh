#!/usr/bin/env bash
# Sobe VM1, VM2 e gpu-broker em namespaces isolados (sem Docker daemon)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SHARED_DIR="/tmp/vm-shared"
LOG_DIR="/tmp/vm-logs"
PID_DIR="/tmp/vm-pids"

mkdir -p "$SHARED_DIR/gpu" "$LOG_DIR" "$PID_DIR"

stop_existing() {
  for pidfile in "$PID_DIR"/*.pid; do
    [ -f "$pidfile" ] || continue
    name=$(basename "$pidfile" .pid)
    pid=$(cat "$pidfile")
    if kill -0 "$pid" 2>/dev/null; then
      echo "Parando $name (pid $pid)..."
      kill "$pid" 2>/dev/null || true
    fi
    rm -f "$pidfile"
  done
}

start_process() {
  local name="$1"; shift
  local cmd=("$@")
  unshare --uts --fork -- bash -c "${cmd[*]}" >> "$LOG_DIR/${name}.log" 2>&1 &
  local pid=$!
  echo "$pid" > "$PID_DIR/${name}.pid"
  echo "  [OK] $name iniciado (pid $pid) → $LOG_DIR/${name}.log"
}

echo "=== VirtualMachine — GPU Share ==="
echo "Parando instâncias anteriores..."
stop_existing

echo ""
echo "Iniciando gpu-broker..."
GPU_TOTAL_MEM=8192 GPU_VF_COUNT=2 SHARED_DIR="$SHARED_DIR" LOG_DIR="$LOG_DIR" \
  start_process "gpu-broker" "bash $SCRIPT_DIR/gpu-broker.sh"
sleep 1

echo ""
echo "Iniciando vm1..."
VM_NAME=vm1 VM_CPUS=2 VM_RAM=6144 GPU_VF=vf0 GPU_MEM=4096 \
  SHARED_DIR="$SHARED_DIR" LOG_DIR="$LOG_DIR" \
  start_process "vm1" "bash $SCRIPT_DIR/vm-runtime.sh"

echo ""
echo "Iniciando vm2..."
VM_NAME=vm2 VM_CPUS=2 VM_RAM=6144 GPU_VF=vf1 GPU_MEM=4096 \
  SHARED_DIR="$SHARED_DIR" LOG_DIR="$LOG_DIR" \
  start_process "vm2" "bash $SCRIPT_DIR/vm-runtime.sh"

echo ""
echo "=== Status ==="
sleep 2
for pidfile in "$PID_DIR"/*.pid; do
  name=$(basename "$pidfile" .pid)
  pid=$(cat "$pidfile")
  if kill -0 "$pid" 2>/dev/null; then
    echo "  RUNNING  $name (pid $pid)"
  else
    echo "  STOPPED  $name"
  fi
done

echo ""
echo "Logs em tempo real:"
echo "  tail -f $LOG_DIR/gpu-broker.log $LOG_DIR/vm1.log $LOG_DIR/vm2.log"
echo ""
echo "Para parar tudo: bash $SCRIPT_DIR/vm-down.sh"
