"""Tests for core/tdc_parser.py — TDC event and coincidence parsing."""

import struct

from src.core.models import TdcTimeFlags
from src.core.protocol import MARKER_TDC_COINCIDENCE, MARKER_TDC_EVENT
from src.core.tdc_parser import (
    COINCIDENCE_RECORD_SIZE,
    TDC_EVENT_RECORD_SIZE,
    parse_coincidence_payload,
    parse_tdc_event_payload,
)


def _make_tdc_event_record(
    ch_id: int = 0,
    flags: int = 0x07,
    tot: int = 100,
    toa: int = 200,
    cal: int = 300,
    lsb_q16: int = 0x00050000,  # 5.0 ps
) -> bytes:
    """Build a 14-byte TDC event record."""
    return struct.pack(
        ">HBBHHHI",
        MARKER_TDC_EVENT,  # 2B
        ch_id,             # 1B
        flags,             # 1B
        tot,               # 2B
        toa,               # 2B
        cal,               # 2B
        lsb_q16,           # 4B
    )


def _make_coincidence_record(
    dtm_ps: int = 150,
    data_flags: int = 0x0003,
    ch1_err: int = 0,
    ch2_err: int = 0,
) -> bytes:
    """Build an 8-byte coincidence record."""
    return struct.pack(
        ">HhHBB",
        MARKER_TDC_COINCIDENCE,  # 2B
        dtm_ps,                   # 2B signed
        data_flags,               # 2B
        ch1_err,                  # 1B
        ch2_err,                  # 1B
    )


class TestParseTdcEvent:
    def test_single_event(self):
        payload = _make_tdc_event_record(ch_id=0, tot=100, toa=200, cal=300)
        events = parse_tdc_event_payload(payload)
        assert len(events) == 1
        e = events[0]
        assert e.channel_id == 0
        assert e.tot_ticks == 100
        assert e.toa_ticks == 200
        assert e.cal_ticks == 300
        assert e.flags == TdcTimeFlags(0x07)

    def test_lsb_conversion(self):
        # Q16.16: 0x00050000 = 5.0 ps
        payload = _make_tdc_event_record(lsb_q16=0x00050000)
        events = parse_tdc_event_payload(payload)
        assert abs(events[0].lsb_ps - 5.0) < 0.001

    def test_multiple_events(self):
        payload = _make_tdc_event_record(ch_id=0) + _make_tdc_event_record(ch_id=1)
        events = parse_tdc_event_payload(payload)
        assert len(events) == 2
        assert events[0].channel_id == 0
        assert events[1].channel_id == 1

    def test_empty_payload(self):
        events = parse_tdc_event_payload(b"")
        assert events == ()

    def test_partial_record_ignored(self):
        # 10 bytes < 14 required
        payload = _make_tdc_event_record()[:10]
        events = parse_tdc_event_payload(payload)
        assert events == ()

    def test_wrong_marker_skipped(self):
        bad = b"\x00\x00" + b"\x00" * 12  # wrong marker
        good = _make_tdc_event_record(ch_id=1)
        events = parse_tdc_event_payload(bad + good)
        # Should eventually find the good record after resyncing
        assert any(e.channel_id == 1 for e in events)

    def test_12bit_masking(self):
        # Pass values > 12 bits — should be masked
        payload = _make_tdc_event_record(tot=0xFFFF, toa=0xFFFF, cal=0xFFFF)
        events = parse_tdc_event_payload(payload)
        assert events[0].tot_ticks == 0x0FFF
        assert events[0].toa_ticks == 0x0FFF
        assert events[0].cal_ticks == 0x0FFF


class TestParseCoincidence:
    def test_single_match(self):
        payload = _make_coincidence_record(dtm_ps=150, data_flags=0x03)
        matches = parse_coincidence_payload(payload)
        assert len(matches) == 1
        m = matches[0]
        assert m.time_diff_ps == 150
        assert m.data_flags == 0x03

    def test_negative_dtm(self):
        payload = _make_coincidence_record(dtm_ps=-2500)
        matches = parse_coincidence_payload(payload)
        assert matches[0].time_diff_ps == -2500

    def test_multiple_matches(self):
        payload = (
            _make_coincidence_record(dtm_ps=100)
            + _make_coincidence_record(dtm_ps=-100)
        )
        matches = parse_coincidence_payload(payload)
        assert len(matches) == 2
        assert matches[0].time_diff_ps == 100
        assert matches[1].time_diff_ps == -100

    def test_empty_payload(self):
        matches = parse_coincidence_payload(b"")
        assert matches == ()

    def test_error_fields(self):
        payload = _make_coincidence_record(ch1_err=5, ch2_err=10)
        matches = parse_coincidence_payload(payload)
        assert matches[0].ch1_error == 5
        assert matches[0].ch2_error == 10
