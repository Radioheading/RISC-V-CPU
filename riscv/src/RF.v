`include "const_def.v"

module RF (
    input wire clk,
    input wire rst,
    input wire rdy,
    
    // port with ROB
    input wire         rob_valid, // commit now
    input wire [4:0]   dest,
    input wire [4:0]   dest_depend, // what if the commit is obsolete
    input wire [31:0]  rob_data,
    input wire         wrong_commit,

    // port with dispatcher
    input wire         dispatch_enable,
    input wire  [4:0]  dispatch_name,
    input wire  [4:0]  dispatch_rename,
    // combinatorial logic
    input wire  [4:0]  dispatch_rs1,
    input wire  [4:0]  dispatch_rs2,
    output wire [4:0]  dispatch_Qi,
    output wire [4:0]  dispatch_Qj,
    output wire [31:0] dispatch_Vi,
    output wire [31:0] dispatch_Vj
);

// integer debug_file;

// initial begin
//     debug_file = $fopen("rf_debug.txt");
// end

// data
reg [31:0] register_file[31:0];
reg [4:0]  dependency[31:0];

assign dispatch_Qi = (rob_valid && dest == dispatch_rs1 && dest_depend == dependency[dispatch_rs1]) ? 0 : dependency[dispatch_rs1];
assign dispatch_Qj = (rob_valid && dest == dispatch_rs2 && dest_depend == dependency[dispatch_rs2]) ? 0 : dependency[dispatch_rs2];
assign dispatch_Vi = (rob_valid && dest == dispatch_rs1 && dest_depend == dependency[dispatch_rs1]) ? rob_data : register_file[dispatch_rs1];
assign dispatch_Vj = (rob_valid && dest == dispatch_rs2 && dest_depend == dependency[dispatch_rs2]) ? rob_data : register_file[dispatch_rs2];

integer i, clk_count = 0;

always @(posedge clk) begin
    clk_count = clk_count + 1;
    if (rst) begin
        for (i = 0; i < 32; i = i + 1) begin
            register_file[i] <= 0;
            dependency[i] <= 0;
        end
    end
    else if (rdy) begin
        if (wrong_commit) begin
            for (i = 0; i < 32; i = i + 1) begin
                dependency[i] <= 0;
            end
        end
        else begin
            if (dispatch_enable && dispatch_name) begin
                dependency[dispatch_name] = dispatch_rename;
            end
            if (rob_valid && dest) begin
                // if (clk_count < 200000) begin
                    // $fdisplay(debug_file, "RF: %d <= %d", dest, $signed(rob_data));
                // end
                register_file[dest] <= rob_data;
                if (dest_depend == dependency[dest]) begin
                    dependency[dest] <= 0;
                end
            end
        end
    end
end

endmodule