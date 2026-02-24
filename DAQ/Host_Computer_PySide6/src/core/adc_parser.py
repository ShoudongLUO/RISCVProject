"""Parse channel-tagged ADC payloads from new-format packets.

Each 16-bit word: bits[15:12] = channel_id, bits[11:0] = adc_value.
"""

from __future__ import annotations

import struct

from .models import AdcFrame, AdcSample


def parse_adc_payload(payload: bytes, counter: int) -> AdcFrame:
    """Demux a new-format ADC payload into per-channel samples.

    Args:
        payload: Raw bytes after the 6-byte envelope (all 16-bit BE words).
        counter: Packet counter from the envelope.

    Returns:
        AdcFrame with channel-tagged samples.
    """
    samples: list[AdcSample] = []
    for offset in range(0, len(payload) - 1, 2):
        word = struct.unpack(">H", payload[offset : offset + 2])[0]
        channel_id = (word >> 12) & 0x0F
        raw_value = word & 0x0FFF
        samples.append(AdcSample(channel_id=channel_id, raw_value=raw_value))
    return AdcFrame(counter=counter, samples=tuple(samples))


def demux_frame_by_channel(
    frame: AdcFrame, num_channels: int = 20
) -> dict[int, list[int]]:
    """Group an AdcFrame's samples by channel_id.

    Returns:
        Dict mapping channel_id -> list of 12-bit ADC values.
    """
    result: dict[int, list[int]] = {ch: [] for ch in range(num_channels)}
    for sample in frame.samples:
        if 0 <= sample.channel_id < num_channels:
            result[sample.channel_id].append(sample.raw_value)
    return result
