# nvgraph

`nvgraph` is a native GTK dashboard for GreenLotus. It samples the local NVIDIA GPUs every five seconds and displays graphical bars for temperature, power draw, utilization, and VRAM use. Each metric is a compact vertical row, with GPU 0 and GPU 1 bars directly beside one another for easy comparison.

## Limits and colors

- Temperature is green through 80 C and red above 80 C, the Tesla P100 PCIe maximum operating temperature.
- Power is green through the power limit reported by `nvidia-smi` and red above it.
- Utilization and VRAM use are informational; they remain green within their natural 0–100% ranges.

## Installation

From the Mac development checkout:

```zsh
cd ~/Documents/GitHub/nvgraph
./scripts/deploy-greenlotus.sh
```

On GreenLotus, launch **nvgraph** from the Applications menu, or run:

```bash
python3 ~/nvgraph/nvgraph.py
```

The **Launch nvgraph at sign-in** option creates or removes the signed-in user’s standard desktop autostart entry. Window size and placement are saved after a normal close in `~/.config/nvgraph/settings.json`.

## Windows

The native Windows PowerShell/WinForms edition is in `windows/`. It polls local `nvidia-smi` every five seconds and uses a side-by-side comparison layout. Its hardware policy is external: `windows/nvgraph.ini` supplies per-GPU power, warning-temperature, and critical-temperature limits.

`nvgraph.ini` is reloaded with every sample, so adding a GPU model or changing a limit requires neither a rebuild nor an application restart. GPU section names match the model string returned by `nvidia-smi`; `[defaults]` applies when no model-specific section matches. A `power_limit_w` of `0` uses the current GPU-reported limit.

Included entries cover the current fleet's Tesla M40, Tesla P40, Tesla P100 PCIe 16 GB, RTX 3090, and RTX 4090 GPUs. Treat those entries as editable policies and confirm actual hardware limits with `nvidia-smi` before relying on them.

Deploy it from the Mac checkout with:

```zsh
./scripts/deploy-blacklotus.sh
```

On a Windows host, launch `C:\nvgraph\Start-nvgraph.cmd`. Keep `nvgraph.ini` beside `nvgraph.ps1`. Window settings are saved under `%APPDATA%\nvgraph\settings.json`; optional sign-in launch is stored in the current user's normal Windows Run key.
