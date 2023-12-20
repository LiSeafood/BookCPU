`include "defines.v"
module EX (
    input wire rst,

    //id_ex段送来的信息
    input wire [  `AluOpBus] aluop,
    input wire [ `AluSelBus] alusel,
    input wire [    `RegBus] reg1,
    input wire [    `RegBus] reg2,
    input wire [    `RegBus] inst_i,
    input wire [`RegAddrBus] w_addr_i,
    input wire               we_i,
    input wire [       31:0] excepttype_i,
    input wire [    `RegBus] current_inst_address_i,

    //HILO模块传来的HI、LO寄存器的值
    input wire [`RegBus] hi_i,
    input wire [`RegBus] lo_i,

    //WB段关于HI、LO寄存器的数据相关问题
    input wire           wb_hilo_i,  //WB阶段的指令是否要写HI、LO寄存器
    input wire [`RegBus] wb_hi_i,    //要写进HI的值
    input wire [`RegBus] wb_lo_i,    //要写进LO的值

    //MEM段关于HI、LO寄存器的数据相关问题
    input wire           mem_hilo_i,  //MEM阶段的指令是否要写HI、LO寄存器
    input wire [`RegBus] mem_hi_i,    //要写进HI的值
    input wire [`RegBus] mem_lo_i,    //要写进LO的值

    //乘累加、乘累减指令相关
    input wire [`DoubleRegBus] hilo_temp_i,
    input wire [          1:0] cnt_i,

    //来自除法模块的输入
    input wire [`DoubleRegBus] div_res_i,  //除法结果
    input wire                 div_done_i, //除法是否完成

    //EX段的转移指令要保存的返回值
    input wire [`RegBus] link_addr_i,

    //当前EX段的指令是否位于延迟槽
    input wire is_in_delayslot_i,

    //访存阶段的指令是否要写CP0，用来检测数据相关
    input wire           mem_cp0_reg_we,
    input wire [    4:0] mem_cp0_reg_write_addr,
    input wire [`RegBus] mem_cp0_reg_data,

    //回写阶段的指令是否要写CP0，用来检测数据相关
    input wire           wb_cp0_reg_we,
    input wire [    4:0] wb_cp0_reg_write_addr,
    input wire [`RegBus] wb_cp0_reg_data,

    //与CP0相连，读取其中CP0寄存器的值
    input  wire [`RegBus] cp0_reg_data_i,
    output reg  [    4:0] cp0_reg_read_addr_o,

    //向下一流水级传递，用于写CP0中的寄存器
    output reg           cp0_reg_we_o,
    output reg [    4:0] cp0_reg_write_addr_o,
    output reg [`RegBus] cp0_reg_data_o,

    //EX段的指令对HI、LO寄存器的写操作请求
    output reg           hilo_o,
    output reg [`RegBus] hi_o,
    output reg [`RegBus] lo_o,

    //EX段的执行结果
    output reg               we_o,      //运算结果最终是否要写入
    output reg [`RegAddrBus] w_addr_o,  //执行指令最终要写入的寄存器地址
    output reg [    `RegBus] w_data_o,  //运算结果的值

    //乘累加、乘累减指令相关
    output reg [`DoubleRegBus] hilo_temp_o,
    output reg [          1:0] cnt_o,

    //去往除法模块的输出
    output reg [`RegBus] div_reg1_o,   //被除数
    output reg [`RegBus] div_reg2_o,   //除数
    output reg           div_start_o,  //是否开始除法运算
    output reg           div_sign_o,   //是否有符号

    //下面新增的几个输出是为加载、存储指令准备的
    output wire [`AluOpBus] aluop_o,
    output wire [  `RegBus] mem_addr_o,
    output wire [  `RegBus] reg2_o,

    //当前EX段的指令是否位于延迟槽
    output wire is_in_delayslot_o,

    output wire [   31:0] excepttype_o,
    output wire [`RegBus] current_inst_address_o,

    output reg stallreq  //暂停请求
);

  reg trapassert;  //是否有自陷异常
  reg ovassert;  //是否有溢出异常

  assign excepttype_o           = {excepttype_i[31:12], ovassert, trapassert, excepttype_i[9:8], 8'h00};
  assign is_in_delayslot_o      = is_in_delayslot_i;
  assign current_inst_address_o = current_inst_address_i;
  assign aluop_o                = aluop;
  assign mem_addr_o             = reg1 + {{16{inst_i[15]}}, inst_i[15:0]};
  assign reg2_o                 = reg2;

  reg [`RegBus] HI;  //保存HI的最新值
  reg [`RegBus] LO;  //保存LO的最新值

  //处理HILO的值及数据相关问题
  always @(*) begin
    if (rst) begin
      {HI, LO} <= {`zeroword, `zeroword};
    end else if (mem_hilo_i) begin
      {HI, LO} <= {mem_hi_i, mem_lo_i};  //MEM段的指令要写HI、LO寄存器
    end else if (wb_hilo_i) begin
      {HI, LO} <= {wb_hi_i, wb_lo_i};  //WB段的指令要写HI、LO寄存器
    end else begin
      {HI, LO} <= {hi_i, lo_i};
    end
  end

  //加、减、比较运算
  wire           ov_sum;  //保存溢出情况
  wire           reg1_eq_reg2;  //第一个操作数是否等于第二个操作数
  wire           reg1_lt_reg2;  //第一个操作数是否小于第二个操作数
  wire [`RegBus] reg2_mux;  //第二个操作数的补码
  wire [`RegBus] reg1_not;  //第一个操作数的反码
  wire [`RegBus] sum_res;  //保存加法结果

  //若为有符号自陷、减法或符号比较运算，则reg2_mux就等于第二个操作数的补码
  assign reg2_mux = ((aluop == `EXE_SUB_OP) || (aluop == `EXE_SUBU_OP) || (aluop == `EXE_SLT_OP) || (aluop == `EXE_TLT_OP) || (aluop == `EXE_TLTI_OP) || (aluop == `EXE_TGE_OP) || (aluop == `EXE_TGEI_OP)) ? (~reg2) + 1 : reg2;  //否则等于第二个操作数

  assign sum_res = reg1 + reg2_mux;  //加、减、符号比较运算的结果

  assign ov_sum  = ((!reg1[31] && !reg2_mux[31])&& sum_res[31])||//两正之和得负数，溢出
                     ((reg1[31]  && reg2_mux[31]) && !sum_res[31]);//两负之和得正数，溢出

  assign reg1_lt_reg2 = ((aluop == `EXE_SLT_OP) || (aluop == `EXE_TLT_OP) || (aluop == `EXE_TLTI_OP) || (aluop == `EXE_TGE_OP) || (aluop == `EXE_TGEI_OP)) ?  //若为有符号比较,或者自陷指令
      ((reg1[31] && !reg2[31]) ||  //1负2正，1小于2
      (!reg1[31] && !reg2[31] && sum_res[31]) ||  //两正之差为负，1小于2
      (reg1[31] && reg2[31] && sum_res[31])) :  //两负之差为负，1小于2
      (reg1 < reg2);  //无符号比较就直接比较得出结果

  assign reg1_not = ~reg1;  //reg1逐位取反

  //乘法运算
  wire [      `RegBus] opdata1_mult;  //乘法中的被乘数
  wire [      `RegBus] opdata2_mult;  //乘法中的乘数
  wire [`DoubleRegBus] hilo_temp;  //临时保存乘法结果
  reg  [`DoubleRegBus] hilo_temp1;
  reg  [`DoubleRegBus] mulres;  //保存乘法结果

  //如果是有符号的乘法且被乘数为负，则取补码
  assign opdata1_mult = (((aluop == `EXE_MUL_OP) || (aluop == `EXE_MULT_OP) || (aluop == `EXE_MADD_OP) || (aluop == `EXE_MSUB_OP)) && reg1[31]) ? (reg1_not + 1) : reg1;
  //如果是有符号的乘法且乘数为负，则取补码
  assign opdata2_mult = (((aluop == `EXE_MUL_OP) || (aluop == `EXE_MULT_OP) || (aluop == `EXE_MADD_OP) || (aluop == `EXE_MSUB_OP)) && reg2[31]) ? (~reg2 + 1) : reg2;
  assign hilo_temp    = opdata1_mult * opdata2_mult;  //临时的乘法结果
  always @(*) begin  //调整最终乘法结果
    if (rst) begin
      mulres <= {`zeroword, `zeroword};
    end else if (((aluop == `EXE_MULT_OP) || (aluop == `EXE_MUL_OP) || (aluop == `EXE_MADD_OP) || (aluop == `EXE_MSUB_OP)) && (reg1[31] ^ reg2[31])) begin
      mulres <= ~hilo_temp + 1;  //对临时结果取补码
    end else begin
      mulres <= hilo_temp;
    end
  end

  reg stallreq_m;  //是否因为乘累加、乘累减而暂停
  //乘累加、乘累减
  always @(*) begin
    if (rst) begin
      hilo_temp_o <= {`zeroword, `zeroword};
      cnt_o       <= 2'b0;
      stallreq_m  <= `NoStop;
    end else begin
      case (aluop)
        `EXE_MADD_OP, `EXE_MADDU_OP: begin
          if (cnt_i == 2'b00) begin  //第一个时钟周期
            hilo_temp_o <= mulres;
            cnt_o       <= 2'b01;
            hilo_temp1  <= {`zeroword, `zeroword};
            stallreq_m  <= `Stop;
          end else if (cnt_i == 2'b01) begin  //第二个时钟周期
            hilo_temp_o <= {`zeroword, `zeroword};
            cnt_o       <= 2'b10;
            hilo_temp1  <= hilo_temp_i + {HI, LO};
            stallreq_m  <= `NoStop;
          end
        end
        `EXE_MSUB_OP, `EXE_MSUBU_OP: begin
          if (cnt_i == 2'b00) begin  //第一个时钟周期
            hilo_temp_o <= ~mulres + 1;
            cnt_o       <= 2'b01;
            stallreq_m  <= `Stop;
          end else if (cnt_i == 2'b01) begin  //第二个时钟周期
            hilo_temp_o <= {`zeroword, `zeroword};
            cnt_o       <= 2'b10;
            hilo_temp1  <= hilo_temp_i + {HI, LO};
            stallreq_m  <= `NoStop;
          end
        end
        default: begin
          hilo_temp_o <= {`zeroword, `zeroword};
          cnt_o       <= 2'b00;
          stallreq_m  <= `NoStop;
        end
      endcase
    end
  end

  reg stallreq_d;  //是否因为除法而暂停
  //除法
  always @(*) begin
    stallreq_d  <= `NoStop;
    div_reg1_o  <= `zeroword;
    div_reg2_o  <= `zeroword;
    div_start_o <= `DivStop;
    div_sign_o  <= 1'b0;
    if (!rst) begin
      case (aluop)
        `EXE_DIV_OP: begin  //有符号除法
          div_reg1_o <= reg1;
          div_reg2_o <= reg2;
          div_sign_o <= 1'b1;
          if (!div_done_i) begin  //还没完成
            div_start_o <= `DivStart;  //开始！
            stallreq_d  <= `Stop;  //请求流水线暂停
          end else if (div_done_i) begin  //已完成
            div_start_o <= `DivStop;  //停止
            stallreq_d  <= `NoStop;  //流水线不再暂停
          end
        end
        `EXE_DIVU_OP: begin  //有符号除法
          div_reg1_o <= reg1;
          div_reg2_o <= reg2;
          div_sign_o <= 1'b0;
          if (!div_done_i) begin  //还没完成
            div_start_o <= `DivStart;  //继续进行
            stallreq_d  <= `Stop;  //请求流水线暂停
          end else if (div_done_i) begin  //已完成
            div_start_o <= `DivStop;  //停止
            stallreq_d  <= `NoStop;  //流水线不再暂停
          end
        end
        default: begin

        end
      endcase
    end
  end

  //判断是否发生自陷异常
  always @(*) begin
    trapassert <= `TrapNotAssert;
    case (aluop)
      `EXE_TEQ_OP, `EXE_TEQI_OP: begin
        if (reg1 == reg2) begin
          trapassert <= `TrapAssert;
        end
      end
      `EXE_TGE_OP, `EXE_TGEI_OP, `EXE_TGEIU_OP, `EXE_TGEU_OP: begin
        if (~reg1_lt_reg2) begin
          trapassert <= `TrapAssert;
        end
      end
      `EXE_TLT_OP, `EXE_TLTI_OP, `EXE_TLTIU_OP, `EXE_TLTU_OP: begin
        if (reg1_lt_reg2) begin
          trapassert <= `TrapAssert;
        end
      end
      `EXE_TNE_OP, `EXE_TNEI_OP: begin
        if (reg1 != reg2) begin
          trapassert <= `TrapAssert;
        end
      end
      default: begin
        trapassert <= `TrapNotAssert;
      end
    endcase
  end

  //暂停流水线
  always @(*) begin
    stallreq = stallreq_m || stallreq_d;
  end

  //ALU的运算
  always @(*) begin
    w_addr_o <= w_addr_i;
    if (((aluop == `EXE_ADD_OP) || (aluop == `EXE_ADDI_OP) || (aluop == `EXE_SUB_OP)) && ov_sum) begin
      we_o     <= `writeDisable;  //有溢出，不写啦
      ovassert <= 1'b1;  //溢出异常发生
    end else begin
      we_o     <= we_i;
      ovassert <= 1'b0;
    end
    if (rst) begin
      w_data_o <= `zeroword;
    end else begin
      case (aluop)
        `EXE_OR_OP: begin  //或
          w_data_o <= reg1 | reg2;
        end
        `EXE_AND_OP: begin  //与
          w_data_o <= reg1 & reg2;
        end
        `EXE_NOR_OP: begin  //或非
          w_data_o <= ~(reg1 | reg2);
        end
        `EXE_XOR_OP: begin  //异或
          w_data_o <= reg1 ^ reg2;
        end
        `EXE_SLL_OP: begin  //逻辑左移
          w_data_o <= reg2 << reg1[4:0];
        end
        `EXE_SRL_OP: begin  //逻辑右移
          w_data_o <= reg2 >> reg1[4:0];
        end
        `EXE_SRA_OP: begin  //算术右移
          w_data_o <= ({32{reg2[31]}} << (6'd32 - {1'b0, reg1[4:0]})) | reg2 >> reg1[4:0];
        end
        `EXE_MFHI_OP: begin
          w_data_o <= HI;
        end
        `EXE_MFLO_OP: begin
          w_data_o <= LO;
        end
        `EXE_MOVZ_OP, `EXE_MOVN_OP: begin
          w_data_o <= reg1;
        end
        `EXE_SLT_OP, `EXE_SLTU_OP: begin  //比较
          w_data_o <= reg1_lt_reg2;
        end
        `EXE_ADD_OP, `EXE_ADDU_OP, `EXE_ADDI_OP, `EXE_ADDIU_OP, `EXE_SUB_OP, `EXE_SUBU_OP: begin  //加、减
          w_data_o <= sum_res;
        end
        `EXE_MULT_OP, `EXE_MUL_OP, `EXE_MULTU_OP: begin  //乘法
          w_data_o <= mulres[31:0];
        end
        `EXE_MFC0_OP: begin
          cp0_reg_read_addr_o <= inst_i[15:11];  //要读的cp0里的地址
          w_data_o            <= cp0_reg_data_i;  //读来的数据
          if (mem_cp0_reg_we == `writeEnable && mem_cp0_reg_write_addr == inst_i[15:11]) begin
            w_data_o <= mem_cp0_reg_data;  //和MEM段有数据相关喔
          end else if (wb_cp0_reg_we == `writeEnable && wb_cp0_reg_write_addr == inst_i[15:11]) begin
            w_data_o <= wb_cp0_reg_data;  //和WB段有数据相关喔
          end
        end
        `EXE_CLZ_OP: begin  //计数clz
          w_data_o<=reg1[31] ? 0  : 
                      reg1[30] ? 1  : 
                      reg1[29] ? 2  :
                      reg1[28] ? 3  : 
                      reg1[27] ? 4  : 
                      reg1[26] ? 5  :
                      reg1[25] ? 6  : 
                      reg1[24] ? 7  : 
                      reg1[23] ? 8  : 
                      reg1[22] ? 9  : 
                      reg1[21] ? 10 : 
                      reg1[20] ? 11 :
                      reg1[19] ? 12 : 
                      reg1[18] ? 13 : 
                      reg1[17] ? 14 : 
                      reg1[16] ? 15 : 
                      reg1[15] ? 16 : 
                      reg1[14] ? 17 : 
                      reg1[13] ? 18 : 
                      reg1[12] ? 19 : 
                      reg1[11] ? 20 :
                      reg1[10] ? 21 : 
                      reg1[9]  ? 22 : 
                      reg1[8]  ? 23 : 
                      reg1[7]  ? 24 : 
                      reg1[6]  ? 25 : 
                      reg1[5]  ? 26 : 
                      reg1[4]  ? 27 : 
                      reg1[3]  ? 28 : 
                      reg1[2]  ? 29 : 
                      reg1[1]  ? 30 : 
                      reg1[0]  ? 31 : 32 ;
        end
        `EXE_CLO_OP: begin  //计数clo
          w_data_o<=reg1_not[31] ? 0  : 
                      reg1_not[30] ? 1  : 
                      reg1_not[29] ? 2  :
                      reg1_not[28] ? 3  : 
                      reg1_not[27] ? 4  : 
                      reg1_not[26] ? 5  :
                      reg1_not[25] ? 6  : 
                      reg1_not[24] ? 7  : 
                      reg1_not[23] ? 8  : 
                      reg1_not[22] ? 9  : 
                      reg1_not[21] ? 10 : 
                      reg1_not[20] ? 11 :
                      reg1_not[19] ? 12 : 
                      reg1_not[18] ? 13 : 
                      reg1_not[17] ? 14 : 
                      reg1_not[16] ? 15 : 
                      reg1_not[15] ? 16 : 
                      reg1_not[14] ? 17 : 
                      reg1_not[13] ? 18 : 
                      reg1_not[12] ? 19 : 
                      reg1_not[11] ? 20 :
                      reg1_not[10] ? 21 : 
                      reg1_not[9]  ? 22 : 
                      reg1_not[8]  ? 23 : 
                      reg1_not[7]  ? 24 : 
                      reg1_not[6]  ? 25 : 
                      reg1_not[5]  ? 26 : 
                      reg1_not[4]  ? 27 : 
                      reg1_not[3]  ? 28 : 
                      reg1_not[2]  ? 29 : 
                      reg1_not[1]  ? 30 : 
                      reg1_not[0]  ? 31 : 32;
        end
        default: begin
          w_data_o <= `zeroword;
        end
      endcase
      if (alusel == `EXE_RES_JUMP_BRANCH) begin  //分支转移
        w_data_o <= link_addr_i;
      end
    end
  end

  //对HI、LO寄存器的写操作
  always @(*) begin
    if (rst) begin
      hilo_o <= `writeDisable;
      hi_o   <= `zeroword;
      lo_o   <= `zeroword;
    end else if ((aluop == `EXE_MSUB_OP) || (aluop == `EXE_MSUBU_OP) || (aluop == `EXE_MADD_OP) || (aluop == `EXE_MADDU_OP)) begin
      hilo_o <= `writeEnable;
      hi_o   <= hilo_temp1[63:32];
      lo_o   <= hilo_temp1[31:0];
    end else if ((aluop == `EXE_MULT_OP) || (aluop == `EXE_MULTU_OP)) begin
      hilo_o <= `writeEnable;
      hi_o   <= mulres[63:32];
      lo_o   <= mulres[31:0];
    end else if ((aluop == `EXE_DIV_OP) || (aluop == `EXE_DIVU_OP)) begin
      hilo_o <= `writeEnable;
      hi_o   <= div_res_i[63:32];
      lo_o   <= div_res_i[31:0];
    end else if (aluop == `EXE_MTHI_OP) begin
      hilo_o <= `writeEnable;
      hi_o   <= reg1;  //写HI寄存器
      lo_o   <= LO;  //LO寄存器保持不变
    end else if (aluop == `EXE_MTLO_OP) begin
      hilo_o <= `writeEnable;
      hi_o   <= HI;  //HI寄存器保持不变
      lo_o   <= reg1;  //写LO寄存器
    end else begin
      hilo_o <= `writeDisable;
      hi_o   <= `zeroword;
      lo_o   <= `zeroword;
    end
  end

  always @(*) begin
    if (rst == `RstEnable) begin
      cp0_reg_write_addr_o <= 5'b00000;
      cp0_reg_we_o         <= `writeDisable;
      cp0_reg_data_o       <= `zeroword;
    end else if (aluop == `EXE_MTC0_OP) begin
      cp0_reg_write_addr_o <= inst_i[15:11];
      cp0_reg_we_o         <= `writeEnable;
      cp0_reg_data_o       <= reg1;
    end else begin
      cp0_reg_write_addr_o <= 5'b00000;
      cp0_reg_we_o         <= `writeDisable;
      cp0_reg_data_o       <= `zeroword;
    end
  end
endmodule
