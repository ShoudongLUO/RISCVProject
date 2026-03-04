"""TDC chart panel — Delta-T histogram + coincidence timeline.

Uses pyqtgraph for real-time plotting.
Dark scientific instrument styling with neon accent colors.
Supports batch updates to avoid per-item repaints.
"""

from __future__ import annotations

from typing import Sequence

import numpy as np
import pyqtgraph as pg
from PySide6.QtGui import QColor, QFont
from PySide6.QtWidgets import QVBoxLayout, QWidget

from ...core.models import CoincidenceMatch

HIST_BINS = 60
HIST_RANGE = (-3000, 3000)  # +/- 3000 ps
TIMELINE_MAX_POINTS = 5000

_BG_COLOR = "#181b20"
_AXIS_COLOR = "#6b7280"
_TITLE_COLOR = "#00e5ff"


def _style_plot(plot: pg.PlotWidget, title: str) -> None:
    """Apply consistent dark scientific styling to a plot widget."""
    axis_font = QFont("Consolas", 9)
    for axis_name in ("bottom", "left"):
        axis = plot.getAxis(axis_name)
        axis.setPen(pg.mkPen(_AXIS_COLOR, width=1))
        axis.setTextPen(pg.mkPen(_AXIS_COLOR))
        axis.setTickFont(axis_font)

    plot.getPlotItem().titleLabel.setText(title, color=_TITLE_COLOR)
    plot.showGrid(x=True, y=True, alpha=0.15)
    plot.getPlotItem().getViewBox().setBackgroundColor(QColor(_BG_COLOR))


class TdcChartPanel(QWidget):
    """TDC Charts tab: delta-T histogram (top) + coincidence timeline (bottom)."""

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(4, 4, 4, 4)

        # --- Histogram ---
        self._hist_plot = pg.PlotWidget(background=_BG_COLOR)
        _style_plot(self._hist_plot, "Delta-T Histogram")
        self._hist_plot.setLabel("bottom", "Delta-T (ps)", color=_AXIS_COLOR)
        self._hist_plot.setLabel("left", "Count", color=_AXIS_COLOR)

        self._hist_data = np.zeros(HIST_BINS, dtype=np.int64)
        self._bin_edges = np.linspace(HIST_RANGE[0], HIST_RANGE[1], HIST_BINS + 1)
        self._bin_centers = (self._bin_edges[:-1] + self._bin_edges[1:]) / 2.0
        self._hist_bar = pg.BarGraphItem(
            x=self._bin_centers,
            height=self._hist_data.astype(float),
            width=(HIST_RANGE[1] - HIST_RANGE[0]) / HIST_BINS * 0.85,
            brush=pg.mkBrush(0, 229, 255, 120),  # cyan with transparency
            pen=pg.mkPen("#00838f", width=1),
        )
        self._hist_plot.addItem(self._hist_bar)

        # --- Timeline ---
        self._timeline_plot = pg.PlotWidget(background=_BG_COLOR)
        _style_plot(self._timeline_plot, "Coincidence Timeline")
        self._timeline_plot.setLabel("bottom", "Match #", color=_AXIS_COLOR)
        self._timeline_plot.setLabel("left", "Delta-T (ps)", color=_AXIS_COLOR)

        self._tl_curve = self._timeline_plot.plot(
            pen=pg.mkPen("#ffd740", width=1),
            symbol="o",
            symbolSize=3,
            symbolBrush="#ffd740",
            symbolPen=None,
        )
        self._tl_x: list[float] = []
        self._tl_y: list[float] = []
        self._match_index = 0

        layout.addWidget(self._hist_plot, stretch=1)
        layout.addWidget(self._timeline_plot, stretch=1)

    def add_coincidences(self, matches: Sequence[CoincidenceMatch]) -> None:
        """Add a batch of coincidence matches — repaints only once at the end."""
        if not matches:
            return

        for match in matches:
            dtm = match.time_diff_ps

            # Accumulate into histogram bins (no repaint yet)
            bin_idx = int(np.searchsorted(self._bin_edges, dtm, side="right")) - 1
            if 0 <= bin_idx < HIST_BINS:
                self._hist_data[bin_idx] += 1

            # Accumulate into timeline data (no repaint yet)
            self._match_index += 1
            self._tl_x.append(float(self._match_index))
            self._tl_y.append(float(dtm))

        # Trim timeline if needed
        if len(self._tl_x) > TIMELINE_MAX_POINTS:
            self._tl_x = self._tl_x[-TIMELINE_MAX_POINTS:]
            self._tl_y = self._tl_y[-TIMELINE_MAX_POINTS:]

        # Single repaint for histogram + timeline
        self._hist_bar.setOpts(height=self._hist_data.astype(float))
        self._tl_curve.setData(self._tl_x, self._tl_y)

    def reset(self) -> None:
        """Clear histogram and timeline."""
        self._hist_data[:] = 0
        self._hist_bar.setOpts(height=self._hist_data.astype(float))
        self._tl_x.clear()
        self._tl_y.clear()
        self._tl_curve.setData([], [])
        self._match_index = 0
