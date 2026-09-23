#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ssh blacklotus 'powershell -NoProfile -Command "New-Item -ItemType Directory -Force C:\nvgraph | Out-Null"'
scp "$ROOT/windows/nvgraph.ps1" "$ROOT/windows/Start-nvgraph.cmd" blacklotus:'C:/nvgraph/'
ssh blacklotus 'powershell -NoProfile -Command "Unblock-File C:\nvgraph\nvgraph.ps1 -ErrorAction SilentlyContinue"'
printf '%s\n' 'Installed nvgraph for Windows at C:\nvgraph'
