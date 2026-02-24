"""Entry point — QApplication, Fusion style, QSS loading."""

from __future__ import annotations

import sys
from pathlib import Path

from PySide6.QtWidgets import QApplication

from .ui.main_window import MainWindow


def main() -> None:
    app = QApplication(sys.argv)
    app.setStyle("Fusion")

    # Load stylesheet
    qss_path = Path(__file__).parent / "resources" / "style.qss"
    if qss_path.exists():
        app.setStyleSheet(qss_path.read_text(encoding="utf-8"))

    window = MainWindow()
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
