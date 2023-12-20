`include "defines.v"
//相当于书中的pc模块
module IF (
    input wire           clk,     //时钟信号
    input wire           rst,     //复位信号
    input wire [    5:0] stall,   //暂停信号
    input wire           branch,  //是否转移
    input wire [`RegBus] b_addr,  //转移地址
    input wire           flush,   //流水线清除信号
    input wire [`RegBus] new_pc,  //异常处理例程地址

    output reg [`InstAddrBus] pc,
    output reg                ce
);

  always @(posedge clk) begin
    if (!ce) begin
      pc <= 32'hbfc00000;
    end else if (flush) begin  //异常发生了
      pc <= new_pc;
    end else if (!stall[0]) begin//不是暂停
      if (branch) begin  //转移
        pc <= b_addr;
      end else begin
        pc <= pc + 4'h4;  //pc每周期+4
      end
    end
  end

  always @(posedge clk) begin
    if (rst) begin
      ce <= 1'b0;  //复位时禁用指令存储器
    end else begin
      ce <= 1'b1;  //指令存储器可用
    end
  end

endmodule
