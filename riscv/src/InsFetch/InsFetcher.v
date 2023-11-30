`include "const_def.v"

`define IDLE  2'b00;
`define BUSY  2'b01;
`define RESET 2'b10;

module InsFetcher (
    input wire issue_stall, // ROB / RS / LSB
    input wire clk,
    input wire rst,
    input wire rdy,

    // port with dispatcher
    output reg        if_jump,
    output reg        if_valid,
    output reg [31:0] dispatch_inst,
    output reg [31:0] dispatch_pc,

    // port with predictor
    input wire        suggest_jump,
    input wire        suggest_pc,
    output reg [31:0] predict_inst,
    output reg [31:0] predict_pc,

    // port with ROB
    input wire        should_reset,
    input wire [31:0] reset_pc,

    // port with i-cache
    input wire        hit_valid,
    input wire [31:0] hit_inst,
    input wire        cache_valid,
    input wire [31:0] cache_inst,
    output reg [31:0] cache_pc,
    output reg        fetch_enable
);

reg        state;
reg [31:0] pc; // the real pc is maintained in InsFetcher
assign     predict_pc   = pc;
assign     predict_inst = hit_inst; 

always @(posedge clk) begin
    if (rst) begin
        // reset output to false/zero
        if_jump         <= 1'b0;
        if_valid        <= 1'b0;
        dispatch_inst   <= 0;
        dispatch_pc     <= 0;
        predict_inst    <= 0;
        predict_pc      <= 0;
        cache_pc        <= 0;
        fetch_enable    <= 1'b0;
        state          <= `IDLE;
    end
    else if (~rdy) begin // wait
    end
    else if (should_reset) begin
        pc           <= reset_pc;
        fetch_enable <= 1'b0;
        if_valid     <= 1'b0;
        state        <= `IDLE;
    end
    else if (state == `IDLE) begin
        if (issue_stall) begin
            fetch_enable <= 1'b0;
        end
        else begin
            fetch_enable <= 1'b1;
            state        <= `BUSY;
            cache_pc     <= pc;

            if_valid     <= 1'b0;
            if_jump      <= 1'b0;
        end
    end
    else if (state == `BUSY) begin
        if (~issue_stall && cache_valid) begin
            if (cache_inst[6:0] == `JAL_type) begin
                pc      <= pc + {{20{cache_inst[31]}}, cache_inst[19:12], cache_inst[20], cache_inst[30:21], 1'b0};
                if_jump <= 1'b1;
            end
            else begin
                pc      <= suggest_pc;
                if_jump <= suggest_jump;
            end

            if_valid      <= 1'b1;
            dispatch_inst <= cache_inst;
            dispatch_pc   <= pc;

            cache_pc      <= pc;
            fetch_enable  <= 1'b1;
        end
    end 
end

endmodule