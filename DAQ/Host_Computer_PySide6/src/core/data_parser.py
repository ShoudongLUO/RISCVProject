"""UDP datagram parsing — auto-detect new-format (0xAAAA) or legacy.

New-format envelope (6 bytes):
  [0xAAAA (2B)] [type (1B)] [reserved (1B)] [counter (2B)]

If the first two bytes are NOT 0xAAAA, falls back to legacy chunk-based parsing
for backward compatibility.
"""

from __future__ import annotations

import struct
from typing import Optional

from .adc_parser import parse_adc_payload
from .calibration_parser import parse_calibration_payload, parse_mode_ack_payload
from .models import ParsedPacket
from .protocol import (
    MARKER_BASELINE_NOISE,
    MARKER_MODE_CHANGE,
    MARKER_PACKET_HEADER,
    PACKET_ENVELOPE_SIZE,
    DeviceMode,
    PacketType,
)
from .tdc_parser import parse_coincidence_payload, parse_tdc_event_payload


def parse_datagram(data: bytes, num_channels: int = 20) -> ParsedPacket:
    """Parse a UDP datagram, auto-detecting format.

    Args:
        data: Raw bytes from QUdpSocket.
        num_channels: ADC channel count (used for legacy fallback only).

    Returns:
        Immutable ParsedPacket.
    """
    if len(data) < 2:
        return ParsedPacket(raw_size=len(data), is_legacy=True)

    header = struct.unpack(">H", data[0:2])[0]
    if header == MARKER_PACKET_HEADER and len(data) >= PACKET_ENVELOPE_SIZE:
        return _parse_new_format(data)
    return _parse_legacy(data, num_channels)


# ---------------------------------------------------------------------------
# New-format parser
# ---------------------------------------------------------------------------

def _parse_new_format(data: bytes) -> ParsedPacket:
    """Parse a packet with the 0xAAAA envelope."""
    pkt_type_raw = data[2]
    counter = struct.unpack(">H", data[4:6])[0]
    payload = data[PACKET_ENVELOPE_SIZE:]

    try:
        pkt_type = PacketType(pkt_type_raw)
    except ValueError:
        # Unknown type — return raw info only
        return ParsedPacket(
            counter=counter,
            raw_size=len(data),
        )

    if pkt_type == PacketType.ADC:
        frame = parse_adc_payload(payload, counter)
        return ParsedPacket(
            packet_type=pkt_type,
            counter=counter,
            adc_frame=frame,
            raw_size=len(data),
        )

    if pkt_type == PacketType.TDC_EVENT:
        events = parse_tdc_event_payload(payload)
        return ParsedPacket(
            packet_type=pkt_type,
            counter=counter,
            tdc_events=events,
            raw_size=len(data),
        )

    if pkt_type == PacketType.TDC_COINCIDENCE:
        matches = parse_coincidence_payload(payload)
        return ParsedPacket(
            packet_type=pkt_type,
            counter=counter,
            coincidence_matches=matches,
            raw_size=len(data),
        )

    if pkt_type == PacketType.CALIBRATION:
        cal = parse_calibration_payload(payload)
        return ParsedPacket(
            packet_type=pkt_type,
            counter=counter,
            calibration=cal,
            raw_size=len(data),
        )

    if pkt_type == PacketType.MODE_ACK:
        ack = parse_mode_ack_payload(payload)
        return ParsedPacket(
            packet_type=pkt_type,
            counter=counter,
            mode_ack=ack,
            raw_size=len(data),
        )

    return ParsedPacket(
        packet_type=pkt_type,
        counter=counter,
        raw_size=len(data),
    )


# ---------------------------------------------------------------------------
# Legacy parser (backward compat)
# ---------------------------------------------------------------------------

def _parse_legacy(data: bytes, num_channels: int) -> ParsedPacket:
    """Parse using the old chunk-based format (pre-0xAAAA)."""
    byte_num = 2 * num_channels
    baseline: Optional[int] = None
    noise: Optional[int] = None
    mode_confirmed: Optional[DeviceMode] = None
    mode_flag_seen = False

    if len(data) >= 2:
        i = 0
        while i + byte_num <= len(data):
            chunk = data[i : i + byte_num]
            value = struct.unpack(">H", chunk[byte_num - 4 : byte_num - 2])[0]
            marker = struct.unpack(">H", chunk[byte_num - 2 : byte_num])[0]

            if marker == MARKER_BASELINE_NOISE:
                baseline = (value >> 8) & 0xFF
                noise = value & 0xFF
            elif marker == MARKER_MODE_CHANGE and not mode_flag_seen:
                mode_flag_seen = True
                raw_mode = value & 0xFF
                if raw_mode in (m.value for m in DeviceMode):
                    mode_confirmed = DeviceMode(raw_mode)
            i += byte_num

    adc_values: list[int] = []
    for j in range(0, len(data) - 1, 2):
        adc_values.append(struct.unpack(">H", data[j : j + 2])[0])

    return ParsedPacket(
        is_legacy=True,
        legacy_baseline=baseline,
        legacy_noise=noise,
        legacy_mode_confirmed=mode_confirmed,
        legacy_adc_values=tuple(adc_values),
        raw_size=len(data),
    )
