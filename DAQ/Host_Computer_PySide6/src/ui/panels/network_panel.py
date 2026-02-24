"""Network configuration panel — Host IP/Port, Destination IP/Port, Start/ReBind/Stop."""

from __future__ import annotations

from PySide6.QtCore import Signal
from PySide6.QtWidgets import (
    QFormLayout,
    QGroupBox,
    QHBoxLayout,
    QLineEdit,
    QPushButton,
    QVBoxLayout,
    QWidget,
)


class NetworkPanel(QWidget):
    """Left panel: network configuration and connection controls."""

    start_requested = Signal(str, int, str, int)  # host_ip, host_port, dest_ip, dest_port
    rebind_requested = Signal()
    stop_requested = Signal()

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(4, 4, 4, 4)

        # --- Host configuration ---
        host_group = QGroupBox("Host Configuration")
        host_form = QFormLayout()
        self._host_ip = QLineEdit("192.168.185.243")
        self._host_port = QLineEdit("1234")
        host_form.addRow("IP Address:", self._host_ip)
        host_form.addRow("Port:", self._host_port)
        host_group.setLayout(host_form)

        # --- Destination configuration ---
        dest_group = QGroupBox("FPGA Destination")
        dest_form = QFormLayout()
        self._dest_ip = QLineEdit("192.168.185.111")
        self._dest_port = QLineEdit("1234")
        dest_form.addRow("IP Address:", self._dest_ip)
        dest_form.addRow("Port:", self._dest_port)
        dest_group.setLayout(dest_form)

        # --- Buttons ---
        btn_layout = QHBoxLayout()
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

    @property
    def dest_ip(self) -> str:
        return self._dest_ip.text()

    @property
    def dest_port(self) -> int:
        return int(self._dest_port.text() or "0")
