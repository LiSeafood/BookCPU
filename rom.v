`include "defines.v"
//指令存储器
module rom (
    input  wire                ce,
    input  wire [`InstAddrBus] addr,
    output reg  [    `InstBus] inst
);
  //指令寄存器,每个元素32位共128k(InstMemNum=2^17)
  reg [`InstBus] inst_mem[0:`InstMemNum-1];

  //这串是初始化指令存储器的代码

  initial $readmemh("E:/Codes/Verilog_Program/BookCPU/inst_rom.data", inst_mem);

  always @(*) begin
    if (ce == `ChipDisable) begin
      inst <= `zeroword;  //复位取得空指令
    end else begin  //否则按输入地址取rom中元素
      inst <= inst_mem[addr[`InstMemNumLog2+1:2]];
    end  //地址除以4(右移2位)才是inst_mem中的正确下标
  end

endmodule
