#!/bin/bash
# Wrapper shell script para gerar param.sfo
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "==> Gerando sce_sys/param.sfo para RETR00001 (Retro Player)..."
python3 "$SCRIPT_DIR/generate_sfo.py" "$ROOT_DIR/sce_sys/param.sfo"

