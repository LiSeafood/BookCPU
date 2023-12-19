`include "defines.v"
module top (
    input wire clk,
    input wire rst,

    //连接指令存储器
    input  wire [`RegBus] rom_data_i,
    output wire [`RegBus] rom_addr_o,
    output wire           rom_ce_o,

    //连接数据存储器data_ram
    input  wire [`RegBus] ram_data_i,
    output wire [`RegBus] ram_addr_o,
    output wire [`RegBus] ram_data_o,
    output wire           ram_we_o,
    output wire [    3:0] ram_sel_o,
    output wire           ram_ce_o
);

  //连接IF/ID模块与译码阶段ID模块的变量
  wire [`InstAddrBus] pc;
  wire [`InstAddrBus] id_pc_i;
  wire [`InstBus] id_inst_i;

  //连接译码阶段ID模块的输出与ID/EX模块的输入
  wire [`AluOpBus] id_aluop_o;
  wire [`AluSelBus] id_alusel_o;
  wire [`RegBus] id_reg1_o;
  wire [`RegBus] id_reg2_o;
  wire id_wreg_o;
  wire [`RegAddrBus] id_wd_o;
  wire id_is_in_delayslot_o;
  wire [`RegBus] id_link_address_o;
  wire [`RegBus] id_inst_o;

  //连接ID/EX模块的输出与执行阶段EX模块的输入
  wire [`AluOpBus] ex_aluop_i;
  wire [`AluSelBus] ex_alusel_i;
  wire [`RegBus] ex_reg1_i;
  wire [`RegBus] ex_reg2_i;
  wire ex_wreg_i;
  wire [`RegAddrBus] ex_wd_i;
  wire ex_is_in_delayslot_i;
  wire [`RegBus] ex_link_address_i;
  wire [`RegBus] ex_inst_i;

  //连接执行阶段EX模块的输出与EX/MEM模块的输入
  wire ex_wreg_o;
  wire [`RegAddrBus] ex_wd_o;
  wire [`RegBus] ex_wdata_o;
  wire [`RegBus] ex_hi_o;
  wire [`RegBus] ex_lo_o;
  wire ex_whilo_o;
  wire [`AluOpBus] ex_aluop_o;
  wire [`RegBus] ex_mem_addr_o;
  wire [`RegBus] ex_reg1_o;
  wire [`RegBus] ex_reg2_o;

  //连接EX/MEM模块的输出与访存阶段MEM模块的输入
  wire mem_wreg_i;
  wire [`RegAddrBus] mem_wd_i;
  wire [`RegBus] mem_wdata_i;
  wire [`RegBus] mem_hi_i;
  wire [`RegBus] mem_lo_i;
  wire mem_whilo_i;
  wire [`AluOpBus] mem_aluop_i;
  wire [`RegBus] mem_mem_addr_i;
  wire [`RegBus] mem_reg1_i;
  wire [`RegBus] mem_reg2_i;

  //连接访存阶段MEM模块的输出与MEM/WB模块的输入
  wire mem_wreg_o;
  wire [`RegAddrBus] mem_wd_o;
  wire [`RegBus] mem_wdata_o;
  wire [`RegBus] mem_hi_o;
  wire [`RegBus] mem_lo_o;
  wire mem_whilo_o;

  //连接MEM/WB模块的输出与回写阶段的输入	
  wire wb_wreg_i;
  wire [`RegAddrBus] wb_wd_i;
  wire [`RegBus] wb_wdata_i;
  wire [`RegBus] wb_hi_i;
  wire [`RegBus] wb_lo_i;
  wire wb_whilo_i;

  //连接译码阶段ID模块与通用寄存器Regfile模块
  wire reg1_read;
  wire reg2_read;
  wire [`RegBus] reg1_data;
  wire [`RegBus] reg2_data;
  wire [`RegAddrBus] reg1_addr;
  wire [`RegAddrBus] reg2_addr;

  //连接执行阶段与hilo模块的输出，读取HI、LO寄存器
  wire [`RegBus] hi;
  wire [`RegBus] lo;

  //连接执行阶段与ex_reg模块，用于多周期的MADD、MADDU、MSUB、MSUBU指令
  wire [`DoubleRegBus] hilo_temp_o;
  wire [1:0] cnt_o;

  wire [`DoubleRegBus] hilo_temp_i;
  wire [1:0] cnt_i;

  //连接除法模块和EX
  wire [`DoubleRegBus] div_result;
  wire div_ready;
  wire [`RegBus] div_opdata1;
  wire [`RegBus] div_opdata2;
  wire div_start;
  wire div_annul;
  wire signed_div;

  //分支延迟信号
  wire is_in_delayslot_i;
  wire is_in_delayslot_o;
  wire next_inst_in_delayslot_o;
  wire id_branch_flag_o;
  wire [`RegBus] branch_target_address;

  //暂停信号
  wire [5:0] stall;
  wire stallreq_from_id;
  wire stallreq_from_ex;

  //IF例化
  IF if0 (
      .clk(clk),
      .rst(rst),
      .stall(stall),
      .branch(id_branch_flag_o),
      .b_addr(branch_target_address),
      .pc(pc),
      .ce(rom_ce_o)
  );

  assign rom_addr_o = pc;  //指令存储器的输入地址就是pc的值

  //IF/ID模块例化
  if_id if_id0 (
      .clk(clk),
      .rst(rst),
      .stall(stall),
      .if_pc(pc),
      .if_inst(rom_data_i),
      .id_pc(id_pc_i),
      .id_inst(id_inst_i)
  );

  //译码阶段ID模块
  ID id0 (
      .rst (rst),
      .pc  (id_pc_i),
      .inst(id_inst_i),

      .rs_data(reg1_data),
      .rt_data(reg2_data),

      //处于EX阶段的指令要写入的目的寄存器信息
      .ex_we(ex_wreg_o),
      .ex_w_data(ex_wdata_o),
      .ex_w_addr(ex_wd_o),

      //处于MEM阶段的指令要写入的目的寄存器信息
      .mem_we(mem_wreg_o),
      .mem_w_data(mem_wdata_o),
      .mem_w_addr(mem_wd_o),

      //延迟槽
      .delay_i(is_in_delayslot_i),

      //送到regfile的信息
      .rs_read(reg1_read),
      .rt_read(reg2_read),
      .rs_addr(reg1_addr),
      .rt_addr(reg2_addr),

      //送到ID/EX模块的信息
      .aluop(id_aluop_o),
      .alusel(id_alusel_o),
      .reg1(id_reg1_o),
      .reg2(id_reg2_o),
      .w_addr(id_wd_o),
      .we(id_wreg_o),
      .inst_o(id_inst_o),

      //分支转移延迟槽相关
      .next_delay_o(next_inst_in_delayslot_o),
      .branch(id_branch_flag_o),
      .b_addr(branch_target_address),
      .link_addr(id_link_address_o),
      .delay_o(id_is_in_delayslot_o),

      .stallreq(stallreq_from_id)
  );

  //通用寄存器Regfile例化
  regfile regfile0 (
      .clk(clk),
      .rst(rst),
      .we(wb_wreg_i),
      .waddr(wb_wd_i),
      .wdata(wb_wdata_i),
      .re1(reg1_read),
      .raddr1(reg1_addr),
      .rdata1(reg1_data),
      .re2(reg2_read),
      .raddr2(reg2_addr),
      .rdata2(reg2_data)
  );

  //ID/EX模块
  id_ex id_ex0 (
      .clk  (clk),
      .rst  (rst),
      .stall(stall),

      //从译码阶段ID模块传递的信息
      .id_aluop(id_aluop_o),
      .id_alusel(id_alusel_o),
      .id_reg1(id_reg1_o),
      .id_reg2(id_reg2_o),
      .id_wd(id_wd_o),
      .id_wreg(id_wreg_o),
      .id_link_address(id_link_address_o),
      .id_is_in_delayslot(id_is_in_delayslot_o),
      .next_inst_in_delayslot_i(next_inst_in_delayslot_o),
      .id_inst(id_inst_o),

      //传递到执行阶段EX模块的信息
      .ex_aluop(ex_aluop_i),
      .ex_alusel(ex_alusel_i),
      .ex_reg1(ex_reg1_i),
      .ex_reg2(ex_reg2_i),
      .ex_wd(ex_wd_i),
      .ex_wreg(ex_wreg_i),
      .ex_link_address(ex_link_address_i),
      .ex_is_in_delayslot(ex_is_in_delayslot_i),
      .is_in_delayslot_o(is_in_delayslot_i),
      .ex_inst(ex_inst_i)
  );

  //EX模块
  EX ex0 (
      .rst(rst),

      //送到执行阶段EX模块的信息
      .aluop(ex_aluop_i),
      .alusel(ex_alusel_i),
      .reg1(ex_reg1_i),
      .reg2(ex_reg2_i),
      .w_addr_i(ex_wd_i),
      .we_i(ex_wreg_i),
      .hi_i(hi),
      .lo_i(lo),
      .inst_i(ex_inst_i),

      .wb_hi_i(wb_hi_i),
      .wb_lo_i(wb_lo_i),
      .wb_hilo_i(wb_whilo_i),
      .mem_hi_i(mem_hi_o),
      .mem_lo_i(mem_lo_o),
      .mem_hilo_i(mem_whilo_o),

      .hilo_temp_i(hilo_temp_i),
      .cnt_i(cnt_i),

      .div_res_i (div_result),
      .div_done_i(div_ready),

      .link_addr_i(ex_link_address_i),
      .is_in_delayslot_i(ex_is_in_delayslot_i),

      //EX模块的输出到EX/MEM模块信息
      .we_o(ex_wreg_o),
      .w_addr_o(ex_wd_o),
      .w_data_o(ex_wdata_o),

      .hi_o  (ex_hi_o),
      .lo_o  (ex_lo_o),
      .hilo_o(ex_whilo_o),

      .hilo_temp_o(hilo_temp_o),
      .cnt_o(cnt_o),

      .aluop_o(ex_aluop_o),
      .mem_addr_o(ex_mem_addr_o),
      .reg2_o(ex_reg2_o),


      //EX模块输出到除法模块的信息
      .div_reg1_o (div_opdata1),
      .div_reg2_o (div_opdata2),
      .div_start_o(div_start),
      .div_sign_o (signed_div),

      .stallreq(stallreq_from_ex)
  );

  //除法模块
  div div0 (
      .clk(clk),
      .rst(rst),

      .sign  (signed_div),
      .reg1  (div_opdata1),
      .reg2  (div_opdata2),
      .start (div_start),
      .cancel(1'b0),

      .result(div_result),
      .done  (div_ready)
  );

  //EX/MEM模块
  ex_mem ex_mem0 (
      .clk  (clk),
      .rst  (rst),
      .stall(stall),

      //来自执行阶段EX模块的信息	
      .ex_wd(ex_wd_o),
      .ex_wreg(ex_wreg_o),
      .ex_wdata(ex_wdata_o),
      .ex_hi(ex_hi_o),
      .ex_lo(ex_lo_o),
      .ex_hilo(ex_whilo_o),
      .ex_aluop(ex_aluop_o),
      .ex_mem_addr(ex_mem_addr_o),
      .ex_reg2(ex_reg2_o),

      //为了乘累加、乘累减指令增加的输入口
      .hilo_i(hilo_temp_o),
      .cnt_i (cnt_o),

      //送到访存阶段MEM模块的信息
      .mem_wd(mem_wd_i),
      .mem_wreg(mem_wreg_i),
      .mem_wdata(mem_wdata_i),
      .mem_hi(mem_hi_i),
      .mem_lo(mem_lo_i),
      .mem_hilo(mem_whilo_i),
      .mem_aluop(mem_aluop_i),
      .mem_mem_addr(mem_mem_addr_i),
      .mem_reg2(mem_reg2_i),

      //为了乘累加、乘累减指令增加的输出口	       	
      .hilo_o(hilo_temp_i),
      .cnt_o (cnt_i)
  );

  //MEM模块例化
  MEM mem0 (
      .rst(rst),

      //来自EX/MEM模块的信息	
      .we_i(mem_wreg_i),
      .w_addr_i(mem_wd_i),
      .w_data_i(mem_wdata_i),
      .hi_i(mem_hi_i),
      .lo_i(mem_lo_i),
      .hilo_i(mem_whilo_i),
      .aluop_i(mem_aluop_i),
      .mem_addr_i(mem_mem_addr_i),
      .reg2_i(mem_reg2_i),

      //来自数据存储器的信息
      .mem_data_i(ram_data_i),

      //送到MEM/WB模块的信息
      .we_o(mem_wreg_o),
      .w_addr_o(mem_wd_o),
      .w_data_o(mem_wdata_o),
      .hi_o(mem_hi_o),
      .lo_o(mem_lo_o),
      .hilo_o(mem_whilo_o),

      //送到数据存储器的信息
      .mem_addr_o(ram_addr_o),
      .mem_we_o  (ram_we_o),
      .mem_sel_o (ram_sel_o),
      .mem_data_o(ram_data_o),
      .mem_ce_o  (ram_ce_o)
  );

  //MEM/WB模块例化
  mem_wb mem_wb0 (
      .clk  (clk),
      .rst  (rst),
      .stall(stall),

      //来自访存阶段MEM模块的信息	
      .mem_wd(mem_wd_o),
      .mem_wreg(mem_wreg_o),
      .mem_wdata(mem_wdata_o),
      .mem_hi(mem_hi_o),
      .mem_lo(mem_lo_o),
      .mem_hilo(mem_whilo_o),

      //送到回写阶段的信息
      .wb_wd(wb_wd_i),
      .wb_wreg(wb_wreg_i),
      .wb_wdata(wb_wdata_i),
      .wb_hi(wb_hi_i),
      .wb_lo(wb_lo_i),
      .wb_hilo(wb_whilo_i)

  );

  //WB段HILO寄存器例化
  hilo hilo0 (
      .clk(clk),
      .rst(rst),

      //写端口
      .we  (wb_whilo_i),
      .hi_i(wb_hi_i),
      .lo_i(wb_lo_i),

      //读端口1
      .hi_o(hi),
      .lo_o(lo)
  );

  ctrl ctrl0 (
      .rst(rst),
      .id_stall(stallreq_from_id),
      .ex_stall(stallreq_from_ex),
      .stall(stall)
  );

endmodule
