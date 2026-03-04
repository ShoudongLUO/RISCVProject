#!/usr/bin/env python3
"""verify_and_send.py — Verify RTL simulation output and send to Host PC.

1. Reads binary dump (host_pc_udp_payloads.bin) from Vivado simulation.
2. Verifies packets using the real Host_Computer_PySide6 parsers.
3. Sends packets to the Host PC via UDP (supporting both raw and payload-only modes).

Usage:
    python verify_and_send.py [path/to/host_pc_udp_payloads.bin]
"""

from __future__ import annotations

import struct
import sys
import socket
import time
from pathlib import Path

# ===========================================================================
# CONFIGURATION
# ===========================================================================

# Network Configuration
DEST_IP = "192.168.185.243"  # Target Host PC IP
DEST_PORT = 1234             # Target UDP Port

# Simulation File Path Configuration
_DAQ_ROOT = Path("C:/Users/ShoudongLUO/Desktop/RISCV/TinyRiscV_My/DAQ")
DEFAULT_BIN_PATH = _DAQ_ROOT / "Tiny_FPGA_LGard_LATRIC" / "Tiny_FPGA.sim" / "sim_1" / "behav" / "xsim" / "host_pc_udp_payloads.bin"

# Host Code Source Path (for importing parsers)
_SCRIPT_DIR = Path(__file__).resolve().parent
# Navigate up from DAQ/Tiny.../sim_1/new/ to DAQ/
_HOST_PC_SRC = _DAQ_ROOT / "Host_Computer_PySide6" / "src"

# ===========================================================================
# IMPORT HOST PARSERS
# ===========================================================================

if not _HOST_PC_SRC.is_dir():
    print(f"ERROR: Cannot find Host_Computer_PySide6/src at {_HOST_PC_SRC}")
    sys.exit(1)

sys.path.insert(0, str(_HOST_PC_SRC))

try:
    from core.data_parser import parse_datagram
    from core.protocol import PacketType
except ImportError as e:
    print(f"ERROR: Failed to import Host PC parsers: {e}")
    sys.exit(1)


# ===========================================================================
# FILE READER
# ===========================================================================

def read_payloads(bin_path: Path) -> list[bytes]:
    """Read length-prefixed UDP payloads from the simulation binary file.

    File format: repeating [uint16_le length][length bytes payload].
    """
    payloads: list[bytes] = []
    try:
        data = bin_path.read_bytes()
    except Exception as e:
        print(f"ERROR: Failed to read file {bin_path}: {e}")
        return []

    offset = 0
    while offset + 2 <= len(data):
        # Read 2-byte length header (Little Endian)
        pkt_len = struct.unpack_from("<H", data, offset)[0]
        offset += 2
        
        # Safety check for file truncation
        if offset + pkt_len > len(data):
            print(f"WARNING: Truncated packet at offset {offset - 2}, "
                  f"expected {pkt_len} bytes but only {len(data) - offset} remain")
            break
            
        payloads.append(data[offset : offset + pkt_len])
        offset += pkt_len
        
    return payloads


# ===========================================================================
# VERIFICATION LOGIC
# ===========================================================================

_PKT_TYPE_NAMES = {
    PacketType.ADC: "ADC",
    PacketType.TDC_EVENT: "TDC_EVENT",
    PacketType.TDC_COINCIDENCE: "TDC_COINCIDENCE",
    PacketType.CALIBRATION: "CALIBRATION",
    PacketType.MODE_ACK: "MODE_ACK",
}

def pkt_type_name(pt: PacketType | None) -> str:
    if pt is None: return "NONE"
    return _PKT_TYPE_NAMES.get(pt, f"UNKNOWN(0x{pt:02x})")

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
        if len(payload) > 20: hex_preview += " ..."

        try:
            # Attempt to parse using the Host's logic
            result = parse_datagram(payload)
        except Exception as exc:
            failed += 1
            print(f"  [{pkt_num:4d}] FAIL  len={len(payload):4d}  EXCEPTION: {exc}")
            print(f"         hex: {hex_preview}")
            continue

        # Check if the result contains valid data
        ok = True
        details = []

        if result.is_legacy:
            details.append("legacy format")
        else:
            details.append(f"type={pkt_type_name(result.packet_type)}")
            details.append(f"cnt={result.counter}")

            if result.packet_type == PacketType.ADC:
                if result.adc_frame is None: ok = False; details.append("NO DATA")
                else: details.append(f"{len(result.adc_frame.samples)} samples")
            
            elif result.packet_type == PacketType.TDC_EVENT:
                details.append(f"{len(result.tdc_events)} events")
            
            elif result.packet_type == PacketType.TDC_COINCIDENCE:
                details.append(f"{len(result.coincidence_matches)} matches")

            elif result.packet_type is None:
                ok = False; details.append("UNKNOWN TYPE")

        status = "OK  " if ok else "FAIL"
        if ok: passed += 1
        else: failed += 1

        print(f"  [{pkt_num:4d}] {status}  len={len(payload):4d}  {', '.join(details)}")

    # Summary
    print(f"\n{'='*60}")
    print(f"  VERIFY RESULTS: {passed} passed, {failed} failed")
    if failed > 0: print("  WARNING: Some packets failed verification.")
    else: print("  SUCCESS: All packets verified.")
    print(f"{'='*60}\n")

    return failed == 0


# ===========================================================================
# SENDING LOGIC
# ===========================================================================

def send_payloads(payloads: list[bytes], mode: str = 'full'):
    """Send packets to Host PC via UDP.
    
    Args:
        payloads: List of binary packets.
        mode: 'full' = Send entire packet (header + body).
              'data' = Strip potential headers (e.g., first 4 bytes) and send body.
    """
    print(f"\n{'='*60}")
    print(f"  Sending {len(payloads)} packets to {DEST_IP}:{DEST_PORT}")
    print(f"  Mode: {mode.upper()}")
    print(f"{'='*60}\n")

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    
    count = 0
    for payload in payloads:
        data_to_send = payload

        # MODE 2: Extract Data Only (Example: Strip 4-byte Sequence/Header)
        # Modify the slicing index based on your specific protocol header size
        if mode == 'data':
            HEADER_SIZE = 8  # Example: 8 bytes header to strip
            if len(payload) > HEADER_SIZE:
                data_to_send = payload[HEADER_SIZE:]
            else:
                # If packet is too short, skip stripping or skip sending
                # data_to_send = payload 
                continue 

        # Send via UDP
        sock.sendto(data_to_send, (DEST_IP, DEST_PORT))
        count += 1
        
        # Rate Limiting (Prevent buffer overflow on Host)
        time.sleep(0.002) 
        
        if count % 50 == 0:
            print(f"  Sent {count} packets...")

    print(f"  Done. Sent {count} packets.")
    sock.close()


# ===========================================================================
# MAIN ENTRY POINT
# ===========================================================================

def main() -> None:
    # 1. Determine Binary File Path
    if len(sys.argv) > 1:
        bin_path = Path(sys.argv[1])
    else:
        bin_path = DEFAULT_BIN_PATH

    print(f"Target File: {bin_path}")

    if not bin_path.exists():
        print(f"ERROR: File not found at {bin_path}")
        print("Hint: Run the FPGA_TDC_SoC_HostPC_tb simulation first.")
        sys.exit(1)

    # 2. Read Payloads from File
    payloads = read_payloads(bin_path)
    if not payloads:
        print("WARNING: No payloads found in file.")
        sys.exit(1)

    # 3. Verify Payloads (Offline Check)
    print("Step 1: Verifying packets...")
    verification_passed = verify(payloads)
    
    if not verification_passed:
        user_input = input("Verification found errors. Continue sending? (y/n): ")
        if user_input.lower() != 'y':
            sys.exit(1)

    # 4. Send Payloads (Real UDP Transmission)
    # Configure Mode Here: 'full' or 'data'
    # 'full' = Sends exactly what RTL dumped
    # 'data' = Strips headers (configure HEADER_SIZE in function)
    SEND_MODE = 'full' 
    
    print("Step 2: Sending packets...")
    send_payloads(payloads, mode=SEND_MODE)

if __name__ == "__main__":
    main()