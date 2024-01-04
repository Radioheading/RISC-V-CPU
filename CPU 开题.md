# CPU 开题

- cpu.v

  rst_in：重置信号，可能上板的时候会用到

  rdy_in：准备好了（虽然好像一直是准备好的）

- Memory

  mem_din：数据读入；mem_dout：数据写出（一次是一个 byte）

  mem_a：地址线，只有后 18 位有用（也即内存大小约 256 kB）

  mem_wr：表示是读还是写

  0x30000/0x30004 代表内存中被映射到 I/O 的区域

- Predictor

  我的设计基本按照 risc-v-simulation 进行

## Q&As

### Tomasulo 相关

- IF
  - 真的可以像我这样连续发射吗（目前还未实现，取指成功后加入了 IDLE 状态）
  - (todo) 优化：在 cache miss 的时候，要不要强迫自己往后连续多读几条指令（等价于块大小的加大，目前感觉意义不大）
  
- LSB
  - 啥时候进行访存：在提交指令的时候（错），在对应指令来到队头的时候，这样队头指令才能 ready
  - 设计形式：FIFO 为佳
  - LSB 的接线方式：
    - 和 ALU ：计算结果接线，更新 $Q_i, Q_j,V_i,V_j$
    - 和 ROB：由第一条结论，只需要传是否在提交和是否是提交错了（
    - 和 Dispatcher：
  
- RS
  - (todo) 优化：在 ALU/LSB 和 RS 之间加一条线来直接 forward 传递数据
  
- ROB
  - dispatcher 是如何获取每个操作数是否有依赖的呢？首先告诉 RF 自己需要哪两个寄存器，然后从 RF 获取依赖；如果有依赖，向 ROB 发送信号，看看这条依赖需要的值是不是已经算好了（只是还没在 ROB 中提交）。
  
  - ROB 提交之后，不一定对应寄存器的依赖就被改为 -1 了（可能后面发射了又一条对相应寄存器的 def）
  
  - 我的奇怪的循环队列设计：
  
    1. 0 处不存东西，为了与无依赖区分开
  
    2. 这导致判满的时候有两种情况，具体代码为：
  
       ```verilog
       assign full = (next_tail == head) || (head == 0 && next_tail == `ROB_SIZE - 1);
       ```
  
       
  
- JALR
  - 注定预测失败的 jump（
  
- Dispatcher
  - 需要清空，因为可能清空信号发出的时候这里正准备射出指令到 ROB/RS/LSB，可能导致错误

## Task

- 完成接线
- 重新思考取指令之后 pc 改变的细节

## 上板日记

1. 环境太难配了，出现 uart 之后不一定按 reset 键就是可以的，可能会需要 reprogram！

2. 关于 RF：

   考虑这样一件事情，在周期 `clk_0` 的时候，同时有 `rd` 为 `id` 的指令被发射和被重命名，这个时候非阻塞赋值可能会导致发射的 rename 被冲刷。（更何况一个东西同时被两个东西非阻塞赋值也不是什么好东西）

## 上板时间

| 测试点名称     | 运行时间（s） |
| -------------- | ------------- |
| array_test1    | 0.003368      |
| array_test2    | 0.003227      |
| basicopt1      | 0.025588      |
| bulgarian      | 1.764885      |
| expr           | 0.004830      |
| gcd            | 0.012338      |
| hanoi          | 3.537087      |
| heart          | 747.291825    |
| looper         | 0.005523      |
| lvalue2        | 0.012833      |
| magic          | 0.041369      |
| manyarguments  | 0.011444      |
| multiarray     | 0.029162      |
| pi             | 3.505460      |
| qsort          | 6.699893      |
| queens         | 3.048212      |
| statement_test | 0.015059      |
| superloop      | 0.033227      |
| tak            | 0.078317      |
| testsleep      | 7.015130      |
| uartboom       | 0.782218      |

