这是一份完整且结构清晰的 `README.md`。按照你的要求，我特别将仿真部分划分为**“单元模块测试”**和**“SoC系统集成测试”**两大部分，并详细解释了数据流和工作原理。

---

# Tiny FPGA LGAD LATRIC DAQ System

本项目实现了一个用于 LGAD（Low-Gain Avalanche Diode）探测器的高精度数据采集与分析系统（DAQ）。系统基于 RISC-V SoC 架构，集成了专用的 RTL 硬件加速模块，支持从高速示波器/TDC 接口接收数据、进行实时符合分析（Coincidence Analysis），并通过 UDP 以太网传输结果。

---

## 🛠️ 数据预处理工作流 (Python Data Workflow)

在进行 RTL 仿真前，必须将真实的物理波形转换为 FPGA 可读取的数字激励向量。

### 脚本：`gen_128bit_Package.py`
该脚本负责“软件数字化”和“协议打包”。

1.  **读取 (Read)**:
    *   解析示波器导出的 CSV 文件（包含时间戳和两路通道电压）。
    *   **自动采样率检测**: 自动计算采样间隔（如 0.16ns），处理文件头。
2.  **数字化 (Digitize)**:
    *   设定电压阈值（如 0.13V）。遍历模拟数据，将其转换为 `0/1` 比特流。
3.  **编码 (Encode)**:
    *   **时域转换**: 将高电平持续时间转换为 720MHz 时钟下的比特数。
    *   **组包**: 搜索同步头，并将数据填入 **128-bit 私有协议**：
        *   `[127:98]` Fine TOT (30-bit)
        *   `[97:68]` Fine TOA (30-bit)
        *   `[67:38]` Fine CAL (30-bit)
        *   `[37:17]` Coarse Counters (7-bit x3)
4.  **生成 (Generate)**:
    *   输出 `ch1_vectors.txt` 和 `ch2_vectors.txt`（十六进制文件），供仿真器读取。

---

## ⚡ RTL LATRIC 分析工作流 (Analysis Workflow)

FPGA 内部的 `top_dual_channel_analysis` 模块执行核心物理分析，流程如下：

```mermaid
graph LR
    Raw[128-bit Raw Data] --> Decoder[FineTime Decoder]
    Decoder --> Calib[Calibration & AbsTime]
    Calib --> FIFO[Async FIFO]
    FIFO --> Matcher[Coincidence Matcher]
    Matcher --> Result[Delta T Output]
```

1.  **解码与检错 (`TDC_FineTime_Decoder.sv`)**:
    *   接收 30-bit 温度计码（Thermometer Code）。
    *   **边缘检测**: 寻找 `0` 到 `1` 的跳变点。
    *   **气泡检测 (Bubble Check)**: 验证 `1` 的总数是否严格等于 15，过滤亚稳态或噪声产生的无效数据。
2.  **校准与时间计算 (`tdc_channel_core.sv`)**:
    *   **在线校准**: 利用 CAL 和 TOA 的计数值差（`dcode`）与参考时钟周期（55.55ns）计算当前的 LSB 精度（皮秒/Bin）。
    *   **绝对时间**: `Abs_Time = Total_Ticks * LSB`。
3.  **符合分析 (`Coincidence_Matcher.sv`)**:
    *   **跨时钟域**: 使用异步 FIFO 将数据从解码时钟域（Fast Clk）同步到分析时钟域（Sys Clk）。
    *   **滑动窗口匹配**: 实时比对两通道数据。若 `abs(T1 - T2) < Window` (如 3ns)，判定为符合事件。
    *   **周期修正**: 自动处理计数器翻转导致的周期性时间偏差。

---

## 🧪 仿真与验证 (Simulation & Verification)

本项目包含两个层级的仿真环境，分别用于算法验证和全系统集成验证。

### 1. 单元模块测试 (Module Level Test)
*   **文件**: `TDC_tb.sv`
*   **目标**: `top_dual_channel_analysis.sv` (纯逻辑模块)
*   **目的**: 快速验证解码算法、校准数学运算和匹配逻辑是否正确，不涉及 CPU 和总线。
*   **特点**: 编译速度快，波形清晰，适合调试算法细节（如 LSB 计算精度、气泡检测灵敏度）。

### 2. SoC 系统集成测试 (System Integration Test)
这是对最终上板逻辑的完整模拟，验证分析模块是否能正确挂载到 SoC 中并正常工作。

*   **顶层文件**: `FPGA_TDC_SoC_tb.sv`
*   **目标**: `fpga_tdc_test.v` (包含 `tinyriscv_soc_top`)

#### 仿真层级架构 (Hierarchy):

1.  **Testbench (`FPGA_TDC_SoC_tb`)**:
    *   **职责**: 仅提供外部物理激励（时钟、复位、按键）。它不直接处理数据，而是模拟用户按下“开始”按钮的操作。

2.  **虚拟开发板/数据发生器 (`fpga_tdc_test`)**:
    *   **角色**: 这是一个用于仿真的 FPGA 顶层封装（Simulation Wrapper）。
    *   **核心机制**:
        *   利用 `$readmemh` 加载 Python 生成的 `ch*_vectors.txt` 到内部显存。
        *   当检测到 `start_btn` 信号后，充当**虚拟探测器**，将显存中的数据按时序注入到 SoC 的引脚。
        *   这样做隔离了不可综合代码（文件读取），保证了 SoC 代码的纯洁性。

3.  **SoC 核心 (`tinyriscv_soc_top`)**:
    *   **集成**: 内部实例化了 `top_dual_channel_analysis`。
    *   **数据流**: 128-bit 数据从端口进入 -> 经过分析模块处理 -> 生成 `match_valid` 中断或数据 -> (未来) 送入 RISC-V 总线或 UDP 发送模块。

#### 如何运行系统仿真:
1.  在 Vivado 中将 `FPGA_TDC_SoC_tb.sv` 设置为 **Top Module**。
2.  确保 `ch1_vectors.txt` 等文件位于仿真运行目录中。
3.  运行仿真，观察 `tinyriscv_soc_top` 内部的 `match_time_diff_ps` 信号，确认是否正确解算出了时间差。

---

## 🚀 快速开始

1.  **生成数据**:
    ```bash
    python gen_128bit_Package.py ./data/scope_trace.csv
    ```
2.  **启动仿真**:
    打开 Vivado，加载项目。
    *   **调试算法**: 运行 `TDC_tb`。
    *   **调试系统**: 运行 `FPGA_TDC_SoC_tb`。
3.  **观察结果**:
    在波形窗口中查找 `match_valid` 信号的高电平脉冲，并查看对应的 `Time Delta` 值。