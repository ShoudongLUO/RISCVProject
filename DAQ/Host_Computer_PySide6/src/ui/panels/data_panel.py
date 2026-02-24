"""ADC Data dashboard panel — 20-channel grid, packet counter, calibration.

Displayed as a tab in the bottom tab widget (not in the top splitter).
"""

from __future__ import annotations

from PySide6.QtCore import Qt, Slot
from PySide6.QtWidgets import (
    QFormLayout,
    QGridLayout,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QScrollArea,
    QVBoxLayout,
    QWidget,
)


_NUM_CHANNELS = 20
_GRID_COLS = 5


class DataPanel(QWidget):
    """ADC Dashboard tab: packet counter + calibration + 20-channel value grid."""

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(8, 8, 8, 8)

        # --- Top row: packet counter + calibration side by side ---
        top_row = QHBoxLayout()

        counter_group = QGroupBox("Packet Counter")
        counter_layout = QVBoxLayout()
        self._counter_label = QLabel("0")
        self._counter_label.setStyleSheet("font-weight: bold; font-size: 14pt;")
        self._counter_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        counter_layout.addWidget(self._counter_label)
        counter_group.setLayout(counter_layout)

        cal_group = QGroupBox("Calibration")
        cal_form = QFormLayout()
        self._baseline_label = QLabel("--")
        self._baseline_label.setStyleSheet("font-weight: bold; font-size: 11pt;")
        self._noise_label = QLabel("--")
        self._noise_label.setStyleSheet("font-weight: bold; font-size: 11pt;")
        cal_form.addRow("Baseline:", self._baseline_label)
        cal_form.addRow("Noise:", self._noise_label)
        cal_group.setLayout(cal_form)

        top_row.addWidget(counter_group)
        top_row.addWidget(cal_group)
        layout.addLayout(top_row)

        # --- 20-channel grid ---
        channels_group = QGroupBox("ADC Channels (20ch)")
        channels_inner = QVBoxLayout()

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setObjectName("channelScroll")

        grid_widget = QWidget()
        grid_layout = QGridLayout(grid_widget)
        grid_layout.setSpacing(6)

        self._channel_labels: list[QLabel] = []
        for ch in range(_NUM_CHANNELS):
            row = ch // _GRID_COLS
            col = ch % _GRID_COLS
            lbl = QLabel(f"CH{ch:02d}: --")
            lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
            lbl.setMinimumWidth(100)
            lbl.setMinimumHeight(36)
            lbl.setStyleSheet(
                "background-color: #E3F2FD; border: 1px solid #BBDEFB; "
                "border-radius: 4px; padding: 4px 6px; font-size: 10pt;"
            )
            grid_layout.addWidget(lbl, row, col)
            self._channel_labels.append(lbl)

        scroll.setWidget(grid_widget)
        channels_inner.addWidget(scroll)
        channels_group.setLayout(channels_inner)

        layout.addWidget(channels_group, stretch=1)

    @property
    def num_channels(self) -> int:
        """Fixed at 20 for the new FPGA format."""
        return _NUM_CHANNELS

    @Slot(int)
    def update_counter(self, value: int) -> None:
        self._counter_label.setText(str(value))

    @Slot(int)
    def update_baseline(self, value: int) -> None:
        self._baseline_label.setText(str(value))

    @Slot(int)
    def update_noise(self, value: int) -> None:
        self._noise_label.setText(str(value))

    def update_channel(self, channel_id: int, adc_value: int) -> None:
        """Update a single channel's displayed value."""
        if 0 <= channel_id < _NUM_CHANNELS:
            voltage = adc_value * 3.3 / 4095.0
            self._channel_labels[channel_id].setText(
                f"CH{channel_id:02d}: {adc_value} ({voltage:.3f}V)"
            )

    def update_channels_batch(self, channel_values: dict[int, int]) -> None:
        """Update multiple channels at once (latest value per channel)."""
        for ch_id, value in channel_values.items():
            self.update_channel(ch_id, value)

    def reset(self) -> None:
        """Clear all displayed values."""
        self._counter_label.setText("0")
        self._baseline_label.setText("--")
        self._noise_label.setText("--")
        for ch in range(_NUM_CHANNELS):
            self._channel_labels[ch].setText(f"CH{ch:02d}: --")
