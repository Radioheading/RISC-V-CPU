`include "const_def.v"

`define MY_HASH 8:2

// predictor doesn't need the "ready" signal

module Predictor (
    input wire clk,
    input wire rst,
    input wire rdy,

    // port with ins_fetcher
    input wire [31:0] if_pc,
    input wire [31:0] if_inst,
    output wire       predict_res,
    output wire[31:0] predict_pc,

    // port with ROB
    input wire        ROB_valid,
    input wire [31:0] commit_pc,
    input wire        real_result // the real result of prev branch
);

reg [1:0] judger[127:0];

assign predict_res = if_pc[6:0] == `B_type ? judger[if_pc[8:2]][1] : 1'b0;
assign predict_pc  = predict_res ? if_pc + {{20{if_inst[31]}}, if_inst[7], if_inst[30:25], if_inst[11:8], 1'b0} : if_pc + 4;

integer i;

always @(posedge clk) begin
    if (rst) begin // just reset
        for (i = 0; i < 128; i = i + 1) begin
            judger[i] <= 0;
            end
    end
    if (rdy) begin
        if (ROB_valid) begin
            if (~real_result) begin
                if (judger[commit_pc[8:2]] < 2'b11) judger[commit_pc[8:2]] <= judger[commit_pc[8:2]] + 1;
            end
            else begin
                if (judger[commit_pc[8:2]] > 2'b00) judger[commit_pc[8:2]] <= judger[commit_pc[8:2]] - 1;
            end
        end
    end
end

endmodule