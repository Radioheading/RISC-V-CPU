`include "const_def.v"

`define IDLE 2'b00
`define LOAD 2'b01
`define STORE 2'b10

module LoadStoreBuffer (
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
    output reg [2:0]  load_store_size,
    output reg        load_or_store,
    output reg [4:0]  load_store_op,

    // port with dispatcher
    input wire        dispatch_valid,
    input wire [31:0] dispatch_imm,
    input wire [31:0] dispatch_pc,
    input wire [4:0]  dispatch_Qi,
    input wire [4:0]  dispatch_Qj,
    input wire [4:0]  dispatch_rd,
    input wire [6:0]  dispatch_op,
    input wire [31:0] dispatch_Vi,
    input wire [31:0] dispatch_Vj,
    output reg        lsb_full

    // port with RS
    output reg        lsb_valid,
    output reg [31:0] lsb_res,
    output reg [4:0]  lsb_rob_id
);

wire            empty, full;
reg [`RS_RANGE] head, tail;
reg [`RS_RANGE] next_head, next_tail;
reg [1:0]       state;

assign next_head = (head + 1) % `LSB_SIZE;
assign next_tail = (tail + 1) % `LSB_SIZE;
assign empty = (head == tail);
assign full = (next_head == tail);
assign lsb_full = full;

// data of load-store buffer
reg [6:0] op[`LSB_SIZE];
reg [31:0] imm[`LSB_SIZE];
reg [4:0]  Qi[`LSB_SIZE];
reg [4:0]  Qj[`LSB_SIZE];
reg [4:0]  rd[`LSB_SIZE];
reg [31:0] Vi[`LSB_SIZE];
reg [31:0] Vj[`LSB_SIZE];

integer i;

always @(posedge clk) begin
    if (rst || wrong_commit) begin
        state <= IDLE;
        head  <= 0;
        tail  <= 0;
        load_store_enable <= 0;
        load_store_addr   <= 0;
        load_store_data   <= 0;
        load_store_size   <= 0;
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
            Qi[next_tail]  <= dispatch_Qi;
            Qj[next_tail]  <= dispatch_Qj;
            rd[next_tail]  <= dispatch_rd;
            Vi[next_tail]  <= dispatch_Vi;
            Vj[next_tail]  <= dispatch_Vj;
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
                if (Qi[i] == rob_commit_id) begin
                    Vi[i] <= mem_res;
                    Qi[i] <= 0;
                end
                if (Qj[i] == rob_commit_id) begin
                    Vj[i] <= mem_res;
                    Qj[i] <= 0;
                end
            end
        end
        case (state)
        `IDLE: begin
            lsb_valid <= 0;
            if (full == 0 && Qi[next_head] == 0 && Qj[next_head] == 0 && ROB_valid && rd[next_head] == rob_commit_id) begin
                // access memory
                head <= next_head;

                load_store_enable <= 1;
                load_store_addr   <= Vi[next_head] + imm[next_head];
                load_store_op     <= op[next_head];
                load_or_store     <= op[next_head] >= `LB && op[next_head] <= `LHU;
                lsb_rob_id        <= rob_commit_id;
                state             <= (op[next_head] >= `LB && op[next_head] <= `LHU) ? 1 : 0;

                case (op[next_head])
                `LB, LBU : load_store_size <= 3'b001;
                `LH, LHU : load_store_size <= 3'b010;
                `LW      : load_store_size <= 3'b100;
                `SB      : load_store_size <= 3'b001;
                `SH      : load_store_size <= 3'b010;
                `SW      : load_store_size <= 3'b100;
                endcase
            end
        end
        `LOAD: begin
            lsb_valid <= 0;
            if (mem_valid) begin
                lsb_valid  <= 1;
                lsb_res    <= mem_res;
                state      <= `IDLE;
                lsb_enable <= 0;
            end
        end
        `STORE: begin
            lsb_valid <= 0;
            if (mem_valid) begin
                lsb_valid  <= 1;
                lsb_res    <= 0;
                state      <= `IDLE;
                lsb_enable <= 0;
            end
        end
        endcase
    end
end


endmodule