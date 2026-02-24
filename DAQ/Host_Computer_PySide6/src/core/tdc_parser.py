"""Parse TDC event and coincidence payloads from new-format packets.

TDC event record (14 bytes):
  [0x7DC1(2B), ch_id(1B), flags(1B), tot(2B), toa(2B), cal(2B), lsb_q16(4B)]

Coincidence record (8 bytes):
  [0x7DC2(2B), dtm_ps(int16), data_flags(2B), ch1_err(1B), ch2_err(1B)]
"""

from __future__ import annotations

import struct

from .models import CoincidenceMatch, TdcEvent, TdcTimeFlags
from .protocol import MARKER_TDC_COINCIDENCE, MARKER_TDC_EVENT

TDC_EVENT_RECORD_SIZE = 14
COINCIDENCE_RECORD_SIZE = 8


def parse_tdc_event_payload(payload: bytes) -> tuple[TdcEvent, ...]:
    """Parse zero or more TDC event records from a TDC_EVENT payload.

    Each record is 14 bytes starting with 0x7DC1.
    Invalid records (wrong marker) are skipped.
    """
    events: list[TdcEvent] = []
    offset = 0
    while offset + TDC_EVENT_RECORD_SIZE <= len(payload):
        marker = struct.unpack(">H", payload[offset : offset + 2])[0]
        if marker != MARKER_TDC_EVENT:
            offset += 2  # try to resync
            continue

        ch_id = payload[offset + 2]
        raw_flags = payload[offset + 3]
        tot = struct.unpack(">H", payload[offset + 4 : offset + 6])[0] & 0x0FFF
        toa = struct.unpack(">H", payload[offset + 6 : offset + 8])[0] & 0x0FFF
        cal = struct.unpack(">H", payload[offset + 8 : offset + 10])[0] & 0x0FFF
        lsb_q16 = struct.unpack(">I", payload[offset + 10 : offset + 14])[0]

        events.append(
            TdcEvent(
                channel_id=ch_id,
                flags=TdcTimeFlags(raw_flags & 0x07),
                tot_ticks=tot,
                toa_ticks=toa,
                cal_ticks=cal,
                lsb_ps_q16=lsb_q16,
            )
        )
        offset += TDC_EVENT_RECORD_SIZE

    return tuple(events)


def parse_coincidence_payload(payload: bytes) -> tuple[CoincidenceMatch, ...]:
    """Parse zero or more coincidence records from a TDC_COINCIDENCE payload.

    Each record is 8 bytes starting with 0x7DC2.
    """
    matches: list[CoincidenceMatch] = []
    offset = 0
    while offset + COINCIDENCE_RECORD_SIZE <= len(payload):
        marker = struct.unpack(">H", payload[offset : offset + 2])[0]
        if marker != MARKER_TDC_COINCIDENCE:
            offset += 2
            continue

        dtm_ps = struct.unpack(">h", payload[offset + 2 : offset + 4])[0]  # signed
        data_flags = struct.unpack(">H", payload[offset + 4 : offset + 6])[0]
        ch1_err = payload[offset + 6]
        ch2_err = payload[offset + 7]

        matches.append(
            CoincidenceMatch(
                time_diff_ps=dtm_ps,
                data_flags=data_flags,
                ch1_error=ch1_err,
                ch2_error=ch2_err,
            )
        )
        offset += COINCIDENCE_RECORD_SIZE

    return tuple(matches)
