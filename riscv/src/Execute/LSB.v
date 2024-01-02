`include "const_def.v"

`define IDLE 2'b00
`define LOAD 2'b01
`define STORE 2'b10

module LoadStoreBuffer (
    input wire        clk,
    input wire        rst,
    input wire        rdy,
    // port with ALU
    input wire        alu_valid,
    input wire [31:0] alu_res,
    input wire [4:0]  alu_rob_id,

    // port with ROB
    input wire        wrong_commit,
    input wire        rob_valid,
    input wire [4:0]  rob_commit_id,

    // port with MemoryController
    input wire        mem_valid,
    input wire [31:0] mem_res,
    output reg        load_store_enable,
    output reg [31:0] load_store_addr,
    output reg [31:0] load_store_data,
    output reg        load_or_store,
    output reg [6:0]  load_store_op,

    // port with dispatcher
    input wire        dispatch_valid,
    input wire [31:0] dispatch_imm,
    input wire [4:0]  dispatch_Qi,
    input wire [4:0]  dispatch_Qj,
    input wire [4:0]  dispatch_rd,
    input wire [6:0]  dispatch_op,
    input wire [31:0] dispatch_Vi,
    input wire [31:0] dispatch_Vj,
    output wire       lsb_full,

    // port with RS
    output reg        lsb_valid,
    output reg [31:0] lsb_res,
    output reg [4:0]  lsb_rob_id
);

wire             empty, full;
reg [`RS_RANGE]  head, tail;
wire [`RS_RANGE] next_head, next_tail;
reg  [1:0]       state;
wire [4:0]       Qi_in = (alu_valid && alu_rob_id == dispatch_Qi) ? 0 : (lsb_valid && lsb_rob_id == dispatch_Qi) ? 0 : dispatch_Qi;
wire [4:0]       Qj_in = (alu_valid && alu_rob_id == dispatch_Qj) ? 0 : (lsb_valid && lsb_rob_id == dispatch_Qj) ? 0 : dispatch_Qj;
wire [31:0]      Vi_in = (alu_valid && alu_rob_id == dispatch_Qi) ? alu_res : (lsb_valid && lsb_rob_id == dispatch_Qi) ? lsb_res : dispatch_Vi;
wire [31:0]      Vj_in = (alu_valid && alu_rob_id == dispatch_Qj) ? alu_res : (lsb_valid && lsb_rob_id == dispatch_Qj) ? lsb_res : dispatch_Vj;

assign next_head = (head + 1) % `LSB_SIZE;
assign next_tail = (tail + 1) % `LSB_SIZE;
assign empty = (head == tail);
assign full = (next_tail == head);
assign lsb_full = full;

// data of load-store buffer
reg [6:0]  op[`LSB_ARR];
reg [31:0] imm[`LSB_ARR];
reg [4:0]  Qi[`LSB_ARR];
reg [4:0]  Qj[`LSB_ARR];
reg [4:0]  rd[`LSB_ARR];
reg [31:0] Vi[`LSB_ARR];
reg [31:0] Vj[`LSB_ARR];

integer i;
integer clk_count = 0;
// integer debug_file;
// initial begin
//     debug_file = $fopen("lsb_debug.txt");
// end

always @(posedge clk) begin
    // clk_count = clk_count + 1;
    if (rst || wrong_commit) begin
        state <= `IDLE;
        head  <= 0;
        tail  <= 0;
        load_store_enable <= 0;
        load_store_addr   <= 0;
        load_store_data   <= 0;
        load_or_store     <= 0;
        load_store_op     <= 0;
        lsb_valid         <= 0;
        lsb_res           <= 0;
        lsb_rob_id        <= 0;

        for (i = 0; i < `LSB_SIZE; i = i + 1) begin
            op[i]  <= 0;
            imm[i] <= 0;
            Qi[i]  <= 0;
            Qj[i]  <= 0;
            rd[i]  <= 0;
            Vi[i]  <= 0;
            Vj[i]  <= 0;
        end
    end
    else if (rdy) begin
        if (dispatch_valid && full == 0) begin
            op[next_tail]  <= dispatch_op;
            imm[next_tail] <= dispatch_imm;
            Qi[next_tail]  <= Qi_in;
            Qj[next_tail]  <= Qj_in;
            rd[next_tail]  <= dispatch_rd;
            Vi[next_tail]  <= Vi_in;
            Vj[next_tail]  <= Vj_in;
            tail           <= next_tail;
        end 
        if (alu_valid) begin
            for (i = 0; i < `LSB_SIZE; i = i + 1) begin
                if (Qi[i] == alu_rob_id) begin
                    Vi[i] <= alu_res;
                    Qi[i] <= 0;
                end
                if (Qj[i] == alu_rob_id) begin
                    Vj[i] <= alu_res;
                    Qj[i] <= 0;
                end
            end
        end
        if (lsb_valid) begin
            for (i = 0; i < `LSB_SIZE; i = i + 1) begin
                if (Qi[i] == lsb_rob_id) begin
                    Vi[i] <= lsb_res;
                    Qi[i] <= 0;
                end
                if (Qj[i] == lsb_rob_id) begin
                    Vj[i] <= lsb_res;
                    Qj[i] <= 0;
                end
            end
        end
        case (state)
        `IDLE: begin
            lsb_valid <= 0;
            if (empty == 0 && Qi[next_head] == 0 && Qj[next_head] == 0 && rob_valid && rd[next_head] == rob_commit_id) begin
                // $display("LSB: going to load or store");                
                // access memory
                head <= next_head;
                load_store_enable <= 1;
                load_store_addr   <= Vi[next_head] + imm[next_head];
                load_store_data   <= Vj[next_head];
                load_store_op     <= op[next_head];
                load_or_store     <= op[next_head] >= `LB && op[next_head] <= `LHU;
                lsb_rob_id        <= rob_commit_id;
                state             <= (op[next_head] >= `LB && op[next_head] <= `LHU) ? 1 : 2;
            end
        end
        `LOAD: begin
            if (mem_valid) begin
                lsb_valid  <= 1;
                lsb_res    <= mem_res;
                state      <= `IDLE;
                load_store_enable <= 0;
                // $fdisplay(debug_file, "clk: %d", clk_count);
                // $fdisplay(debug_file, "load address: %d, value: %d", load_store_addr, mem_res);
            end
            else begin
                lsb_valid <= 0;
            end
        end
        `STORE: begin
            if (mem_valid) begin
                lsb_valid  <= 1;
                lsb_res    <= 0;
                state      <= `IDLE;
                load_store_enable <= 0;
                // $display("LSB: store finish");
            end
            else begin
                lsb_valid <= 0;
            end
        end
        endcase
    end
end


endmodule