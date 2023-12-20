`include "defines.v"
module if_id (
    input wire       clk,
    input wire       rst,
    input wire [5:0] stall,

    //来自IF的pc信号
    input wire [`InstAddrBus] if_pc,

    //来自指令存储器的指令
    input wire [`InstBus] if_inst,

    //去往ID的信号
    output reg [`InstAddrBus] id_pc,
    output reg [    `InstBus] id_inst
);

  always @(posedge clk) begin
    if (rst || (stall[1] && !stall[2])) begin  //复位或暂停时
      id_pc   <= `zeroword;  //pc为0
      id_inst <= `zeroword;  //指令为空
    end else if (!stall[1]) begin  //其余非暂停时刻向下传递数据
      id_pc   <= if_pc;
      id_inst <= if_inst;
    end  //其余情况保持寄存器不变，不向下传递数据
  end
endmodule
