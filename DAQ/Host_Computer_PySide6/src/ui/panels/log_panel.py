"""System log panel — color-coded debug messages on dark background."""

from __future__ import annotations

from PySide6.QtCore import Slot
from PySide6.QtWidgets import QPlainTextEdit, QVBoxLayout, QGroupBox, QWidget

_LEVEL_COLORS = {
    "debug": "#64B5F6",    # blue
    "info": "#81C784",     # green
    "warning": "#FFB74D",  # orange
    "error": "#E57373",    # red
}


class LogPanel(QWidget):
    """Center-right panel: color-coded system log with dark terminal style."""

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(4, 4, 4, 4)

        group = QGroupBox("System Log")
        group_layout = QVBoxLayout()

        self._text = QPlainTextEdit()
        self._text.setObjectName("logPanel")
        self._text.setReadOnly(True)
        self._text.setMaximumBlockCount(1000)

        group_layout.addWidget(self._text)
        group.setLayout(group_layout)
        layout.addWidget(group)

    @Slot(str, str)
    def append_message(self, level: str, message: str) -> None:
        """Append a color-coded message to the log."""
        color = _LEVEL_COLORS.get(level, "#ECEFF1")
        html = f'<span style="color:{color};">[{level.upper()}] {message}</span>'
        self._text.appendHtml(html)

        # Auto-scroll to bottom
        scrollbar = self._text.verticalScrollBar()
        scrollbar.setValue(scrollbar.maximum())
