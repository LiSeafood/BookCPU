`include "defines.v"
module ex_mem(
	input wire					clk,
	input wire					rst,
	
	//来自执行阶段的信息	
	input wire[`RegAddrBus]     ex_wd,
	input wire                  ex_wreg,
	input wire[`RegBus]			ex_wdata, 	
	input wire[`RegBus]			ex_hi,
	input wire[`RegBus]			ex_lo,
	input wire 					ex_hilo,
	
	//送到访存阶段的信息
	output reg[`RegAddrBus]      mem_wd,
	output reg                   mem_wreg,
	output reg[`RegBus]			 mem_wdata,
	output reg[`RegBus]			 mem_hi,
	output reg[`RegBus]			 mem_lo,
	output reg 					 mem_hilo
);

	always @ (posedge clk) begin
		if(rst == `RstEnable) begin
		  mem_wd <= `NOPRegAddr;
		  mem_wreg <= `writeDisable;
		  mem_wdata <= `zeroword;	
		  mem_hi<=`zeroword;
		  mem_lo<=`zeroword;
		  mem_hilo<=`writeDisable;
		end else begin
		  mem_wd <= ex_wd;
		  mem_wreg <= ex_wreg;
		  mem_wdata <= ex_wdata;
		  mem_hi<=ex_hi;
		  mem_lo<=ex_lo;
		  mem_hilo<=ex_hilo;
		end
	end
			

endmodule