"""pyqtgraph real-time multi-channel line chart widget.

Supports 20 ADC channels with distinct colors.
Maintains backward compat via add_point() for single-curve use.
"""

from __future__ import annotations

import numpy as np
import pyqtgraph as pg
from PySide6.QtCore import Slot


# 20 visually distinct colors (Material Design palette)
CHANNEL_COLORS = [
    "#F44336", "#E91E63", "#9C27B0", "#673AB7", "#3F51B5",
    "#2196F3", "#03A9F4", "#00BCD4", "#009688", "#4CAF50",
    "#8BC34A", "#CDDC39", "#FFC107", "#FF9800", "#FF5722",
    "#795548", "#607D8B", "#E53935", "#1E88E5", "#43A047",
]

NUM_CHANNELS = 20
PEN_WIDTH = 1
MAX_POINTS_PER_CHANNEL = 5000


class ChartWidget(pg.PlotWidget):
    """Real-time scrolling multi-channel line chart for ADC data."""

    BUFFER_FLUSH = 100  # legacy compat

    def __init__(self, parent=None) -> None:
        super().__init__(parent, background="w")

        self.setLabel("bottom", "Sample #")
        self.setLabel("left", "ADC Value (12-bit)")
        self.setTitle("Multi-Channel ADC Data")
        self.showGrid(x=True, y=True, alpha=0.3)
        self.addLegend(offset=(10, 10))

        # Per-channel curves
        self._curves: list[pg.PlotDataItem] = []
        self._x_data: list[list[float]] = []
        self._y_data: list[list[float]] = []
        self._sample_counters: list[int] = []

        for ch in range(NUM_CHANNELS):
            color = CHANNEL_COLORS[ch % len(CHANNEL_COLORS)]
            curve = self.plot(
                pen=pg.mkPen(color=color, width=PEN_WIDTH),
                name=f"CH{ch:02d}",
            )
            self._curves.append(curve)
            self._x_data.append([])
            self._y_data.append([])
            self._sample_counters.append(0)

        # Legacy single-curve support
        self._legacy_x: list[float] = []
        self._legacy_y: list[float] = []
        self._legacy_curve = self._curves[0]  # alias to ch0
        self._legacy_count = 0

    def add_channel_point(self, channel_id: int, x: float, y: float) -> None:
        """Add a data point for a specific channel."""
        if not (0 <= channel_id < NUM_CHANNELS):
            return
        xs = self._x_data[channel_id]
        ys = self._y_data[channel_id]
        xs.append(x)
        ys.append(y)
        # Trim if too large
        if len(xs) > MAX_POINTS_PER_CHANNEL:
            trim = len(xs) - MAX_POINTS_PER_CHANNEL
            del xs[:trim]
            del ys[:trim]

    def add_channel_samples(self, channel_id: int, values: list[int]) -> None:
        """Add multiple ADC values for a channel, auto-incrementing x."""
        if not (0 <= channel_id < NUM_CHANNELS):
            return
        for val in values:
            self._sample_counters[channel_id] += 1
            self.add_channel_point(
                channel_id,
                float(self._sample_counters[channel_id]),
                float(val),
            )

    def flush_all(self) -> None:
        """Update all curve visuals from buffered data."""
        for ch in range(NUM_CHANNELS):
            xs = self._x_data[ch]
            ys = self._y_data[ch]
            if xs:
                self._curves[ch].setData(
                    np.array(xs, dtype=np.float64),
                    np.array(ys, dtype=np.float64),
                )

    @Slot(float, float)
    def add_point(self, x: float, y: float) -> None:
        """Legacy single-channel API — maps to channel 0."""
        self.add_channel_point(0, x, y)
        self._legacy_count += 1
        if self._legacy_count % self.BUFFER_FLUSH == 0:
            self.flush_all()

    @Slot()
    def reset(self) -> None:
        """Clear all channels and reset axes."""
        for ch in range(NUM_CHANNELS):
            self._x_data[ch].clear()
            self._y_data[ch].clear()
            self._sample_counters[ch] = 0
            self._curves[ch].setData([], [])
        self._legacy_count = 0
        self.setXRange(0, 100, padding=0)
        self.setYRange(0, 4095, padding=0)
