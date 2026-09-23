# nvgraph for Windows — local NVIDIA telemetry dashboard for BlackLotus.
# Requires only Windows PowerShell, Windows Forms, and nvidia-smi.exe.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$NvGraphBarSource = @'
using System;
using System.Drawing;
using System.Windows.Forms;

public class NvGraphBar : Panel {
    public double MeterValue { get; set; }
    public double MeterMaximum { get; set; }
    public bool Critical { get; set; }
    public string DisplayText { get; set; }

    public NvGraphBar() {
        MeterMaximum = 100;
        DisplayText = "";
        Height = 38;
        DoubleBuffered = true;
        Margin = new Padding(0);
    }

    protected override void OnPaint(PaintEventArgs e) {
        base.OnPaint(e);
        var fraction = MeterMaximum <= 0 ? 0 : Math.Max(0, Math.Min(MeterValue / MeterMaximum, 1));
        e.Graphics.FillRectangle(new SolidBrush(Color.FromArgb(45, 45, 48)), ClientRectangle);
        var fill = new Rectangle(0, 0, (int)Math.Round(ClientSize.Width * fraction), ClientSize.Height);
        e.Graphics.FillRectangle(new SolidBrush(Critical ? Color.FromArgb(200, 57, 69) : Color.FromArgb(47, 179, 75)), fill);
        TextRenderer.DrawText(e.Graphics, DisplayText, Font, ClientRectangle, Color.White,
            TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis);
        e.Graphics.DrawRectangle(Pens.DimGray, 0, 0, Math.Max(0, ClientSize.Width - 1), Math.Max(0, ClientSize.Height - 1));
    }
}
'@
Add-Type -TypeDefinition $NvGraphBarSource -ReferencedAssemblies @(
    [System.Windows.Forms.Form].Assembly.Location,
    [System.Drawing.Color].Assembly.Location
)

$ErrorActionPreference = 'Stop'
$RefreshSeconds = 5
$TemperatureLimitC = 80.0
$AppDirectory = 'C:\nvgraph'
$SettingsPath = Join-Path $env:APPDATA 'nvgraph\settings.json'
$RunKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$RunValueName = 'nvgraph'

function Convert-ToNumber([string]$Value) {
    $number = 0.0
    if ([double]::TryParse($Value, [ref]$number)) { return $number }
    return 0.0
}

function Get-GpuReadings {
    $output = & nvidia-smi --query-gpu=index,name,temperature.gpu,power.draw,power.limit,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>&1
    if ($LASTEXITCODE -ne 0) { throw ($output -join [Environment]::NewLine) }
    $gpus = @()
    foreach ($line in $output) {
        $field = $line.ToString().Split(',').ForEach({ $_.Trim() })
        if ($field.Count -ne 8) { continue }
        $gpus += [PSCustomObject]@{
            Index = $field[0]; Name = $field[1]; Temperature = Convert-ToNumber $field[2]
            Power = Convert-ToNumber $field[3]; PowerLimit = Convert-ToNumber $field[4]
            Utilization = Convert-ToNumber $field[5]; MemoryUsed = Convert-ToNumber $field[6]
            MemoryTotal = Convert-ToNumber $field[7]
        }
    }
    if ($gpus.Count -eq 0) { throw 'nvidia-smi returned no NVIDIA GPUs.' }
    return $gpus
}

function Read-Settings {
    if (-not (Test-Path $SettingsPath)) { return @{} }
    try { return Get-Content $SettingsPath -Raw | ConvertFrom-Json -AsHashtable }
    catch { return @{} }
}

function Save-Settings {
    $bounds = if ($Form.WindowState -eq [System.Windows.Forms.FormWindowState]::Normal) { $Form.Bounds } else { $Form.RestoreBounds }
    $settings = @{
        settingsVersion = 1
        x = $bounds.X; y = $bounds.Y; width = $bounds.Width; height = $bounds.Height
        launchAtSignIn = $LaunchAtSignIn.Checked
    }
    $folder = Split-Path $SettingsPath
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
    $settings | ConvertTo-Json | Set-Content -Path $SettingsPath -Encoding UTF8
}

function Set-Autostart([bool]$Enabled) {
    if ($Enabled) {
        New-Item -Path $RunKey -Force | Out-Null
        Set-ItemProperty -Path $RunKey -Name $RunValueName -Value ('"{0}"' -f (Join-Path $AppDirectory 'Start-nvgraph.cmd'))
    } else {
        Remove-ItemProperty -Path $RunKey -Name $RunValueName -ErrorAction SilentlyContinue
    }
}

function New-Header([string]$Text) {
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Dock = 'Fill'
    $label.TextAlign = 'MiddleLeft'
    $label.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $label.ForeColor = [System.Drawing.Color]::Gainsboro
    return $label
}

function New-MetricLabel([string]$Text) {
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Dock = 'Fill'
    $label.TextAlign = 'MiddleLeft'
    $label.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    $label.ForeColor = [System.Drawing.Color]::Gainsboro
    return $label
}

$settings = Read-Settings
$Form = New-Object System.Windows.Forms.Form
$Form.Text = 'nvgraph — BlackLotus GPU Telemetry'
$Form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$Form.ForeColor = [System.Drawing.Color]::Gainsboro
$Form.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$Form.StartPosition = 'CenterScreen'
$Form.MinimumSize = New-Object System.Drawing.Size(880, 410)
$Form.Size = New-Object System.Drawing.Size(1040, 500)
if ($settings.width -ge 880 -and $settings.height -ge 410) {
    $Form.StartPosition = 'Manual'
    $Form.Size = New-Object System.Drawing.Size([int]$settings.width, [int]$settings.height)
    $Form.Location = New-Object System.Drawing.Point([int]$settings.x, [int]$settings.y)
}

$Root = New-Object System.Windows.Forms.TableLayoutPanel
$Root.Dock = 'Fill'; $Root.Padding = New-Object System.Windows.Forms.Padding(16)
$Root.ColumnCount = 1; $Root.RowCount = 5
$Root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
$Root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
$Root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
$Root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$Root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
$Form.Controls.Add($Root)

$Title = New-Object System.Windows.Forms.Label
$Title.Text = 'nvgraph'; $Title.AutoSize = $true
$Title.Font = New-Object System.Drawing.Font('Segoe UI', 20, [System.Drawing.FontStyle]::Bold)
$Root.Controls.Add($Title, 0, 0)
$Subtitle = New-Object System.Windows.Forms.Label
$Subtitle.Text = 'BlackLotus · local NVIDIA telemetry · live comparison bars'
$Subtitle.AutoSize = $true; $Subtitle.ForeColor = [System.Drawing.Color]::Silver
$Root.Controls.Add($Subtitle, 0, 1)
$Status = New-Object System.Windows.Forms.Label
$Status.Text = 'Starting local GPU sample…'; $Status.AutoSize = $true; $Status.ForeColor = [System.Drawing.Color]::LightGray
$Root.Controls.Add($Status, 0, 2)

$Comparison = New-Object System.Windows.Forms.TableLayoutPanel
$Comparison.Dock = 'Fill'; $Comparison.AutoScroll = $true; $Comparison.Padding = New-Object System.Windows.Forms.Padding(0, 8, 0, 8)
$Root.Controls.Add($Comparison, 0, 3)

$Controls = New-Object System.Windows.Forms.FlowLayoutPanel
$Controls.Dock = 'Fill'; $Controls.AutoSize = $true; $Controls.FlowDirection = 'LeftToRight'
$LaunchAtSignIn = New-Object System.Windows.Forms.CheckBox
$LaunchAtSignIn.Text = 'Launch nvgraph at sign-in'; $LaunchAtSignIn.AutoSize = $true
$LaunchAtSignIn.Checked = [bool]$settings.launchAtSignIn
$Refresh = New-Object System.Windows.Forms.Button
$Refresh.Text = 'Refresh Now'; $Refresh.AutoSize = $true
$Quit = New-Object System.Windows.Forms.Button
$Quit.Text = 'Quit'; $Quit.AutoSize = $true
$Controls.Controls.AddRange(@($LaunchAtSignIn, $Refresh, $Quit))
$Root.Controls.Add($Controls, 0, 4)

$MetricBars = @{}
function Build-Comparison([array]$Gpus) {
    $Comparison.Controls.Clear(); $Comparison.ColumnStyles.Clear(); $Comparison.RowStyles.Clear()
    $Comparison.ColumnCount = $Gpus.Count + 1; $Comparison.RowCount = 5
    $Comparison.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 180)))
    foreach ($gpu in $Gpus) { $Comparison.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, (100 / $Gpus.Count)))) }
    $Comparison.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 30)))
    foreach ($unused in 1..4) { $Comparison.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 50))) }
    $Comparison.Controls.Add((New-Header 'Metric'), 0, 0)
    for ($column = 0; $column -lt $Gpus.Count; $column++) { $Comparison.Controls.Add((New-Header ("GPU {0} · {1}" -f $Gpus[$column].Index, $Gpus[$column].Name)), $column + 1, 0) }
    $definitions = @(
        @{ Key = 'Temperature'; Label = 'Temperature · 80 °C limit' },
        @{ Key = 'Power'; Label = 'Power draw' },
        @{ Key = 'Utilization'; Label = 'GPU utilization' },
        @{ Key = 'Memory'; Label = 'VRAM use' }
    )
    $script:MetricBars = @{}
    for ($row = 0; $row -lt $definitions.Count; $row++) {
        $definition = $definitions[$row]
        $Comparison.Controls.Add((New-MetricLabel $definition.Label), 0, $row + 1)
        $script:MetricBars[$definition.Key] = @()
        for ($column = 0; $column -lt $Gpus.Count; $column++) {
            $bar = New-Object NvGraphBar
            $bar.Dock = 'Fill'
            $Comparison.Controls.Add($bar, $column + 1, $row + 1)
            $script:MetricBars[$definition.Key] += $bar
        }
    }
}

$KnownGpuIndices = @()
function Update-Comparison {
    try {
        $gpus = @(Get-GpuReadings)
        $indices = @($gpus | ForEach-Object Index)
        if (($KnownGpuIndices -join ',') -ne ($indices -join ',')) { $script:KnownGpuIndices = $indices; Build-Comparison $gpus }
        for ($column = 0; $column -lt $gpus.Count; $column++) {
            $gpu = $gpus[$column]
            $updates = @{
                Temperature = @($gpu.Temperature, $TemperatureLimitC, ("{0:N0} °C / {1:N0} °C" -f $gpu.Temperature, $TemperatureLimitC), ($gpu.Temperature -gt $TemperatureLimitC))
                Power = @($gpu.Power, $gpu.PowerLimit, ("{0:N0} W / {1:N0} W" -f $gpu.Power, $gpu.PowerLimit), ($gpu.Power -gt $gpu.PowerLimit))
                Utilization = @($gpu.Utilization, 100, ("{0:N0}%" -f $gpu.Utilization), $false)
                Memory = @($gpu.MemoryUsed, $gpu.MemoryTotal, ("{0:N0} / {1:N0} MiB" -f $gpu.MemoryUsed, $gpu.MemoryTotal), ($gpu.MemoryUsed -gt $gpu.MemoryTotal))
            }
            foreach ($key in $updates.Keys) {
                $bar = $MetricBars[$key][$column]; $value = $updates[$key]
                $bar.MeterValue = $value[0]; $bar.MeterMaximum = $value[1]; $bar.DisplayText = $value[2]; $bar.Critical = $value[3]; $bar.Invalidate()
            }
        }
        $Status.Text = "Last successful sample: $(Get-Date -Format 'HH:mm:ss') · refreshes every $RefreshSeconds seconds · red means a reported limit was exceeded"
    } catch { $Status.Text = "Sample failed: $($_.Exception.Message)" }
}

$Refresh.Add_Click({ Update-Comparison })
$Quit.Add_Click({ $Form.Close() })
$LaunchAtSignIn.Add_CheckedChanged({ Set-Autostart $LaunchAtSignIn.Checked; Save-Settings })
$Form.Add_FormClosing({ Save-Settings })
$Timer = New-Object System.Windows.Forms.Timer
$Timer.Interval = $RefreshSeconds * 1000
$Timer.Add_Tick({ Update-Comparison })
Update-Comparison
$Timer.Start()
[void]$Form.ShowDialog()
