`include "const_def.v"

module Parser (
    input wire [31:0] inst,
    output reg        is_j_type,
    output reg        is_load_store,
    output reg [4:0]  rd,
    output reg [4:0]  rs1,
    output reg [4:0]  rs2,
    output reg [31:0] imm,
    output reg [6:0]  op
);

wire [6:0] inst_type = inst[6:0];
wire [2:0] funct_3   = inst[`FUNCT_3];
wire [6:0] r_judge   = inst[31:25];

always @(*) begin
    // $display("Parser inst: %b", inst);
    // $display("Parser inst_type: %b", inst_type);
    is_load_store = (inst_type == `L_type || inst_type == `S_type);
    is_j_type     = (inst_type == `JAL_type || inst_type == `JALR_type || inst_type == `B_type);

    rd     = inst[`RD];
    rs1    = inst[`RS_1];
    rs2    = inst[`RS_2];
    imm    = 32'b0;
    op = `NULL;

    case (inst_type)
        `R_type: begin
            case (funct_3)
                3'b000: op = r_judge ? `SUB : `ADD;
                3'b001: op = `SLL;
                3'b010: op = `SLT;
                3'b011: op = `SLTU;
                3'b100: op = `XOR;
                3'b101: op = r_judge ? `SRA : `SRL;
                3'b110: op = `OR;
                3'b111: op = `AND;
            endcase
        end
        `I_type: begin
            rs2 = 0;
            // $display("rs1: %d, rs2: %d", rs1, rs2);
            imm = {{20{inst[31]}}, inst[31:20]}; // sign-extend
            case (funct_3)
                3'b000: op = `ADDI;
                3'b001: begin
                    imm = {27'b0, inst[24:20]}; 
                    op  = `SLLI;
                end
                3'b010: op = `SLTI;
                3'b011: op = `SLTIU;
                3'b100: op = `XORI;
                3'b101: begin
                    imm = {27'b0, inst[24:20]};
                    op  = r_judge ? `SRAI : `SRLI; 
                end
                3'b110: op = `ORI;
                3'b111: op = `ANDI;
            endcase
        end
        `L_type: begin
            rs2 = 0;
            imm = {{20{inst[31]}}, inst[31:20]};
            case (funct_3)
                3'b000: op = `LB;
                3'b001: op = `LH;
                3'b010: op = `LW;
                3'b100: op = `LBU;
                3'b101: op = `LHU;
            endcase
        end 
        `S_type: begin
            imm = {{20{inst[31]}}, inst[31:25], inst[11:7]};
            case (funct_3)
                3'b000: op = `SB;
                3'b001: op = `SH;
                3'b010: op = `SW;
            endcase
            rd = 0;
        end
        `B_type: begin
            imm = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
            case (funct_3)
                3'b000: op = `BEQ;
                3'b001: op = `BNE;
                3'b100: op = `BLT;
                3'b101: op = `BGE;
                3'b110: op = `BLTU;
                3'b111: op = `BGEU;
            endcase
            rd = 0;
        end
        `JAL_type: begin
            rs1 = 0;
            rs2 = 0;
            op  = `JAL;
            imm = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
        end
        `JALR_type: begin
            rs2 = 0;
            op  = `JALR;
            imm = {{20{inst[31]}}, inst[31:20]};
        end
        `LUI_type: begin
            rs1 = 0;
            rs2 = 0;
            op = `LUI;
            imm = {inst[31:12], 12'b0};

        end
        `AUIPC_type: begin
            rs1 = 0;
            rs2 = 0;
            op = `AUIPC;
            imm = {inst[31:12], 12'b0};
        end
    endcase
end

endmodule