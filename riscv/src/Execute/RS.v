`include "const_def.v"

module ReservationStation (
    input wire clk,
    input wire rst,
    input wire rdy,
    
    // port with ROB
    input wire wrong_commit,

    // port with ALU
    input wire        alu_valid,
    input wire [31:0] alu_res,
    input wire [4:0]  alu_rob_id,
    output reg [6:0]  alu_op,
    output reg [31:0] Vi_alu,
    output reg [31:0] Vj_alu,
    output reg [31:0] imm_alu,
    output reg [4:0]  alu_rd,
    output reg [31:0] pc_alu, // for JAL, JALR, AUIPC

    // port with LSB, for memory alias
    input wire        lsb_valid,
    input wire [31:0] lsb_res,
    input wire [4:0]  lsb_rob_id,

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
    output wire       rs_full
);

wire [4:0]  first_empty;
wire [4:0]  first_ready;
wire [4:0]  Qi_in = (alu_valid && alu_rob_id == dispatch_Qi) ? 0 : (lsb_valid && lsb_rob_id == dispatch_Qi) ? 0 : dispatch_Qi;
wire [4:0]  Qj_in = (alu_valid && alu_rob_id == dispatch_Qj) ? 0 : (lsb_valid && lsb_rob_id == dispatch_Qj) ? 0 : dispatch_Qj;
wire [31:0] Vi_in = (alu_valid && alu_rob_id == dispatch_Qi) ? alu_res : (lsb_valid && lsb_rob_id == dispatch_Qi) ? lsb_res : dispatch_Vi;
wire [31:0] Vj_in = (alu_valid && alu_rob_id == dispatch_Qj) ? alu_res : (lsb_valid && lsb_rob_id == dispatch_Qj) ? lsb_res : dispatch_Vj;

// internal data
reg        busy[`RS_ARR];
reg [31:0] pc[`RS_ARR];
reg [31:0] imm[`RS_ARR];
reg [31:0] Vi[`RS_ARR];
reg [31:0] Vj[`RS_ARR];
reg [4:0]  Qi[`RS_ARR];
reg [4:0]  Qj[`RS_ARR];
reg [4:0]  rd[`RS_ARR];
reg [6:0]  op[`RS_ARR];

/* warning: ROB id must be 1-based, or there'll be 
 * conflict with the ID 0 in terms of Qi and Qj
 */

assign first_empty = (busy[0] == 0) ? 0 : (busy[1] == 0) ? 1 : (busy[2] == 0) ? 2 : (busy[3] == 0) ? 3 : 
                     (busy[4] == 0) ? 4 : (busy[5] == 0) ? 5 : (busy[6] == 0) ? 6 : (busy[7] == 0) ? 7 : 
                     (busy[8] == 0) ? 8 : (busy[9] == 0) ? 9 : (busy[10] == 0) ? 10 : (busy[11] == 0) ? 11 : 
                     (busy[12] == 0) ? 12 : (busy[13] == 0) ? 13 : (busy[14] == 0) ? 14 : (busy[15] == 0) ? 15 : 16;


assign first_ready = (busy[0] == 1 && Qi[0] == 0 && Qj[0] == 0) ? 0 : (busy[1] == 1 && Qi[1] == 0 && Qj[1] == 0) ? 1 : 
                     (busy[2] == 1 && Qi[2] == 0 && Qj[2] == 0) ? 2 : (busy[3] == 1 && Qi[3] == 0 && Qj[3] == 0) ? 3 :
                     (busy[4] == 1 && Qi[4] == 0 && Qj[4] == 0) ? 4 : (busy[5] == 1 && Qi[5] == 0 && Qj[5] == 0) ? 5 :
                     (busy[6] == 1 && Qi[6] == 0 && Qj[6] == 0) ? 6 : (busy[7] == 1 && Qi[7] == 0 && Qj[7] == 0) ? 7 :
                     (busy[8] == 1 && Qi[8] == 0 && Qj[8] == 0) ? 8 : (busy[9] == 1 && Qi[9] == 0 && Qj[9] == 0) ? 9 :
                     (busy[10] == 1 && Qi[10] == 0 && Qj[10] == 0) ? 10 : (busy[11] == 1 && Qi[11] == 0 && Qj[11] == 0) ? 11 :
                     (busy[12] == 1 && Qi[12] == 0 && Qj[12] == 0) ? 12 : (busy[13] == 1 && Qi[13] == 0 && Qj[13] == 0) ? 13 :
                     (busy[14] == 1 && Qi[14] == 0 && Qj[14] == 0) ? 14 : (busy[15] == 1 && Qi[15] == 0 && Qj[15] == 0) ? 15 : 16;

assign rs_full = (first_empty == `RS_SIZE);

integer i, clk_count = 0;

always @(posedge clk) begin
    // $display("RS clk: %d", clk_count);
    clk_count = clk_count + 1;
    if (rst || wrong_commit) begin
        for (i = 0; i < `RS_SIZE; i = i + 1) begin
            busy[i] <= 0;
            pc[i]  <= 0;
            imm[i] <= 0;
            Vi[i]  <= 0;
            Vj[i]  <= 0;
            Qi[i]  <= 0;
            Qj[i]  <= 0;
            rd[i]  <= 0;
            op[i]  <= 0;
        end
        alu_op  <= 0;
        Vi_alu  <= 0;
        Vj_alu  <= 0;
        imm_alu <= 0;
        alu_rd  <= 0;
        pc_alu  <= 0;
    end
    else if (rdy) begin
        if (alu_valid) begin // ALU result is ready
            for (i = 0; i < `RS_SIZE; i = i + 1) begin
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
        if (lsb_valid) begin // LSB result is ready
            for (i = 0; i < `RS_SIZE; i = i + 1) begin
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
        if (first_ready < `RS_SIZE) begin // can execute
            // $display("RS execute, first_ready: %d", first_ready);
            // $display("RS execute, pc: %d", pc[first_ready]);
            // if (rd[first_ready] == 3) begin
            //     $display("Vi: %d, Vj: %d", Vi[first_ready], Vj[first_ready]);
            // end
            alu_op            <= op[first_ready];
            Vi_alu            <= Vi[first_ready];
            Vj_alu            <= Vj[first_ready];
            imm_alu           <= imm[first_ready];
            pc_alu            <= pc[first_ready];
            alu_rd            <= rd[first_ready];
            busy[first_ready] <= 0;
        end
        else begin // can't execute
            alu_op  <= 0;
            Vi_alu  <= 0;
            Vj_alu  <= 0;
            imm_alu <= 0;
            pc_alu  <= 0;
            alu_rd <= 0;
        end
        if (first_empty < `RS_SIZE && dispatch_valid) begin // can dispatch
            // $display("RS dispatch, pc: %d", dispatch_pc);
            // $display("RS dispatch, first_empty: %d", first_empty);
            // if (dispatch_rd == 3) begin
            //     $display("Qi: %d, Qj: %d", Qi_in, Qj_in);
            //     $display("Vi: %d, Vj: %d", Vi_in, Vj_in);
            // end
            busy[first_empty] <= 1;
            pc[first_empty]   <= dispatch_pc;
            imm[first_empty]  <= dispatch_imm;
            Vi[first_empty]   <= Vi_in;
            Vj[first_empty]   <= Vj_in;
            Qi[first_empty]   <= Qi_in;
            Qj[first_empty]   <= Qj_in;
            rd[first_empty]   <= dispatch_rd;
            op[first_empty]   <= dispatch_op;
        end
    end
end

endmodule