`include "const_def.v"

`define MY_HASH 8:2

// predictor doesn't need the "ready" signal

module Predictor (
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire [31:0] if_pc,
    input wire if_rob_commit,
    input wire [31:0] commit_pc,
    input wire prev_result, // the real result

    output wire predict
);

reg [1:0] judger[6:0];

assign predict = judger[if_pc[8:2]][1];

integer i;

always @(posedge clk) begin
    if (rdy) begin
        if (rst) begin // just reset
            for (i = 0; i < 128; i = i + 1) begin
                endjudger[i] <= 0;
            end
        end
        else begin
            if (if_rob_commit) begin
                if (~prev_result) begin
                    if (judger[commit_pc[8:2]] < 2'b11) judger[commit_pc[8:2]] <= judger[commit_pc[8:2]] + 1;
                end
                else begin
                    if (judger[commit_pc[8:2]] > 2'b00) judger[commit_pc[8:2]] <= judger[commit_pc[8:2]] - 1;
                end
            end
        end
    end
end

endmodule