`include "defines.v"

module mem_wb(
	input wire					clk,
	input wire					rst,
	input wire [5:0]			stall,
	
	//来自访存阶段的信息	
	input wire[`RegAddrBus]       mem_wd,
	input wire                    mem_wreg,
	input wire[`RegBus]			mem_wdata,
	input wire [`RegBus]		mem_hi,
	input wire [`RegBus]		mem_lo,
	input wire 				mem_hilo,

	//送到回写阶段的信息
	output reg[`RegAddrBus]      wb_wd,
	output reg                   wb_wreg,
	output reg[`RegBus]		wb_wdata,	 
	output reg[`RegBus] 		wb_hi, 
	output reg[`RegBus] 		wb_lo, 
	output reg 					wb_hilo
);

	always @ (posedge clk) begin
		if(rst||(stall[4]&&!stall[5])) begin
		  wb_wd <= `NOPRegAddr;
		  wb_wreg <= `writeDisable;
		  wb_wdata <= `zeroword;	
		  wb_hi<=`zeroword;
		  wb_lo<=`zeroword;
		  wb_hilo<=`writeDisable;
		end else if(!stall[4])begin
		  wb_wd <= mem_wd;
		  wb_wreg <= mem_wreg;
		  wb_wdata <= mem_wdata;
		  wb_hi<=mem_hi;
		  wb_lo<=mem_lo;
		  wb_hilo<=mem_hilo;
		end
	end

endmodule