"""System log panel — color-coded messages on deep dark background.

Scientific terminal aesthetic with monospace font and subtle level colors.
"""

from __future__ import annotations

import html as html_mod

from PySide6.QtCore import Slot
from PySide6.QtWidgets import QPlainTextEdit, QVBoxLayout, QGroupBox, QWidget

_LEVEL_COLORS = {
    "debug": "#64B5F6",    # soft blue
    "info": "#69f0ae",     # neon green
    "warning": "#ffd740",  # amber
    "error": "#ff5252",    # red
}

_LEVEL_PREFIXES = {
    "debug": "DBG",
    "info": "INF",
    "warning": "WRN",
    "error": "ERR",
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
        color = _LEVEL_COLORS.get(level, "#c8cdd3")
        prefix = _LEVEL_PREFIXES.get(level, level.upper()[:3])
        safe_msg = html_mod.escape(message)
        html = (
            f'<span style="color:#555e6e;">[</span>'
            f'<span style="color:{color};font-weight:bold;">{prefix}</span>'
            f'<span style="color:#555e6e;">]</span> '
            f'<span style="color:{color};">{safe_msg}</span>'
        )
        self._text.appendHtml(html)

        # Auto-scroll to bottom
        scrollbar = self._text.verticalScrollBar()
        scrollbar.setValue(scrollbar.maximum())
