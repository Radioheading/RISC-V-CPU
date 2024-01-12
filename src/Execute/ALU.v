`include "const_def.v"

// change: jalr auipc calculation are done in ALU

module ALU (
    input [31:0] pc,
    input [31:0] rs1,
    input [31:0] rs2,
    input [31:0] imm,
    input [6:0]  opcode,
    input [4:0]  calc_name,

    output reg         alu_valid,
    output reg [31:0]  A,
    output reg [31:0]  jump_pc,
    output reg         should_jump,
    output reg [4:0]   finish_name // broadcast to LSB & RS
);

always @(*) begin
    finish_name = calc_name;
    alu_valid = (opcode > 0);
    should_jump = 0;
    A = 0;
    jump_pc = pc;
    // $display("ALU opcode: %d", opcode);
    // $display("ALU calc_name: %d", calc_name);
    case (opcode)
        `LUI: begin
            A = imm;
        end
        `AUIPC: begin
            A = pc + imm;
        
        end
        `JAL: begin
            A = pc + 4;
            jump_pc = pc + imm;
            should_jump = 1;
        end
        `JALR: begin
            A = pc + 4;
            jump_pc = (rs1 + imm) & 32'hfffffffe;
            should_jump = 1;
        end
        `BEQ: begin
            if (rs1 == rs2) begin
                A = 1;
                should_jump = 1;
            end
            jump_pc = pc + imm;
        end
        `BNE: begin
            if (rs1 != rs2) begin
                A = 1;
                should_jump = 1;
            end
            jump_pc = pc + imm;
        end
        `BLT: begin
            if ($signed(rs1) < $signed(rs2)) begin
                A = 1;
                should_jump = 1;
            end
            jump_pc = pc + imm;
        end
        `BGE: begin
            if ($signed(rs1) >= $signed(rs2)) begin
                A = 1;
                should_jump = 1;
            end
            jump_pc = pc + imm;
        end
        `BLTU: begin
            if (rs1 < rs2) begin
                A = 1;
                should_jump = 1;
            end
            jump_pc = pc + imm;
        end
        `BGEU: begin
            if (rs1 >= rs2) begin
                A = 1;
                should_jump = 1;
            end
            jump_pc = pc + imm;
        end
        `ADDI: begin
            A = rs1 + imm;
        end
        `SLTI: begin
            if ($signed(rs1) < $signed(imm)) begin
                A = 1;
            end
        end
        `SLTIU: begin
            if (rs1 < imm) begin
                A = 1;
            end
        end
        `XORI : begin
            A = rs1 ^ imm;
        end
        `ORI: begin
            A = rs1 | imm;
        end
        `ANDI: begin
            A = rs1 & imm;
        end
        `SLLI: begin
            A = rs1 << imm[4:0];
        end
        `SRLI: begin
            A = rs1 >> imm[4:0];
        end
        `SRAI: begin
            A = $signed(rs1) >>> imm[4:0];
        end
        `ADD: begin
            A = rs1 + rs2;
        end
        `SUB: begin
            A = rs1 - rs2;
        end
        `SLL: begin
            A = rs1 << (rs2 & 5'h1f);
        end
        `SLT: begin
            if ($signed(rs1) < $signed(rs2)) begin
                A = 1;
            end
        end
        `SLTU: begin
            if (rs1 < rs2) begin
                A = 1;
            end
        end
        `XOR: begin
            A = rs1 ^ rs2;
        end
        `SRL: begin
            A = rs1 >> (rs2 & 5'h1f);
        end
        `SRA: begin
            A = $signed(rs1) >>> (rs2 & 5'h1f);
        end
        `OR: begin
            A = rs1 | rs2;
        end
        `AND: begin
            A = rs1 & rs2;
        end
        default: begin
            A = 0;
        end
    endcase
end

endmodule