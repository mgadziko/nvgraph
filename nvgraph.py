#!/usr/bin/env python3
"""nvgraph: a live, local NVIDIA GPU telemetry dashboard for GreenLotus."""

import json
import os
import subprocess
import time
from dataclasses import dataclass

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gdk, GLib, Gtk


REFRESH_SECONDS = 5
TEMPERATURE_LIMIT_C = 80.0
APP_DIRECTORY = "nvgraph"
AUTOSTART_PATH = os.path.join(GLib.get_user_config_dir(), "autostart", "nvgraph.desktop")


@dataclass
class GPU:
    index: str
    name: str
    temperature: float
    power: float
    power_limit: float
    utilization: float
    memory_used: float
    memory_total: float


def run(command: list[str]) -> str:
    completed = subprocess.run(command, text=True, capture_output=True, timeout=12, check=False)
    if completed.returncode:
        detail = completed.stderr.strip() or completed.stdout.strip() or f"exit status {completed.returncode}"
        raise RuntimeError(detail)
    return completed.stdout


def numeric(value: str) -> float:
    try:
        return float(value)
    except ValueError:
        return 0.0


def read_gpus() -> list[GPU]:
    output = run([
        "nvidia-smi",
        "--query-gpu=index,name,temperature.gpu,power.draw,power.limit,utilization.gpu,memory.used,memory.total",
        "--format=csv,noheader,nounits",
    ])
    gpus = []
    for line in output.splitlines():
        fields = [field.strip() for field in line.split(",")]
        if len(fields) != 8:
            continue
        gpus.append(GPU(
            index=fields[0], name=fields[1], temperature=numeric(fields[2]),
            power=numeric(fields[3]), power_limit=numeric(fields[4]), utilization=numeric(fields[5]),
            memory_used=numeric(fields[6]), memory_total=numeric(fields[7]),
        ))
    if not gpus:
        raise RuntimeError("No NVIDIA GPUs were returned by nvidia-smi.")
    return gpus


class MetricRow(Gtk.Grid):
    """One vertical metric row, with each GPU's thick graph beside the other."""

    def __init__(self, label: str, gpu_count: int):
        super().__init__(column_spacing=12)
        self.label = Gtk.Label(label=label)
        self.label.set_halign(Gtk.Align.START)
        self.label.set_valign(Gtk.Align.CENTER)
        self.label.set_size_request(150, -1)
        self.attach(self.label, 0, 0, 1, 1)
        self.bars = []
        for column in range(gpu_count):
            bar = Gtk.ProgressBar()
            bar.set_show_text(True)
            bar.set_hexpand(True)
            bar.set_size_request(260, 36)
            bar.get_style_context().add_class("telemetry-bar")
            self.attach(bar, column + 1, 0, 1, 1)
            self.bars.append(bar)

    def update(self, values: list[tuple[float, float, str, bool]]) -> None:
        for bar, (value, maximum, text, is_critical) in zip(self.bars, values):
            bar.set_fraction(0.0 if maximum <= 0 else min(value / maximum, 1.0))
            bar.set_text(text)
            context = bar.get_style_context()
            context.remove_class("normal")
            context.remove_class("critical")
            context.add_class("critical" if is_critical else "normal")


class NVGraph(Gtk.Window):
    def __init__(self):
        super().__init__(title="nvgraph — GreenLotus GPU Telemetry")
        self.settings_path = os.path.join(GLib.get_user_config_dir(), APP_DIRECTORY, "settings.json")
        self.saved_position: tuple[int, int] | None = None
        self.current_position: tuple[int, int] | None = None
        self.gpu_indices: list[str] = []
        self.metric_rows: dict[str, MetricRow] = {}
        self.set_border_width(18)
        self.set_default_size(960, 510)
        self.connect("configure-event", self.on_configure)
        self.connect("map-event", self.on_map)
        self.connect("destroy", self.on_destroy)

        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        self.add(root)
        title = Gtk.Label()
        title.set_markup("<span size='x-large' weight='bold'>nvgraph</span>")
        title.set_halign(Gtk.Align.START)
        root.pack_start(title, False, False, 0)
        subtitle = Gtk.Label(label="GreenLotus · local NVIDIA telemetry · live bar graphs")
        subtitle.set_halign(Gtk.Align.START)
        subtitle.get_style_context().add_class("dim-label")
        root.pack_start(subtitle, False, False, 0)

        self.status = Gtk.Label(label="Starting local GPU sample…")
        self.status.set_halign(Gtk.Align.START)
        self.status.set_line_wrap(True)
        root.pack_start(self.status, False, False, 0)

        comparison_frame = Gtk.Frame(label="GPU comparison")
        comparison_frame.set_label_align(0.03, 0.5)
        comparison_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10, margin=12)
        comparison_frame.add(comparison_box)
        self.comparison_grid = Gtk.Grid(row_spacing=12, column_spacing=12)
        comparison_box.pack_start(self.comparison_grid, False, False, 0)
        root.pack_start(comparison_frame, True, True, 0)

        controls = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        self.launch_at_sign_in = Gtk.CheckButton(label="Launch nvgraph at sign-in")
        controls.pack_start(self.launch_at_sign_in, False, False, 0)
        refresh = Gtk.Button(label="Refresh Now")
        refresh.connect("clicked", lambda _button: self.refresh())
        controls.pack_end(refresh, False, False, 0)
        quit_button = Gtk.Button(label="Quit")
        quit_button.connect("clicked", lambda _button: self.destroy())
        controls.pack_end(quit_button, False, False, 0)
        root.pack_start(controls, False, False, 0)

        self.restore_settings()
        self.launch_at_sign_in.connect("toggled", self.on_autostart_toggled)
        self.install_css()
        self.refresh()
        GLib.timeout_add_seconds(REFRESH_SECONDS, self.refresh)

    def install_css(self) -> None:
        css = b"""
        progressbar.telemetry-bar.normal progress { background-color: #2fb344; }
        progressbar.telemetry-bar.critical progress { background-color: #dc3545; }
        progressbar.telemetry-bar trough { min-height: 36px; }
        progressbar.telemetry-bar progress { min-height: 36px; }
        """
        provider = Gtk.CssProvider()
        provider.load_from_data(css)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

    def restore_settings(self) -> None:
        try:
            with open(self.settings_path, encoding="utf-8") as settings_file:
                settings = json.load(settings_file)
        except (OSError, ValueError, TypeError):
            self.set_position(Gtk.WindowPosition.CENTER)
            return
        geometry = settings.get("window", {})
        width, height = geometry.get("width"), geometry.get("height")
        if isinstance(width, int) and isinstance(height, int) and width >= 400 and height >= 350:
            self.resize(width, height)
        x, y = geometry.get("x"), geometry.get("y")
        if settings.get("settings_version") == 1 and isinstance(x, int) and isinstance(y, int):
            self.saved_position = (x, y)
        else:
            self.set_position(Gtk.WindowPosition.CENTER)
        self.launch_at_sign_in.set_active(bool(settings.get("launch_at_sign_in", False)))

    def save_settings(self) -> None:
        width, height = self.get_size()
        x, y = self.current_position or self.get_position()
        settings = {
            "settings_version": 1,
            "window": {"width": width, "height": height, "x": x, "y": y},
            "launch_at_sign_in": self.launch_at_sign_in.get_active(),
        }
        try:
            os.makedirs(os.path.dirname(self.settings_path), exist_ok=True)
            temporary_path = f"{self.settings_path}.tmp"
            with open(temporary_path, "w", encoding="utf-8") as settings_file:
                json.dump(settings, settings_file)
            os.replace(temporary_path, self.settings_path)
        except OSError:
            pass

    def on_autostart_toggled(self, _button: Gtk.CheckButton) -> None:
        try:
            if self.launch_at_sign_in.get_active():
                os.makedirs(os.path.dirname(AUTOSTART_PATH), exist_ok=True)
                with open(AUTOSTART_PATH, "w", encoding="utf-8") as autostart_file:
                    autostart_file.write(
                        "[Desktop Entry]\nType=Application\nName=nvgraph\n"
                        "Comment=GreenLotus GPU telemetry dashboard\n"
                        "Exec=/usr/bin/python3 /home/ricercar/nvgraph/nvgraph.py\n"
                        "Terminal=false\nX-GNOME-Autostart-enabled=true\n"
                    )
            elif os.path.exists(AUTOSTART_PATH):
                os.remove(AUTOSTART_PATH)
        except OSError as error:
            self.status.set_text(f"Could not update launch-at-sign-in preference: {error}")
        self.save_settings()

    def refresh(self) -> bool:
        try:
            gpus = read_gpus()
            self.ensure_comparison_layout(gpus)
            self.metric_rows["temperature"].update([
                (gpu.temperature, TEMPERATURE_LIMIT_C, f"{gpu.temperature:.0f} °C / {TEMPERATURE_LIMIT_C:.0f} °C", gpu.temperature > TEMPERATURE_LIMIT_C)
                for gpu in gpus
            ])
            self.metric_rows["power"].update([
                (gpu.power, gpu.power_limit, f"{gpu.power:.0f} W / {gpu.power_limit:.0f} W", gpu.power > gpu.power_limit)
                for gpu in gpus
            ])
            self.metric_rows["utilization"].update([
                (gpu.utilization, 100.0, f"{gpu.utilization:.0f}%", False) for gpu in gpus
            ])
            self.metric_rows["memory"].update([
                (gpu.memory_used, gpu.memory_total, f"{gpu.memory_used:.0f} / {gpu.memory_total:.0f} MiB", gpu.memory_used > gpu.memory_total)
                for gpu in gpus
            ])
            self.status.set_text(
                f"Last successful sample: {time.strftime('%H:%M:%S')} · refreshes every {REFRESH_SECONDS} seconds · "
                f"red means a reported limit was exceeded"
            )
        except Exception as error:
            self.status.set_text(f"Sample failed: {error}")
        return True

    def ensure_comparison_layout(self, gpus: list[GPU]) -> None:
        indices = [gpu.index for gpu in gpus]
        if indices == self.gpu_indices:
            return
        for child in self.comparison_grid.get_children():
            self.comparison_grid.remove(child)
        self.metric_rows.clear()
        self.gpu_indices = indices

        metric_heading = Gtk.Label()
        metric_heading.set_markup("<b>Metric</b>")
        metric_heading.set_halign(Gtk.Align.START)
        self.comparison_grid.attach(metric_heading, 0, 0, 1, 1)
        for column, gpu in enumerate(gpus, start=1):
            heading = Gtk.Label()
            heading.set_markup(f"<b>GPU {gpu.index}</b> · {gpu.name}")
            heading.set_halign(Gtk.Align.START)
            heading.set_hexpand(True)
            self.comparison_grid.attach(heading, column, 0, 1, 1)

        row_definitions = (
            ("temperature", "Temperature · 80 °C limit"),
            ("power", "Power draw"),
            ("utilization", "GPU utilization"),
            ("memory", "VRAM use"),
        )
        for row_number, (key, label) in enumerate(row_definitions, start=1):
            row = MetricRow(label, len(gpus))
            self.metric_rows[key] = row
            self.comparison_grid.attach(row, 0, row_number, len(gpus) + 1, 1)
        self.comparison_grid.show_all()

    def on_configure(self, _window: Gtk.Window, event: Gdk.EventConfigure) -> bool:
        self.current_position = (event.x, event.y)
        return False

    def on_map(self, _window: Gtk.Window, _event: Gdk.EventAny) -> bool:
        if self.saved_position is not None:
            GLib.timeout_add(100, self.apply_saved_position)
        return False

    def apply_saved_position(self) -> bool:
        if self.saved_position is not None:
            self.move(*self.saved_position)
        return False

    def on_destroy(self, _window: Gtk.Window) -> None:
        self.save_settings()
        Gtk.main_quit()


if __name__ == "__main__":
    window = NVGraph()
    window.show_all()
    window.present()
    Gtk.main()
