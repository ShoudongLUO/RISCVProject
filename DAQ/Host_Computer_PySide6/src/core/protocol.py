"""Command generation, marker constants, PacketType enum, and DeviceMode enum.

Translates mainwindow.cpp generateCommand() (lines 322-350) and
marker constants used in readDatagram() parsing.

New-format packets use a 6-byte envelope:
  [0xAAAA (2B)] [type (1B)] [reserved (1B)] [counter (2B)]
"""

from __future__ import annotations

import struct
from enum import IntEnum, IntFlag


class DeviceMode(IntEnum):
    """FPGA operating modes (low 4 bits of control byte)."""

    IDLE = 0x00
    CALIBRATION = 0x01
    DATA_ACQUIRE = 0x02


class CommandFlag(IntFlag):
    """Bit flags for bits 4-7 of the control byte."""

    NONE = 0x00
    STOP = 0x10
    DATA_DETECTED = 0x20
    UART_DEBUG = 0x40
    RESET = 0x80


class PacketType(IntEnum):
    """Packet type byte in the 6-byte new-format envelope."""

    ADC = 0x01
    TDC_EVENT = 0x02
    TDC_COINCIDENCE = 0x03
    CALIBRATION = 0x04
    MODE_ACK = 0x05


# --- New-format envelope marker ---
MARKER_PACKET_HEADER = 0xAAAA

# --- TDC record markers ---
MARKER_TDC_EVENT = 0x7DC1
MARKER_TDC_COINCIDENCE = 0x7DC2

# --- Legacy marker constants (backward compat) ---
MARKER_BASELINE_NOISE = 0x3456
MARKER_MODE_CHANGE = 0x0666
MARKER_ADC_DATA = 0x1234

# --- Envelope size ---
PACKET_ENVELOPE_SIZE = 6  # 2B header + 1B type + 1B reserved + 2B counter


def generate_command(
    mode: DeviceMode = DeviceMode.IDLE,
    flags: CommandFlag = CommandFlag.NONE,
) -> bytes:
    """Generate a 4-byte command packet.

    Byte layout: [0x00, 0x00, 0x00, control_byte]
    control_byte = (mode & 0x0F) | flags

    Returns immutable bytes object.
    """
    control_byte = (mode & 0x0F) | (flags & 0xF0)
    return struct.pack(">3xB", control_byte)
