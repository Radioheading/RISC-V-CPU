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
    assign finish_name = calc_namel;
    should_jump = 0;
    result = 0;
    jump_pc = pc;
    
    case (opcode)
        `LUI_type: begin
            result = imm;
        end
        `AUIPC_type: begin
            result = pc + imm;
        
        end
        `JAL_type: begin
            result = pc + 4;
            jump_pc = pc + imm;
            should_jump = 1;
        end
        `JALR_type: begin
            result = pc + 4;
            jump_pc = (rs1 + imm) & 32'hfffffffe;
            should_jump = 1;
        end
        `BEQ_type: begin
            if (rs1 == rs2) begin
                result = 1;
                should_jump = 1;
            end
            jump_pc = pc + imm;
        end
        `BNE_type: begin
            if (rs1 != rs2) begin
                result = 1;
                should_jump = 1;
            end
            jump_pc = pc + imm;
        end
        `BLT_type: begin
            if ($signed(rs1) < $signed(rs2)) begin
                result = 1;
                should_jump = 1;
            end
            jump_pc = pc + imm;
        end
        `BGE_type: begin
            if ($signed(rs1) >= $signed(rs2)) begin
                result = 1;
                should_jump = 1;
            end
            jump_pc = pc + imm;
        end
        `BLTU_type: begin
            if (rs1 < rs2) begin
                result = 1;
                should_jump = 1;
            end
            jump_pc = pc + imm;
        end
        `BGEU_type: begin
            if (rs1 >= rs2) begin
                result = 1;
                should_jump = 1;
            end
            jump_pc = pc + imm;
        end
        `ADDI_type: begin
            result = rs1 + imm;
        end
        `SLTI_type: begin
            if ($signed(rs1) < $signed(imm)) begin
                result = 1;
            end
        end
        `SLTIU_type: begin
            if (rs1 < imm) begin
                result = 1;
            end
        end
        `XORI_type : begin
            result = rs1 ^ imm;
        end
        `ORI_type: begin
            result = rs1 | imm;
        end
        `ANDI_type: begin
            result = rs1 & imm;
        end
        `SLLI_type: begin
            result = rs1 << imm[4:0];
        end
        `SRLI_type: begin
            result = rs1 >> imm[4:0];
        end
        `SRAI_type: begin
            result = $signed(rs1) >>> imm[4:0];
        end
        `ADD_type: begin
            result = rs1 + rs2;
        end
        `SUB_type: begin
            result = rs1 - rs2;
        end
        `SLL_type: begin
            result = rs1 << (rs2 & 5'h1f);
        end
        `SLT_type: begin
            if ($signed(rs1) < $signed(rs2)) begin
                result = 1;
            end
        end
        `SLTU_type: begin
            if (rs1 < rs2) begin
                result = 1;
            end
        end
        `XOR_type: begin
            result = rs1 ^ rs2;
        end
        `SRL_type: begin
            result = rs1 >> (rs2 & 5'h1f);
        end
        `SRA_type: begin
            result = $signed(rs1) >>> (rs2 & 5'h1f);
        end
        `OR_type: begin
            result = rs1 | rs2;
        end
        `AND_type: begin
            result = rs1 & rs2;
        end
        default: begin
            result = 0;
        end
    endcase
end

endmodule