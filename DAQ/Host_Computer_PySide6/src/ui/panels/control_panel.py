"""Control panel — mode buttons, UART debug, reset, file send.

Dark scientific instrument styling with mode indicator and grouped controls.
Uses QScrollArea to prevent overlap in narrow panel widths.
"""

from __future__ import annotations

from PySide6.QtCore import Qt, Signal, Slot
from PySide6.QtWidgets import (
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QPushButton,
    QScrollArea,
    QVBoxLayout,
    QWidget,
)

from ...core.protocol import DeviceMode


class ControlPanel(QWidget):
    """Right panel: mode control, UART debug, reset, data file operations."""

    mode_change_requested = Signal(DeviceMode)
    stop_procedure_requested = Signal()
    uart_debug_toggled = Signal(bool)
    reset_requested = Signal()
    reset_figure_requested = Signal()
    send_adc_requested = Signal(str)  # file path / name

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        outer_layout = QVBoxLayout(self)
        outer_layout.setContentsMargins(0, 0, 0, 0)

        # Wrap everything in a scroll area to prevent overlap
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)

        inner = QWidget()
        layout = QVBoxLayout(inner)
        layout.setContentsMargins(4, 4, 4, 4)
        layout.setSpacing(6)

        # --- Mode control ---
        mode_group = QGroupBox("Device Mode")
        mode_layout = QVBoxLayout()
        mode_layout.setSpacing(6)

        self._mode_label = QLabel("IDLE")
        self._mode_label.setObjectName("modeLabel")

        self._btn_idle = QPushButton("IDLE")
        self._btn_calibration = QPushButton("Calibration")
        self._btn_data_acquire = QPushButton("DataAcquire")
        self._btn_stop_proc = QPushButton("Stop Procedure")
        self._btn_stop_proc.setProperty("cssClass", "danger")

        mode_layout.addWidget(self._mode_label)

        mode_btn_row = QHBoxLayout()
        mode_btn_row.setSpacing(4)
        mode_btn_row.addWidget(self._btn_idle)
        mode_btn_row.addWidget(self._btn_calibration)
        mode_layout.addLayout(mode_btn_row)

        mode_btn_row2 = QHBoxLayout()
        mode_btn_row2.setSpacing(4)
        mode_btn_row2.addWidget(self._btn_data_acquire)
        mode_btn_row2.addWidget(self._btn_stop_proc)
        mode_layout.addLayout(mode_btn_row2)
        mode_group.setLayout(mode_layout)

        # --- UART Debug ---
        debug_group = QGroupBox("Debug")
        debug_layout = QVBoxLayout()
        debug_layout.setSpacing(4)
        self._btn_uart_debug = QPushButton("Start Debug")
        self._btn_uart_debug.setCheckable(True)
        debug_layout.addWidget(self._btn_uart_debug)
        debug_group.setLayout(debug_layout)

        # --- Figure / Reset ---
        tools_group = QGroupBox("Tools")
        tools_layout = QHBoxLayout()
        tools_layout.setSpacing(4)
        self._btn_reset_figure = QPushButton("Reset Figure")
        self._btn_reset = QPushButton("System Reset")
        self._btn_reset.setProperty("cssClass", "danger")
        tools_layout.addWidget(self._btn_reset_figure)
        tools_layout.addWidget(self._btn_reset)
        tools_group.setLayout(tools_layout)

        # --- File / Send ---
        file_group = QGroupBox("Data File")
        file_layout = QVBoxLayout()
        file_layout.setSpacing(4)
        self._file_name = QLineEdit("ReceivedData")
        self._file_name.setPlaceholderText("File name...")
        self._btn_send_adc = QPushButton("Send Data")
        file_layout.addWidget(self._file_name)
        file_layout.addWidget(self._btn_send_adc)
        file_group.setLayout(file_layout)

        layout.addWidget(mode_group)
        layout.addWidget(debug_group)
        layout.addWidget(tools_group)
        layout.addWidget(file_group)
        layout.addStretch()

        scroll.setWidget(inner)
        outer_layout.addWidget(scroll)

        # --- Connections ---
        self._btn_idle.clicked.connect(
            lambda: self.mode_change_requested.emit(DeviceMode.IDLE)
        )
        self._btn_calibration.clicked.connect(
            lambda: self.mode_change_requested.emit(DeviceMode.CALIBRATION)
        )
        self._btn_data_acquire.clicked.connect(
            lambda: self.mode_change_requested.emit(DeviceMode.DATA_ACQUIRE)
        )
        self._btn_stop_proc.clicked.connect(self.stop_procedure_requested)
        self._btn_uart_debug.toggled.connect(self._on_uart_debug_toggled)
        self._btn_reset.clicked.connect(self.reset_requested)
        self._btn_reset_figure.clicked.connect(self.reset_figure_requested)
        self._btn_send_adc.clicked.connect(self._on_send_adc)

    def _on_uart_debug_toggled(self, checked: bool) -> None:
        self._btn_uart_debug.setText("Stop Debug" if checked else "Start Debug")
        self.uart_debug_toggled.emit(checked)

    def _on_send_adc(self) -> None:
        self.send_adc_requested.emit(self._file_name.text())

    @Slot(str)
    def update_mode(self, mode_text: str) -> None:
        self._mode_label.setText(mode_text)

    @property
    def current_mode_text(self) -> str:
        return self._mode_label.text()

    @property
    def file_name(self) -> str:
        return self._file_name.text()
