`include "defines.v"
module MEM (
    input wire rst,

    //来自ex_mem的信息
    input wire               we_i,
    input wire [`RegAddrBus] w_addr_i,
    input wire [    `RegBus] w_data_i,
    input wire [    `RegBus] hi_i,
    input wire [    `RegBus] lo_i,
    input wire               hilo_i,      //是否要写
    input wire [  `AluOpBus] aluop_i,
    input wire [    `RegBus] mem_addr_i,
    input wire [    `RegBus] reg2_i,

    //来自数据存储器的信息
    input wire [`RegBus] mem_data_i,

    //协处理器CP0的写信号
    input wire           cp0_reg_we_i,
    input wire [    4:0] cp0_reg_write_addr_i,
    input wire [`RegBus] cp0_reg_data_i,

    output reg           cp0_reg_we_o,
    output reg [    4:0] cp0_reg_write_addr_o,
    output reg [`RegBus] cp0_reg_data_o,

    //MEM的结果
    output reg               we_o,
    output reg [`RegAddrBus] w_addr_o,
    output reg [    `RegBus] w_data_o,
    output reg [    `RegBus] hi_o,
    output reg [    `RegBus] lo_o,
    output reg               hilo_o,

    //送到数据存储器的信息
    output reg  [`RegBus] mem_addr_o,
    output wire           mem_we_o,
    output reg  [    3:0] mem_sel_o,
    output reg  [`RegBus] mem_data_o,
    output reg            mem_ce_o
);

  wire [`RegBus] zero32;
  reg            mem_we;
  assign zero32   = `zeroword;
  assign mem_we_o = mem_we;

  always @(*) begin
    if (rst) begin
      we_o       <= `writeDisable;
      w_addr_o   <= `NOPRegAddr;
      w_data_o   <= `zeroword;
      hi_o       <= `zeroword;
      lo_o       <= `zeroword;
      hilo_o     <= `writeDisable;
      mem_addr_o <= `zeroword;
      mem_we     <= `writeDisable;
      mem_sel_o  <= 4'b0000;
      mem_data_o <= `zeroword;
      mem_ce_o   <= `ChipDisable;	
		  cp0_reg_we_o <= `writeDisable;
		  cp0_reg_write_addr_o <= 5'b00000;
		  cp0_reg_data_o <= `zeroword;		
    end else begin
      we_o       <= we_i;
      w_addr_o   <= w_addr_i;
      w_data_o   <= w_data_i;
      hi_o       <= hi_i;
      lo_o       <= lo_i;
      hilo_o     <= hilo_i;
      mem_we     <= `writeDisable;
      mem_addr_o <= `zeroword;
      mem_sel_o  <= 4'b1111;
      mem_ce_o   <= `ChipDisable;	
		  cp0_reg_we_o <= cp0_reg_we_i;
		  cp0_reg_write_addr_o <= cp0_reg_write_addr_i;
		  cp0_reg_data_o <= cp0_reg_data_i;		
      case (aluop_i)
        `EXE_LB_OP: begin
          mem_addr_o <= mem_addr_i;
          mem_we     <= `writeDisable;
          mem_ce_o   <= `ChipEnable;
          case (mem_addr_i[1:0])
            2'b00: begin
              w_data_o  <= {{24{mem_data_i[31]}}, mem_data_i[31:24]};
              mem_sel_o <= 4'b1000;
            end
            2'b01: begin
              w_data_o  <= {{24{mem_data_i[23]}}, mem_data_i[23:16]};
              mem_sel_o <= 4'b0100;
            end
            2'b10: begin
              w_data_o  <= {{24{mem_data_i[15]}}, mem_data_i[15:8]};
              mem_sel_o <= 4'b0010;
            end
            2'b11: begin
              w_data_o  <= {{24{mem_data_i[7]}}, mem_data_i[7:0]};
              mem_sel_o <= 4'b0001;
            end
            default: begin
              w_data_o <= `zeroword;
            end
          endcase
        end
        `EXE_LBU_OP: begin
          mem_addr_o <= mem_addr_i;
          mem_we     <= `writeDisable;
          mem_ce_o   <= `ChipEnable;
          case (mem_addr_i[1:0])
            2'b00: begin
              w_data_o  <= {{24{1'b0}}, mem_data_i[31:24]};
              mem_sel_o <= 4'b1000;
            end
            2'b01: begin
              w_data_o  <= {{24{1'b0}}, mem_data_i[23:16]};
              mem_sel_o <= 4'b0100;
            end
            2'b10: begin
              w_data_o  <= {{24{1'b0}}, mem_data_i[15:8]};
              mem_sel_o <= 4'b0010;
            end
            2'b11: begin
              w_data_o  <= {{24{1'b0}}, mem_data_i[7:0]};
              mem_sel_o <= 4'b0001;
            end
            default: begin
              w_data_o <= `zeroword;
            end
          endcase
        end
        `EXE_LH_OP: begin
          mem_addr_o <= mem_addr_i;
          mem_we     <= `writeDisable;
          mem_ce_o   <= `ChipEnable;
          case (mem_addr_i[1:0])
            2'b00: begin
              w_data_o  <= {{16{mem_data_i[31]}}, mem_data_i[31:16]};
              mem_sel_o <= 4'b1100;
            end
            2'b10: begin
              w_data_o  <= {{16{mem_data_i[15]}}, mem_data_i[15:0]};
              mem_sel_o <= 4'b0011;
            end
            default: begin
              w_data_o <= `zeroword;
            end
          endcase
        end
        `EXE_LHU_OP: begin
          mem_addr_o <= mem_addr_i;
          mem_we     <= `writeDisable;
          mem_ce_o   <= `ChipEnable;
          case (mem_addr_i[1:0])
            2'b00: begin
              w_data_o  <= {{16{1'b0}}, mem_data_i[31:16]};
              mem_sel_o <= 4'b1100;
            end
            2'b10: begin
              w_data_o  <= {{16{1'b0}}, mem_data_i[15:0]};
              mem_sel_o <= 4'b0011;
            end
            default: begin
              w_data_o <= `zeroword;
            end
          endcase
        end
        `EXE_LW_OP: begin
          mem_addr_o <= mem_addr_i;
          mem_we     <= `writeDisable;
          w_data_o   <= mem_data_i;
          mem_sel_o  <= 4'b1111;
          mem_ce_o   <= `ChipEnable;
        end
        `EXE_LWL_OP: begin
          mem_addr_o <= {mem_addr_i[31:2], 2'b00};
          mem_we     <= `writeDisable;
          mem_sel_o  <= 4'b1111;
          mem_ce_o   <= `ChipEnable;
          case (mem_addr_i[1:0])
            2'b00: begin
              w_data_o <= mem_data_i[31:0];
            end
            2'b01: begin
              w_data_o <= {mem_data_i[23:0], reg2_i[7:0]};
            end
            2'b10: begin
              w_data_o <= {mem_data_i[15:0], reg2_i[15:0]};
            end
            2'b11: begin
              w_data_o <= {mem_data_i[7:0], reg2_i[23:0]};
            end
            default: begin
              w_data_o <= `zeroword;
            end
          endcase
        end
        `EXE_LWR_OP: begin
          mem_addr_o <= {mem_addr_i[31:2], 2'b00};
          mem_we     <= `writeDisable;
          mem_sel_o  <= 4'b1111;
          mem_ce_o   <= `ChipEnable;
          case (mem_addr_i[1:0])
            2'b00: begin
              w_data_o <= {reg2_i[31:8], mem_data_i[31:24]};
            end
            2'b01: begin
              w_data_o <= {reg2_i[31:16], mem_data_i[31:16]};
            end
            2'b10: begin
              w_data_o <= {reg2_i[31:24], mem_data_i[31:8]};
            end
            2'b11: begin
              w_data_o <= mem_data_i;
            end
            default: begin
              w_data_o <= `zeroword;
            end
          endcase
        end
        `EXE_SB_OP: begin
          mem_addr_o <= mem_addr_i;
          mem_we     <= `writeEnable;
          mem_data_o <= {reg2_i[7:0], reg2_i[7:0], reg2_i[7:0], reg2_i[7:0]};
          mem_ce_o   <= `ChipEnable;
          case (mem_addr_i[1:0])
            2'b00: begin
              mem_sel_o <= 4'b1000;
            end
            2'b01: begin
              mem_sel_o <= 4'b0100;
            end
            2'b10: begin
              mem_sel_o <= 4'b0010;
            end
            2'b11: begin
              mem_sel_o <= 4'b0001;
            end
            default: begin
              mem_sel_o <= 4'b0000;
            end
          endcase
        end
        `EXE_SH_OP: begin
          mem_addr_o <= mem_addr_i;
          mem_we     <= `writeEnable;
          mem_data_o <= {reg2_i[15:0], reg2_i[15:0]};
          mem_ce_o   <= `ChipEnable;
          case (mem_addr_i[1:0])
            2'b00: begin
              mem_sel_o <= 4'b1100;
            end
            2'b10: begin
              mem_sel_o <= 4'b0011;
            end
            default: begin
              mem_sel_o <= 4'b0000;
            end
          endcase
        end
        `EXE_SW_OP: begin
          mem_addr_o <= mem_addr_i;
          mem_we     <= `writeEnable;
          mem_data_o <= reg2_i;
          mem_sel_o  <= 4'b1111;
          mem_ce_o   <= `ChipEnable;
        end
        `EXE_SWL_OP: begin
          mem_addr_o <= {mem_addr_i[31:2], 2'b00};
          mem_we     <= `writeEnable;
          mem_ce_o   <= `ChipEnable;
          case (mem_addr_i[1:0])
            2'b00: begin
              mem_sel_o  <= 4'b1111;
              mem_data_o <= reg2_i;
            end
            2'b01: begin
              mem_sel_o  <= 4'b0111;
              mem_data_o <= {zero32[7:0], reg2_i[31:8]};
            end
            2'b10: begin
              mem_sel_o  <= 4'b0011;
              mem_data_o <= {zero32[15:0], reg2_i[31:16]};
            end
            2'b11: begin
              mem_sel_o  <= 4'b0001;
              mem_data_o <= {zero32[23:0], reg2_i[31:24]};
            end
            default: begin
              mem_sel_o <= 4'b0000;
            end
          endcase
        end
        `EXE_SWR_OP: begin
          mem_addr_o <= {mem_addr_i[31:2], 2'b00};
          mem_we     <= `writeEnable;
          mem_ce_o   <= `ChipEnable;
          case (mem_addr_i[1:0])
            2'b00: begin
              mem_sel_o  <= 4'b1000;
              mem_data_o <= {reg2_i[7:0], zero32[23:0]};
            end
            2'b01: begin
              mem_sel_o  <= 4'b1100;
              mem_data_o <= {reg2_i[15:0], zero32[15:0]};
            end
            2'b10: begin
              mem_sel_o  <= 4'b1110;
              mem_data_o <= {reg2_i[23:0], zero32[7:0]};
            end
            2'b11: begin
              mem_sel_o  <= 4'b1111;
              mem_data_o <= reg2_i[31:0];
            end
            default: begin
              mem_sel_o <= 4'b0000;
            end
          endcase
        end
        default: begin
          //什么也不做
        end
      endcase
    end
  end

endmodule
