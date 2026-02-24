"""Tests for core/data_parser.py — new-format dispatch + legacy fallback."""

import struct

from src.core.data_parser import parse_datagram
from src.core.models import ParsedPacket
from src.core.protocol import (
    MARKER_BASELINE_NOISE,
    MARKER_MODE_CHANGE,
    MARKER_PACKET_HEADER,
    MARKER_TDC_COINCIDENCE,
    MARKER_TDC_EVENT,
    PACKET_ENVELOPE_SIZE,
    DeviceMode,
    PacketType,
)


def _make_envelope(pkt_type: int, counter: int = 0, payload: bytes = b"") -> bytes:
    """Build a new-format datagram: [0xAAAA, type, 0x00, counter] + payload."""
    return struct.pack(">HBxH", MARKER_PACKET_HEADER, pkt_type, counter) + payload


def _make_adc_word(ch: int, val: int) -> bytes:
    return struct.pack(">H", ((ch & 0x0F) << 12) | (val & 0x0FFF))


def _make_legacy_chunk(num_channels: int, value: int, marker: int) -> bytes:
    padding = b"\x00" * ((num_channels - 2) * 2)
    return padding + struct.pack(">HH", value, marker)


# ---- New-format detection ----

class TestNewFormatDetection:
    def test_detects_new_format(self):
        data = _make_envelope(PacketType.ADC, counter=5, payload=_make_adc_word(0, 100))
        result = parse_datagram(data)
        assert not result.is_legacy
        assert result.packet_type == PacketType.ADC
        assert result.counter == 5

    def test_legacy_when_no_marker(self):
        data = b"\x00\x01\x02\x03\x04\x05"
        result = parse_datagram(data)
        assert result.is_legacy

    def test_too_short_for_new_format(self):
        # Only 4 bytes, starts with 0xAAAA but too short for envelope
        data = struct.pack(">HH", MARKER_PACKET_HEADER, 0x0000)
        result = parse_datagram(data)
        assert result.is_legacy

    def test_empty_datagram(self):
        result = parse_datagram(b"")
        assert result.is_legacy
        assert result.raw_size == 0


# ---- ADC packets ----

class TestNewFormatAdc:
    def test_adc_single_sample(self):
        payload = _make_adc_word(3, 1024)
        data = _make_envelope(PacketType.ADC, counter=10, payload=payload)
        result = parse_datagram(data)
        assert result.packet_type == PacketType.ADC
        assert result.adc_frame is not None
        assert len(result.adc_frame.samples) == 1
        assert result.adc_frame.samples[0].channel_id == 3
        assert result.adc_frame.samples[0].raw_value == 1024

    def test_adc_multiple_samples(self):
        payload = _make_adc_word(0, 100) + _make_adc_word(5, 2000) + _make_adc_word(19, 4095)
        data = _make_envelope(PacketType.ADC, payload=payload)
        result = parse_datagram(data)
        assert len(result.adc_frame.samples) == 3

    def test_adc_empty_payload(self):
        data = _make_envelope(PacketType.ADC)
        result = parse_datagram(data)
        assert result.adc_frame is not None
        assert result.adc_frame.samples == ()


# ---- TDC event packets ----

class TestNewFormatTdcEvent:
    def test_tdc_event(self):
        record = struct.pack(
            ">HBBHHHI",
            MARKER_TDC_EVENT, 0, 0x07, 100, 200, 300, 0x00050000,
        )
        data = _make_envelope(PacketType.TDC_EVENT, payload=record)
        result = parse_datagram(data)
        assert result.packet_type == PacketType.TDC_EVENT
        assert len(result.tdc_events) == 1
        assert result.tdc_events[0].tot_ticks == 100

    def test_tdc_event_empty(self):
        data = _make_envelope(PacketType.TDC_EVENT)
        result = parse_datagram(data)
        assert result.tdc_events == ()


# ---- Coincidence packets ----

class TestNewFormatCoincidence:
    def test_coincidence(self):
        record = struct.pack(">HhHBB", MARKER_TDC_COINCIDENCE, -500, 0x03, 0, 0)
        data = _make_envelope(PacketType.TDC_COINCIDENCE, payload=record)
        result = parse_datagram(data)
        assert result.packet_type == PacketType.TDC_COINCIDENCE
        assert len(result.coincidence_matches) == 1
        assert result.coincidence_matches[0].time_diff_ps == -500


# ---- Calibration packets ----

class TestNewFormatCalibration:
    def test_calibration(self):
        payload = struct.pack(">HHH", 1000, 50, MARKER_BASELINE_NOISE)
        data = _make_envelope(PacketType.CALIBRATION, payload=payload)
        result = parse_datagram(data)
        assert result.packet_type == PacketType.CALIBRATION
        assert result.calibration is not None
        assert result.calibration.baseline == 1000
        assert result.calibration.noise == 50

    def test_calibration_bad_marker(self):
        payload = struct.pack(">HHH", 1000, 50, 0xFFFF)
        data = _make_envelope(PacketType.CALIBRATION, payload=payload)
        result = parse_datagram(data)
        assert result.calibration is None


# ---- Mode-ACK packets ----

class TestNewFormatModeAck:
    def test_mode_ack(self):
        payload = struct.pack(">HH", 0x0001, MARKER_MODE_CHANGE)
        data = _make_envelope(PacketType.MODE_ACK, payload=payload)
        result = parse_datagram(data)
        assert result.packet_type == PacketType.MODE_ACK
        assert result.mode_ack is not None
        assert result.mode_ack.mode == DeviceMode.CALIBRATION


# ---- Unknown type ----

class TestNewFormatUnknown:
    def test_unknown_type(self):
        data = _make_envelope(0xFF, counter=99)
        result = parse_datagram(data)
        assert result.packet_type is None
        assert result.counter == 99


# ---- Legacy backward compat ----

class TestLegacyFallback:
    def test_legacy_baseline_noise(self):
        data = _make_legacy_chunk(3, 0xAB0C, MARKER_BASELINE_NOISE)
        result = parse_datagram(data, num_channels=3)
        assert result.is_legacy
        assert result.legacy_baseline == 0xAB
        assert result.legacy_noise == 0x0C

    def test_legacy_mode_change(self):
        data = _make_legacy_chunk(3, 0x0001, MARKER_MODE_CHANGE)
        result = parse_datagram(data, num_channels=3)
        assert result.is_legacy
        assert result.legacy_mode_confirmed == DeviceMode.CALIBRATION

    def test_legacy_adc_values(self):
        data = struct.pack(">HHH", 100, 200, 300)
        result = parse_datagram(data, num_channels=3)
        assert result.is_legacy
        assert result.legacy_adc_values == (100, 200, 300)

    def test_legacy_empty(self):
        result = parse_datagram(b"", num_channels=3)
        assert result.is_legacy
        assert result.legacy_adc_values == ()

    def test_legacy_raw_size(self):
        data = b"\x00" * 12
        result = parse_datagram(data, num_channels=3)
        assert result.raw_size == 12


class TestParsedPacketImmutable:
    def test_frozen(self):
        data = b"\x00" * 6
        result = parse_datagram(data, num_channels=3)
        try:
            result.raw_size = 42  # type: ignore[misc]
            assert False, "Should have raised"
        except AttributeError:
            pass
