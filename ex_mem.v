`include "defines.v"
module ex_mem(
	input wire					clk,
	input wire					rst,
	input wire [5:0]			stall,

	//为了乘累加、乘累减指令增加的输入口
	input  wire [`DoubleRegBus] hilo_i,
	input  wire [1:0]			cnt_i,
	
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
	output reg 					 mem_hilo,

	//为了乘累加、乘累减指令增加的输出口
	output reg [`DoubleRegBus] hilo_o,
	output reg [1:0]			cnt_o
);

	always @ (posedge clk) begin
		if(rst) begin
		  mem_wd <= `NOPRegAddr;
		  mem_wreg <= `writeDisable;
		  mem_wdata <= `zeroword;	
		  mem_hi<=`zeroword;
		  mem_lo<=`zeroword;
		  mem_hilo<=`writeDisable;
		  hilo_o<={`zeroword,`zeroword};
		  cnt_o<=2'b00;
		end else if(stall[3]&&!stall[4]) begin
		  mem_wd <= `NOPRegAddr;
		  mem_wreg <= `writeDisable;
		  mem_wdata <= `zeroword;	
		  mem_hi<=`zeroword;
		  mem_lo<=`zeroword;
		  mem_hilo<=`writeDisable;
		  hilo_o<=hilo_i;
		  cnt_o<=cnt_i;
		end else if(!stall[3]) begin
		  mem_wd <= ex_wd;
		  mem_wreg <= ex_wreg;
		  mem_wdata <= ex_wdata;
		  mem_hi<=ex_hi;
		  mem_lo<=ex_lo;
		  mem_hilo<=ex_hilo;
		  hilo_o<={`zeroword,`zeroword};
		  cnt_o<=2'b00;
		end else begin
		  hilo_o<=hilo_i;
		  cnt_o<=cnt_i;
		end
	end

endmodule