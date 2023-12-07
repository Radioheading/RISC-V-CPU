// const for RISC-V instructions

// RS-related
`define RS_SIZE       32
`define RS_RANGE      4:0
`define RS_ARR        31:0

// LSB-related
`define LSB_SIZE      32
`define LSB_RANGE     4:0
`define LSB_ARR       31:0

// ROB-related
`define ROB_SIZE      32
`define ROB_RANGE     4:0
`define ROB_ARR       31:0

// instruction format
`define OP_type       6:0
`define FUNCT_3       14:12
`define RS_1          19:15
`define RS_2          24:20
`define RD            11:7

`define R_type        7'b0110011
`define I_type        7'b0010011
`define L_type        7'b0000011
`define S_type        7'b0100011
`define B_type        7'b1100011

`define JAL_type      7'b1101111
`define JALR_type     7'b1100111
`define LUI_type      7'b0110111
`define AUIPC_type    7'b0010111

`define    NULL     6'd0
`define    LUI      6'd1        //Load From Immediate
`define    AUIPC    6'd2        //Add Upper Immediate to PC
`define    JAL      6'd3        //Jump & Link
`define    JALR     6'd4        //Jump & Link Register
`define    BEQ      6'd5        //Branch Equal
`define    BNE      6'd6        //Branch Not Equal
`define    BLT      6'd7        //Branch Less Than
`define    BGE      6'd8        //Branch Greater than or Equal
`define    BLTU     6'd9        //Branch Less Than Unsigned
`define    BGEU     6'd10        //Branch >  Unsigned
`define    LB       6'd11       // Load Byte
`define    LH       6'd12 
`define    LW       6'd13 
`define    LBU      6'd14 
`define    LHU      6'd15 
`define    SB       6'd16 
`define    SH       6'd17 
`define    SW       6'd18 
`define    ADDI     6'd19 
`define    SLTI     6'd20 
`define    SLTIU    6'd21 
`define    XORI     6'd22 
`define    ORI      6'd23 
`define    ANDI     6'd24 
`define    SLLI     6'd25 
`define    SRLI     6'd26
`define    SRAI     6'd27 
`define    ADD      6'd28 
`define    SUB      6'd29 
`define    SLL      6'd30 
`define    SLT      6'd31 
`define    SLTU     6'd32 
`define    XOR      6'd33 
`define    SRL      6'd34 
`define    SRA      6'd35 
`define    OR       6'd36 
`define    AND      6'd37 