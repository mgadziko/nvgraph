# nvgraph

`nvgraph` is a local NVIDIA GPU telemetry dashboard. The Linux edition is a GTK application and the Windows edition is a PowerShell/WinForms application. Both sample `nvidia-smi` every five seconds and display side-by-side bars for temperature, power draw, utilization, and VRAM use.

## Limits and colors

- **Temperature**:
  - Green: below 75°C
  - Amber: 75°C through 80°C
  - Red: above 80°C
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

The Linux GTK edition displays 83–87°C inclusive in purple, overriding red for that band. Above 87°C, the bar returns to red.

Both editions use Thermal Monitor's palette: green `#40c77a`, amber `#e4ad4a`, and red `#ec5f6d`. The shipped temperature policy is intentionally fixed at 75/80°C for every GPU model so it agrees with the Linux Thermal Monitor. `nvidia-smi` remains the source of truth for each GPU's live temperature, power limit, utilization, and VRAM values.

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

The native Windows PowerShell/WinForms edition is in `windows/`. It has the same metrics, thresholds, and colors as the Linux edition, including warning bands for power, utilization, and VRAM.

`nvgraph.ini` is reloaded with every sample. GPU section names match the model string returned by `nvidia-smi`; `[defaults]` applies when no model-specific section matches. A `power_limit_w` of `0` uses the current GPU-reported limit. The included per-GPU power limits cover the current fleet's Tesla M40, Tesla P40, Tesla P100 PCIe 16 GB, RTX 3090, and RTX 4090 GPUs. Temperature overrides remain supported for compatibility, but the shipped file uses the shared 75/80°C defaults.

Confirm actual hardware power limits with `nvidia-smi` before relying on an edited policy.

Deploy it from the Mac checkout with:

```zsh
./scripts/deploy-blacklotus.sh
```

On a Windows host, launch `C:\nvgraph\Start-nvgraph.cmd` from a signed-in desktop session. Keep `nvgraph.ini` beside `nvgraph.ps1`. Window settings are saved under `%APPDATA%\nvgraph\settings.json`; optional sign-in launch is stored in the current user's normal Windows Run key. A WinForms window cannot be displayed from an SSH/service session.

The current Windows rollout is installed on Hal (dual RTX 3090) and Cheyenne (RTX 4090). Cheyenne's dashboard runs in its active console session; Hal will display it when a desktop user signs in.
