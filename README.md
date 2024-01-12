# <img src="README.assets/cpu.png" width="40" align=center /> RISCV-CPU 2023


## 项目说明

本项目使用 Verilog 语言完成课一个简单的 RISC-V CPU 电路设计。Verilog 代码会以软件仿真和 FPGA 板两种方式运行。

该 CPU 采用 Tomasulo Algorithm 来完成乱序执行。

## 项目阶段

- 环境配置
- 完成 `cpu.v` 的所有模块, 根据 `riscv/src/cpu.v` 提供的接口自顶向下完成代码 （feat: 23.12.09）
- 使用 iVerilog 进行本地仿真测试（结果为 `.vcd` 文件）通过可执行的测试（feat: 23.12.17）
- 将 Verilog 代码烧录至 FPGA 板上，在 FPGA 上通过所有测试（feat: 24.1.5）

## 实现说明

- 使用 Tomasulo 算法，主要模块有 MemoryController, InsFetcher, ICache, Dispatcher, ROB(size 32), RS(size 16), LSB(size 16), Decoder, ALU
- ICache 采用直接映射，大小为 2KB，共 512 个条目
- ROB 采用顺序提交
- LSB 采用顺序提交，以期存储和读取指令不会乱序
- 存在 ALU to LSB/ROB/Dispatcher/RS, LSB to LSB/ROB/Dispatcher 的 Forward Line，以保证性能和正确性
- 为了保证 WNS 为正，将频率降至 77MHz

## 指令集

> 可参考资料见 [RISC-V 指令集](#RISC-V-指令集)

本项目使用 **RV32I 指令集**

基础测试内容不包括 Doubleword 和 Word 相关指令、Environment 相关指令和 CSR 相关等指令。

必须要实现的指令为以下 37 个：`LUI`, `AUIPC`, `JAL`, `JALR`, `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU`, `LB`, `LH`, `LW`, `LBU`, `LHU`, `SB`, `SH`, `SW`, `ADDI`, `SLLI`, `SLTI`, `SLTIU`, `XORI`, `SRLI`, `SRAI`, `ORI`, `ANDI`, `ADD`, `SUB`, `SLL`, `SLT`, `SLTU`, `XOR`, `SRL`, `SRA`, `OR`, `AND`


如果需要额外参考信息，以下内容可能对你有帮助：
- RISC-V官网 https://riscv.org/
- [官方文档下载页面](https://riscv.org/technical/specifications/)
- 基础内容见 Volume 1, Unprivileged Spec
- 特权指令集见 Volume 2, Privileged Spec
- 非官方 [Read the Docs 文档](https://msyksphinz-self.github.io/riscv-isadoc/html/index.html)
- 非官方 Green Card，[PDF 下载链接](https://inst.eecs.berkeley.edu/~cs61c/fa17/img/riscvcard.pdf)
- RISC-V C and C++ Cross-compiler https://jbox.sjtu.edu.cn/l/d1mbTU 这个链接是可以正常使用的包，编译于 Ubuntu20.04，使用方式在教程https://github.com/riscv-collab/riscv-gnu-toolchain。

## 文档说明

- My-Tomasulo-Algorithm-Guide：基于 CAAQA 的 Tomasulo 算法复健
- CPU开题：开发过程中的一些思考和改动

