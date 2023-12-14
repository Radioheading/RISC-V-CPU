`include "const_def.v"

module Dispatcher (
    input wire        clk,
    input wire        rst,
    input wire        rdy,

    input wire        wrong_commit,
    // port with parser
    output wire[31:0] parse_inst,
    input wire        is_jump,
    input wire        is_ls,
    input wire [4:0]  rd,
    input wire [6:0]  op,
    input wire [31:0] imm,
    input wire [4:0]  rs1,
    input wire [4:0]  rs2,
    // port with ROB
    input wire        rob_full,
    input wire [4:0]  rename_rd,
    input wire        Qi_valid,
    input wire        Qj_valid,
    input wire [31:0] Vi_value,
    input wire [31:0] Vj_value,
    output wire[4:0]  Qi_check,
    output wire[4:0]  Qj_check,
    
    output reg        to_rob_valid,
    output reg [31:0] to_rob_imm,
    output reg [31:0] to_rob_pc,
    output reg [4:0]  to_rob_Qi,
    output reg [4:0]  to_rob_Qj,
    output reg [4:0]  to_rob_rd,
    output reg [6:0]  to_rob_op,
    output reg        to_rob_jump_choice,
    output reg        to_rob_is_jump,
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
    output wire[4:0]  to_rf_rs1,
    output wire[4:0]  to_rf_rs2,
    input wire [4:0]  to_rf_Qi,
    input wire [4:0]  to_rf_Qj,
    input wire [31:0] to_rf_Vi,
    input wire [31:0] to_rf_Vj,
    // port with IF
    input wire        if_jump,
    input wire        if_valid,
    input wire [31:0] if_inst,
    input wire [31:0] if_pc,
    output wire       issue_stall,
    // when ALU has result
    input wire        alu_valid,
    input wire [31:0] alu_res,
    input wire [4:0]  alu_rob_id,
    // when LSB has result
    input wire        lsb_valid,
    input wire [31:0] lsb_res,
    input wire [4:0]  lsb_rob_id
);
wire        part_full   = rob_full || rs_full || lsb_full;
wire [4:0]  Qi = (alu_valid && alu_rob_id == to_rf_Qi && alu_rob_id) ? 0 : (lsb_valid && lsb_rob_id == to_rf_Qi && lsb_rob_id) ? 0 : Qi_valid ? 0 : to_rf_Qi;
wire [4:0]  Qj = (alu_valid && alu_rob_id == to_rf_Qj && alu_rob_id) ? 0 : (lsb_valid && lsb_rob_id == to_rf_Qj && lsb_rob_id) ? 0 : Qj_valid ? 0 : to_rf_Qj;
wire [31:0] Vi = (alu_valid && alu_rob_id == to_rf_Qi && alu_rob_id) ? alu_res : (lsb_valid && lsb_rob_id == to_rf_Qi && lsb_rob_id) ? lsb_res : Qi_valid ? Vi_value : to_rf_Vi;
wire [31:0] Vj = (alu_valid && alu_rob_id == to_rf_Qj && alu_rob_id) ? alu_res : (lsb_valid && lsb_rob_id == to_rf_Qj && lsb_rob_id) ? lsb_res : Qj_valid ? Vj_value : to_rf_Vj;
assign issue_stall = part_full;
assign parse_inst  = if_inst;
assign to_rf_rs1   = rs1;
assign to_rf_rs2   = rs2;
assign Qi_check    = to_rf_Qi;
assign Qj_check    = to_rf_Qj;

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
        to_rob_is_jump     <= 0;
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
    end
    else if (rdy) begin
        to_lsb_valid       <= 0;
        to_rs_valid        <= 0;
        if (if_valid && ~part_full) begin
            // if (rename_rd == 3) begin
            //     $display("dispatch Qi: %d, dispatch Qj: %d", Qi, Qj);
            //     $display("dispatch Vi: %d, dispatch Vj: %d", Vi, Vj);
            //     $display("Qi valid: %d, Qj valid: %d", Qi_valid, Qj_valid);
            //     $display("alu has result: %d", (alu_valid && alu_rob_id == to_rf_Qi && alu_rob_id));
            //     $display("lsb has result: %d", (lsb_valid && lsb_rob_id == to_rf_Qj && lsb_rob_id));
            //     $display("to rf rs1: ", to_rf_rs1);
            //     $display("real Vi: %d", (alu_valid && alu_rob_id == to_rf_Qi && alu_rob_id) ? alu_res : (lsb_valid && lsb_rob_id == to_rf_Qi && lsb_rob_id) ? lsb_res : Qi_valid ? Vi_value : to_rf_Vi);
            // end
            to_rf_valid        <= 1;
            to_rf_name         <= rd;
            to_rf_rename       <= rename_rd;
            to_rob_valid       <= 1;
            to_rob_imm         <= imm;
            to_rob_pc          <= if_pc;
            to_rob_Qi          <= Qi;
            to_rob_Qj          <= Qj;
            to_rob_rd          <= rd;
            to_rob_op          <= op;
            to_rob_jump_choice <= if_jump;
            to_rob_is_jump     <= is_jump;
            if (is_ls) begin
                to_lsb_valid       <= 1;
                to_lsb_imm         <= imm;
                to_lsb_pc          <= if_pc;
                to_lsb_Qi          <= Qi;
                to_lsb_Qj          <= Qj;
                to_lsb_rd          <= rename_rd;
                to_lsb_op          <= op;
                to_lsb_Vi          <= Vi;
                to_lsb_Vj          <= Vj;
            end
            else begin
                to_rs_valid        <= 1;
                to_rs_imm          <= imm;
                to_rs_pc           <= if_pc;
                to_rs_Qi           <= Qi;
                to_rs_Qj           <= Qj;
                to_rs_rd           <= rename_rd;
                to_rs_op           <= op;
                to_rs_Vi           <= Vi;
                to_rs_Vj           <= Vj;
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