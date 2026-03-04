# FPGA Data Acquisition Host Computer (PySide6)

A PySide6 desktop application for communicating with an FPGA-based data acquisition system over UDP. Supports **20-channel tagged ADC**, **dual-channel TDC** with time-over-threshold / time-of-arrival / calibration measurements, and **coincidence matching** with picosecond-resolution delta-T analysis.

## Prerequisites

- **Python** 3.10 or newer
- **pip** (comes with Python)
- A network connection to the FPGA board (default `192.168.185.111:1234`)

## Installation

```bash
cd D:\RISCV\Host_Computer_PySide6

# Option 1: Install from requirements.txt
pip install -r requirements.txt

# Option 2: Install as editable package (recommended for development)
pip install -e .
```

### Dependencies

| Package    | Version    | Purpose                        |
|------------|------------|--------------------------------|
| PySide6    | >= 6.7.0   | Qt 6 GUI framework             |
| pyqtgraph  | >= 0.13.7  | Real-time chart rendering      |
| numpy      | >= 1.26.0  | Numeric arrays and ring buffer |

## Running the Application

```bash
# From the project root directory
python -m src.main

# Or if installed as a package
fpga-daq
```

The window opens with:
- **Top row** — three panels: Network Config, System Log, Control
- **Bottom tabs** — ADC Chart, ADC Dashboard, TDC Charts, TDC Dashboard

### Quick Start

1. **Configure network** — Set Host IP/Port (your PC) and FPGA Destination IP/Port in the Network Config panel. Defaults: `192.168.185.243:1234` (host) and `192.168.185.111:1234` (FPGA).
2. **Click Start** — Binds the UDP socket and begins listening. The status bar shows "Listening on ...".
3. **Select a mode** — Click **Calibration** or **DataAcquire** in the Control panel. The FPGA acknowledges with a mode-change packet and the current mode label updates.
4. **View data** — Switch between tabs:
   - **ADC Chart** — Real-time multi-channel line chart (20 color-coded curves)
   - **ADC Dashboard** — Packet counter, calibration baseline/noise, 20-channel value grid
   - **TDC Charts** — Delta-T histogram (+/- 3000 ps, 60 bins) and coincidence timeline
   - **TDC Dashboard** — Per-channel TOT/TOA/CAL/LSB numeric readouts, coincidence statistics
5. **Reset** — Click **Reset Figure** to clear all chart data across all tabs.
6. **Stop** — Click **Stop** in the Network panel to unbind the socket.

### Control Panel Buttons

| Button          | Action                                            |
|-----------------|---------------------------------------------------|
| IDLE            | Send IDLE mode command to FPGA                    |
| Calibration     | Send CALIBRATION mode command                     |
| DataAcquire     | Send DATA_ACQUIRE mode command                    |
| Stop Procedure  | Send stop + idle sequence, reset mode to IDLE     |
| Start Debug     | Toggle UART debug mode (sends 5x for reliability) |
| Reset Figure    | Clear all charts, counters, and dashboard values  |
| System Reset    | Send hardware reset command to FPGA               |
| Send Data       | Transmit ADC data from a CSV file to the FPGA     |

### Data File

Enter a filename (without extension) in the Data File input. When you click **Start**, received raw UDP datagrams are appended to `<filename>.bin` for offline analysis.

## Running Tests

### Unit Tests

All unit tests are pure Python (no Qt event loop required) and test the `src/core/` parsing layer.

```bash
# Run all tests with verbose output
python -m pytest tests/ -v

# Run a specific test file
python -m pytest tests/test_adc_parser.py -v

# Run with coverage report (requires pytest-cov)
pip install pytest-cov
python -m pytest tests/ --cov=src/core --cov-report=term-missing
```

### Integration Test (Live UDP)

A standalone script sends real UDP packets to the running app so you can visually verify the full pipeline (network → parsing → dispatch → UI update). No extra dependencies needed — just Python's `socket` module.

**Step 1:** Start the Host Computer and click **Start** (default settings).

**Step 2:** Run the test script in a separate terminal:

```bash
# Run all scenarios in sequence (recommended for first-time check)
python scripts/send_test_packets.py

# Run a single scenario
python scripts/send_test_packets.py --scenario adc
python scripts/send_test_packets.py --scenario adc_burst
python scripts/send_test_packets.py --scenario tdc
python scripts/send_test_packets.py --scenario coincidence
python scripts/send_test_packets.py --scenario calibration
python scripts/send_test_packets.py --scenario mode_ack
python scripts/send_test_packets.py --scenario legacy

# Custom host/port
python scripts/send_test_packets.py --host 192.168.1.100 --port 5000

# List all scenarios
python scripts/send_test_packets.py --list
```

**What to check in the UI after each scenario:**

| Scenario | What to verify |
|----------|---------------|
| `adc` | **ADC Dashboard** tab: CH00-CH09 show values and voltages, packet counter increments |
| `adc_burst` | **ADC Chart** tab: sine-wave curves appear for channels 0-4 |
| `tdc` | **TDC Dashboard** tab: CH0 and CH1 show TOT/TOA/CAL/LSB values, event counts = 1 |
| `coincidence` | **TDC Dashboard** tab: coincidence count = 50, mean/std update. **TDC Charts** tab: histogram gets bars near 200ps, timeline shows 50 points |
| `calibration` | **ADC Dashboard** tab: Baseline = 1850, Noise = 42 |
| `mode_ack` | **Control panel**: mode label changes to "Calibration" |
| `legacy` | **ADC Dashboard** tab: Baseline/Noise update via legacy code path |
| `mixed` | All of the above in sequence |

### Test Files

| File                        | Tests | What it covers                               |
|-----------------------------|-------|----------------------------------------------|
| `test_protocol.py`          | 18    | Command generation, marker constants, PacketType enum |
| `test_models.py`            | 15    | All dataclasses: creation, defaults, immutability |
| `test_adc_parser.py`        | 9     | Channel-tagged ADC word parsing, demux by channel |
| `test_tdc_parser.py`        | 12    | TDC event records, coincidence records, edge cases |
| `test_calibration_parser.py`| 14    | Calibration payload, mode-ack payload, error cases |
| `test_data_parser.py`       | 17    | New-format dispatch, all packet types, legacy fallback |
| `test_ring_buffer.py`       | 13    | Append, extend, wrap-around, capacity, edge cases |
| **Total**                   | **107** |                                              |

## UDP Packet Protocol

### New Format (recommended)

Every datagram starts with a 6-byte envelope:

```
Offset  Size  Field
0       2B    Header marker (0xAAAA)
2       1B    Packet type (see table)
3       1B    Reserved (0x00)
4       2B    Packet counter (big-endian)
6+      var   Payload (depends on type)
```

| Type byte | Name             | Payload contents                                    |
|-----------|------------------|-----------------------------------------------------|
| 0x01      | ADC              | 16-bit words: `{ch_id[3:0], adc_value[11:0]}`       |
| 0x02      | TDC_EVENT        | 14B records: `[0x7DC1, ch, flags, tot, toa, cal, lsb_q16]` |
| 0x03      | TDC_COINCIDENCE  | 8B records: `[0x7DC2, dtm_ps(int16), flags, err1, err2]` |
| 0x04      | CALIBRATION      | `[baseline(2B), noise(2B), 0x3456(2B)]`             |
| 0x05      | MODE_ACK         | `[mode_value(2B), 0x0666(2B)]`                      |

### Legacy Format (backward compatible)

If the first two bytes are **not** `0xAAAA`, the parser falls back to the original chunk-based format: fixed-size chunks of `(num_channels * 2)` bytes with marker detection at chunk boundaries.

## Crafting Test Packets

You can verify the application by sending crafted UDP packets with `netcat`, Python, or any UDP tool.

```python
import socket
import struct

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
target = ("192.168.185.243", 1234)  # your host IP/port

# --- Send an ADC packet (channel 3, value 2048) ---
header = struct.pack(">HBxH", 0xAAAA, 0x01, 1)   # envelope: ADC, counter=1
adc_word = struct.pack(">H", (3 << 12) | 2048)    # ch3, value=2048
sock.sendto(header + adc_word, target)

# --- Send a TDC event (channel 0, TOT=100, TOA=200, CAL=300, LSB=5.0ps) ---
header = struct.pack(">HBxH", 0xAAAA, 0x02, 2)
record = struct.pack(">HBBHHHI", 0x7DC1, 0, 0x07, 100, 200, 300, 0x00050000)
sock.sendto(header + record, target)

# --- Send a coincidence match (delta-T = -500 ps) ---
header = struct.pack(">HBxH", 0xAAAA, 0x03, 3)
record = struct.pack(">HhHBB", 0x7DC2, -500, 0x03, 0, 0)
sock.sendto(header + record, target)

# --- Send a calibration packet (baseline=1000, noise=50) ---
header = struct.pack(">HBxH", 0xAAAA, 0x04, 4)
payload = struct.pack(">HHH", 1000, 50, 0x3456)
sock.sendto(header + payload, target)

# --- Send a mode-ack (calibration confirmed) ---
header = struct.pack(">HBxH", 0xAAAA, 0x05, 5)
payload = struct.pack(">HH", 0x0001, 0x0666)
sock.sendto(header + payload, target)
```

## Project Structure

```
Host_Computer_PySide6/
├── pyproject.toml          # Build config, dependencies, pytest settings
├── requirements.txt        # Pip dependencies
├── scripts/
│   └── send_test_packets.py  # Integration test: send crafted UDP to running app
├── src/
│   ├── main.py             # Entry point (QApplication + QSS loading)
│   ├── core/               # Pure Python — no Qt imports
│   │   ├── protocol.py     # Constants, enums, command generation
│   │   ├── models.py       # Immutable dataclasses (ADC, TDC, state)
│   │   ├── data_parser.py  # Central dispatcher (new-format + legacy)
│   │   ├── adc_parser.py   # Channel-tagged ADC word parsing
│   │   ├── tdc_parser.py   # TDC event + coincidence record parsing
│   │   ├── calibration_parser.py  # Calibration + mode-ack parsing
│   │   └── ring_buffer.py  # NumPy circular buffer for charts
│   ├── network/            # Qt network layer
│   │   ├── udp_manager.py  # QUdpSocket bind/send/receive
│   │   ├── retry_manager.py# Timer-based command retry
│   │   └── adc_sender.py   # CSV file → UDP packet sender
│   ├── ui/                 # Qt widgets
│   │   ├── main_window.py  # QMainWindow: layout + signal wiring
│   │   ├── chart_widget.py # pyqtgraph multi-channel line chart
│   │   └── panels/
│   │       ├── network_panel.py    # IP/port config + Start/ReBind/Stop
│   │       ├── control_panel.py    # Mode buttons, debug, reset, file
│   │       ├── data_panel.py       # 20-channel ADC grid + calibration
│   │       ├── log_panel.py        # Color-coded system log
│   │       ├── tdc_panel.py        # TDC numeric dashboard
│   │       └── tdc_chart_panel.py  # Delta-T histogram + timeline
│   ├── logging_/
│   │   └── log_handler.py  # File + Qt signal logger bridge
│   └── resources/
│       └── style.qss       # Material Design light theme
└── tests/
    ├── test_protocol.py
    ├── test_models.py
    ├── test_adc_parser.py
    ├── test_tdc_parser.py
    ├── test_calibration_parser.py
    ├── test_data_parser.py
    └── test_ring_buffer.py
```

---

## Architecture & Module Reference

### Layer Diagram

```
┌─────────────────────────────────────────────────────────┐
│                      UI Layer                           │
│  main_window.py ── dispatches packets to panels/charts  │
│  ┌──────────┐ ┌───────────┐ ┌────────────┐             │
│  │ network  │ │   log     │ │  control   │             │
│  │ _panel   │ │  _panel   │ │  _panel    │             │
│  └──────────┘ └───────────┘ └────────────┘             │
│  ┌──────────┐ ┌──────────┐ ┌─────────────┐ ┌────────┐  │
│  │  chart   │ │  data    │ │ tdc_chart   │ │  tdc   │  │
│  │ _widget  │ │ _panel   │ │  _panel     │ │ _panel │  │
│  └──────────┘ └──────────┘ └─────────────┘ └────────┘  │
├─────────────────────────────────────────────────────────┤
│                    Network Layer                        │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐    │
│  │ udp_manager  │ │ retry_manager│ │  adc_sender  │    │
│  └──────────────┘ └──────────────┘ └──────────────┘    │
├─────────────────────────────────────────────────────────┤
│                     Core Layer  (no Qt)                 │
│  ┌──────────┐ ┌──────────┐ ┌─────────────┐             │
│  │ protocol │ │  models  │ │ data_parser │             │
│  └──────────┘ └──────────┘ └──────┬──────┘             │
│                                   │ dispatches to       │
│              ┌────────────────────┼────────────┐        │
│              ▼                    ▼            ▼        │
│  ┌────────────────┐ ┌─────────────┐ ┌──────────────┐   │
│  │  adc_parser    │ │ tdc_parser  │ │ calibration  │   │
│  │                │ │             │ │   _parser    │   │
│  └────────────────┘ └─────────────┘ └──────────────┘   │
│  ┌──────────────┐                                       │
│  │ ring_buffer  │                                       │
│  └──────────────┘                                       │
├─────────────────────────────────────────────────────────┤
│                    Logging Layer                        │
│  ┌──────────────┐                                       │
│  │ log_handler  │ → debug_log.txt + Signal → LogPanel   │
│  └──────────────┘                                       │
└─────────────────────────────────────────────────────────┘
```

### Core Layer (`src/core/`)

All modules in this layer are **pure Python** with no Qt imports. This makes them independently testable and reusable outside the GUI.

#### `protocol.py` — Constants, Enums, Command Generation

Single source of truth for the FPGA communication protocol.

| Item | Description |
|------|-------------|
| `DeviceMode` enum | FPGA operating modes: `IDLE` (0x00), `CALIBRATION` (0x01), `DATA_ACQUIRE` (0x02) |
| `CommandFlag` flags | Bit flags for command byte: `STOP`, `DATA_DETECTED`, `UART_DEBUG`, `RESET` |
| `PacketType` enum | New-format packet types: `ADC` (0x01), `TDC_EVENT` (0x02), `TDC_COINCIDENCE` (0x03), `CALIBRATION` (0x04), `MODE_ACK` (0x05) |
| `MARKER_PACKET_HEADER` | `0xAAAA` — identifies new-format packets |
| `MARKER_TDC_EVENT` | `0x7DC1` — TDC event record start marker |
| `MARKER_TDC_COINCIDENCE` | `0x7DC2` — Coincidence record start marker |
| `MARKER_BASELINE_NOISE` | `0x3456` — Calibration marker (also used in legacy format) |
| `MARKER_MODE_CHANGE` | `0x0666` — Mode-ack marker (also used in legacy format) |
| `generate_command()` | Builds a 4-byte command packet: `[0x00, 0x00, 0x00, control_byte]` where `control_byte = mode | flags` |

#### `models.py` — Immutable Dataclasses

All data structures used throughout the application. Every dataclass is `frozen=True` (immutable).

| Dataclass | Fields | Description |
|-----------|--------|-------------|
| `NetworkConfig` | host_ip, host_port, dest_ip, dest_port | Network addresses |
| `AppState` | current_mode, uart_debug_active, is_listening, data_file_name, num_adc_channels, packet_counter, tdc_event_count, coincidence_count | Global application state |
| `AdcSample` | channel_id (0-15), raw_value (0-4095) | Single ADC reading from a 16-bit tagged word |
| `AdcFrame` | counter, samples | Collection of `AdcSample`s from one ADC packet |
| `TdcTimeFlags` | TOT_VALID, TOA_VALID, CAL_VALID | IntFlag enum for TDC data validity bits |
| `TdcEvent` | channel_id, flags, tot_ticks, toa_ticks, cal_ticks, lsb_ps_q16 | One TDC measurement. Property `lsb_ps` converts Q16.16 to float picoseconds |
| `CoincidenceMatch` | time_diff_ps, data_flags, ch1_error, ch2_error | Coincidence match with signed delta-T in picoseconds |
| `CalibrationData` | baseline, noise | 16-bit calibration values |
| `ModeAck` | mode | DeviceMode confirmed by FPGA |
| `ParsedPacket` | packet_type, counter, is_legacy, adc_frame, tdc_events, coincidence_matches, calibration, mode_ack, legacy_* fields, raw_size | Unified parse result — only relevant fields are populated |

#### `data_parser.py` — Central Dispatch

Entry point for all UDP datagram parsing. Auto-detects packet format:

1. If `len(data) < 2` → empty legacy result
2. First 2 bytes `== 0xAAAA` and `len >= 6` → **new-format path**: reads 6-byte envelope, dispatches by `PacketType` to sub-parsers
3. Otherwise → **legacy path**: chunk-based parsing with marker detection at chunk boundaries

#### `adc_parser.py` — ADC Payload Parser

| Function | Input | Output | Description |
|----------|-------|--------|-------------|
| `parse_adc_payload(payload, counter)` | raw bytes, counter | `AdcFrame` | Each 16-bit word: `bits[15:12]` = channel_id, `bits[11:0]` = ADC value |
| `demux_frame_by_channel(frame, num_channels)` | `AdcFrame`, count | `dict[int, list[int]]` | Groups samples by channel_id |

#### `tdc_parser.py` — TDC Event & Coincidence Parser

| Function | Record size | Marker | Output |
|----------|-------------|--------|--------|
| `parse_tdc_event_payload(payload)` | 14 bytes | `0x7DC1` | `tuple[TdcEvent, ...]` — extracts ch_id, flags, TOT/TOA/CAL (12-bit masked), LSB Q16.16 |
| `parse_coincidence_payload(payload)` | 8 bytes | `0x7DC2` | `tuple[CoincidenceMatch, ...]` — extracts signed delta-T, flags, error bytes |

#### `calibration_parser.py` — Calibration & Mode-Ack Parser

| Function | Expected payload | Output |
|----------|-----------------|--------|
| `parse_calibration_payload(payload)` | 6B: `[baseline, noise, 0x3456]` | `CalibrationData` or `None` |
| `parse_mode_ack_payload(payload)` | 4B: `[mode_value, 0x0666]` | `ModeAck` or `None` |

#### `ring_buffer.py` — NumPy Circular Buffer

Fixed-capacity ring buffer for real-time chart data. Methods: `append(value)`, `extend(values)`, `get_all()` (chronological copy), `clear()`. Properties: `count`, `capacity`, `is_full`.

### Network Layer (`src/network/`)

#### `udp_manager.py` — QUdpSocket Wrapper

Manages a single `QUdpSocket`. Signals: `datagram_received(bytes)`, `bind_success(str, int)`, `bind_failed(str)`, `send_complete(int)`, `send_failed(str)`. Methods: `bind()`, `rebind()`, `send()`, `close()`.

#### `retry_manager.py` — Command Retry Logic

Retries sending a command every 1000ms until FPGA acknowledges (mode confirmed) or max 5 retries. Methods: `start(command)`, `confirm()`, `stop()`.

#### `adc_sender.py` — CSV-to-UDP Sender

Reads ADC values from CSV, applies channel filtering (192-255), packs 66 values per packet with `0x1234` header. Non-blocking via `QTimer.singleShot` (10ms delay between rows).

### UI Layer (`src/ui/`)

#### `main_window.py` — Main Window & Signal Router

Assembles panels and tabs, wires all Qt signals. Packet routing:

| Packet type | Routed to |
|-------------|-----------|
| `ADC` | `DataPanel` (channel grid) + `ChartWidget` (decimated 1:100) |
| `TDC_EVENT` | `TdcPanel` (numeric readout) |
| `TDC_COINCIDENCE` | `TdcPanel` (stats) + `TdcChartPanel` (histogram + timeline) |
| `CALIBRATION` | `DataPanel` (baseline/noise) |
| `MODE_ACK` | `ControlPanel` (mode label), updates `AppState`, stops retry |
| Legacy | Chunk-based parsing with legacy field routing |

Every received datagram also triggers a data-detected ACK to the FPGA (in Calibration/DataAcquire modes) and raw bytes are appended to the data file.

#### `chart_widget.py` — Multi-Channel ADC Chart

pyqtgraph `PlotWidget` with 20 color-coded curves. Methods: `add_channel_point(ch, x, y)`, `add_channel_samples(ch, values)`, `flush_all()`, `add_point(x, y)` (legacy), `reset()`. Max 5000 points/channel.

#### `panels/network_panel.py` — Network Configuration

Host IP/Port and FPGA Destination IP/Port inputs. Signals: `start_requested`, `rebind_requested`, `stop_requested`.

#### `panels/control_panel.py` — Mode & Tools

Wrapped in `QScrollArea` to prevent overlap. Mode buttons in 2x2 grid, Tools side-by-side. Signals: `mode_change_requested`, `stop_procedure_requested`, `uart_debug_toggled`, `reset_requested`, `reset_figure_requested`, `send_adc_requested`.

#### `panels/data_panel.py` — ADC Dashboard (Tab)

Packet counter, calibration baseline/noise, 20-channel grid (5 cols x 4 rows). Each cell: `CH##: <raw> (<voltage>V)` where voltage = raw * 3.3 / 4095.

#### `panels/tdc_panel.py` — TDC Numeric Dashboard (Tab)

Dual-channel readout (TOT/TOA/CAL/LSB/Flags/Events) side by side. Coincidence section: latest delta-T, total matches, running mean, running standard deviation (incremental computation).

#### `panels/tdc_chart_panel.py` — TDC Charts (Tab)

- **Delta-T Histogram** (top): 60-bin bar chart, +/- 3000 ps range
- **Coincidence Timeline** (bottom): scatter + line of delta-T vs match number (max 5000 points)

#### `panels/log_panel.py` — System Log

Color-coded (debug=blue, info=green, warning=orange, error=red) on dark background. Max 1000 lines, auto-scroll.

### Logging Layer (`src/logging_/log_handler.py`)

Bridges Python `logging` to both `debug_log.txt` (with timestamps) and a Qt signal connected to `LogPanel`. Methods: `debug()`, `info()`, `warning()`, `error()`.

### Styling (`src/resources/style.qss`)

Material Design light theme. Blue buttons, white group boxes with blue title bars, blue-underlined active tabs, dark terminal log panel, thin scrollbars.

### Data Flow

```
FPGA  ──UDP──►  QUdpSocket (udp_manager)
                      │
                      ▼ datagram_received signal
               MainWindow._on_datagram()
                      │
                      ▼
               data_parser.parse_datagram()
                  │         │
         0xAAAA? Yes       No (legacy)
                  │         │
          ┌───────┴───┐     └──► _parse_legacy()
          ▼           ▼              │
    PacketType    sub-parsers        ▼
    dispatch:     adc_parser    legacy fields in
    ADC/TDC/      tdc_parser    ParsedPacket
    CAL/ACK       cal_parser
          │
          ▼
    ParsedPacket (immutable)
          │
          ▼
    MainWindow routes to UI:
    ├── DataPanel (ADC grid, calibration)
    ├── ChartWidget (ADC line chart)
    ├── TdcPanel (numeric dashboard)
    ├── TdcChartPanel (histogram, timeline)
    └── ControlPanel (mode label update)
```
