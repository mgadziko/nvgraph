# nvgraph

`nvgraph` is a local NVIDIA GPU telemetry dashboard. The Linux edition is a GTK application and the Windows edition is a PowerShell/WinForms application. Both sample `nvidia-smi` every five seconds and display side-by-side bars for temperature, power draw, utilization, and VRAM use, along with GPU core and VRAM clock readings in MHz.

## Limits and colors

- **Temperature**:
  - Green: below 75°C
  - Amber: 75°C to below 80°C
  - Red: 80°C to below 85°C
  - Purple: 85°C to below 90°C
  - Blue: 90°C and above
- **Power**:
  - Green: below 90% of the reported or configured power limit
  - Amber: 90% through 100% of that limit
  - Red: above the limit
- **Utilization**:
  - Green: below 80%
  - Amber: 80% or higher
- **VRAM use**:
  - Green: below 85% of the reported total
  - Amber: 85% through 100% of the reported total
  - Red: above the reported total

Both editions use the same fixed temperature bands. Temperature colors are display indicators; NVGraph does not change GPU limits.

## Installation

From the Mac development checkout:

```zsh
cd ~/Documents/GitHub/nvgraph
./scripts/deploy-greenlotus.sh
```

On GreenLotus, launch **nvgraph** from the Applications menu, or run:

```bash
python3 /home/ricercar/Documents/GitHub/nvgraph/nvgraph.py
```

The **Launch nvgraph at sign-in** option creates or removes the signed-in user’s standard desktop autostart entry. Window size and placement are saved after a normal close in `~/.config/nvgraph/settings.json`.

## Windows

The native Windows PowerShell/WinForms edition is in `windows/`. It displays the same metrics and default color bands as the Linux edition.

`nvgraph.ini` is reloaded with every sample. GPU section names match the model string returned by `nvidia-smi`; `[defaults]` applies when no model-specific section matches. A `power_limit_w` of `0` uses the current GPU-reported limit. The included per-GPU power limits cover the current fleet's Tesla M40, Tesla P40, Tesla P100 PCIe 16 GB, RTX 3090, and RTX 4090 GPUs. Temperature bands are built into both editions.

Confirm actual hardware power limits with `nvidia-smi` before relying on an edited policy.

For Cheyenne, copy the Windows app files from the Mac checkout:

```zsh
scp windows/nvgraph.ps1 windows/Start-nvgraph.cmd cheyenne:'C:/nvgraph/'
```

On a Windows host, launch `C:\nvgraph\Start-nvgraph.cmd` from a signed-in desktop session. For a fresh install, copy `windows/nvgraph.ini` to the same folder. Keep `nvgraph.ini` beside `nvgraph.ps1`. Window settings are saved under `%APPDATA%\nvgraph\settings.json`; optional sign-in launch is stored in the current user's normal Windows Run key. A WinForms window cannot be displayed from an SSH/service session.

Windows deployment hosts include Cheyenne (RTX 4090) and Hal3090 (dual RTX 3090).
