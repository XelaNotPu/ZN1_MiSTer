// 64 x 32-bit simple dual-port RAM with byte enables (Quartus M10K template).
// Used as the YMF271 slot-register file (six instances = 24 byte lanes).
module ymf_regram (
	input  logic        clk,
	input  logic        we,
	input  logic  [5:0] waddr,
	input  logic  [3:0] be,
	input  logic [31:0] wdata,
	input  logic  [5:0] raddr,
	output logic [31:0] q
);

logic [3:0][7:0] ram [0:63];

always_ff @(posedge clk) begin
	if (we) begin
		if (be[0]) ram[waddr][0] <= wdata[7:0];
		if (be[1]) ram[waddr][1] <= wdata[15:8];
		if (be[2]) ram[waddr][2] <= wdata[23:16];
		if (be[3]) ram[waddr][3] <= wdata[31:24];
	end
	q <= ram[raddr];
end

endmodule
