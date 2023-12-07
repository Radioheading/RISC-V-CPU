# CPU 开题

- cpu.v

  rst_in：重置信号，可能上板的时候会用到

  rdy_in：准备好了（虽然好像一直是准备好的）

- Memory

  mem_din：数据读入；mem_dout：数据写出（一次是一个 byte）

  mem_a：地址线，只有后 18 位有用（也即内存大小约 256 MB）

  mem_wr：表示是读还是写

  0x30000/0x30004 代表内存中被映射到 I/O 的区域

- Predictor

  我的设计基本按照 risc-v-simulation 进行

## Q&As

### Tomasulo 相关

- IF
  - 真的可以像我这样连续发射吗
  - (todo) 优化：在 cache miss 的时候，要不要强迫自己往后连续多读几条指令
- LSB
  - 啥时候进行访存：在提交指令的时候
  - 设计形式：FIFO 为佳
  - LSB 的接线方式：
    - 和 ALU ：计算结果接线，更新 $Q_i, Q_j,V_i,V_j$
    - 和 ROB：由第一条结论，只需要传是否在提交和是否是提交错了（
    - 和 Dispatcher：
- RS
  - (todo) 优化：在 ALU/LSB 和 RS 之间加一条线来直接 forward 传递数据
- ROB
  -  dispatcher 是如何获取每个操作数是否有依赖的呢？首先告诉 RF 自己需要哪两个寄存器，然后从 RF 获取依赖；如果有依赖，向 ROB 发送信号，看看这条依赖需要的值是不是已经算好了（只是还没在 ROB 中提交）。
  - ROB 提交之后，不一定对应寄存器的依赖就被改为 -1 了（可能后面发射了又一条对相应寄存器的 def）
- JALR
  - 注定预测失败的 jump（