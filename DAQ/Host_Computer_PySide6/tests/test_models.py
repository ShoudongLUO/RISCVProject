"""Tests for core/models.py — dataclass immutability and properties."""

import pytest

from src.core.models import (
    AdcFrame,
    AdcSample,
    AppState,
    CalibrationData,
    CoincidenceMatch,
    ModeAck,
    NetworkConfig,
    ParsedPacket,
    TdcEvent,
    TdcTimeFlags,
)
from src.core.protocol import DeviceMode, PacketType


class TestAdcSample:
    def test_creation(self):
        s = AdcSample(channel_id=5, raw_value=2048)
        assert s.channel_id == 5
        assert s.raw_value == 2048

    def test_frozen(self):
        s = AdcSample(channel_id=0, raw_value=0)
        with pytest.raises(AttributeError):
            s.channel_id = 1  # type: ignore[misc]


class TestAdcFrame:
    def test_creation(self):
        samples = (AdcSample(0, 100), AdcSample(1, 200))
        f = AdcFrame(counter=42, samples=samples)
        assert f.counter == 42
        assert len(f.samples) == 2

    def test_default_samples(self):
        f = AdcFrame(counter=0)
        assert f.samples == ()


class TestTdcEvent:
    def test_lsb_ps_conversion(self):
        # Q16.16: 0x000A8000 = 10.5 ps
        e = TdcEvent(
            channel_id=0,
            flags=TdcTimeFlags.NONE,
            tot_ticks=100,
            toa_ticks=200,
            cal_ticks=300,
            lsb_ps_q16=0x000A8000,
        )
        assert abs(e.lsb_ps - 10.5) < 0.001

    def test_flags(self):
        f = TdcTimeFlags.TOT_VALID | TdcTimeFlags.TOA_VALID
        e = TdcEvent(0, f, 0, 0, 0, 0)
        assert TdcTimeFlags.TOT_VALID in e.flags
        assert TdcTimeFlags.TOA_VALID in e.flags
        assert TdcTimeFlags.CAL_VALID not in e.flags


class TestCoincidenceMatch:
    def test_negative_dtm(self):
        m = CoincidenceMatch(time_diff_ps=-2500, data_flags=0, ch1_error=0, ch2_error=0)
        assert m.time_diff_ps == -2500

    def test_frozen(self):
        m = CoincidenceMatch(0, 0, 0, 0)
        with pytest.raises(AttributeError):
            m.time_diff_ps = 999  # type: ignore[misc]


class TestCalibrationData:
    def test_creation(self):
        c = CalibrationData(baseline=1000, noise=50)
        assert c.baseline == 1000
        assert c.noise == 50


class TestModeAck:
    def test_creation(self):
        m = ModeAck(mode=DeviceMode.CALIBRATION)
        assert m.mode == DeviceMode.CALIBRATION


class TestAppState:
    def test_defaults(self):
        s = AppState()
        assert s.num_adc_channels == 20
        assert s.packet_counter == 0
        assert s.tdc_event_count == 0
        assert s.coincidence_count == 0
        assert s.current_mode == DeviceMode.IDLE

    def test_frozen(self):
        s = AppState()
        with pytest.raises(AttributeError):
            s.current_mode = DeviceMode.CALIBRATION  # type: ignore[misc]


class TestNetworkConfig:
    def test_defaults(self):
        c = NetworkConfig()
        assert c.host_ip == "192.168.185.243"
        assert c.host_port == 1234


class TestParsedPacket:
    def test_defaults(self):
        p = ParsedPacket()
        assert p.packet_type is None
        assert p.is_legacy is False
        assert p.adc_frame is None
        assert p.tdc_events == ()
        assert p.coincidence_matches == ()
        assert p.calibration is None
        assert p.mode_ack is None
        assert p.legacy_adc_values == ()

    def test_frozen(self):
        p = ParsedPacket(raw_size=100)
        with pytest.raises(AttributeError):
            p.raw_size = 0  # type: ignore[misc]
