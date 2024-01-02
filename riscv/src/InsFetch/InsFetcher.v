`include "const_def.v"

`define IDLE  2'b00
`define BUSY  2'b01
`define RESET 2'b10

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
    input wire         suggest_jump,
    input wire  [31:0] suggest_pc,
    output wire [31:0] predict_inst,
    output wire [31:0] predict_pc,

    // port with ROB
    input wire        should_reset,
    input wire [31:0] reset_pc,

    // port with i-cache
    input wire        cache_valid,
    input wire [31:0] cache_inst,
    output reg [31:0] cache_pc,
    output reg        fetch_enable
);

reg [1:0]  state;
reg [31:0] pc; // the real pc is maintained in InsFetcher
assign     predict_pc   = pc;
assign     predict_inst = cache_inst; 

integer clk_count = 0;
// integer debug_file;

// initial begin
//     debug_file = $fopen("ins_fetch_debug.txt");
// end

always @(posedge clk) begin
    clk_count = clk_count + 1;
    // $fdisplay(debug_file, "InsFetch clk: %d", clk_count);
    // $fdisplay(debug_file, "InsFetch pc: %x", pc);
    if (rst) begin
        // reset output to false/zero
        if_jump         <= 1'b0;
        if_valid        <= 1'b0;
        dispatch_inst   <= 0;
        dispatch_pc     <= 0;
        cache_pc        <= 0;
        fetch_enable    <= 1'b0;
        state           <= `IDLE;
        pc              <= 0;
    end
    else if (~rdy) begin // wait
    end
    else if (should_reset) begin
        pc           <= reset_pc;
        fetch_enable <= 1'b0;
        cache_pc     <= 1'b0;
        if_valid     <= 1'b0;
        state        <= `IDLE;
        // $fdisplay(debug_file, "pc: %x, clk: %d, (reset)", reset_pc, clk_count);
    end
    else begin
        if (state == `IDLE) begin
            if (issue_stall) begin
                fetch_enable <= 1'b0;
                cache_pc     <= 0;
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
            // $display("InsFetcher: BUSY");
            // $display("InsFetcher: cache_valid = %d", cache_valid);
            // $display("InsFetcher: issue_stall = %d", issue_stall);
            if (~issue_stall && cache_valid) begin
                fetch_enable <= 1'b0;
                // $display("InsFetcher: get something from cache");
                // $display("InsFetcher: cache_inst = %d", cache_inst);
                // if (pc == 4624) begin
                //     $display("InsFetcher: clk = %d", clk_count);
                //     $display("Fuck Instruction: %x", cache_inst);
                // end
                // $fdisplay(debug_file, "pc: %x, clk: %d", pc, clk_count);
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
                state         <= `IDLE;
            end
        end
    end
end

endmodule