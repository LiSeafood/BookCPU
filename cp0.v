`include "defines.v"
//用于系统控制的协处理器cp0
//功能：配置CPU工作状态、高速缓存控制、异常控制、存储管理单元控制等
//这里只实现了部分这些功能
module cp0 (
    input wire clk,
    input wire rst,

    input wire           we_i,
    input wire [    4:0] waddr_i,
    input wire [    4:0] raddr_i,
    input wire [`RegBus] data_i,

    input wire [    5:0] int_i,                //6个外部硬件的中断输入
    input wire [   31:0] excepttype_i,         //最终的异常类型
    input wire [`RegBus] current_inst_addr_i,  //发生异常的指令地址
    input wire           is_in_delayslot_i,    //异常的指令是否在延迟槽

    output reg [`RegBus] data_o,
    output reg [`RegBus] count_o,    //处理器计数周期
    output reg [`RegBus] compare_o,  //定时中断控制
    output reg [`RegBus] status_o,   //处理器状态和控制寄存器
    output reg [`RegBus] cause_o,    //上一次的异常原因
    output reg [`RegBus] epc_o,      //上一次异常时的程序计数器
    output reg [`RegBus] config_o,   //配置寄存器，用于设置CPU参数
    output reg [`RegBus] prid_o,     //处理器标志和版本

    output reg timer_int_o  //是否发生了定时中断
);

  //写
  always @(posedge clk) begin
    if (rst) begin
      count_o     <= `zeroword;
      compare_o   <= `zeroword;
      //status寄存器的CU为0001，表示协处理器CP0存在
      status_o    <= 32'b00010000000000000000000000000000;
      cause_o     <= `zeroword;
      epc_o       <= `zeroword;
      //config寄存器的BE为1，表示Big-Endian(大端模式）；MT为00，表示没有MMU
      config_o    <= 32'b00000000000000001000000000000000;
      //制作者是L，对应的是0x48，类型是0x1，基本类型，版本号是1.0
      prid_o      <= 32'b00000000010011000000000100000010;
      timer_int_o <= `InterruptNotAssert;
    end else begin
      count_o        <= count_o + 1;  //每周期计数+1
      cause_o[15:10] <= int_i;  //这几位保存外部中断声明
      //compare不是0，且count值等于compare值时
      if (compare_o != `zeroword && count_o == compare_o) begin
        timer_int_o <= `InterruptAssert;  //时钟中断发生
      end

      if (we_i) begin
        case (waddr_i)
          `CP0_REG_COUNT: begin
            count_o <= data_i;
          end
          `CP0_REG_COMPARE: begin
            compare_o   <= data_i;
            timer_int_o <= `InterruptNotAssert;
          end
          `CP0_REG_STATUS: begin
            status_o <= data_i;
          end
          `CP0_REG_EPC: begin
            epc_o <= data_i;
          end
          `CP0_REG_CAUSE: begin
            //cause寄存器只有IP[1:0]、IV、WP字段是可写的
            cause_o[9:8] <= data_i[9:8];
            cause_o[23]  <= data_i[23];
            cause_o[22]  <= data_i[22];
          end
        endcase  //case addr_i
      end

      case (excepttype_i)
        32'h00000001: begin
          if (is_in_delayslot_i == `InDelaySlot) begin
            epc_o       <= current_inst_addr_i - 4;
            cause_o[31] <= 1'b1;
          end else begin
            epc_o       <= current_inst_addr_i;
            cause_o[31] <= 1'b0;
          end
          status_o[1]  <= 1'b1;
          cause_o[6:2] <= 5'b00000;

        end
        32'h00000008: begin
          if (status_o[1] == 1'b0) begin
            if (is_in_delayslot_i == `InDelaySlot) begin
              epc_o       <= current_inst_addr_i - 4;
              cause_o[31] <= 1'b1;
            end else begin
              epc_o       <= current_inst_addr_i;
              cause_o[31] <= 1'b0;
            end
          end
          status_o[1]  <= 1'b1;
          cause_o[6:2] <= 5'b01000;
        end
        32'h0000000a: begin
          if (status_o[1] == 1'b0) begin
            if (is_in_delayslot_i == `InDelaySlot) begin
              epc_o       <= current_inst_addr_i - 4;
              cause_o[31] <= 1'b1;
            end else begin
              epc_o       <= current_inst_addr_i;
              cause_o[31] <= 1'b0;
            end
          end
          status_o[1]  <= 1'b1;
          cause_o[6:2] <= 5'b01010;
        end
        32'h0000000d: begin
          if (status_o[1] == 1'b0) begin
            if (is_in_delayslot_i == `InDelaySlot) begin
              epc_o       <= current_inst_addr_i - 4;
              cause_o[31] <= 1'b1;
            end else begin
              epc_o       <= current_inst_addr_i;
              cause_o[31] <= 1'b0;
            end
          end
          status_o[1]  <= 1'b1;
          cause_o[6:2] <= 5'b01101;
        end
        32'h0000000c: begin
          if (status_o[1] == 1'b0) begin
            if (is_in_delayslot_i == `InDelaySlot) begin
              epc_o       <= current_inst_addr_i - 4;
              cause_o[31] <= 1'b1;
            end else begin
              epc_o       <= current_inst_addr_i;
              cause_o[31] <= 1'b0;
            end
          end
          status_o[1]  <= 1'b1;
          cause_o[6:2] <= 5'b01100;
        end
        32'h0000000e: begin
          status_o[1] <= 1'b0;
        end
        default: begin
        end
      endcase

    end  //if
  end  //always

  //读
  always @(*) begin
    if (rst) begin
      data_o <= `zeroword;
    end else begin
      case (raddr_i)
        `CP0_REG_COUNT: begin
          data_o <= count_o;
        end
        `CP0_REG_COMPARE: begin
          data_o <= compare_o;
        end
        `CP0_REG_STATUS: begin
          data_o <= status_o;
        end
        `CP0_REG_CAUSE: begin
          data_o <= cause_o;
        end
        `CP0_REG_EPC: begin
          data_o <= epc_o;
        end
        `CP0_REG_PrId: begin
          data_o <= prid_o;
        end
        `CP0_REG_CONFIG: begin
          data_o <= config_o;
        end
        default: begin
        end
      endcase  //case addr_i			
    end  //if
  end  //always

endmodule  //cp0
