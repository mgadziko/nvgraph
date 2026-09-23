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

## Windows / BlackLotus

The native Windows PowerShell/WinForms edition is in `windows/`. It uses the same five-second local `nvidia-smi` polling and side-by-side comparison layout, with 80 C temperature and GPU-reported power-limit warnings.

Deploy it from the Mac checkout with:

```zsh
./scripts/deploy-blacklotus.sh
```

On BlackLotus, launch `C:\nvgraph\Start-nvgraph.cmd`. Its settings are saved under `%APPDATA%\nvgraph\settings.json`; its optional sign-in launch is stored in the current user's normal Windows Run key.
