"""Tests for core/adc_parser.py — channel-tagged ADC parsing."""

import struct

from src.core.adc_parser import demux_frame_by_channel, parse_adc_payload
from src.core.models import AdcFrame, AdcSample


def _make_adc_word(channel_id: int, value: int) -> bytes:
    """Build a single 16-bit BE word: bits[15:12]=ch, bits[11:0]=value."""
    word = ((channel_id & 0x0F) << 12) | (value & 0x0FFF)
    return struct.pack(">H", word)


class TestParseAdcPayload:
    def test_single_sample(self):
        payload = _make_adc_word(3, 1024)
        frame = parse_adc_payload(payload, counter=42)
        assert frame.counter == 42
        assert len(frame.samples) == 1
        assert frame.samples[0].channel_id == 3
        assert frame.samples[0].raw_value == 1024

    def test_multiple_samples(self):
        payload = _make_adc_word(0, 100) + _make_adc_word(5, 2000) + _make_adc_word(15, 4095)
        frame = parse_adc_payload(payload, counter=1)
        assert len(frame.samples) == 3
        assert frame.samples[0] == AdcSample(channel_id=0, raw_value=100)
        assert frame.samples[1] == AdcSample(channel_id=5, raw_value=2000)
        assert frame.samples[2] == AdcSample(channel_id=15, raw_value=4095)

    def test_empty_payload(self):
        frame = parse_adc_payload(b"", counter=0)
        assert frame.samples == ()
        assert frame.counter == 0

    def test_odd_byte_ignored(self):
        # 3 bytes: only first 2 form a valid word
        payload = _make_adc_word(1, 500) + b"\xFF"
        frame = parse_adc_payload(payload, counter=10)
        assert len(frame.samples) == 1

    def test_max_channel_and_value(self):
        payload = _make_adc_word(15, 4095)
        frame = parse_adc_payload(payload, counter=0)
        assert frame.samples[0].channel_id == 15
        assert frame.samples[0].raw_value == 4095

    def test_zero_channel_and_value(self):
        payload = _make_adc_word(0, 0)
        frame = parse_adc_payload(payload, counter=0)
        assert frame.samples[0].channel_id == 0
        assert frame.samples[0].raw_value == 0


class TestDemuxFrameByChannel:
    def test_basic_demux(self):
        frame = AdcFrame(
            counter=1,
            samples=(
                AdcSample(0, 100),
                AdcSample(1, 200),
                AdcSample(0, 150),
                AdcSample(1, 250),
            ),
        )
        result = demux_frame_by_channel(frame, num_channels=20)
        assert result[0] == [100, 150]
        assert result[1] == [200, 250]
        assert result[2] == []

    def test_out_of_range_channel_ignored(self):
        frame = AdcFrame(
            counter=1,
            samples=(AdcSample(25, 100),),  # ch 25 > 20
        )
        result = demux_frame_by_channel(frame, num_channels=20)
        # No crash, all channels empty
        assert all(len(v) == 0 for v in result.values())

    def test_empty_frame(self):
        frame = AdcFrame(counter=0, samples=())
        result = demux_frame_by_channel(frame)
        assert len(result) == 20
        assert all(len(v) == 0 for v in result.values())
