#!/usr/bin/env bash
# Configura NVIDIA Multi-Instance GPU (MIG) — alternativa ao SR-IOV para A100/H100/A30
# Cada "instância MIG" é uma fatia isolada da GPU (memória + SMs dedicados)
set -euo pipefail

GPU_INDEX="${1:-0}"

# Verifica suporte
nvidia-smi -i "$GPU_INDEX" --query-gpu=mig.mode.current --format=csv,noheader 2>/dev/null \
  || { echo "[ERRO] nvidia-smi não encontrado ou GPU $GPU_INDEX não suporta MIG"; exit 1; }

echo "=== Habilitando MIG na GPU $GPU_INDEX ==="
nvidia-smi -i "$GPU_INDEX" -mig 1

echo ""
echo "=== Perfis MIG disponíveis ==="
nvidia-smi mig -lgip

echo ""
echo "Criando 2 instâncias GPU (perfil 3g.20gb — ajuste conforme sua GPU):"
# A100 80GB → 2x 3g.40gb  |  A100 40GB → 2x 3g.20gb  |  A30 → 2x 2g.12gb
nvidia-smi mig -cgi 3g.20gb,3g.20gb -C

echo ""
echo "=== Instâncias criadas ==="
nvidia-smi mig -lgi

echo ""
echo "Para usar nas VMs, passe os UUIDs das instâncias MIG via VFIO:"
nvidia-smi -L | grep MIG
