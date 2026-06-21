#!/usr/bin/env bash
# Para todas as VMs e o gpu-broker
set -euo pipefail

PID_DIR="/tmp/vm-pids"

if [ ! -d "$PID_DIR" ] || [ -z "$(ls "$PID_DIR" 2>/dev/null)" ]; then
  echo "Nenhuma VM em execução."
  exit 0
fi

for pidfile in "$PID_DIR"/*.pid; do
  [ -f "$pidfile" ] || continue
  name=$(basename "$pidfile" .pid)
  pid=$(cat "$pidfile")
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" && echo "[OK] $name parada (pid $pid)"
  else
    echo "[INFO] $name já estava parada"
  fi
  rm -f "$pidfile"
done

rm -f /tmp/vm-shared/gpu/*.status
echo "Concluído."
