"""Network configuration panel — Host IP/Port, Destination IP/Port, Start/ReBind/Stop.

Dark scientific instrument styling with LED-like status indicators.
"""

from __future__ import annotations

from PySide6.QtCore import Signal, Qt
from PySide6.QtWidgets import (
    QFormLayout,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QPushButton,
    QVBoxLayout,
    QWidget,
)


class _StatusLed(QLabel):
    """Tiny circular LED indicator for connection status."""

    _STYLES = {
        "off": "background-color: #33384a; border: 1px solid #555e6e;",
        "on": "background-color: #00e676; border: 1px solid #00c853;",
        "error": "background-color: #ff5252; border: 1px solid #d32f2f;",
    }

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setFixedSize(12, 12)
        self.set_state("off")

    def set_state(self, state: str) -> None:
        base = self._STYLES.get(state, self._STYLES["off"])
        self.setStyleSheet(f"{base} border-radius: 6px; min-width: 12px; min-height: 12px;")


class NetworkPanel(QWidget):
    """Left panel: network configuration and connection controls."""

    start_requested = Signal(str, int, str, int)  # host_ip, host_port, dest_ip, dest_port
    rebind_requested = Signal()
    stop_requested = Signal()

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(4, 4, 4, 4)
        layout.setSpacing(6)

        # --- Connection status ---
        status_row = QHBoxLayout()
        self._led = _StatusLed()
        self._status_label = QLabel("Disconnected")
        self._status_label.setStyleSheet(
            "color: #6b7280; font-size: 9pt; font-family: 'Consolas', monospace;"
        )
        status_row.addWidget(self._led)
        status_row.addWidget(self._status_label)
        status_row.addStretch()
        layout.addLayout(status_row)

        # --- Host configuration ---
        host_group = QGroupBox("Host")
        host_form = QFormLayout()
        host_form.setSpacing(6)
        self._host_ip = QLineEdit("192.168.185.243")
        self._host_port = QLineEdit("1234")
        self._host_ip.setMinimumHeight(28)
        self._host_port.setMinimumHeight(28)
        host_form.addRow("IP:", self._host_ip)
        host_form.addRow("Port:", self._host_port)
        host_group.setLayout(host_form)

        # --- Destination configuration ---
        dest_group = QGroupBox("FPGA Destination")
        dest_form = QFormLayout()
        dest_form.setSpacing(6)
        self._dest_ip = QLineEdit("192.168.185.111")
        self._dest_port = QLineEdit("1234")
        self._dest_ip.setMinimumHeight(28)
        self._dest_port.setMinimumHeight(28)
        dest_form.addRow("IP:", self._dest_ip)
        dest_form.addRow("Port:", self._dest_port)
        dest_group.setLayout(dest_form)

        # --- Buttons ---
        btn_layout = QHBoxLayout()
        btn_layout.setSpacing(4)
        self._btn_start = QPushButton("Start")
        self._btn_rebind = QPushButton("ReBind")
        self._btn_stop = QPushButton("Stop")
        self._btn_stop.setProperty("cssClass", "danger")
        btn_layout.addWidget(self._btn_start)
        btn_layout.addWidget(self._btn_rebind)
        btn_layout.addWidget(self._btn_stop)

        layout.addWidget(host_group)
        layout.addWidget(dest_group)
        layout.addLayout(btn_layout)
        layout.addStretch()

        # --- Connections ---
        self._btn_start.clicked.connect(self._on_start)
        self._btn_rebind.clicked.connect(self.rebind_requested)
        self._btn_stop.clicked.connect(self.stop_requested)

    def _on_start(self) -> None:
        self.start_requested.emit(
            self._host_ip.text(),
            int(self._host_port.text() or "0"),
            self._dest_ip.text(),
            int(self._dest_port.text() or "0"),
        )

    def set_connected(self, connected: bool) -> None:
        """Update LED and status text."""
        if connected:
            self._led.set_state("on")
            self._status_label.setText("Connected")
            self._status_label.setStyleSheet(
                "color: #69f0ae; font-size: 9pt; font-family: 'Consolas', monospace;"
            )
        else:
            self._led.set_state("off")
            self._status_label.setText("Disconnected")
            self._status_label.setStyleSheet(
                "color: #6b7280; font-size: 9pt; font-family: 'Consolas', monospace;"
            )

    @property
    def host_ip(self) -> str:
        return self._host_ip.text()

    @property
    def host_port(self) -> int:
        return int(self._host_port.text() or "0")

    @property
    def dest_ip(self) -> str:
        return self._dest_ip.text()

    @property
    def dest_port(self) -> int:
        return int(self._dest_port.text() or "0")
