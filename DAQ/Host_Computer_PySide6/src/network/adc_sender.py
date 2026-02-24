"""CSV reader + ADC packet transmission.

Translates sendADCData() and sendADCPacket() from mainwindow.cpp (lines 519-582).
Uses QTimer.singleShot instead of QThread::msleep for non-blocking delays.
"""

from __future__ import annotations

import csv
import struct
from pathlib import Path

from PySide6.QtCore import QObject, QTimer, Signal

from ..core.protocol import MARKER_ADC_DATA


class AdcSender(QObject):
    """Reads ADC values from a CSV file and sends them as UDP packets."""

    packet_ready = Signal(bytes)  # emits raw packet bytes for UdpManager to send
    send_complete = Signal(int)  # total lines processed
    send_failed = Signal(str)  # error message

    PACKET_SIZE = 66  # 66 ADC values per packet (matches C++ PACKET_SIZE)
    SEND_DELAY_MS = 10

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._buffer: list[int] = []
        self._rows: list[list[str]] = []
        self._current_row: int = 0
        self._line_count: int = 0
        self._sending: bool = False

    def send_file(self, file_path: str) -> None:
        """Start sending ADC data from *file_path* (CSV)."""
        path = Path(file_path)
        if not path.exists():
            self.send_failed.emit(f"File not found: {file_path}")
            return

        try:
            with path.open("r", newline="") as f:
                reader = csv.reader(f)
                header = next(reader, None)  # skip header
                if header is None:
                    self.send_failed.emit("CSV file is empty")
                    return
                self._rows = [row for row in reader if len(row) >= 3]
        except OSError as e:
            self.send_failed.emit(str(e))
            return

        self._current_row = 0
        self._line_count = 0
        self._buffer.clear()
        self._sending = True
        self._process_next_row()

    def _process_next_row(self) -> None:
        if not self._sending or self._current_row >= len(self._rows):
            self._flush_buffer()
            self._sending = False
            self.send_complete.emit(self._line_count)
            return

        row = self._rows[self._current_row]
        self._current_row += 1
        self._line_count += 1

        # ADC values are space-separated in the third column (index 2)
        adc_strings = row[2].split() if len(row) > 2 else []

        # Channel filtering: match C++ channel_cut logic (channels 192..255)
        channel_cut_start = 64 * 3  # 192
        channel_cut_end = 64 * 4  # 256

        for idx, val_str in enumerate(adc_strings):
            if not (channel_cut_start <= idx < channel_cut_end):
                continue
            try:
                adc_value = int(val_str)
            except ValueError:
                continue
            if 0 <= adc_value <= 4095:
                self._buffer.append(adc_value)
                if len(self._buffer) >= self.PACKET_SIZE:
                    self._send_packet()

        self._flush_buffer()

        # Non-blocking delay before next row
        QTimer.singleShot(self.SEND_DELAY_MS, self._process_next_row)

    def _send_packet(self) -> None:
        """Pack buffer into a big-endian UDP packet with ADC_DATA tag header."""
        packet = struct.pack(">H", MARKER_ADC_DATA)
        for val in self._buffer[: self.PACKET_SIZE]:
            packet += struct.pack(">H", val)
        self.packet_ready.emit(packet)
        self._buffer = self._buffer[self.PACKET_SIZE :]

    def _flush_buffer(self) -> None:
        """Send any remaining values in the buffer."""
        if self._buffer:
            self._send_packet()

    def cancel(self) -> None:
        """Stop sending."""
        self._sending = False
