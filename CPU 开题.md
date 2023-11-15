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