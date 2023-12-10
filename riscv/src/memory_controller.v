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
    output reg        ram_enable,
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

always @(posedge clk) begin
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
        ram_enable    <= 1'b0;
        lw_type       <= 1'b0;
        addr          <= 32'b0;
        byte_out      <= 8'b0;
        read_data     <= 32'b0;
    end 
    else begin
        if (~rdy) begin
            // wait
        end
        else if (io_buffer_full) begin
            // wait
        end
        else begin
            if (state == `IDLE) begin
                i_cache_valid <= 1'b0;
                lsb_valid     <= 1'b0;
                if (lsb_enable) begin
                    cur_byte <= 3'b000;
                    if (lsb_r_or_w) begin
                        // read
                        ram_enable <= 1'b1;
                        lw_type    <= 1'b0;
                        byte_out    <= 32'b0;
                        addr       <= lsb_addr;
                        state      <= `LOAD;
                    end
                    else begin
                        // write
                        ram_enable <= 1'b0; // we can't read immediately
                        lw_type    <= 1'b1;
                        byte_out    <= 32'b0;
                        addr       <= lsb_addr;
                        state      <= `STORE;
                    end
                end
                else if (fetch_enable) begin
                    cur_byte   <= 3'b000;
                    ram_enable <= 1'b1;
                    lw_type    <= 1'b0;
                    byte_out    <= 32'b0;
                    addr       <= inst_addr;
                    state      <= `FETCH;
                end
                else begin
                    ram_enable <= 1'b0;
                    lw_type    <= 1'b0;
                    byte_out   <= 32'b0;
                    addr       <= 32'b0;
                    state      <= `IDLE;
                    cur_byte   <= 3'b000;
                end
            end
            else if (state == `STORE && !io_buffer_full) begin
                lw_type        <= 1'b1;
                case (cur_byte)
                    3'b000: byte_out <= lsb_data[7:0];
                    3'b001: byte_out <= lsb_data[15:8];
                    3'b010: byte_out <= lsb_data[23:16];
                    3'b011: byte_out <= lsb_data[31:24];
                    3'b100: byte_out <= 8'b0;
                endcase

                if (cur_byte == lsb_data_size) begin
                    cur_byte   <= 3'b000;
                    state      <= `STALL;
                    lsb_valid  <= 1'b1;
                    ram_enable <= 1'b0;
                    lw_type    <= 1'b0;
                    addr       <= 32'b0;
                end
                else begin
                    cur_byte   <= cur_byte + 1;
                    addr       <= addr + 1;
                    ram_enable <= 1'b1;
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
                    ram_enable <= 1'b0;
                    lw_type    <= 1'b0;
                    addr       <= 32'b0;
                    if (op == `LH) begin
                        read_data[31:16] <= {16{read_data[15]}};
                    end
                    else if (op == `LB) begin
                        read_data[31:8] <= {24{read_data[7]}};
                    end
                end
                else begin
                    cur_byte   <= cur_byte + 1;
                    addr       <= addr + 1;
                    ram_enable <= 1'b1;
                end
            end   
            else if (state == `FETCH) begin
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
                    ram_enable    <= 1'b0;
                end

                else begin
                    cur_byte <= cur_byte + 1;
                    addr     <= addr + 1;    
                end
            end
            else if (state == `STALL) begin
                state         <= `IDLE;
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