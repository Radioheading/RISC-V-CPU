`include "const_def.v"

`define IDLE        1'b1
`define BUSY        1'b0
`define CACHE_RANGE 10:2
`define CACHE_SIZE  512
`define TAG_RANGE   31:11

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
    output reg        hit,
    output reg [31:0] hit_data

);

reg [31:0]  data  [`CACHE_SIZE - 1:0];
reg [31:11] tag   [`CACHE_SIZE - 1:0];
reg         valid [`CACHE_SIZE - 1:0];
reg         state;
wire [10:2] index = pc[10:2];
wire        cache_hit = fetch_enable && (tag[index] == pc[`TAG_RANGE]) && valid[index];
integer     i;

always @(posedge clk) begin
    if (rst) begin
        // reset
        state         <= `IDLE;
        mem_enable    <= 1'b0;
        inst_addr     <= 32'b0;
        for (i = 0; i < `CACHE_SIZE; i = i + 1) begin
            data[i]  <= 32'b0;
            tag[i]   <= 21'b0;
            valid[i] <= 1'b0;
        end
    end 
    else if (~rdy) begin // wait
    end
    else if (fetch_enable) begin
        if (cache_hit) begin
            mem_enable  <= 1'b0;
            hit         <= 1'b1;
            hit_data    <= data[index];
        end
        else if (state == `BUSY) begin
            if (mem_valid) begin
                state                  <= `IDLE;
                mem_enable             <= 1'b0;
                data[inst_addr[10:2]]  <= inst;
                tag[inst_addr[10:2]]   <= inst[`TAG_RANGE];
                valid[inst_addr[10:2]] <= 1'b1;
            end
        end
        else if (state == `IDLE) begin
            mem_enable <= 1'b1;
            inst_addr  <= pc;
            state      <= `BUSY;
        end
    end
    else begin
        mem_enable  <= 1'b0;
    end
end
endmodule