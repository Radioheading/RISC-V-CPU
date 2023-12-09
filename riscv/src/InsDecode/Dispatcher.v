`include "const_def.v"

module Dispatcher (
    input wire        clk,
    input wire        rst,
    input wire        rdy,

    input wire        wrong_commit,
    // port with parser
    output reg [31:0] parse_inst,
    input wire        is_jump,
    input wire        is_ls,
    input wire [4:0]  rd,
    input wire [6:0]  op,
    input wire [31:0] imm,
    input wire [4:0]  rs1,
    input wire [4:0]  rs2,
    // port with ROB
    input wire        rob_full,
    input wire        rename_rd,
    input wire        Qi_valid,
    input wire        Qj_valid,
    input wire [31:0] Vi_value,
    input wire [31:0] Vj_value,
    output reg        Qi_check,
    output reg        Qj_check,
    
    output reg        to_rob_valid,
    output reg [31:0] to_rob_imm,
    output reg [31:0] to_rob_pc,
    output reg [4:0]  to_rob_Qi,
    output reg [4:0]  to_rob_Qj,
    output reg [4:0]  to_rob_rd,
    output reg [6:0]  to_rob_op,
    output reg        to_rob_jump_choice,
    // port with RS
    input wire        rs_full,
    output reg        to_rs_valid,
    output reg [31:0] to_rs_imm,
    output reg [31:0] to_rs_pc,
    output reg [4:0]  to_rs_Qi,
    output reg [4:0]  to_rs_Qj,
    output reg [4:0]  to_rs_rd,
    output reg [6:0]  to_rs_op,
    output reg [31:0] to_rs_Vi,
    output reg [31:0] to_rs_Vj,
    // port with LSB
    input wire        lsb_full,
    output reg        to_lsb_valid,
    output reg [31:0] to_lsb_imm,
    output reg [31:0] to_lsb_pc,
    output reg [4:0]  to_lsb_Qi,
    output reg [4:0]  to_lsb_Qj,
    output reg [4:0]  to_lsb_rd,
    output reg [6:0]  to_lsb_op,
    output reg [31:0] to_lsb_Vi,
    output reg [31:0] to_lsb_Vj,
    // port with RF
    output reg        to_rf_valid,
    output reg [4:0]  to_rf_name,
    output reg [4:0]  to_rf_rename,
    output reg [4:0]  to_rf_rs1,
    output reg [4:0]  to_rf_rs2,
    input wire [4:0]  to_rf_Qi,
    input wire [4:0]  to_rf_Qj,
    input wire [31:0] to_rf_Vi,
    input wire [31:0] to_rf_Vj,
    // port with IF
    input wire        if_jump,
    input wire        if_valid,
    input wire [31:0] if_inst,
    input wire [31:0] if_pc,
    output reg        issue_stall,
    // when ALU has result
    input wire        alu_valid,
    input wire [31:0] alu_res,
    input wire [4:0]  alu_rob_id,
    // when LSB has result
    input wire        lsb_valid,
    input wire [31:0] lsb_res,
    input wire [4:0]  lsb_rob_id
);
wire    part_full = rob_full || rs_full || lsb_full;
assign issue_stall = part_full;
assign parse_inst = if_inst;
assign to_rf_rs1  = rs1;
assign to_rf_rs2  = rs2;
assign Qi_check   = to_rf_Qi;
assign Qj_check   = to_rf_Qj;

always @(posedge clk) begin
    if (rst || wrong_commit) begin
        // all output port is set to 0
        to_rob_valid       <= 0;
        to_rob_imm         <= 0;
        to_rob_pc          <= 0;
        to_rob_Qi          <= 0;
        to_rob_Qj          <= 0;
        to_rob_rd          <= 0;
        to_rob_op          <= 0;
        to_rob_jump_choice <= 0;
        to_rs_valid        <= 0;
        to_rs_imm          <= 0;
        to_rs_pc           <= 0;
        to_rs_Qi           <= 0;
        to_rs_Qj           <= 0;
        to_rs_rd           <= 0;
        to_rs_op           <= 0;
        to_rs_Vi           <= 0;
        to_rs_Vj           <= 0;
        to_lsb_valid       <= 0;
        to_lsb_imm         <= 0;
        to_lsb_pc          <= 0;
        to_lsb_Qi          <= 0;
        to_lsb_Qj          <= 0;
        to_lsb_rd          <= 0;
        to_lsb_op          <= 0;
        to_lsb_Vi          <= 0;
        to_lsb_Vj          <= 0;
        to_rf_valid        <= 0;
        to_rf_name         <= 0;
        to_rf_rename       <= 0;
        to_rf_rs1          <= 0;
        to_rf_rs2          <= 0;
    end
    else if (rdy) begin
        to_lsb_valid       <= 0;
        to_rs_valid        <= 0;
        if (if_valid && ~is_full) begin
            to_rf_valid        <= 1;
            to_rf_name         <= rd;
            to_rf_rename       <= rename_rd;
            to_rob_valid       <= 1;
            to_rob_imm         <= imm;
            to_rob_pc          <= if_pc;
            to_rob_Qi          <= Qi_valid ? 0 : to_rf_Qi;
            to_rob_Qj          <= Qj_valid ? 0 : to_rf_Qj;
            to_rob_rd          <= Qi_valid ? Vi_value : to_rf_Vi;
            to_rob_op          <= Qj_valid ? Vj_value : to_rf_Vj;
            to_rob_jump_choice <= if_jump;
            if (is_ls) begin
                to_lsb_valid       <= 1;
                to_lsb_imm         <= imm;
                to_lsb_pc          <= if_pc;
                to_lsb_Qi          <= Qi_valid ? 0 : to_rf_Qi;
                to_lsb_Qj          <= Qj_valid ? 0 : to_rf_Qj;
                to_lsb_rd          <= rd;
                to_lsb_op          <= op;
                to_lsb_Vi          <= Qi_valid ? Vi_value : to_rf_Vi;
                to_lsb_Vj          <= Qj_valid ? Vj_value : to_rf_Vj;
            end
            else begin
                to_rs_valid        <= 1;
                to_rs_imm          <= imm;
                to_rs_pc           <= if_pc;
                to_rs_Qi           <= Qi_valid ? 0 : to_rf_Qi;
                to_rs_Qj           <= Qj_valid ? 0 : to_rf_Qj;
                to_rs_rd           <= rd;
                to_rs_op           <= op;
                to_rs_Vi           <= Qi_valid ? Vi_value : to_rf_Vi;
                to_rs_Vj           <= Qj_valid ? Vj_value : to_rf_Vj;
            end
        end
        else begin
            to_rob_valid       <= 0;
            to_rs_valid        <= 0;
            to_rf_valid        <= 0;
            to_lsb_valid       <= 0;
        end
    end
end

endmodule