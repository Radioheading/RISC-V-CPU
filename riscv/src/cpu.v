// RISCV32I CPU top module
// port modification allowed for debugging purposes
module cpu(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire [ 7:0]          mem_din,		// data input bus
  output wire [ 7:0]          mem_dout,		// data output bus
  output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
  output wire                 mem_wr,			// write/read signal (1 for write)
	
	input  wire                 io_buffer_full, // 1 if uart buffer is full
	
	output wire [31:0]			    dbgreg_dout		// cpu register output (debugging demo)
);

// implementation goes here

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)

// general ROB
wire        wrong_commit;
wire [31:0] reset_pc;

// common data bus
wire        alu_valid;
wire [31:0] alu_result;
wire        alu_should_jump;
wire [31:0] alu_jump_pc;
wire [4:0]  alu_rob_id;

wire        lsb_valid;
wire [31:0] lsb_result;
wire [4:0]  lsb_rob_id;

// memory controller & i-cache
wire        fetch_enable;
wire [31:0] fetch_inst_addr;
wire        i_cache_valid;
wire [31:0] i_cache_data;

// memory controller & lsb
wire        lsb_enable;
wire        lsb_r_or_w;
wire [6:0]  lsb_op;
wire [31:0] lsb_read_addr;
wire [31:0] lsb_write_data;
wire        mc_to_lsb_valid;
wire [31:0] mc_to_lsb_read_data;

// predictor & IF
wire [31:0] if_predictor_pc;
wire [31:0] if_predictor_inst;
wire [31:0] predictor_suggest_pc;
wire        predictor_suggest_res;

// predictor & ROB
wire        rob_commit_to_predictor;
wire [31:0] rob_predictor_pc;
wire        rob_predictor_result;

// i-cache & IF
wire        IF_enable;
wire [31:0] IF_pc;
wire        IF_hit;
wire [31:0] IF_hit_data;

// IF & dispatcher
wire        issue_stall;
wire        if_to_dispatcher_jump;
wire        if_to_dispatcher_valid;
wire [31:0] if_to_dispatcher_inst;
wire [31:0] if_to_dispatcher_pc;

// dispatcher & parser
wire [31:0] parser_inst;
wire        parser_is_jump;
wire        parser_is_ls;
wire [4:0]  parser_rd;
wire [6:0]  parser_op;
wire [31:0] parser_imm;
wire [4:0]  parser_rs1;
wire [4:0]  parser_rs2;

// dispatcher & ROB
wire        rob_full;
wire [4:0]  rob_rename_rd;
wire        rob_Qi_valid;
wire        rob_Qj_valid;
wire [31:0] rob_Vi_value;
wire [31:0] rob_Vj_value;
wire [4:0]  rob_Qi_check;
wire [4:0]  rob_Qj_check;
wire        to_rob_valid;
wire [31:0] to_rob_imm;
wire [31:0] to_rob_pc;
wire [4:0]  to_rob_Qi;
wire [4:0]  to_rob_Qj;
wire [4:0]  to_rob_rd;
wire [6:0]  to_rob_op;
wire        to_rob_jump_choice;
wire        to_rob_is_jump;

// dispatcher & RS
wire        rs_full;
wire        to_rs_valid;
wire [31:0] to_rs_imm;
wire [31:0] to_rs_pc;
wire [4:0]  to_rs_Qi;
wire [4:0]  to_rs_Qj;
wire [4:0]  to_rs_rd;
wire [6:0]  to_rs_op;
wire [31:0] to_rs_Vi;
wire [31:0] to_rs_Vj;

// dispatcher & LSB
wire        lsb_full;
wire        to_lsb_valid;
wire [31:0] to_lsb_imm;
wire [31:0] to_lsb_pc;
wire [4:0]  to_lsb_Qi;
wire [4:0]  to_lsb_Qj;
wire [4:0]  to_lsb_rd;
wire [6:0]  to_lsb_op;
wire [31:0] to_lsb_Vi;
wire [31:0] to_lsb_Vj;

// dispatcher & RF
wire        to_rf_valid;
wire [4:0]  to_rf_name;
wire [4:0]  to_rf_rename;
wire [4:0]  to_rf_rs1;
wire [4:0]  to_rf_rs2;
wire [4:0]  to_rf_Qi;
wire [4:0]  to_rf_Qj;
wire [31:0] to_rf_Vi;
wire [31:0] to_rf_Vj;

// ROB & LSB
wire        load_store_commit;
wire [4:0]  load_store_rob_id;

// ROB & RF
wire        to_rf_commit_valid;
wire [4:0]  to_rf_commit_rd;
wire [31:0] to_rf_commit_res;
wire [4:0]  to_rf_commit_dependency;

// ALU & RS
wire [31:0] alu_in_pc;
wire [31:0] alu_in_rs1;
wire [31:0] alu_in_rs2;
wire [31:0] alu_in_imm;
wire [6:0]  alu_in_opcode;
wire [4:0]  alu_in_calc_name;

MemController mem_controller(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  .byte_in(mem_din),
  .io_buffer_full(1'b0),
  .lw_type(mem_wr),
  .addr(mem_a),
  .byte_out(mem_dout),
  .fetch_enable(fetch_enable),
  .inst_addr(fetch_inst_addr),
  .i_cache_valid(i_cache_valid),
  .i_cache_data(i_cache_data),
  .lsb_enable(lsb_enable),
  .lsb_r_or_w(lsb_r_or_w),
  .op(lsb_op),
  .lsb_addr(lsb_read_addr),
  .lsb_data(lsb_write_data),
  .lsb_valid(mc_to_lsb_valid),
  .read_data(mc_to_lsb_read_data)
);

Predictor predictor(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  .if_pc(if_predictor_pc),
  .if_inst(if_predictor_inst),
  .predict_res(predictor_suggest_res),
  .predict_pc(predictor_suggest_pc),
  .ROB_valid(rob_commit_to_predictor),
  .commit_pc(rob_predictor_pc),
  .real_result(rob_predictor_result)
);

ICache i_cache(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  .inst(i_cache_data),
  .mem_valid(i_cache_valid),
  .mem_enable(fetch_enable),
  .inst_addr(fetch_inst_addr),
  .fetch_enable(IF_enable),
  .pc(IF_pc),
  .hit(IF_hit),
  .hit_data(IF_hit_data)
);

InsFetcher ins_fetcher(
  .issue_stall(issue_stall),
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  .if_jump(if_to_dispatcher_jump),
  .if_valid(if_to_dispatcher_valid),
  .dispatch_inst(if_to_dispatcher_inst),
  .dispatch_pc(if_to_dispatcher_pc),
  .suggest_jump(predictor_suggest_res),
  .suggest_pc(predictor_suggest_pc),
  .predict_inst(if_predictor_inst),
  .predict_pc(if_predictor_pc),
  .should_reset(wrong_commit),
  .reset_pc(reset_pc),
  .cache_valid(IF_hit),
  .cache_inst(IF_hit_data),
  .cache_pc(IF_pc),
  .fetch_enable(IF_enable)
);

Parser parser(
  .inst(parser_inst),
  .is_j_type(parser_is_jump),
  .is_load_store(parser_is_ls),
  .rd(parser_rd),
  .op(parser_op),
  .imm(parser_imm),
  .rs1(parser_rs1),
  .rs2(parser_rs2)
);

Dispatcher dispatcher(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  .wrong_commit(wrong_commit),
  .parse_inst(parser_inst),
  .is_jump(parser_is_jump),
  .is_ls(parser_is_ls),
  .rd(parser_rd),
  .op(parser_op),
  .imm(parser_imm),
  .rs1(parser_rs1),
  .rs2(parser_rs2),
  .rob_full(rob_full),
  .rename_rd(rob_rename_rd),
  .Qi_valid(rob_Qi_valid),
  .Qj_valid(rob_Qj_valid),
  .Vi_value(rob_Vi_value),
  .Vj_value(rob_Vj_value),
  .Qi_check(rob_Qi_check),
  .Qj_check(rob_Qj_check),
  .to_rob_valid(to_rob_valid),
  .to_rob_imm(to_rob_imm),
  .to_rob_pc(to_rob_pc),
  .to_rob_Qi(to_rob_Qi),
  .to_rob_Qj(to_rob_Qj),
  .to_rob_rd(to_rob_rd),
  .to_rob_op(to_rob_op),
  .to_rob_jump_choice(to_rob_jump_choice),
  .to_rob_is_jump(to_rob_is_jump),
  .rs_full(rs_full),
  .to_rs_valid(to_rs_valid),
  .to_rs_imm(to_rs_imm),
  .to_rs_pc(to_rs_pc),
  .to_rs_Qi(to_rs_Qi),
  .to_rs_Qj(to_rs_Qj),
  .to_rs_rd(to_rs_rd),
  .to_rs_op(to_rs_op),
  .to_rs_Vi(to_rs_Vi),
  .to_rs_Vj(to_rs_Vj),
  .lsb_full(lsb_full),
  .to_lsb_valid(to_lsb_valid),
  .to_lsb_imm(to_lsb_imm),
  .to_lsb_pc(to_lsb_pc),
  .to_lsb_Qi(to_lsb_Qi),
  .to_lsb_Qj(to_lsb_Qj),
  .to_lsb_rd(to_lsb_rd),
  .to_lsb_op(to_lsb_op),
  .to_lsb_Vi(to_lsb_Vi),
  .to_lsb_Vj(to_lsb_Vj),
  .to_rf_valid(to_rf_valid),
  .to_rf_name(to_rf_name),
  .to_rf_rename(to_rf_rename),
  .to_rf_rs1(to_rf_rs1),
  .to_rf_rs2(to_rf_rs2),
  .to_rf_Qi(to_rf_Qi),
  .to_rf_Qj(to_rf_Qj),
  .to_rf_Vi(to_rf_Vi),
  .to_rf_Vj(to_rf_Vj),
  .if_jump(if_to_dispatcher_jump),
  .if_valid(if_to_dispatcher_valid),
  .if_inst(if_to_dispatcher_inst),
  .if_pc(if_to_dispatcher_pc),
  .issue_stall(issue_stall),
  .alu_valid(alu_valid),
  .alu_res(alu_result),
  .alu_rob_id(alu_rob_id),
  .lsb_valid(lsb_valid),
  .lsb_res(lsb_result),
  .lsb_rob_id(lsb_rob_id)
);

ReOrderBuffer reorder_buffer (
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  .lsb_valid(lsb_valid),
  .lsb_res(lsb_result),
  .lsb_rob_id(lsb_rob_id),
  .ls_commit(load_store_commit),
  .ls_rob_id(load_store_rob_id),
  .wrong_commit(wrong_commit),
  .true_pc(reset_pc),
  .rob_full(rob_full),
  .predictor_enable(rob_commit_to_predictor),
  .predictor_update(rob_predictor_result),
  .predictor_update_pc(rob_predictor_pc),
  .alu_valid(alu_valid),
  .alu_res(alu_result),
  .alu_rob_id(alu_rob_id),
  .alu_jump_choice(alu_should_jump),
  .alu_pc(alu_jump_pc),
  .dispatch_valid(to_rob_valid),
  .dispatch_pc(to_rob_pc),
  .dispatch_rd(to_rob_rd),
  .dispatch_op(to_rob_op),
  .dispatch_jump_choice(to_rob_jump_choice),
  .dispatch_is_jump(to_rob_is_jump),
  .dispatch_Qi(to_rob_Qi),
  .dispatch_Qj(to_rob_Qj),
  .Qi_check(rob_Qi_check),
  .Qj_check(rob_Qj_check),
  .rename_rd(rob_rename_rd),
  .Qi_valid(rob_Qi_valid),
  .Qj_valid(rob_Qj_valid),
  .Vi_value(rob_Vi_value),
  .Vj_value(rob_Vj_value),
  .commit_valid(to_rf_commit_valid),
  .commit_rd(to_rf_commit_rd),
  .commit_res(to_rf_commit_res),
  .commit_dependency(to_rf_commit_dependency)
);

ALU alu (
  .pc(alu_in_pc),
  .rs1(alu_in_rs1),
  .rs2(alu_in_rs2),
  .imm(alu_in_imm),
  .opcode(alu_in_opcode),
  .calc_name(alu_in_calc_name),
  .alu_valid(alu_valid),
  .A(alu_result),
  .jump_pc(alu_jump_pc),
  .should_jump(alu_should_jump),
  .finish_name(alu_rob_id)
);

ReservationStation rs (
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  .wrong_commit(wrong_commit),
  .alu_valid(alu_valid),
  .alu_res(alu_result),
  .alu_rob_id(alu_rob_id),
  .alu_op(alu_in_opcode),
  .Vi_alu(alu_in_rs1),
  .Vj_alu(alu_in_rs2),
  .imm_alu(alu_in_imm),
  .alu_rd(alu_in_calc_name),
  .pc_alu(alu_in_pc),
  .lsb_valid(lsb_valid),
  .lsb_res(lsb_result),
  .lsb_rob_id(lsb_rob_id),
  .dispatch_valid(to_rs_valid),
  .dispatch_imm(to_rs_imm),
  .dispatch_pc(to_rs_pc),
  .dispatch_Qi(to_rs_Qi),
  .dispatch_Qj(to_rs_Qj),
  .dispatch_rd(to_rs_rd),
  .dispatch_op(to_rs_op),
  .dispatch_Vi(to_rs_Vi),
  .dispatch_Vj(to_rs_Vj),
  .rs_full(rs_full)
);

LoadStoreBuffer load_store_buffer (
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  .alu_valid(alu_valid),
  .alu_res(alu_result),
  .alu_rob_id(alu_rob_id),
  .wrong_commit(wrong_commit),
  .rob_valid(load_store_commit),
  .rob_commit_id(load_store_rob_id),
  .mem_valid(mc_to_lsb_valid),
  .mem_res(mc_to_lsb_read_data),
  .load_store_enable(lsb_enable),
  .load_store_addr(lsb_read_addr),
  .load_store_data(lsb_write_data),
  .load_or_store(lsb_r_or_w),
  .load_store_op(lsb_op),
  .dispatch_valid(to_lsb_valid),
  .dispatch_imm(to_lsb_imm),
  .dispatch_pc(to_lsb_pc),
  .dispatch_Qi(to_lsb_Qi),
  .dispatch_Qj(to_lsb_Qj),
  .dispatch_rd(to_lsb_rd),
  .dispatch_op(to_lsb_op),
  .dispatch_Vi(to_lsb_Vi),
  .dispatch_Vj(to_lsb_Vj),
  .lsb_full(lsb_full),
  .lsb_valid(lsb_valid),
  .lsb_res(lsb_result),
  .lsb_rob_id(lsb_rob_id)
);

RF register_file (
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  .rob_valid(to_rf_commit_valid),
  .dest(to_rf_commit_rd),
  .dest_depend(to_rf_commit_dependency),
  .rob_data(to_rf_commit_res),
  .wrong_commit(wrong_commit),
  .dispatch_enable(to_rf_valid),
  .dispatch_name(to_rf_name),
  .dispatch_rename(to_rf_rename),
  .dispatch_rs1(to_rf_rs1),
  .dispatch_rs2(to_rf_rs2),
  .dispatch_Qi(to_rf_Qi),
  .dispatch_Qj(to_rf_Qj),
  .dispatch_Vi(to_rf_Vi),
  .dispatch_Vj(to_rf_Vj)
);
endmodule