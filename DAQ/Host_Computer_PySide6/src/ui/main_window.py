"""QMainWindow — layout assembly + signal wiring.

Translates the MainWindow constructor, readDatagram() UI logic,
and all slot connections from mainwindow.cpp.

Updated for 20-channel ADC, TDC events, coincidence, and new packet format.
"""

from __future__ import annotations

import traceback

from PySide6.QtCore import Slot
from PySide6.QtWidgets import (
    QMainWindow,
    QSplitter,
    QTabWidget,
    QVBoxLayout,
    QWidget,
)
from PySide6.QtCore import Qt

from ..core.adc_parser import demux_frame_by_channel
from ..core.data_parser import parse_datagram
from ..core.models import AppState
from ..core.protocol import CommandFlag, DeviceMode, PacketType, generate_command
from ..logging_.log_handler import AppLogger
from ..network.adc_sender import AdcSender
from ..network.retry_manager import RetryManager
from ..network.udp_manager import UdpManager
from .chart_widget import ChartWidget
from .panels.control_panel import ControlPanel
from .panels.data_panel import DataPanel
from .panels.log_panel import LogPanel
from .panels.network_panel import NetworkPanel
from .panels.tdc_chart_panel import TdcChartPanel
from .panels.tdc_panel import TdcPanel

# Only plot every Nth ADC packet to avoid UI overload
ADC_CHART_DECIMATION = 100


class MainWindow(QMainWindow):
    """Main application window — assembles panels, chart, and wires signals."""

    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle("FPGA Data Acquisition")
        self.setMinimumSize(1100, 700)

        # --- State ---
        self._state = AppState()
        self._time_counter: int = 0
        self._adc_packet_counter: int = 0
        self._data_file = None
        self._uart_debug_active: bool = False

        # --- Core services ---
        self._logger = AppLogger(parent=self)
        self._udp = UdpManager(parent=self)
        self._retry = RetryManager(parent=self)
        self._adc_sender = AdcSender(parent=self)

        # --- Build UI ---
        self._build_ui()
        self._wire_signals()

        self._logger.debug("System initialised")

    def _build_ui(self) -> None:
        central = QWidget()
        self.setCentralWidget(central)
        root_layout = QVBoxLayout(central)
        root_layout.setContentsMargins(6, 6, 6, 6)

        # Top panels: Network | Log | Control (3 panels, no data panel)
        self._splitter = QSplitter(Qt.Orientation.Horizontal)

        self._network_panel = NetworkPanel()
        self._log_panel = LogPanel()
        self._control_panel = ControlPanel()

        self._splitter.addWidget(self._network_panel)
        self._splitter.addWidget(self._log_panel)
        self._splitter.addWidget(self._control_panel)
        self._splitter.setSizes([220, 500, 250])

        # Bottom tabs: ADC Chart | ADC Dashboard | TDC Charts | TDC Dashboard
        self._tabs = QTabWidget()
        self._chart = ChartWidget()
        self._data_panel = DataPanel()
        self._tdc_chart_panel = TdcChartPanel()
        self._tdc_panel = TdcPanel()

        self._tabs.addTab(self._chart, "ADC Chart")
        self._tabs.addTab(self._data_panel, "ADC Dashboard")
        self._tabs.addTab(self._tdc_chart_panel, "TDC Charts")
        self._tabs.addTab(self._tdc_panel, "TDC Dashboard")

        root_layout.addWidget(self._splitter, stretch=0)
        root_layout.addWidget(self._tabs, stretch=1)

        # Status bar
        self.statusBar().showMessage("Disconnected")

    def _wire_signals(self) -> None:
        # Network panel
        self._network_panel.start_requested.connect(self._on_start)
        self._network_panel.rebind_requested.connect(self._on_rebind)
        self._network_panel.stop_requested.connect(self._on_stop)

        # UDP manager
        self._udp.datagram_received.connect(self._on_datagram)
        self._udp.bind_success.connect(self._on_bind_success)
        self._udp.bind_failed.connect(self._on_bind_failed)
        self._udp.send_complete.connect(
            lambda n: self._logger.debug(
                f"Sent {n} bytes to {self._network_panel.dest_ip}:{self._network_panel.dest_port}"
            )
        )
        self._udp.send_failed.connect(
            lambda msg: self._logger.error(f"Send failed: {msg}")
        )

        # Retry manager
        self._retry.retry_requested.connect(self._on_retry)
        self._retry.max_retries_reached.connect(
            lambda: self._logger.warning("Max retries reached, stopping")
        )

        # Control panel
        self._control_panel.mode_change_requested.connect(self._on_mode_change)
        self._control_panel.stop_procedure_requested.connect(self._on_stop_procedure)
        self._control_panel.uart_debug_toggled.connect(self._on_uart_debug)
        self._control_panel.reset_requested.connect(self._on_reset)
        self._control_panel.reset_figure_requested.connect(self._on_reset_figure)
        self._control_panel.send_adc_requested.connect(self._on_send_adc)

        # ADC sender
        self._adc_sender.packet_ready.connect(
            lambda pkt: self._udp.send(
                pkt, self._network_panel.dest_ip, self._network_panel.dest_port
            )
        )
        self._adc_sender.send_complete.connect(
            lambda n: self._logger.debug(f"Finished sending {n} lines of ADC data")
        )
        self._adc_sender.send_failed.connect(
            lambda msg: self._logger.error(f"ADC send error: {msg}")
        )

        # Logger -> log panel
        self._logger.message_logged.connect(self._log_panel.append_message)

    # ---- Slots ----

    @Slot(str, int, str, int)
    def _on_start(
        self, host_ip: str, host_port: int, dest_ip: str, dest_port: int
    ) -> None:
        file_name = self._control_panel.file_name + ".bin"
        try:
            self._data_file = open(file_name, "ab")
            self._logger.debug(f"Data will be saved to {file_name}")
        except OSError as e:
            self._logger.error(f"Data file open failed: {e}")

        self._udp.bind(host_ip, host_port)

    @Slot()
    def _on_rebind(self) -> None:
        host_ip = self._network_panel._host_ip.text()
        host_port = int(self._network_panel._host_port.text() or "0")
        self._udp.rebind(host_ip, host_port)

    @Slot()
    def _on_stop(self) -> None:
        self._udp.close()
        if self._data_file is not None:
            self._data_file.close()
            self._data_file = None
        self.statusBar().showMessage("Disconnected")
        self._logger.debug("UDP socket unbound")

    @Slot(str, int)
    def _on_bind_success(self, host: str, port: int) -> None:
        self.statusBar().showMessage(f"Listening on {host}:{port}")
        self._logger.debug(f"IPAddress {host} Port {port}")

    @Slot(str)
    def _on_bind_failed(self, msg: str) -> None:
        self.statusBar().showMessage("Bind failed")
        self._logger.error(msg)

    @Slot(bytes)
    def _on_datagram(self, data: bytes) -> None:
        """Central dispatcher — parse and route to appropriate UI.

        Wrapped in try/except so a parsing or UI error never crashes the app.
        """
        try:
            self._dispatch_datagram(data)
        except Exception:
            self._logger.error(f"Datagram handler error:\n{traceback.format_exc()}")

    def _dispatch_datagram(self, data: bytes) -> None:
        """Actual dispatch logic, called from _on_datagram."""
        num_ch = self._data_panel.num_channels
        result = parse_datagram(data, num_channels=num_ch)

        # --- New-format packets ---
        if not result.is_legacy and result.packet_type is not None:
            self._data_panel.update_counter(result.counter)

            if result.packet_type == PacketType.ADC:
                self._handle_adc_packet(result)

            elif result.packet_type == PacketType.TDC_EVENT:
                for event in result.tdc_events:
                    self._tdc_panel.update_tdc_event(event)

            elif result.packet_type == PacketType.TDC_COINCIDENCE:
                # Batch: update numeric stats per-item, chart once at end
                for match in result.coincidence_matches:
                    self._tdc_panel.update_coincidence(match)
                self._tdc_chart_panel.add_coincidences(result.coincidence_matches)

            elif result.packet_type == PacketType.CALIBRATION:
                if result.calibration is not None:
                    self._data_panel.update_baseline(result.calibration.baseline)
                    self._data_panel.update_noise(result.calibration.noise)
                    self._logger.debug(
                        f"[CAL] baseline={result.calibration.baseline} "
                        f"noise={result.calibration.noise}"
                    )

            elif result.packet_type == PacketType.MODE_ACK:
                if result.mode_ack is not None:
                    self._handle_mode_ack(result.mode_ack.mode)

        # --- Legacy format ---
        else:
            self._handle_legacy(result)

        # Save raw data
        if self._data_file is not None:
            self._data_file.write(data)
            self._data_file.flush()

        # Data-detected ack (only for new-format packets, not legacy)
        if not result.is_legacy:
            current_mode = self._state.current_mode
            if current_mode in (DeviceMode.CALIBRATION, DeviceMode.DATA_ACQUIRE):
                ack = generate_command(current_mode, CommandFlag.DATA_DETECTED)
                ack += generate_command(current_mode, CommandFlag.NONE)
                self._udp.send(
                    ack,
                    self._network_panel.dest_ip,
                    self._network_panel.dest_port,
                )

    def _handle_adc_packet(self, result) -> None:
        """Process a new-format ADC packet."""
        frame = result.adc_frame
        if frame is None:
            return

        # Update per-channel values in data panel
        channel_map = demux_frame_by_channel(frame)
        latest: dict[int, int] = {}
        for ch_id, vals in channel_map.items():
            if vals:
                latest[ch_id] = vals[-1]
        self._data_panel.update_channels_batch(latest)

        # Decimated chart update
        self._adc_packet_counter += 1
        if self._adc_packet_counter % ADC_CHART_DECIMATION == 0:
            for ch_id, vals in channel_map.items():
                if vals:
                    self._chart.add_channel_samples(ch_id, vals)
            self._chart.flush_all()

    def _handle_mode_ack(self, mode: DeviceMode) -> None:
        """Process a mode acknowledgement."""
        display_names = {
            DeviceMode.IDLE: "IDLE",
            DeviceMode.CALIBRATION: "Calibration",
            DeviceMode.DATA_ACQUIRE: "DataAcquire",
        }
        display = display_names.get(mode, mode.name)
        self._control_panel.update_mode(display)
        self._state = AppState(
            current_mode=mode,
            uart_debug_active=self._uart_debug_active,
            is_listening=True,
            data_file_name=self._control_panel.file_name,
        )
        self._retry.confirm()
        self._logger.debug(f"Mode confirmed: {display}")

    def _handle_legacy(self, result) -> None:
        """Process a legacy-format datagram (backward compat)."""
        if result.legacy_baseline is not None:
            self._logger.debug(
                f"[UDP] Received packet, size: {result.raw_size} bytes"
            )
            self._data_panel.update_baseline(result.legacy_baseline)
            self._data_panel.update_noise(result.legacy_noise)

        if result.legacy_mode_confirmed is not None:
            self._handle_mode_ack(result.legacy_mode_confirmed)

        # Chart update — every 10000th sample
        for val in result.legacy_adc_values:
            self._time_counter += 1
            if self._time_counter % 10000 == 0:
                self._chart.add_point(
                    float(self._time_counter), float(val & 0xFF)
                )

    @Slot(DeviceMode)
    def _on_mode_change(self, mode: DeviceMode) -> None:
        cmd = generate_command(mode)
        self._udp.send(
            cmd, self._network_panel.dest_ip, self._network_panel.dest_port
        )

        display_names = {
            DeviceMode.IDLE: "IDLE",
            DeviceMode.CALIBRATION: "Calibration",
            DeviceMode.DATA_ACQUIRE: "DataAcquire",
        }
        expected = display_names.get(mode, mode.name)

        if self._control_panel._mode_label.text() != expected:
            self._retry.start(cmd)

    @Slot()
    def _on_stop_procedure(self) -> None:
        stop_cmd = generate_command(DeviceMode.IDLE, CommandFlag.STOP)
        stop_cmd += generate_command(DeviceMode.IDLE)
        self._udp.send(
            stop_cmd, self._network_panel.dest_ip, self._network_panel.dest_port
        )
        self._control_panel.update_mode("IDLE")
        self._state = AppState(
            current_mode=DeviceMode.IDLE,
            uart_debug_active=self._uart_debug_active,
            is_listening=self._state.is_listening,
            data_file_name=self._control_panel.file_name,
        )

    @Slot(bool)
    def _on_uart_debug(self, active: bool) -> None:
        self._uart_debug_active = active
        flags = CommandFlag.UART_DEBUG if active else CommandFlag.NONE
        cmd = generate_command(DeviceMode.IDLE, flags)
        for _ in range(5):
            self._udp.send(
                cmd, self._network_panel.dest_ip, self._network_panel.dest_port
            )

    @Slot()
    def _on_reset(self) -> None:
        cmd = generate_command(DeviceMode.IDLE)
        cmd += generate_command(DeviceMode.IDLE, CommandFlag.RESET)
        self._udp.send(
            cmd, self._network_panel.dest_ip, self._network_panel.dest_port
        )

    @Slot()
    def _on_reset_figure(self) -> None:
        """Reset all tabs."""
        self._chart.reset()
        self._tdc_chart_panel.reset()
        self._tdc_panel.reset()
        self._data_panel.reset()
        self._adc_packet_counter = 0
        self._time_counter = 0

    @Slot(bytes)
    def _on_retry(self, command: bytes) -> None:
        self._logger.debug("Retrying command send...")
        self._udp.send(
            command, self._network_panel.dest_ip, self._network_panel.dest_port
        )

    @Slot(str)
    def _on_send_adc(self, name: str) -> None:
        file_path = "D:/RISCV_Project/fpga/Data/temp/output.csv"
        self._adc_sender.send_file(file_path)

    def closeEvent(self, event) -> None:
        """Clean up on window close."""
        self._udp.close()
        self._retry.stop()
        if self._data_file is not None:
            self._data_file.close()
            self._data_file = None
        super().closeEvent(event)
