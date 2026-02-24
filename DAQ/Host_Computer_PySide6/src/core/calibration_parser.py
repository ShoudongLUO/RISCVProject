"""Parse calibration and mode-ack payloads from new-format packets.

Calibration payload (6 bytes):
  [baseline(2B), noise(2B), 0x3456(2B)]

Mode-ACK payload (4 bytes):
  [mode_value(2B), 0x0666(2B)]
"""

from __future__ import annotations

import struct
from typing import Optional

from .models import CalibrationData, ModeAck
from .protocol import MARKER_BASELINE_NOISE, MARKER_MODE_CHANGE, DeviceMode


def parse_calibration_payload(payload: bytes) -> Optional[CalibrationData]:
    """Parse a CALIBRATION-type payload.

    Expected: [baseline(2B), noise(2B), marker=0x3456(2B)].
    Returns None if payload is too short or marker mismatch.
    """
    if len(payload) < 6:
        return None
    baseline = struct.unpack(">H", payload[0:2])[0]
    noise = struct.unpack(">H", payload[2:4])[0]
    marker = struct.unpack(">H", payload[4:6])[0]
    if marker != MARKER_BASELINE_NOISE:
        return None
    return CalibrationData(baseline=baseline, noise=noise)


def parse_mode_ack_payload(payload: bytes) -> Optional[ModeAck]:
    """Parse a MODE_ACK-type payload.

    Expected: [mode_value(2B), marker=0x0666(2B)].
    Returns None if payload is too short, marker mismatch, or invalid mode.
    """
    if len(payload) < 4:
        return None
    mode_val = struct.unpack(">H", payload[0:2])[0]
    marker = struct.unpack(">H", payload[2:4])[0]
    if marker != MARKER_MODE_CHANGE:
        return None
    raw_mode = mode_val & 0xFF
    if raw_mode not in (m.value for m in DeviceMode):
        return None
    return ModeAck(mode=DeviceMode(raw_mode))
