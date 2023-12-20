`include "defines.v"
module ctrl (
    input wire rst,
    input wire id_stall,  //来自ID段的暂停信号
    input wire ex_stall,  //来自EX段的暂停信号

    input wire [   31:0] excepttype_i,  //发生的异常类型
    input wire [`RegBus] cp0_epc_i,     //epc寄存器的值

    output reg [`RegBus] new_pc,  //异常处理入口地址
    output reg           flush,   //是否要清除流水线
    output reg [    5:0] stall    //发往各段的暂停信号
);

  always @(*) begin
    if (rst) begin
      stall  <= 6'b000000;
      flush  <= 1'b0;
      new_pc <= `zeroword;
    end else if (excepttype_i != `zeroword) begin  //发生异常
      flush <= 1'b1;
      stall <= 6'b000000;
      case (excepttype_i)
        32'h00000001: begin  //中断
          new_pc <= 32'h00000020;
        end
        32'h00000008: begin  //syscall或者break
          new_pc <= 32'h00000040;
        end
        32'h0000000a: begin  //无效的指令
          new_pc <= 32'h00000040;
        end
        32'h0000000d: begin  //自陷
          new_pc <= 32'h00000040;
        end
        32'h0000000c: begin  //溢出
          new_pc <= 32'h00000040;
        end
        32'h0000000e: begin  //异常返回指令
          new_pc <= cp0_epc_i;
        end
        default: begin
        end
      endcase
    end else if (ex_stall) begin
      stall <= 6'b001111;  //把EX段和它前面的阶段都暂停
			flush <= 1'b0;		
    end else if (id_stall) begin
      stall <= 6'b000111;  //把ID段和它前面的阶段都暂停
			flush <= 1'b0;		
    end else begin
      stall <= 6'b000000;
			flush <= 1'b0;		
			new_pc <= `zeroword;		
    end 
  end
endmodule  //ctrl
