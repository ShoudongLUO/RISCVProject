"""Send crafted UDP packets to the running Host Computer for integration testing.

Usage:
    # Start the Host Computer first, click "Start" with default settings.
    # Then run this script:

    python scripts/send_test_packets.py                  # run all scenarios
    python scripts/send_test_packets.py --scenario adc   # run one scenario
    python scripts/send_test_packets.py --list            # list all scenarios
    python scripts/send_test_packets.py --host 192.168.185.243 --port 1234

What to check in the UI after each scenario:
    1. adc        → ADC Dashboard tab: channels show values, packet counter increments
    2. adc_burst  → ADC Chart tab: curves appear for channels 0-4
    3. tdc        → TDC Dashboard tab: CH0/CH1 show TOT/TOA/CAL/LSB values
    4. coincidence→ TDC Dashboard tab: coincidence stats update
                    TDC Charts tab: histogram gets bars, timeline gets points
    5. calibration→ ADC Dashboard tab: baseline and noise values update
    6. mode_ack   → Control panel: mode label changes to "Calibration"
    7. legacy     → ADC Dashboard tab: baseline/noise update (legacy path)
    8. mixed      → Run all of the above in sequence with delays
"""

from __future__ import annotations

import argparse
import math
import random
import socket
import struct
import sys
import time


# --------------------------------------------------------------------------
# Protocol constants (duplicated here so the script is standalone)
# --------------------------------------------------------------------------
MARKER_HEADER = 0xAAAA
MARKER_TDC_EVENT = 0x7DC1
MARKER_TDC_COINCIDENCE = 0x7DC2
MARKER_BASELINE_NOISE = 0x3456
MARKER_MODE_CHANGE = 0x0666

TYPE_ADC = 0x01
TYPE_TDC_EVENT = 0x02
TYPE_TDC_COINCIDENCE = 0x03
TYPE_CALIBRATION = 0x04
TYPE_MODE_ACK = 0x05


# --------------------------------------------------------------------------
# Packet builders
# --------------------------------------------------------------------------

def make_envelope(pkt_type: int, counter: int) -> bytes:
    """6-byte new-format envelope."""
    return struct.pack(">HBxH", MARKER_HEADER, pkt_type, counter)


def make_adc_word(channel_id: int, value: int) -> bytes:
    """Single 16-bit ADC word: bits[15:12]=ch, bits[11:0]=value."""
    return struct.pack(">H", ((channel_id & 0x0F) << 12) | (value & 0x0FFF))


def make_tdc_event_record(
    ch_id: int, tot: int, toa: int, cal: int, lsb_q16: int, flags: int = 0x07
) -> bytes:
    """14-byte TDC event record."""
    return struct.pack(
        ">HBBHHHI", MARKER_TDC_EVENT, ch_id, flags, tot, toa, cal, lsb_q16
    )


def make_coincidence_record(
    dtm_ps: int, data_flags: int = 0x03, ch1_err: int = 0, ch2_err: int = 0
) -> bytes:
    """8-byte coincidence record."""
    return struct.pack(
        ">HhHBB", MARKER_TDC_COINCIDENCE, dtm_ps, data_flags, ch1_err, ch2_err
    )


# --------------------------------------------------------------------------
# Test scenarios
# --------------------------------------------------------------------------

def send_adc(sock: socket.socket, target: tuple, counter: int) -> int:
    """Send one ADC packet with samples on channels 0-9."""
    print("  [ADC] Sending 10 samples on channels 0-9...")
    payload = b""
    for ch in range(10):
        value = random.randint(500, 3500)
        payload += make_adc_word(ch, value)
        print(f"    CH{ch:02d} = {value} ({value * 3.3 / 4095:.3f}V)")
    packet = make_envelope(TYPE_ADC, counter) + payload
    sock.sendto(packet, target)
    return counter + 1


def send_adc_burst(sock: socket.socket, target: tuple, counter: int) -> int:
    """Send 200 ADC packets to populate the chart (channels 0-4, sine waves)."""
    print("  [ADC BURST] Sending 200 packets with sine-wave data on CH0-4...")
    for i in range(200):
        payload = b""
        for ch in range(5):
            phase = ch * 0.5
            value = int(2048 + 1500 * math.sin(2 * math.pi * i / 50 + phase))
            value = max(0, min(4095, value))
            payload += make_adc_word(ch, value)
        packet = make_envelope(TYPE_ADC, counter) + payload
        sock.sendto(packet, target)
        counter += 1
        time.sleep(0.005)  # 5ms between packets
    print(f"    Sent 200 packets (counter now {counter})")
    return counter


def send_tdc(sock: socket.socket, target: tuple, counter: int) -> int:
    """Send TDC events for both channels."""
    print("  [TDC EVENT] Sending 2 TDC events (CH0 and CH1)...")
    # Channel 0: TOT=150, TOA=320, CAL=280, LSB=7.5ps (Q16.16 = 0x00078000)
    rec0 = make_tdc_event_record(0, tot=150, toa=320, cal=280, lsb_q16=0x00078000)
    print("    CH0: TOT=150, TOA=320, CAL=280, LSB=7.5ps")

    # Channel 1: TOT=200, TOA=410, CAL=350, LSB=8.2ps (Q16.16 ~ 0x00083333)
    rec1 = make_tdc_event_record(1, tot=200, toa=410, cal=350, lsb_q16=0x00083333)
    print("    CH1: TOT=200, TOA=410, CAL=350, LSB=8.2ps")

    packet = make_envelope(TYPE_TDC_EVENT, counter) + rec0 + rec1
    sock.sendto(packet, target)
    return counter + 1


def send_coincidence(sock: socket.socket, target: tuple, counter: int) -> int:
    """Send 50 coincidence matches with Gaussian-distributed delta-T."""
    print("  [COINCIDENCE] Sending 50 matches (Gaussian, mean=200ps, std=500ps)...")
    payload = b""
    for _ in range(50):
        dtm = int(random.gauss(200, 500))
        dtm = max(-3000, min(3000, dtm))  # clamp to histogram range
        payload += make_coincidence_record(dtm)
    packet = make_envelope(TYPE_TDC_COINCIDENCE, counter) + payload
    sock.sendto(packet, target)
    print(f"    Sent 50 coincidence records")
    return counter + 1


def send_calibration(sock: socket.socket, target: tuple, counter: int) -> int:
    """Send a calibration packet."""
    baseline = 1850
    noise = 42
    print(f"  [CALIBRATION] baseline={baseline}, noise={noise}")
    payload = struct.pack(">HHH", baseline, noise, MARKER_BASELINE_NOISE)
    packet = make_envelope(TYPE_CALIBRATION, counter) + payload
    sock.sendto(packet, target)
    return counter + 1


def send_mode_ack(sock: socket.socket, target: tuple, counter: int) -> int:
    """Send a mode-ack confirming CALIBRATION mode."""
    print("  [MODE_ACK] Confirming mode = CALIBRATION (0x01)")
    payload = struct.pack(">HH", 0x0001, MARKER_MODE_CHANGE)
    packet = make_envelope(TYPE_MODE_ACK, counter) + payload
    sock.sendto(packet, target)
    return counter + 1


def send_legacy(sock: socket.socket, target: tuple, _counter: int) -> int:
    """Send a legacy-format packet (no 0xAAAA header)."""
    print("  [LEGACY] Sending legacy chunk (3ch) with baseline=0xAB, noise=0x0C")
    # 3-channel chunk: 2 bytes padding + 2 bytes value + 2 bytes marker
    value = 0xAB0C  # baseline=0xAB, noise=0x0C
    chunk = b"\x00\x00" + struct.pack(">HH", value, MARKER_BASELINE_NOISE)
    sock.sendto(chunk, target)
    return _counter


SCENARIOS = {
    "adc": ("Single ADC packet (10 channels)", send_adc),
    "adc_burst": ("200 ADC packets with sine waves on CH0-4", send_adc_burst),
    "tdc": ("TDC events for CH0 and CH1", send_tdc),
    "coincidence": ("50 coincidence matches (Gaussian distribution)", send_coincidence),
    "calibration": ("Calibration baseline + noise", send_calibration),
    "mode_ack": ("Mode-ack confirming CALIBRATION", send_mode_ack),
    "legacy": ("Legacy-format baseline/noise packet", send_legacy),
}


def run_mixed(sock: socket.socket, target: tuple) -> None:
    """Run all scenarios in sequence with pauses."""
    counter = 1
    order = ["calibration", "mode_ack", "adc", "tdc", "coincidence", "adc_burst", "legacy"]
    for name in order:
        desc, func = SCENARIOS[name]
        print(f"\n--- {name}: {desc} ---")
        counter = func(sock, target, counter)
        time.sleep(0.5)


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Send test UDP packets to the FPGA DAQ Host Computer.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "--host", default="192.168.1.41",
        help="Host Computer IP (default: 192.168.1.41)",
    )
    parser.add_argument(
        "--port", type=int, default=1234,
        help="Host Computer port (default: 1234)",
    )
    parser.add_argument(
        "--scenario", "-s", choices=list(SCENARIOS.keys()) + ["mixed"],
        default="mixed",
        help="Which scenario to run (default: mixed = all)",
    )
    parser.add_argument(
        "--list", "-l", action="store_true",
        help="List all available scenarios and exit",
    )
    args = parser.parse_args()

    if args.list:
        print("Available scenarios:")
        for name, (desc, _) in SCENARIOS.items():
            print(f"  {name:15s} — {desc}")
        print(f"  {'mixed':15s} — Run all scenarios in sequence")
        return

    target = (args.host, args.port)
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    print(f"Target: {target[0]}:{target[1]}")
    print(f"Scenario: {args.scenario}")
    print()

    if args.scenario == "mixed":
        run_mixed(sock, target)
    else:
        desc, func = SCENARIOS[args.scenario]
        print(f"--- {args.scenario}: {desc} ---")
        func(sock, target, counter=1)

    print("\nDone. Check the Host Computer UI for results.")
    sock.close()


if __name__ == "__main__":
    main()
