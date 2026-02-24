"""Tests for core/calibration_parser.py — calibration and mode-ack parsing."""

import struct

from src.core.calibration_parser import parse_calibration_payload, parse_mode_ack_payload
from src.core.models import CalibrationData, ModeAck
from src.core.protocol import MARKER_BASELINE_NOISE, MARKER_MODE_CHANGE, DeviceMode


def _make_cal_payload(baseline: int, noise: int, marker: int = MARKER_BASELINE_NOISE) -> bytes:
    return struct.pack(">HHH", baseline, noise, marker)


def _make_mode_ack_payload(mode_val: int, marker: int = MARKER_MODE_CHANGE) -> bytes:
    return struct.pack(">HH", mode_val, marker)


class TestParseCalibrationPayload:
    def test_valid_calibration(self):
        payload = _make_cal_payload(1000, 50)
        result = parse_calibration_payload(payload)
        assert result is not None
        assert result.baseline == 1000
        assert result.noise == 50

    def test_zero_values(self):
        payload = _make_cal_payload(0, 0)
        result = parse_calibration_payload(payload)
        assert result is not None
        assert result.baseline == 0
        assert result.noise == 0

    def test_max_values(self):
        payload = _make_cal_payload(0xFFFF, 0xFFFF)
        result = parse_calibration_payload(payload)
        assert result is not None
        assert result.baseline == 0xFFFF
        assert result.noise == 0xFFFF

    def test_wrong_marker_returns_none(self):
        payload = _make_cal_payload(100, 50, marker=0x1234)
        result = parse_calibration_payload(payload)
        assert result is None

    def test_too_short_returns_none(self):
        result = parse_calibration_payload(b"\x00\x01")
        assert result is None

    def test_empty_returns_none(self):
        result = parse_calibration_payload(b"")
        assert result is None

    def test_immutable(self):
        payload = _make_cal_payload(100, 50)
        result = parse_calibration_payload(payload)
        try:
            result.baseline = 999  # type: ignore[misc]
            assert False, "Should raise"
        except AttributeError:
            pass


class TestParseModeAckPayload:
    def test_idle_mode(self):
        payload = _make_mode_ack_payload(0x0000)
        result = parse_mode_ack_payload(payload)
        assert result is not None
        assert result.mode == DeviceMode.IDLE

    def test_calibration_mode(self):
        payload = _make_mode_ack_payload(0x0001)
        result = parse_mode_ack_payload(payload)
        assert result is not None
        assert result.mode == DeviceMode.CALIBRATION

    def test_data_acquire_mode(self):
        payload = _make_mode_ack_payload(0x0002)
        result = parse_mode_ack_payload(payload)
        assert result is not None
        assert result.mode == DeviceMode.DATA_ACQUIRE

    def test_invalid_mode_returns_none(self):
        payload = _make_mode_ack_payload(0x00FF)
        result = parse_mode_ack_payload(payload)
        assert result is None

    def test_wrong_marker_returns_none(self):
        payload = _make_mode_ack_payload(0x0001, marker=0xFFFF)
        result = parse_mode_ack_payload(payload)
        assert result is None

    def test_too_short_returns_none(self):
        result = parse_mode_ack_payload(b"\x00")
        assert result is None

    def test_empty_returns_none(self):
        result = parse_mode_ack_payload(b"")
        assert result is None
