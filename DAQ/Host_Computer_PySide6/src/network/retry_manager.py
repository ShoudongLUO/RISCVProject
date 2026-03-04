"""QTimer-based retry logic for command acknowledgement.

Translates checkAndRetrySend().
"""

from __future__ import annotations

from PySide6.QtCore import QObject, QTimer, Signal


class RetryManager(QObject):
    """Retries sending a command until confirmed or max retries reached."""

    retry_requested = Signal(bytes)  # emits the pending command
    max_retries_reached = Signal()

    MAX_RETRIES = 5
    RETRY_INTERVAL_MS = 1000

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._timer = QTimer(self)
        self._timer.setInterval(self.RETRY_INTERVAL_MS)
        self._timer.timeout.connect(self._on_timeout)
        self._pending_command: bytes = b""
        self._retry_count: int = 0

    @property
    def is_active(self) -> bool:
        return self._timer.isActive()

    def start(self, command: bytes) -> None:
        """Begin retrying *command* every RETRY_INTERVAL_MS."""
        self._pending_command = command
        self._retry_count = 0
        self._timer.start()

    def confirm(self) -> None:
        """Call when the expected response is received — stops retrying."""
        self._timer.stop()
        self._pending_command = b""
        self._retry_count = 0

    def stop(self) -> None:
        """Manually stop retrying."""
        self._timer.stop()

    def _on_timeout(self) -> None:
        if self._retry_count >= self.MAX_RETRIES:
            self._timer.stop()
            self.max_retries_reached.emit()
            return

        self._retry_count += 1
        self.retry_requested.emit(self._pending_command)
