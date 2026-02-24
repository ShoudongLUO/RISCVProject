"""Application logger — file + UI signal bridge.

Translates messageHandler() from mainwindow.cpp (lines 474-517).
"""

from __future__ import annotations

import logging
from datetime import datetime
from pathlib import Path

from PySide6.QtCore import QObject, Signal


class AppLogger(QObject):
    """Bridges Python logging to both a log file and a Qt signal for the UI."""

    message_logged = Signal(str, str)  # (level, formatted_message)

    def __init__(self, log_dir: str = ".", parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._log_path = Path(log_dir) / "debug_log.txt"
        self._file_handler: logging.FileHandler | None = None
        self._logger = logging.getLogger("fpga_daq")
        self._logger.setLevel(logging.DEBUG)
        self._setup_file_handler()

    def _setup_file_handler(self) -> None:
        self._log_path.parent.mkdir(parents=True, exist_ok=True)

        # Write session header
        with self._log_path.open("a", encoding="utf-8") as f:
            f.write(f"\n\n===== Start System {datetime.now()} =====\n")

        handler = logging.FileHandler(self._log_path, encoding="utf-8")
        handler.setLevel(logging.DEBUG)
        formatter = logging.Formatter("%(asctime)s [%(levelname)s] %(message)s")
        handler.setFormatter(formatter)
        self._logger.addHandler(handler)
        self._file_handler = handler

    def debug(self, msg: str) -> None:
        self._logger.debug(msg)
        self.message_logged.emit("debug", msg)

    def warning(self, msg: str) -> None:
        self._logger.warning(msg)
        self.message_logged.emit("warning", msg)

    def error(self, msg: str) -> None:
        self._logger.error(msg)
        self.message_logged.emit("error", msg)

    def info(self, msg: str) -> None:
        self._logger.info(msg)
        self.message_logged.emit("info", msg)
