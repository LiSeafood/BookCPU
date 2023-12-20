`include "defines.v"
module ex_mem (
    input wire       clk,
    input wire       rst,
    input wire [5:0] stall,
    input wire       flush,

    //为了乘累加、乘累减指令增加的输入口
    input wire [`DoubleRegBus] hilo_i,
    input wire [          1:0] cnt_i,

    //来自执行阶段的信息	
    input wire [`RegAddrBus] ex_wd,
    input wire               ex_wreg,
    input wire [    `RegBus] ex_wdata,
    input wire [    `RegBus] ex_hi,
    input wire [    `RegBus] ex_lo,
    input wire               ex_hilo,
    input wire [  `AluOpBus] ex_aluop,
    input wire [    `RegBus] ex_mem_addr,
    input wire [    `RegBus] ex_reg2,
    input wire               ex_cp0_reg_we,
    input wire [        4:0] ex_cp0_reg_write_addr,
    input wire [    `RegBus] ex_cp0_reg_data,
    input wire [       31:0] ex_excepttype,
    input wire               ex_is_in_delayslot,
    input wire [    `RegBus] ex_current_inst_address,

    //送到访存阶段的信息
    output reg [`RegAddrBus] mem_wd,
    output reg               mem_wreg,
    output reg [    `RegBus] mem_wdata,
    output reg [    `RegBus] mem_hi,
    output reg [    `RegBus] mem_lo,
    output reg               mem_hilo,
    output reg [  `AluOpBus] mem_aluop,
    output reg [    `RegBus] mem_mem_addr,
    output reg [    `RegBus] mem_reg2,
    output reg               mem_cp0_reg_we,
    output reg [        4:0] mem_cp0_reg_write_addr,
    output reg [    `RegBus] mem_cp0_reg_data,
    output reg [       31:0] mem_excepttype,
    output reg               mem_is_in_delayslot,
    output reg [    `RegBus] mem_current_inst_address,


    //为了乘累加、乘累减指令增加的输出口
    output reg [`DoubleRegBus] hilo_o,
    output reg [          1:0] cnt_o
);

  always @(posedge clk) begin
    if (rst || flush) begin
      mem_wd                   <= `NOPRegAddr;
      mem_wreg                 <= `writeDisable;
      mem_wdata                <= `zeroword;
      mem_hi                   <= `zeroword;
      mem_lo                   <= `zeroword;
      mem_hilo                 <= `writeDisable;
      mem_aluop                <= `EXE_NOP_OP;
      mem_mem_addr             <= `zeroword;
      mem_reg2                 <= `zeroword;
      mem_cp0_reg_we           <= `writeDisable;
      mem_cp0_reg_write_addr   <= 5'b00000;
      mem_cp0_reg_data         <= `zeroword;
      mem_excepttype           <= `zeroword;
      mem_is_in_delayslot      <= `NotInDelaySlot;
      mem_current_inst_address <= `zeroword;
      hilo_o                   <= {`zeroword, `zeroword};
      cnt_o                    <= 2'b00;
    end else if (stall[3] && !stall[4]) begin
      mem_wd                   <= `NOPRegAddr;
      mem_wreg                 <= `writeDisable;
      mem_wdata                <= `zeroword;
      mem_hi                   <= `zeroword;
      mem_lo                   <= `zeroword;
      mem_hilo                 <= `writeDisable;
      mem_aluop                <= `EXE_NOP_OP;
      mem_mem_addr             <= `zeroword;
      mem_reg2                 <= `zeroword;
      mem_cp0_reg_we           <= `writeDisable;
      mem_cp0_reg_write_addr   <= 5'b00000;
      mem_cp0_reg_data         <= `zeroword;
      mem_excepttype           <= `zeroword;
      mem_is_in_delayslot      <= `NotInDelaySlot;
      mem_current_inst_address <= `zeroword;
      hilo_o                   <= hilo_i;
      cnt_o                    <= cnt_i;
    end else if (!stall[3]) begin
      mem_wd                   <= ex_wd;
      mem_wreg                 <= ex_wreg;
      mem_wdata                <= ex_wdata;
      mem_hi                   <= ex_hi;
      mem_lo                   <= ex_lo;
      mem_hilo                 <= ex_hilo;
      mem_aluop                <= ex_aluop;
      mem_mem_addr             <= ex_mem_addr;
      mem_reg2                 <= ex_reg2;
      mem_cp0_reg_we           <= ex_cp0_reg_we;
      mem_cp0_reg_write_addr   <= ex_cp0_reg_write_addr;
      mem_cp0_reg_data         <= ex_cp0_reg_data;
      mem_excepttype           <= ex_excepttype;
      mem_is_in_delayslot      <= ex_is_in_delayslot;
      mem_current_inst_address <= ex_current_inst_address;
      hilo_o                   <= {`zeroword, `zeroword};
      cnt_o                    <= 2'b00;
    end else begin
      hilo_o <= hilo_i;
      cnt_o  <= cnt_i;
    end
  end

endmodule
