`include "const_def.v"

`define IDLE        1'b1
`define BUSY        1'b0
`define CACHE_RANGE 10:2
`define CACHE_SIZE  512
`define TAG_RANGE   17:11

module ICache (
    input wire clk,
    input wire rst,
    input wire rdy,

    // port with MemController
    input wire [31:0] inst,
    input wire        mem_valid,
    output reg        mem_enable,
    output reg [31:0] inst_addr,

    // port with InsFetch
    input wire        fetch_enable,
    input wire [31:0] pc,
    output wire       hit,
    output wire[31:0] hit_data

);

reg [31:0]          data  [`CACHE_SIZE - 1:0];
reg [`TAG_RANGE]    tag   [`CACHE_SIZE - 1:0];
reg                 valid [`CACHE_SIZE - 1:0];
reg                 state;
wire [`CACHE_RANGE] index = pc[`CACHE_RANGE];
assign hit = fetch_enable && (tag[index] == pc[`TAG_RANGE]) && valid[index] || mem_valid && inst_addr == pc;
assign hit_data = mem_valid && inst_addr == pc ? inst : data[index];
integer i;

always @(posedge clk) begin
    if (rst) begin
        // reset
        state         <= `IDLE;
        mem_enable    <= 1'b0;
        inst_addr     <= 32'b0;
        for (i = 0; i < `CACHE_SIZE; i = i + 1) begin
            data[i]  <= 32'b0;
            tag[i]   <= 7'b0;
            valid[i] <= 1'b0;
        end
    end 
    else if (~rdy) begin // wait
    end
    else if (fetch_enable) begin
        if (state == `BUSY) begin                
            if (mem_valid) begin
                state                          <= `IDLE;
                mem_enable                     <= 1'b0;
                data[inst_addr[`CACHE_RANGE]]  <= inst;
                tag[inst_addr[`CACHE_RANGE]]   <= inst_addr[`TAG_RANGE];
                valid[inst_addr[`CACHE_RANGE]] <= 1'b1;
            end
        end
        else if (state == `IDLE && ~hit) begin
            mem_enable <= 1'b1;
            inst_addr  <= pc;
            state      <= `BUSY;
        end
    end
end
endmodule