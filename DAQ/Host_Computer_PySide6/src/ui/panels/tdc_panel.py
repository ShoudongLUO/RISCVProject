"""TDC numeric dashboard panel — per-channel ticks, coincidence stats.

Dark scientific instrument styling with monospace data readouts
and color-coded coincidence statistics.
"""

from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QFormLayout,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QVBoxLayout,
    QWidget,
)

from ...core.models import CoincidenceMatch, TdcEvent

_VALUE_STYLE = (
    "font-weight: bold; font-size: 12pt; color: #00e5ff; "
    "font-family: 'Consolas', 'Cascadia Mono', monospace;"
)
_STAT_STYLE = (
    "font-weight: bold; font-size: 11pt; color: #69f0ae; "
    "font-family: 'Consolas', monospace;"
)
_COUNT_STYLE = (
    "font-weight: bold; color: #ffd740; "
    "font-family: 'Consolas', monospace;"
)


class TdcPanel(QWidget):
    """TDC Dashboard tab: dual-channel numeric readout + coincidence stats."""

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(6, 6, 6, 6)

        # --- TDC Channel readouts (side by side) ---
        channels_row = QHBoxLayout()
        self._ch_groups: list[dict[str, QLabel]] = []

        for ch in range(2):
            group = QGroupBox(f"TDC Channel {ch}")
            form = QFormLayout()
            form.setSpacing(6)
            labels: dict[str, QLabel] = {}
            for field_name in ("TOT", "TOA", "CAL", "LSB (ps)", "Flags"):
                lbl = QLabel("--")
                lbl.setStyleSheet(_VALUE_STYLE)
                form.addRow(f"{field_name}:", lbl)
                labels[field_name] = lbl
            event_count_lbl = QLabel("0")
            event_count_lbl.setStyleSheet(_COUNT_STYLE)
            form.addRow("Events:", event_count_lbl)
            labels["Events"] = event_count_lbl
            group.setLayout(form)
            channels_row.addWidget(group)
            self._ch_groups.append(labels)

        layout.addLayout(channels_row)

        # --- Coincidence stats ---
        coinc_group = QGroupBox("Coincidence")
        coinc_form = QFormLayout()
        coinc_form.setSpacing(8)

        self._dtm_label = QLabel("--")
        self._dtm_label.setStyleSheet(
            "font-weight: bold; font-size: 14pt; color: #ff4081; "
            "font-family: 'Consolas', 'Cascadia Mono', monospace;"
        )
        coinc_form.addRow("Delta-T (ps):", self._dtm_label)

        self._coinc_count_label = QLabel("0")
        self._coinc_count_label.setStyleSheet(_COUNT_STYLE)
        coinc_form.addRow("Total matches:", self._coinc_count_label)

        self._mean_dtm_label = QLabel("--")
        self._mean_dtm_label.setStyleSheet(_STAT_STYLE)
        coinc_form.addRow("Mean Delta-T:", self._mean_dtm_label)

        self._std_dtm_label = QLabel("--")
        self._std_dtm_label.setStyleSheet(_STAT_STYLE)
        coinc_form.addRow("Std Dev:", self._std_dtm_label)

        coinc_group.setLayout(coinc_form)
        layout.addWidget(coinc_group)
        layout.addStretch()

        # Running stats
        self._event_counts = [0, 0]
        self._coinc_total = 0
        self._dtm_sum: float = 0.0
        self._dtm_sq_sum: float = 0.0

    def update_tdc_event(self, event: TdcEvent) -> None:
        """Update the readout for a single TDC event."""
        ch = event.channel_id
        if ch not in (0, 1):
            return
        labels = self._ch_groups[ch]
        labels["TOT"].setText(str(event.tot_ticks))
        labels["TOA"].setText(str(event.toa_ticks))
        labels["CAL"].setText(str(event.cal_ticks))
        labels["LSB (ps)"].setText(f"{event.lsb_ps:.2f}")
        labels["Flags"].setText(f"0x{int(event.flags):02X}")
        self._event_counts[ch] += 1
        labels["Events"].setText(str(self._event_counts[ch]))

    def update_coincidence(self, match: CoincidenceMatch) -> None:
        """Update coincidence stats with a new match."""
        self._coinc_total += 1
        dtm = match.time_diff_ps
        self._dtm_sum += dtm
        self._dtm_sq_sum += dtm * dtm

        self._dtm_label.setText(f"{dtm} ps")
        self._coinc_count_label.setText(str(self._coinc_total))

        mean = self._dtm_sum / self._coinc_total
        self._mean_dtm_label.setText(f"{mean:.1f} ps")

        if self._coinc_total > 1:
            variance = (self._dtm_sq_sum / self._coinc_total) - (mean * mean)
            std = variance ** 0.5 if variance > 0 else 0.0
            self._std_dtm_label.setText(f"{std:.1f} ps")

    def reset(self) -> None:
        """Clear all displayed values and reset stats."""
        for ch in range(2):
            for key in ("TOT", "TOA", "CAL", "LSB (ps)", "Flags"):
                self._ch_groups[ch][key].setText("--")
            self._ch_groups[ch]["Events"].setText("0")
        self._dtm_label.setText("--")
        self._coinc_count_label.setText("0")
        self._mean_dtm_label.setText("--")
        self._std_dtm_label.setText("--")
        self._event_counts = [0, 0]
        self._coinc_total = 0
        self._dtm_sum = 0.0
        self._dtm_sq_sum = 0.0
