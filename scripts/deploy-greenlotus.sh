#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ssh greenlotus 'mkdir -p /home/ricercar/Documents/GitHub/nvgraph /home/ricercar/.local/share/applications'
scp "$ROOT/nvgraph.py" "$ROOT/nvgraph.desktop" greenlotus:/home/ricercar/Documents/GitHub/nvgraph/
ssh greenlotus 'chmod 755 /home/ricercar/Documents/GitHub/nvgraph/nvgraph.py && cp /home/ricercar/Documents/GitHub/nvgraph/nvgraph.desktop /home/ricercar/.local/share/applications/nvgraph.desktop'
echo "Installed nvgraph on GreenLotus at /home/ricercar/Documents/GitHub/nvgraph/nvgraph.py"
