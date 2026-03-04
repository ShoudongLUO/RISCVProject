"""QUdpSocket wrapper — bind, send, receive signals.

Translates startListening(), sendUdpData(), reBind() from mainwindow.cpp.
"""

from __future__ import annotations

from PySide6.QtCore import QObject, Signal
from PySide6.QtNetwork import QHostAddress, QUdpSocket


class UdpManager(QObject):
    """Manages a single QUdpSocket for bidirectional UDP communication."""

    datagram_received = Signal(bytes)
    bind_success = Signal(str, int)  # host, port
    bind_failed = Signal(str)  # error message
    send_complete = Signal(int)  # bytes sent
    send_failed = Signal(str)  # error message

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._socket: QUdpSocket | None = None

    @property
    def is_bound(self) -> bool:
        return self._socket is not None and self._socket.state() == QUdpSocket.SocketState.BoundState

    def bind(self, host: str, port: int) -> None:
        """Bind to the given host:port and start listening."""
        if self._socket is not None:
            self._close()

        self._socket = QUdpSocket(self)
        address = QHostAddress(host)

        if not self._socket.bind(address, port):
            error_msg = self._socket.errorString()
            self.bind_failed.emit(f"Bind failed: {error_msg}")
            return

        self._socket.readyRead.connect(self._on_ready_read)
        self.bind_success.emit(host, port)

    def rebind(self, host: str, port: int) -> None:
        """Close current socket and re-bind."""
        self._close()
        self.bind(host, port)

    def send(self, data: bytes, dest_host: str, dest_port: int) -> None:
        """Send a datagram to the destination."""
        if self._socket is None:
            self.send_failed.emit("Socket not initialized")
            return

        address = QHostAddress(dest_host)
        bytes_sent = self._socket.writeDatagram(data, address, dest_port)

        if bytes_sent == -1:
            self.send_failed.emit(self._socket.errorString())
        else:
            self.send_complete.emit(bytes_sent)

    def close(self) -> None:
        """Public close — unbinds the socket."""
        self._close()

    def _close(self) -> None:
        if self._socket is not None:
            self._socket.readyRead.disconnect(self._on_ready_read)
            self._socket.close()
            self._socket.deleteLater()
            self._socket = None

    def _on_ready_read(self) -> None:
        if self._socket is None:
            return
        while self._socket.hasPendingDatagrams():
            size = self._socket.pendingDatagramSize()
            data, _, _ = self._socket.readDatagram(size)
            self.datagram_received.emit(bytes(data))
