"""Tests for core/protocol.py — command generation, constants, PacketType."""

import struct

from src.core.protocol import (
    MARKER_ADC_DATA,
    MARKER_BASELINE_NOISE,
    MARKER_MODE_CHANGE,
    MARKER_PACKET_HEADER,
    MARKER_TDC_COINCIDENCE,
    MARKER_TDC_EVENT,
    PACKET_ENVELOPE_SIZE,
    CommandFlag,
    DeviceMode,
    PacketType,
    generate_command,
)


class TestGenerateCommand:
    """Verify generate_command produces correct 4-byte packets."""

    def test_idle_no_flags(self):
        cmd = generate_command(DeviceMode.IDLE, CommandFlag.NONE)
        assert cmd == b"\x00\x00\x00\x00"

    def test_calibration_no_flags(self):
        cmd = generate_command(DeviceMode.CALIBRATION)
        assert cmd == b"\x00\x00\x00\x01"

    def test_data_acquire_no_flags(self):
        cmd = generate_command(DeviceMode.DATA_ACQUIRE)
        assert cmd == b"\x00\x00\x00\x02"

    def test_stop_flag(self):
        cmd = generate_command(DeviceMode.IDLE, CommandFlag.STOP)
        assert cmd == b"\x00\x00\x00\x10"

    def test_data_detected_flag(self):
        cmd = generate_command(DeviceMode.CALIBRATION, CommandFlag.DATA_DETECTED)
        assert cmd == b"\x00\x00\x00\x21"

    def test_uart_debug_flag(self):
        cmd = generate_command(DeviceMode.IDLE, CommandFlag.UART_DEBUG)
        assert cmd == b"\x00\x00\x00\x40"

    def test_reset_flag(self):
        cmd = generate_command(DeviceMode.IDLE, CommandFlag.RESET)
        assert cmd == b"\x00\x00\x00\x80"

    def test_combined_flags(self):
        cmd = generate_command(
            DeviceMode.CALIBRATION,
            CommandFlag.DATA_DETECTED | CommandFlag.STOP,
        )
        assert cmd == b"\x00\x00\x00\x31"

    def test_all_flags(self):
        cmd = generate_command(
            DeviceMode.DATA_ACQUIRE,
            CommandFlag.STOP | CommandFlag.DATA_DETECTED | CommandFlag.UART_DEBUG | CommandFlag.RESET,
        )
        assert cmd == b"\x00\x00\x00\xF2"

    def test_length_is_4(self):
        cmd = generate_command()
        assert len(cmd) == 4

    def test_default_is_idle(self):
        cmd = generate_command()
        assert cmd[-1] == 0x00


class TestMarkerConstants:
    def test_baseline_noise(self):
        assert MARKER_BASELINE_NOISE == 0x3456

    def test_mode_change(self):
        assert MARKER_MODE_CHANGE == 0x0666

    def test_adc_data(self):
        assert MARKER_ADC_DATA == 0x1234

    def test_packet_header(self):
        assert MARKER_PACKET_HEADER == 0xAAAA

    def test_tdc_event(self):
        assert MARKER_TDC_EVENT == 0x7DC1

    def test_tdc_coincidence(self):
        assert MARKER_TDC_COINCIDENCE == 0x7DC2

    def test_envelope_size(self):
        assert PACKET_ENVELOPE_SIZE == 6


class TestPacketType:
    def test_adc_value(self):
        assert PacketType.ADC == 0x01

    def test_tdc_event_value(self):
        assert PacketType.TDC_EVENT == 0x02

    def test_tdc_coincidence_value(self):
        assert PacketType.TDC_COINCIDENCE == 0x03

    def test_calibration_value(self):
        assert PacketType.CALIBRATION == 0x04

    def test_mode_ack_value(self):
        assert PacketType.MODE_ACK == 0x05

    def test_from_int(self):
        assert PacketType(0x01) == PacketType.ADC
        assert PacketType(0x03) == PacketType.TDC_COINCIDENCE
