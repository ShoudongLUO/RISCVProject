"""pyqtgraph real-time multi-channel line chart widget.

Supports 20 ADC channels with distinct colors.
Dark scientific instrument styling with neon trace colors.
Maintains backward compat via add_point() for single-curve use.
"""

from __future__ import annotations

import numpy as np
import pyqtgraph as pg
from PySide6.QtCore import Slot
from PySide6.QtGui import QColor, QFont


# 20 visually distinct neon/scientific colors for dark background
CHANNEL_COLORS = [
    "#00e5ff",  # cyan
    "#ff4081",  # pink
    "#69f0ae",  # green
    "#ffd740",  # amber
    "#7c4dff",  # deep purple
    "#ff6e40",  # deep orange
    "#18ffff",  # cyan accent
    "#b388ff",  # purple accent
    "#64ffda",  # teal accent
    "#ffff00",  # yellow
    "#ea80fc",  # purple light
    "#84ffff",  # cyan light
    "#b9f6ca",  # green light
    "#ff80ab",  # pink light
    "#8c9eff",  # indigo light
    "#ffe57f",  # amber light
    "#a7ffeb",  # teal light
    "#ff9e80",  # orange light
    "#80d8ff",  # light blue
    "#ccff90",  # light green
]

NUM_CHANNELS = 20
PEN_WIDTH = 1
MAX_POINTS_PER_CHANNEL = 5000

# Dark background color matching the QSS theme
_BG_COLOR = "#181b20"
_GRID_COLOR = (50, 60, 80, 100)  # RGBA — subtle blue-tinted grid
_AXIS_COLOR = "#6b7280"
_TITLE_COLOR = "#00e5ff"


class ChartWidget(pg.PlotWidget):
    """Real-time scrolling multi-channel line chart for ADC data."""

    BUFFER_FLUSH = 100  # legacy compat

    def __init__(self, parent=None) -> None:
        super().__init__(parent, background=_BG_COLOR)

        # Axis styling
        title_font = QFont("Segoe UI", 11, QFont.Weight.Bold)
        axis_font = QFont("Consolas", 9)

        for axis_name in ("bottom", "left"):
            axis = self.getAxis(axis_name)
            axis.setPen(pg.mkPen(_AXIS_COLOR, width=1))
            axis.setTextPen(pg.mkPen(_AXIS_COLOR))
            axis.setTickFont(axis_font)

        self.setLabel("bottom", "Sample #", color=_AXIS_COLOR)
        self.setLabel("left", "ADC Value (12-bit)", color=_AXIS_COLOR)

        title_item = self.getPlotItem().titleLabel
        title_item.setText("Multi-Channel ADC Data", color=_TITLE_COLOR)

        self.showGrid(x=True, y=True, alpha=0.15)
        self.getPlotItem().getViewBox().setBackgroundColor(QColor(_BG_COLOR))

        legend = self.addLegend(offset=(10, 10))
        legend.setLabelTextColor(_AXIS_COLOR)

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
