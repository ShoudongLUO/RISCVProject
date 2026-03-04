"""Immutable dataclasses for application state, parsed data, and configuration."""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import IntFlag
from typing import Optional

from .protocol import DeviceMode, PacketType


# ---------------------------------------------------------------------------
# Network / App state
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class NetworkConfig:
    """Network configuration — immutable, use replace() to update."""

    host_ip: str = "192.168.185.243"
    host_port: int = 1234
    dest_ip: str = "192.168.185.111"
    dest_port: int = 1234


@dataclass(frozen=True)
class AppState:
    """Application-level state — immutable, use replace() to update."""

    current_mode: DeviceMode = DeviceMode.IDLE
    uart_debug_active: bool = False
    is_listening: bool = False
    data_file_name: str = "ReceivedData"
    num_adc_channels: int = 20
    packet_counter: int = 0
    tdc_event_count: int = 0
    coincidence_count: int = 0


# ---------------------------------------------------------------------------
# ADC
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class AdcSample:
    """Single ADC sample: channel_id (4-bit) + 12-bit value."""

    channel_id: int  # 0-19
    raw_value: int   # 12-bit ADC code (0-4095)


@dataclass(frozen=True)
class AdcFrame:
    """One ADC packet's worth of channel-tagged samples."""

    counter: int
    samples: tuple[AdcSample, ...] = ()


# ---------------------------------------------------------------------------
# TDC
# ---------------------------------------------------------------------------

class TdcTimeFlags(IntFlag):
    """18-bit data_flag from Dual_TDC_Channel_Analysis."""

    NONE = 0
    TOT_VALID = 1 << 0
    TOA_VALID = 1 << 1
    CAL_VALID = 1 << 2


@dataclass(frozen=True)
class TdcEvent:
    """Parsed TDC event record (14 bytes on wire)."""

    channel_id: int        # 0 or 1
    flags: TdcTimeFlags
    tot_ticks: int         # 12-bit
    toa_ticks: int         # 12-bit
    cal_ticks: int         # 12-bit
    lsb_ps_q16: int        # Q16.16 fixed-point (raw 32-bit)

    @property
    def lsb_ps(self) -> float:
        """LSB in picoseconds (convert Q16.16 to float)."""
        return self.lsb_ps_q16 / 65536.0


@dataclass(frozen=True)
class CoincidenceMatch:
    """Parsed coincidence record (8 bytes on wire)."""

    time_diff_ps: int    # signed 16-bit, picoseconds
    data_flags: int      # 16-bit combined flags
    ch1_error: int       # 8-bit
    ch2_error: int       # 8-bit


# ---------------------------------------------------------------------------
# Calibration / Mode ACK
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class CalibrationData:
    """Baseline + noise from CALIBRATION packet."""

    baseline: int  # 16-bit
    noise: int     # 16-bit


@dataclass(frozen=True)
class ModeAck:
    """Mode acknowledgement from MODE_ACK packet."""

    mode: DeviceMode


# ---------------------------------------------------------------------------
# Unified parse result
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class ParsedPacket:
    """Unified result from parsing any UDP datagram (new or legacy format).

    Only the field(s) matching the packet type are populated.
    """

    packet_type: Optional[PacketType] = None
    counter: int = 0
    is_legacy: bool = False

    # ADC
    adc_frame: Optional[AdcFrame] = None

    # TDC
    tdc_events: tuple[TdcEvent, ...] = ()
    coincidence_matches: tuple[CoincidenceMatch, ...] = ()

    # Calibration / mode
    calibration: Optional[CalibrationData] = None
    mode_ack: Optional[ModeAck] = None

    # Legacy compat
    legacy_baseline: Optional[int] = None
    legacy_noise: Optional[int] = None
    legacy_mode_confirmed: Optional[DeviceMode] = None
    legacy_adc_values: tuple[int, ...] = ()

    raw_size: int = 0
