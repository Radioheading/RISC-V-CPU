`include "const_def.v"

module ReOrderBuffer (
    input wire         clk,
    input wire         rst,
    input wire         rdy,
    // port with LSB
    input  wire        lsb_valid,
    input  wire [31:0] lsb_res,
    input  wire [4:0]  lsb_rob_id,
    output reg         ls_commit,
    output reg  [4:0]  ls_rob_id,

    // common data bus
    output reg         wrong_commit,
    output reg  [31:0] true_pc,
    output reg         rob_full,
    output reg         predictor_enable,
    output reg         predictor_update,
    output reg  [31:0] predictor_update_pc,

    // with ALU
    input wire         alu_valid,
    input wire [31:0]  alu_res,
    input wire [4:0]   alu_rob_id,
    input wire         alu_jump_choice,
    input wire [31:0]  alu_pc,

    // port with dispatcher
    input wire         dispatch_valid,
    input wire  [31:0] dispatch_pc,
    input wire  [4:0]  dispatch_rd,
    input wire  [6:0]  dispatch_op,
    input wire         dispatch_jump_choice,
    input wire  [4:0]  dispatch_Qi,
    input wire  [4:0]  dispatch_Qj,

    input wire  [4:0]  Qi_check,
    input wire  [4:0]  Qj_check,
    output reg  [4:0]  rename_rd,
    output reg         Qi_valid,
    output reg         Qj_valid,
    output reg  [31:0] Vi_value,
    output reg  [31:0] Vj_value,

    // port with register file, only for commit
    output reg         commit_valid,
    output reg [4:0]   commit_rd,
    output reg [31:0]  commit_res,
    output reg [4:0]   commit_dependency
);

wire             empty, full;
reg [`ROB_RANGE] head, tail;
reg [`ROB_RANGE] next_head, next_tail;

assign next_head = head + 1 == `ROB_SIZE ? 1 : head + 1;
assign next_tail = tail + 1 == `ROB_SIZE ? 1 : tail + 1;
assign empty = (head == tail);
assign full = (next_head == tail);
assign rob_full = full;

// data of reorder buffer
reg [6:0]  op[`ROB_ARR];
reg        ready[`ROB_ARR];
reg [4:0]  rd[`ROB_ARR];
reg [31:0] res[`ROB_ARR];
reg        prev_choice[`ROB_ARR];
reg        now_choice[`ROB_ARR];
reg        is_jump[`ROB_ARR];
reg [31:0] pc[`ROB_ARR];
reg [31:0] jump_pc[`ROB_ARR];

assign rename_rd = next_tail;
assign Qi_valid  = ready[Qi_check];
assign Qj_valid  = ready[Qj_check];
assign Vi_value  = res[Qi_check];
assign Vj_value  = res[Qj_check];
assign ls_commit = op[next_head] >= `LB && op[next_head] <= `SW;
assign ls_rob_id = next_head;

integer i;

always @(posedge clk) begin
    if (rst || wrong_commit) begin
        head                <= 0;
        tail                <= 0;
        ls_commit           <= 0;
        ls_rob_id           <= 0;
        wrong_commit        <= 0;
        true_pc             <= 0;
        predictor_enable    <= 0;
        predictor_update    <= 0;
        predictor_update_pc <= 0;
        rename_rd           <= 0;
        Qi_valid            <= 0;
        Qj_valid            <= 0;
        Vi_value            <= 0;
        Vj_value            <= 0;
        commit_valid        <= 0;
        commit_rd           <= 0;
        commit_res          <= 0;
        commit_dependency   <= 0;
        for (i = 0; i < `ROB_SIZE; i = i + 1) begin
            op[i]           <= 0;
            ready[i]        <= 0;
            rd[i]           <= 0;
            res[i]          <= 0;
            prev_choice[i]  <= 0;
            now_choice[i]   <= 0;
            is_jump[i]      <= 0;
            pc[i]           <= 0;
            jump_pc[i]      <= 0;
        end
    end

    else if (rdy) begin
        if (lsb_valid) begin
            ready[lsb_rob_id] <= 1;
            res[lsb_rob_id]   <= lsb_res;
        end
        if (alu_valid) begin
            ready[alu_rob_id]      <= 1;
            res[alu_rob_id]        <= alu_res;
            now_choice[alu_rob_id] <= alu_jump_choice;
            jump_pc [alu_rob_id]   <= alu_pc;
        end
        if (dispatch_valid && ~full) begin
            op[next_tail]          <= dispatch_op;
            rd[next_tail]          <= dispatch_rd;
            pc[next_tail]          <= dispatch_pc;
            is_jump[next_tail]     <= dispatch_jump_choice;
            prev_choice[next_tail] <= dispatch_jump_choice;
            ready[next_tail]       <= 0;
            now_choice[next_tail]  <= 0;
            jump_pc[next_tail]     <= 0;
            res[next_tail]         <= 0;
            tail                   <= next_tail;
        end
        if (ready[next_head] && ~empty) begin
            head <= next_head;
            
            if (is_jump[next_head]) begin
                predictor_update_pc <= pc[next_head];
                predictor_update    <= now_choice[next_head];
                predictor_enable    <= 1;
            end
            else begin
                predictor_enable    <= 0;
            end
            if (prev_choice[next_head] != now_choice[next_head]) begin
                wrong_commit <= 1;
                true_pc      <= now_choice[next_head] ? jump_pc[next_head] : pc[next_head];
            end

            commit_valid      <= 1;
            commit_rd         <= rd[next_head];
            commit_res        <= res[next_head];
            commit_dependency <= next_head;
        end
        else begin
            commit_valid      <= 0;
            predictor_enable  <= 0;
        end
    end
end

endmodule
