// priority: store > load > inst-fetch

`include "const_def.v"

`define IDLE    3'b000
`define STALL   3'b001
`define FETCH   3'b010
`define LOAD    3'b011
`define STORE   3'b100
`define L_STALL 3'b101
`define S_STALL 3'b110

module MemController (
    input wire clk,
    input wire rst,
    input wire rdy,

    // port with ram
    input wire [7:0]  byte_in,
    input wire        io_buffer_full,
    output reg        lw_type, // 0: store, 1: load
    output reg [31:0] addr,
    output reg [7:0]  byte_out,

    // port with i-cache, a read-only cache
    input wire        fetch_enable,
    input wire [31:0] inst_addr,
    output reg        i_cache_valid,
    output reg [31:0] i_cache_data,

    // port with LSB
    input wire        lsb_enable,
    input wire        lsb_r_or_w, // 0: write, 1: read
    input wire [6:0]  op,
    input wire [31:0] lsb_addr,
    input wire [31:0] lsb_data,
    output reg        lsb_valid,
    output reg [31:0] read_data    
);

reg [2:0] state;
reg [2:0] lsb_data_size;
reg [2:0] cur_byte;
reg       stall_time; // load or store: 2, fetch: 1

integer clk_count = 0;
// integer debug_file;
// initial begin
//     debug_file = $fopen("memory_debug.txt");
// end
always @(posedge clk) begin
    clk_count = clk_count + 1;
    // $display("MemController clk_count = %d", clk_count);
    // $display("MemController state = %d", state);
    // if (clk_count % 100000 == 0) begin
    //     $display("MemController clk_count = %d", clk_count);
    // end
    if (op == `LW) begin
        lsb_data_size <= 3'b100;
    end
    else if (op == `LH || op == `LHU) begin
        lsb_data_size <= 3'b010;
    end
    else if (op == `LB || op == `LBU) begin
        lsb_data_size <= 3'b001;
    end
    else if (op == `SW) begin
        lsb_data_size <= 3'b100;
    end
    else if (op == `SH) begin
        lsb_data_size <= 3'b010;
    end
    else if (op == `SB) begin
        lsb_data_size <= 3'b001;
    end
    if (rst) begin
        state         <= `IDLE;
        lsb_valid     <= 1'b0;
        i_cache_valid <= 1'b0;
        cur_byte      <= 3'b000;
        lw_type       <= 1'b0;
        addr          <= 32'b0;
        byte_out      <= 8'b0;
        read_data     <= 32'b0;
    end 
    else begin
        if (~rdy || io_buffer_full) begin
        end
        else begin
            if (state == `IDLE) begin
                i_cache_valid <= 1'b0;
                lsb_valid     <= 1'b0;
                if (lsb_enable) begin
                    cur_byte   <= 3'b000;
                    stall_time <= 1;
                    if (lsb_r_or_w) begin
                        // $display("MemController: going to load");
                        // read
                        lw_type    <= 1'b0;
                        byte_out   <= 32'b0;
                        addr       <= lsb_addr;
                        state      <= `LOAD;
                    end
                    else begin
                        // write
                        // $display("MemController: going to store");
                        lw_type    <= 1'b1;
                        byte_out   <= lsb_data[7:0];
                        addr       <= lsb_addr;
                        state      <= `STORE;
                    end
                end
                else if (fetch_enable) begin
                    stall_time <= 0;
                    cur_byte   <= 3'b000;
                    lw_type    <= 1'b0;
                    byte_out   <= 32'b0;
                    addr       <= inst_addr;
                    state      <= `FETCH;
                end
                else begin
                    lw_type    <= 1'b0;
                    byte_out   <= 32'b0;
                    addr       <= 32'b0;
                    state      <= `IDLE;
                    cur_byte   <= 3'b000;
                end
            end
            else if (state == `STORE && !io_buffer_full) begin
                // $display("MemController: STORE");
                // $display("store data size: %d", lsb_data_size);
                // $display("cur_byte: %d", cur_byte);
                // if (cur_byte == 0 && addr == 196608) begin
                //     $fdisplay(debug_file, "clk: %d", clk_count);
                //     $fdisplay(debug_file, "store address: %d, size: %d, value: %d", addr, lsb_data_size, lsb_data);
                // end
                if (cur_byte == lsb_data_size - 1) begin
                    cur_byte   <= 3'b000;
                    state      <= `STALL;
                    lsb_valid  <= 1'b1;
                    lw_type    <= 1'b0;
                    addr       <= 32'b0;
                end
                else begin 
                    case (cur_byte)
                        3'b000: byte_out <= lsb_data[15:8];
                        3'b001: byte_out <= lsb_data[23:16];
                        3'b010: byte_out <= lsb_data[31:24];
                    endcase
                    cur_byte   <= cur_byte + 1;
                    addr       <= addr + 1;
                end
            end
            else if (state == `LOAD) begin
                lw_type      <= 1'b0;
                case (cur_byte)
                    3'b001: read_data[7:0]   <= byte_in;
                    3'b010: read_data[15:8]  <= byte_in;
                    3'b011: read_data[23:16] <= byte_in;
                    3'b100: read_data[31:24] <= byte_in;
                endcase
                if (cur_byte == lsb_data_size) begin
                    cur_byte   <= 3'b000;
                    state      <= `STALL;
                    lsb_valid  <= 1'b1;
                    lw_type    <= 1'b0;
                    addr       <= 32'b0;
                    if (op == `LH) begin
                        read_data[31:16] <= {16{byte_in[7]}};
                    end
                    else if (op == `LB) begin
                        read_data[31:8] <= {24{byte_in[7]}};
                    end
                    else if (op == `LBU) begin
                        read_data[31:8] <= 24'b0;
                    end
                    else if (op == `LHU) begin
                        read_data[31:16] <= 16'b0;
                    end
                end
                else begin
                    cur_byte   <= cur_byte + 1;
                    addr       <= addr + 1;
                end
            end   
            else if (state == `FETCH) begin
                // $display("MemController: FETCH");
                // $display("pc: %x", addr);
                case (cur_byte)
                    3'b001: i_cache_data[7:0]   <= byte_in;
                    3'b010: i_cache_data[15:8]  <= byte_in;
                    3'b011: i_cache_data[23:16] <= byte_in;
                    3'b100: i_cache_data[31:24] <= byte_in;
                endcase

                if (cur_byte == 4) begin
                    cur_byte      <= 3'b000;
                    state         <= `STALL; // need 1 cycle for i-cache to know
                    i_cache_valid <= 1'b1;
                    addr          <= 32'b0;
                end

                else begin
                    cur_byte <= cur_byte + 1;
                    addr     <= addr + 1;    
                end
            end
            else if (state == `STALL) begin
                // if (stall_time == 0) begin
                //     state <= `IDLE;
                // end
                // else begin
                //     stall_time <= stall_time - 1;
                // end
                state <= `IDLE;
                lsb_valid     <= 1'b0;
                i_cache_valid <= 1'b0;
            end
            else begin
                state <= `IDLE;
            end
        end
    end
end

endmodule