#!/usr/bin/env python3
"""verify_with_host_pc.py — Feed RTL simulation output through the REAL Host PC parsers.

Reads host_pc_udp_payloads.bin (produced by FPGA_TDC_SoC_HostPC_tb.sv),
passes each UDP payload through Host_Computer_PySide6's parse_datagram(),
and reports whether the RTL output is correctly parsed by the host software.

Usage:
    python verify_with_host_pc.py [path/to/host_pc_udp_payloads.bin]

Exit codes:
    0  — all packets parsed successfully
    1  — one or more packets failed to parse
"""

from __future__ import annotations

import struct
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Resolve the Host_Computer_PySide6 source so we can import the real parsers
# ---------------------------------------------------------------------------
_SCRIPT_DIR = Path(__file__).resolve().parent
_HOST_PC_SRC = _SCRIPT_DIR.parent / "Host_Computer_PySide6" / "src"

if not _HOST_PC_SRC.is_dir():
    # Try relative to DAQ root
    _HOST_PC_SRC = _SCRIPT_DIR.parents[1] / "Host_Computer_PySide6" / "src"

if _HOST_PC_SRC.is_dir():
    sys.path.insert(0, str(_HOST_PC_SRC))
else:
    print(f"ERROR: Cannot find Host_Computer_PySide6/src (tried {_HOST_PC_SRC})")
    sys.exit(1)

from core.data_parser import parse_datagram  # noqa: E402
from core.protocol import PacketType  # noqa: E402


# ---------------------------------------------------------------------------
# Read the binary dump from RTL simulation
# ---------------------------------------------------------------------------
def read_payloads(bin_path: Path) -> list[bytes]:
    """Read length-prefixed UDP payloads from the simulation binary file.

    File format: repeating [uint16_le length][length bytes payload].
    """
    payloads: list[bytes] = []
    data = bin_path.read_bytes()
    offset = 0
    while offset + 2 <= len(data):
        pkt_len = struct.unpack_from("<H", data, offset)[0]
        offset += 2
        if offset + pkt_len > len(data):
            print(f"WARNING: Truncated packet at offset {offset - 2}, "
                  f"expected {pkt_len} bytes but only {len(data) - offset} remain")
            break
        payloads.append(data[offset : offset + pkt_len])
        offset += pkt_len
    return payloads


# ---------------------------------------------------------------------------
# Packet type display helper
# ---------------------------------------------------------------------------
_PKT_TYPE_NAMES = {
    PacketType.ADC: "ADC",
    PacketType.TDC_EVENT: "TDC_EVENT",
    PacketType.TDC_COINCIDENCE: "TDC_COINCIDENCE",
    PacketType.CALIBRATION: "CALIBRATION",
    PacketType.MODE_ACK: "MODE_ACK",
}


def pkt_type_name(pt: PacketType | None) -> str:
    if pt is None:
        return "NONE"
    return _PKT_TYPE_NAMES.get(pt, f"UNKNOWN(0x{pt:02x})")


# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------
def verify(payloads: list[bytes]) -> bool:
    """Parse each payload with the real host parsers and report results."""
    total = len(payloads)
    passed = 0
    failed = 0

    print(f"\n{'='*60}")
    print(f"  Verifying {total} UDP payloads with Host PC parsers")
    print(f"{'='*60}\n")

    for i, payload in enumerate(payloads):
        pkt_num = i + 1
        hex_preview = payload[:20].hex(" ")
        if len(payload) > 20:
            hex_preview += " ..."

        try:
            result = parse_datagram(payload)
        except Exception as exc:
            failed += 1
            print(f"  [{pkt_num:4d}] FAIL  len={len(payload):4d}  "
                  f"EXCEPTION: {exc}")
            print(f"         hex: {hex_preview}")
            continue

        # Determine if the parse produced meaningful data
        ok = True
        details = []

        if result.is_legacy:
            details.append("legacy format")
            if result.legacy_adc_values:
                details.append(f"{len(result.legacy_adc_values)} ADC words")
            if result.legacy_baseline is not None:
                details.append(f"baseline={result.legacy_baseline}")
            if result.legacy_noise is not None:
                details.append(f"noise={result.legacy_noise}")
            if result.legacy_mode_confirmed is not None:
                details.append(f"mode={result.legacy_mode_confirmed.name}")
        else:
            details.append(f"type={pkt_type_name(result.packet_type)}")
            details.append(f"counter={result.counter}")

            if result.packet_type == PacketType.ADC:
                if result.adc_frame is None:
                    ok = False
                    details.append("MISSING adc_frame")
                else:
                    n = len(result.adc_frame.samples)
                    details.append(f"{n} samples")
                    if n == 0:
                        ok = False
                        details.append("EMPTY samples")

            elif result.packet_type == PacketType.TDC_EVENT:
                n = len(result.tdc_events)
                details.append(f"{n} events")
                if n == 0:
                    ok = False
                    details.append("EMPTY events")

            elif result.packet_type == PacketType.TDC_COINCIDENCE:
                n = len(result.coincidence_matches)
                details.append(f"{n} matches")
                if n == 0:
                    ok = False
                    details.append("EMPTY matches")

            elif result.packet_type == PacketType.CALIBRATION:
                if result.calibration is None:
                    ok = False
                    details.append("MISSING calibration")
                else:
                    details.append(
                        f"baseline={result.calibration.baseline} "
                        f"noise={result.calibration.noise}"
                    )

            elif result.packet_type == PacketType.MODE_ACK:
                if result.mode_ack is None:
                    ok = False
                    details.append("MISSING mode_ack")
                else:
                    details.append(f"mode={result.mode_ack.mode.name}")

            elif result.packet_type is None:
                ok = False
                details.append("UNKNOWN packet type")

        status = "OK  " if ok else "FAIL"
        if ok:
            passed += 1
        else:
            failed += 1

        detail_str = ", ".join(details)
        print(f"  [{pkt_num:4d}] {status}  len={len(payload):4d}  {detail_str}")

        if not ok:
            print(f"         hex: {hex_preview}")

    # Summary
    print(f"\n{'='*60}")
    print(f"  RESULTS: {passed} passed, {failed} failed, {total} total")
    if failed == 0 and total > 0:
        print("  RTL output is COMPATIBLE with Host PC parsers")
    elif total == 0:
        print("  WARNING: No packets captured — check simulation")
    else:
        print("  INCOMPATIBLE: Some packets could not be parsed")
    print(f"{'='*60}\n")

    return failed == 0


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main() -> None:
    if len(sys.argv) > 1:
        bin_path = Path(sys.argv[1])
    else:
        bin_path = Path("host_pc_udp_payloads.bin")

    if not bin_path.exists():
        print(f"ERROR: {bin_path} not found.")
        print("Run the FPGA_TDC_SoC_HostPC_tb simulation first.")
        sys.exit(1)

    payloads = read_payloads(bin_path)
    if not payloads:
        print("WARNING: No payloads found in file (empty or corrupt).")
        sys.exit(1)

    success = verify(payloads)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
