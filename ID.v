`include "defines.v"
module ID (
    input wire                rst,
    input wire [`InstAddrBus] pc,
    input wire [    `InstBus] inst,

    //读取的regfile的值
    input wire [`RegBus] rs_data,
    input wire [`RegBus] rt_data,

    //来自EX段的运算结果定向
    input wire               ex_we,
    input wire [    `RegBus] ex_w_data,
    input wire [`RegAddrBus] ex_w_addr,

    //来自MEM段的操作结果定向
    input wire               mem_we,
    input wire [    `RegBus] mem_w_data,
    input wire [`RegAddrBus] mem_w_addr,

    //处于EX阶段的指令的一些信息定向，用于解决load相关
    input wire [`AluOpBus] ex_aluop_i,

    //若上一条是转移指令，则下一条指令进入时此变量为true
    input wire delay_i,  //当前指令是否是延迟槽指令

    //输出到regfile的值
    output reg               rs_read,
    output reg               rt_read,
    output reg [`RegAddrBus] rs_addr,
    output reg [`RegAddrBus] rt_addr,

    //送到EX的信息
    output reg  [  `AluOpBus] aluop,   //要进行的运算子类型
    output reg  [ `AluSelBus] alusel,  //要进行的运算类型
    output reg  [    `RegBus] reg1,    //操作数1
    output reg  [    `RegBus] reg2,    //操作数2
    output reg  [`RegAddrBus] w_addr,  //ID的指令要写入的目的寄存器地址
    output reg                we,      //ID的指令是否要写入目的寄存器
    output wire [    `RegBus] inst_o,

    //转移相关指令
    output reg           branch,       //要不要转移
    output reg [`RegBus] b_addr,       //转移到的目标地址
    output reg [`RegBus] link_addr,    //转移指令要保存的返回地址
    output reg           delay_o,      //当前指令是否是延迟槽指令    
    output reg           next_delay_o, //下一条指令是不是延迟槽指令

    output wire stallreq  //暂停请求
);

  assign inst_o = inst;  //向下传递指令

  //转移指令相关
  wire [`RegBus] pc_plus_8;
  wire [`RegBus] pc_plus_4;
  assign pc_plus_8 = pc + 8;  //保存当前指令后第2条指令
  assign pc_plus_4 = pc + 4;  //保存当前指令紧接的指令

  wire [`RegBus] imm_sll2_signednext;  //offset左移两位再扩展至32位
  assign imm_sll2_signednext = {{14{inst[15]}}, inst[15:0], 2'b00};

  //取得指令的指令码和功能码，用于判断是什么指令
  wire [    5:0 ] op = inst[31:26];  //指令码
  wire [    4:0 ] op2 = inst[10:6];
  wire [    5:0 ] op3 = inst[5:0];  //功能码
  wire [    4:0 ] op4 = inst[20:16];

  reg  [`RegBus]                                 imm;  //立即数
  reg                                            valid;  //指令是否有效（这变量感觉没有用啊喂）

  //解决load相关问题
  reg                                            stallreq_for_reg1_loadrelate;  //reg1是否与上一条指令有load相关
  reg                                            stallreq_for_reg2_loadrelate;  //reg2是否与上一条指令有load相关
  wire                                           pre_inst_is_load;  //上一条是不是加载指令

  assign pre_inst_is_load = ((ex_aluop_i == `EXE_LB_OP) || 
  													(ex_aluop_i == `EXE_LBU_OP)||
  													(ex_aluop_i == `EXE_LH_OP) ||
  													(ex_aluop_i == `EXE_LHU_OP)||
  													(ex_aluop_i == `EXE_LW_OP) ||
  													(ex_aluop_i == `EXE_LWR_OP)||
  													(ex_aluop_i == `EXE_LWL_OP)||
  													(ex_aluop_i == `EXE_LL_OP) ||
  													(ex_aluop_i == `EXE_SC_OP)) ? 1'b1 : 1'b0;

  //译码
  always @(*) begin  //先赋初值，都赋为0
    aluop        <= `EXE_NOP_OP;
    alusel       <= `EXE_RES_NOP;
    we           <= `writeDisable;
    rs_read      <= 1'b0;
    rt_read      <= 1'b0;
    imm          <= `zeroword;
    link_addr    <= `zeroword;
    b_addr       <= `zeroword;
    branch       <= `NotBranch;
    next_delay_o <= `NotInDelaySlot;
    if (rst) begin  //复位的话这些都是0
      w_addr  <= `NOPRegAddr;
      rs_addr <= `NOPRegAddr;
      rt_addr <= `NOPRegAddr;
      valid   <= `InstValid;
    end else begin
      w_addr  <= inst[15:11];  //默认写入地址:rd
      rs_addr <= inst[25:21];  //默认读取地址1:rs
      rt_addr <= inst[20:16];  //默认读取地址2:rt
      valid   <= `InstInvalid;  //译码完成前指令无效

      case (op)
        `EXE_SPECIAL_INST: begin  //special类指令
          case (op2)
            5'b00000: begin
              case (op3)
                `EXE_OR: begin
                  we      <= `writeEnable;  //需要写
                  aluop   <= `EXE_OR_OP;  //子运算：或
                  alusel  <= `EXE_RES_LOGIC;  //逻辑运算
                  rs_read <= 1'b1;  //需读rs
                  rt_read <= 1'b1;  //需读rt
                  valid = `InstValid;  //指令有效
                end
                `EXE_AND: begin
                  we      <= `writeEnable;
                  aluop   <= `EXE_AND_OP;
                  alusel  <= `EXE_RES_LOGIC;
                  rs_read <= 1'b1;
                  rt_read <= 1'b1;
                  valid = `InstValid;
                end
                `EXE_XOR: begin
                  we      <= `writeEnable;
                  aluop   <= `EXE_XOR_OP;
                  alusel  <= `EXE_RES_LOGIC;
                  rs_read <= 1'b1;
                  rt_read <= 1'b1;
                  valid = `InstValid;
                end
                `EXE_NOR: begin
                  we      <= `writeEnable;
                  aluop   <= `EXE_NOR_OP;
                  alusel  <= `EXE_RES_LOGIC;
                  rs_read <= 1'b1;
                  rt_read <= 1'b1;
                  valid = `InstValid;
                end
                `EXE_SLLV: begin
                  we      <= `writeEnable;
                  aluop   <= `EXE_SLL_OP;  //子运算：左移
                  alusel  <= `EXE_RES_SHIFT;  //移位运算
                  rs_read <= 1'b1;
                  rt_read <= 1'b1;
                  valid = `InstValid;
                end
                `EXE_SRLV: begin
                  we      <= `writeEnable;
                  aluop   <= `EXE_SRL_OP;
                  alusel  <= `EXE_RES_SHIFT;
                  rs_read <= 1'b1;
                  rt_read <= 1'b1;
                  valid = `InstValid;
                end
                `EXE_SRAV: begin
                  we      <= `writeEnable;
                  aluop   <= `EXE_SRA_OP;
                  alusel  <= `EXE_RES_SHIFT;
                  rs_read <= 1'b1;
                  rt_read <= 1'b1;
                  valid = `InstValid;
                end
                `EXE_SYNC: begin
                  we      <= `writeEnable;
                  aluop   <= `EXE_NOP_OP;
                  alusel  <= `EXE_RES_NOP;
                  rs_read <= 1'b0;
                  rt_read <= 1'b1;
                  valid = `InstValid;
                end
                `EXE_MFHI: begin
                  we      <= `writeEnable;
                  aluop   <= `EXE_MFHI_OP;
                  alusel  <= `EXE_RES_MOVE;  //移动指令
                  rs_read <= 1'b0;
                  rt_read <= 1'b0;
                  valid = `InstValid;
                end
                `EXE_MFLO: begin
                  we      <= `writeEnable;
                  aluop   <= `EXE_MFLO_OP;
                  alusel  <= `EXE_RES_MOVE;
                  rs_read <= 1'b0;
                  rt_read <= 1'b0;
                  valid = `InstValid;
                end
                `EXE_MTHI: begin
                  aluop   <= `EXE_MTHI_OP;
                  rs_read <= 1'b1;
                  rt_read <= 1'b0;
                  valid = `InstValid;
                end
                `EXE_MTLO: begin
                  aluop   <= `EXE_MTLO_OP;
                  rs_read <= 1'b1;
                  rt_read <= 1'b0;
                  valid = `InstValid;
                end
                `EXE_MOVN: begin
                  aluop   <= `EXE_MOVN_OP;
                  alusel  <= `EXE_RES_MOVE;
                  rs_read <= 1'b1;
                  rt_read <= 1'b1;
                  valid = `InstValid;
                  if (reg2 != `zeroword) begin  //reg2应该就是读到rt的值
                    we <= `writeEnable;
                  end else begin
                    we <= `writeDisable;
                  end
                end
                `EXE_MOVZ: begin
                  aluop   <= `EXE_MOVZ_OP;
                  alusel  <= `EXE_RES_MOVE;
                  rs_read <= 1'b1;
                  rt_read <= 1'b1;
                  valid = `InstValid;
                  if (reg2 == `zeroword) begin
                    we <= `writeEnable;
                  end else begin
                    we <= `writeDisable;
                  end
                end
                `EXE_SLT: begin
                  we      <= `writeEnable;
                  aluop   <= `EXE_SLT_OP;
                  alusel  <= `EXE_RES_ARITHMETIC;  //算术指令
                  rs_read <= 1'b1;
                  rt_read <= 1'b1;
                  valid = `InstValid;
                end
                `EXE_SLTU: begin
                  we      <= `writeEnable;
                  aluop   <= `EXE_SLTU_OP;
                  alusel  <= `EXE_RES_ARITHMETIC;
                  rs_read <= 1'b1;
                  rt_read <= 1'b1;
                  valid = `InstValid;
                end
                `EXE_ADD: begin
                  we      <= `writeEnable;
                  aluop   <= `EXE_ADD_OP;
                  alusel  <= `EXE_RES_ARITHMETIC;
                  rs_read <= 1'b1;
                  rt_read <= 1'b1;
                  valid = `InstValid;
                end
                `EXE_ADDU: begin
                  we      <= `writeEnable;
                  aluop   <= `EXE_ADDU_OP;
                  alusel  <= `EXE_RES_ARITHMETIC;
                  rs_read <= 1'b1;
                  rt_read <= 1'b1;
                  valid = `InstValid;
                end
                `EXE_SUB: begin
                  we      <= `writeEnable;
                  aluop   <= `EXE_SUB_OP;
                  alusel  <= `EXE_RES_ARITHMETIC;
                  rs_read <= 1'b1;
                  rt_read <= 1'b1;
                  valid = `InstValid;
                end
                `EXE_SUBU: begin
                  we      <= `writeEnable;
                  aluop   <= `EXE_SUBU_OP;
                  alusel  <= `EXE_RES_ARITHMETIC;
                  rs_read <= 1'b1;
                  rt_read <= 1'b1;
                  valid = `InstValid;
                end
                `EXE_MULT: begin
                  we      <= `writeEnable;
                  aluop   <= `EXE_MULT_OP;
                  alusel  <= `EXE_RES_ARITHMETIC;
                  rs_read <= 1'b1;
                  rt_read <= 1'b1;
                  valid = `InstValid;
                end
                `EXE_MULTU: begin
                  we      <= `writeEnable;
                  aluop   <= `EXE_MULTU_OP;
                  alusel  <= `EXE_RES_ARITHMETIC;
                  rs_read <= 1'b1;
                  rt_read <= 1'b1;
                  valid = `InstValid;
                end
                `EXE_DIV: begin
                  aluop   <= `EXE_DIV_OP;
                  rs_read <= 1'b1;
                  rt_read <= 1'b1;
                  valid = `InstValid;
                end
                `EXE_DIVU: begin
                  aluop   <= `EXE_DIVU_OP;
                  rs_read <= 1'b1;
                  rt_read <= 1'b1;
                  valid = `InstValid;
                end
                `EXE_JR: begin
                  we           <= `writeDisable;
                  aluop        <= `EXE_JR_OP;
                  alusel       <= `EXE_RES_JUMP_BRANCH;  //转移指令
                  rs_read      <= 1'b1;
                  rt_read      <= 1'b0;
                  link_addr    <= `zeroword;
                  b_addr       <= reg1;
                  branch       <= `Branch;
                  next_delay_o <= `InDelaySlot;
                  valid = `InstValid;
                end
                `EXE_JALR: begin
                  we           <= `writeEnable;
                  aluop        <= `EXE_JALR_OP;
                  alusel       <= `EXE_RES_JUMP_BRANCH;
                  rs_read      <= 1'b1;
                  rt_read      <= 1'b0;
                  link_addr    <= pc_plus_8;
                  b_addr       <= reg1;
                  branch       <= `Branch;
                  next_delay_o <= `InDelaySlot;
                  valid = `InstValid;
                end
                default: begin

                end
              endcase  //case op3
            end
            default: begin

            end
          endcase  //case op2
        end

        `EXE_SPECIAL2_INST: begin  //special2类指令
          case (op3)
            `EXE_CLZ: begin
              we      <= `writeEnable;
              aluop   <= `EXE_CLZ_OP;
              alusel  <= `EXE_RES_ARITHMETIC;
              rs_read <= 1'b1;
              rt_read <= 1'b0;
              valid = `InstValid;
            end
            `EXE_CLO: begin
              we      <= `writeEnable;
              aluop   <= `EXE_CLO_OP;
              alusel  <= `EXE_RES_ARITHMETIC;
              rs_read <= 1'b1;
              rt_read <= 1'b0;
              valid = `InstValid;
            end
            `EXE_MUL: begin
              we      <= `writeEnable;
              aluop   <= `EXE_MUL_OP;
              alusel  <= `EXE_RES_ARITHMETIC;
              rs_read <= 1'b1;
              rt_read <= 1'b1;
              valid = `InstValid;
            end
            `EXE_MADD: begin
              aluop   <= `EXE_MADD_OP;
              rs_read <= 1'b1;
              rt_read <= 1'b1;
              valid = `InstValid;
            end
            `EXE_MADDU: begin
              aluop   <= `EXE_MADDU_OP;
              rs_read <= 1'b1;
              rt_read <= 1'b1;
              valid = `InstValid;
            end
            `EXE_MSUB: begin
              aluop   <= `EXE_MSUB_OP;
              rs_read <= 1'b1;
              rt_read <= 1'b1;
              valid = `InstValid;
            end
            `EXE_MSUBU: begin
              aluop   <= `EXE_MSUBU_OP;
              rs_read <= 1'b1;
              rt_read <= 1'b1;
              valid = `InstValid;
            end
            default begin

            end
          endcase  //case op3
        end

        `EXE_REGIMM_INST: begin
          case (op4)
            `EXE_BGEZ: begin
              we      <= `writeDisable;
              aluop   <= `EXE_BGEZ_OP;
              alusel  <= `EXE_RES_JUMP_BRANCH;
              rs_read <= 1'b1;
              rt_read <= 1'b0;
              if (!reg1[31]) begin
                branch       <= `Branch;
                next_delay_o <= `InDelaySlot;
                b_addr       <= pc_plus_4 + imm_sll2_signednext;
              end
              valid = `InstValid;
            end
            `EXE_BGEZAL: begin
              we        <= `writeEnable;
              aluop     <= `EXE_BGEZAL_OP;
              alusel    <= `EXE_RES_JUMP_BRANCH;
              rs_read   <= 1'b1;
              rt_read   <= 1'b0;
              link_addr <= pc_plus_8;
              w_addr    <= 5'b11111;
              if (!reg1[31]) begin
                branch       <= `Branch;
                next_delay_o <= `InDelaySlot;
                b_addr       <= pc_plus_4 + imm_sll2_signednext;
              end
              valid = `InstValid;
            end
            `EXE_BLTZ: begin
              we      <= `writeDisable;
              aluop   <= `EXE_BLTZ_OP;
              alusel  <= `EXE_RES_JUMP_BRANCH;
              rs_read <= 1'b1;
              rt_read <= 1'b0;
              if (reg1[31]) begin
                branch       <= `Branch;
                next_delay_o <= `InDelaySlot;
                b_addr       <= pc_plus_4 + imm_sll2_signednext;
              end
              valid = `InstValid;
            end
            `EXE_BLTZAL: begin
              we        <= `writeEnable;
              aluop     <= `EXE_BLTZAL_OP;
              alusel    <= `EXE_RES_JUMP_BRANCH;
              rs_read   <= 1'b1;
              rt_read   <= 1'b0;
              link_addr <= pc_plus_8;
              w_addr    <= 5'b11111;
              if (reg1[31]) begin
                branch       <= `Branch;
                next_delay_o <= `InDelaySlot;
                b_addr       <= pc_plus_4 + imm_sll2_signednext;
              end
              valid = `InstValid;
            end
            default: begin

            end
          endcase
        end
        `EXE_J: begin
          we           <= `writeDisable;
          aluop        <= `EXE_J_OP;
          alusel       <= `EXE_RES_JUMP_BRANCH;
          rs_read      <= 1'b0;
          rt_read      <= 1'b0;
          link_addr    <= `zeroword;
          branch       <= `Branch;
          next_delay_o <= `InDelaySlot;
          b_addr       <= {pc_plus_4[31:28], inst[25:0], 2'b00};
          valid = `InstValid;
        end
        `EXE_JAL: begin
          we           <= `writeEnable;
          aluop        <= `EXE_JAL_OP;
          alusel       <= `EXE_RES_JUMP_BRANCH;
          rs_read      <= 1'b0;
          rt_read      <= 1'b0;
          w_addr       <= 5'b11111;
          link_addr    <= pc_plus_8;
          branch       <= `Branch;
          next_delay_o <= `InDelaySlot;
          b_addr       <= {pc_plus_4[31:28], inst[25:0], 2'b00};
          valid = `InstValid;
        end
        `EXE_BEQ: begin
          we      <= `writeDisable;
          aluop   <= `EXE_BEQ_OP;
          alusel  <= `EXE_RES_JUMP_BRANCH;
          rs_read <= 1'b1;
          rt_read <= 1'b1;
          if (reg1 == reg2) begin
            branch       <= `Branch;
            next_delay_o <= `InDelaySlot;
            b_addr       <= pc_plus_4 + imm_sll2_signednext;
          end
          valid = `InstValid;
        end
        `EXE_BNE: begin
          we      <= `writeDisable;
          aluop   <= `EXE_BNE_OP;
          alusel  <= `EXE_RES_JUMP_BRANCH;
          rs_read <= 1'b1;
          rt_read <= 1'b1;
          if (reg1 != reg2) begin
            branch       <= `Branch;
            next_delay_o <= `InDelaySlot;
            b_addr       <= pc_plus_4 + imm_sll2_signednext;
          end
          valid = `InstValid;
        end
        `EXE_BGTZ: begin
          we      <= `writeDisable;
          aluop   <= `EXE_BGTZ_OP;
          alusel  <= `EXE_RES_JUMP_BRANCH;
          rs_read <= 1'b1;
          rt_read <= 1'b0;
          if (!reg1[31] && (reg1 != `zeroword)) begin
            branch       <= `Branch;
            next_delay_o <= `InDelaySlot;
            b_addr       <= pc_plus_4 + imm_sll2_signednext;
          end
          valid = `InstValid;
        end
        `EXE_BLEZ: begin
          we      <= `writeDisable;
          aluop   <= `EXE_BLEZ_OP;
          alusel  <= `EXE_RES_JUMP_BRANCH;
          rs_read <= 1'b1;
          rt_read <= 1'b0;
          if (reg1[31] || reg1 == `zeroword) begin
            branch       <= `Branch;
            next_delay_o <= `InDelaySlot;
            b_addr       <= pc_plus_4 + imm_sll2_signednext;
          end
          valid = `InstValid;
        end
        `EXE_LB: begin
          we      <= `writeEnable;
          aluop   <= `EXE_LB_OP;
          alusel  <= `EXE_RES_LOAD_STORE;
          rs_read <= 1'b1;
          rt_read <= 1'b0;
          w_addr  <= inst[20:16];
          valid   <= `InstValid;
        end
        `EXE_LBU: begin
          we      <= `writeEnable;
          aluop   <= `EXE_LBU_OP;
          alusel  <= `EXE_RES_LOAD_STORE;
          rs_read <= 1'b1;
          rt_read <= 1'b0;
          w_addr  <= inst[20:16];
          valid   <= `InstValid;
        end
        `EXE_LH: begin
          we      <= `writeEnable;
          aluop   <= `EXE_LH_OP;
          alusel  <= `EXE_RES_LOAD_STORE;
          rs_read <= 1'b1;
          rt_read <= 1'b0;
          w_addr  <= inst[20:16];
          valid   <= `InstValid;
        end
        `EXE_LHU: begin
          we      <= `writeEnable;
          aluop   <= `EXE_LHU_OP;
          alusel  <= `EXE_RES_LOAD_STORE;
          rs_read <= 1'b1;
          rt_read <= 1'b0;
          w_addr  <= inst[20:16];
          valid   <= `InstValid;
        end
        `EXE_LW: begin
          we      <= `writeEnable;
          aluop   <= `EXE_LW_OP;
          alusel  <= `EXE_RES_LOAD_STORE;
          rs_read <= 1'b1;
          rt_read <= 1'b0;
          w_addr  <= inst[20:16];
          valid   <= `InstValid;
        end
        `EXE_LL: begin
          we      <= `writeEnable;
          aluop   <= `EXE_LL_OP;
          alusel  <= `EXE_RES_LOAD_STORE;
          rs_read <= 1'b1;
          rt_read <= 1'b0;
          w_addr  <= inst[20:16];
          valid   <= `InstValid;
        end
        `EXE_LWL: begin
          we      <= `writeEnable;
          aluop   <= `EXE_LWL_OP;
          alusel  <= `EXE_RES_LOAD_STORE;
          rs_read <= 1'b1;
          rt_read <= 1'b1;
          w_addr  <= inst[20:16];
          valid   <= `InstValid;
        end
        `EXE_LWR: begin
          we      <= `writeEnable;
          aluop   <= `EXE_LWR_OP;
          alusel  <= `EXE_RES_LOAD_STORE;
          rs_read <= 1'b1;
          rt_read <= 1'b1;
          w_addr  <= inst[20:16];
          valid   <= `InstValid;
        end
        `EXE_SB: begin
          we      <= `writeDisable;
          aluop   <= `EXE_SB_OP;
          rs_read <= 1'b1;
          rt_read <= 1'b1;
          valid   <= `InstValid;
          alusel  <= `EXE_RES_LOAD_STORE;
        end
        `EXE_SH: begin
          we      <= `writeDisable;
          aluop   <= `EXE_SH_OP;
          rs_read <= 1'b1;
          rt_read <= 1'b1;
          valid   <= `InstValid;
          alusel  <= `EXE_RES_LOAD_STORE;
        end
        `EXE_SW: begin
          we      <= `writeDisable;
          aluop   <= `EXE_SW_OP;
          rs_read <= 1'b1;
          rt_read <= 1'b1;
          valid   <= `InstValid;
          alusel  <= `EXE_RES_LOAD_STORE;
        end
        `EXE_SWL: begin
          we      <= `writeDisable;
          aluop   <= `EXE_SWL_OP;
          rs_read <= 1'b1;
          rt_read <= 1'b1;
          valid   <= `InstValid;
          alusel  <= `EXE_RES_LOAD_STORE;
        end
        `EXE_SWR: begin
          we      <= `writeDisable;
          aluop   <= `EXE_SWR_OP;
          rs_read <= 1'b1;
          rt_read <= 1'b1;
          valid   <= `InstValid;
          alusel  <= `EXE_RES_LOAD_STORE;
        end
        `EXE_SC: begin
          we      <= `writeEnable;
          aluop   <= `EXE_SC_OP;
          alusel  <= `EXE_RES_LOAD_STORE;
          rs_read <= 1'b1;
          rt_read <= 1'b1;
          w_addr  <= inst[20:16];
          valid   <= `InstValid;
          alusel  <= `EXE_RES_LOAD_STORE;
        end
        `EXE_ORI: begin  //与立即数的或运算
          we      <= `writeEnable;  //需要写
          aluop   <= `EXE_OR_OP;  //子运算：或
          alusel  <= `EXE_RES_LOGIC;  //逻辑运算
          rs_read <= 1'b1;  //需读rs
          rt_read <= 1'b0;  //不用读rt
          imm     <= {16'h0, inst[15:0]};  //无符号扩展立即数
          w_addr  <= inst[20:16];  //结果写进rt
          valid = `InstValid;  //指令有效
        end
        `EXE_ANDI: begin
          we      <= `writeEnable;
          aluop   <= `EXE_AND_OP;
          alusel  <= `EXE_RES_LOGIC;
          rs_read <= 1'b1;
          rt_read <= 1'b0;
          imm     <= {16'h0, inst[15:0]};
          w_addr  <= inst[20:16];
          valid = `InstValid;
        end
        `EXE_XORI: begin
          we      <= `writeEnable;
          aluop   <= `EXE_XOR_OP;
          alusel  <= `EXE_RES_LOGIC;
          rs_read <= 1'b1;
          rt_read <= 1'b0;
          imm     <= {16'h0, inst[15:0]};
          w_addr  <= inst[20:16];
          valid = `InstValid;
        end
        `EXE_LUI: begin
          we      <= `writeEnable;
          aluop   <= `EXE_OR_OP;
          alusel  <= `EXE_RES_LOGIC;
          rs_read <= 1'b1;
          rt_read <= 1'b0;
          imm     <= {inst[15:0], 16'h0};  //立即数（左移16位）
          w_addr  <= inst[20:16];
          valid = `InstValid;
        end
        `EXE_PREF: begin
          we      <= `writeDisable;
          aluop   <= `EXE_NOP_OP;
          alusel  <= `EXE_RES_NOP;
          rs_read <= 1'b0;
          rt_read <= 1'b0;
          valid = `InstValid;
        end
        `EXE_SLTI: begin
          we      <= `writeEnable;
          aluop   <= `EXE_SLT_OP;
          alusel  <= `EXE_RES_LOGIC;
          rs_read <= 1'b1;
          rt_read <= 1'b0;
          imm     <= {{16{inst[15]}}, inst[15:0]};  //有符号扩展立即数
          w_addr  <= inst[20:16];
          valid = `InstValid;
        end
        `EXE_SLTIU: begin
          we      <= `writeEnable;
          aluop   <= `EXE_SLTU_OP;
          alusel  <= `EXE_RES_LOGIC;
          rs_read <= 1'b1;
          rt_read <= 1'b0;
          imm     <= {{16{inst[15]}}, inst[15:0]};
          w_addr  <= inst[20:16];
          valid = `InstValid;
        end
        `EXE_ADDI: begin
          we      <= `writeEnable;
          aluop   <= `EXE_ADDI_OP;
          alusel  <= `EXE_RES_LOGIC;
          rs_read <= 1'b1;
          rt_read <= 1'b0;
          imm     <= {{16{inst[15]}}, inst[15:0]};
          w_addr  <= inst[20:16];
          valid = `InstValid;
        end
        `EXE_ADDIU: begin
          we      <= `writeEnable;
          aluop   <= `EXE_ADDIU_OP;
          alusel  <= `EXE_RES_LOGIC;
          rs_read <= 1'b1;
          rt_read <= 1'b0;
          imm     <= {{16{inst[15]}}, inst[15:0]};
          w_addr  <= inst[20:16];
          valid = `InstValid;
        end
        default begin

        end
      endcase  //case op

      if (inst[31:21] == 11'b00000000000) begin  //立即数移位指令
        if (op3 == `EXE_SLL) begin
          we       <= `writeEnable;
          aluop    <= `EXE_SLL_OP;  //逻辑左移
          alusel   <= `EXE_RES_SHIFT;  //移位运算
          rs_read  <= 1'b0;  //与rs无关
          rt_read  <= 1'b1;
          imm[4:0] <= inst[10:6];  //立即数sa
          valid = `InstValid;
        end else if (op3 == `EXE_SRL) begin
          we       <= `writeEnable;
          aluop    <= `EXE_SRL_OP;  //逻辑右移
          alusel   <= `EXE_RES_SHIFT;
          rs_read  <= 1'b0;
          rt_read  <= 1'b1;
          imm[4:0] <= inst[10:6];
          valid = `InstValid;
        end else if (op3 == `EXE_SRA) begin
          we       <= `writeEnable;
          aluop    <= `EXE_SRA_OP;  //算术右移
          alusel   <= `EXE_RES_SHIFT;
          rs_read  <= 1'b0;
          rt_read  <= 1'b1;
          imm[4:0] <= inst[10:6];
          valid = `InstValid;
        end
      end

      if (inst[31:21] == 11'b01000000000 && inst[10:0] == 11'b00000000000) begin  //cp0访问指令
        aluop   <= `EXE_MFC0_OP;//读取cp0写入rt
        alusel  <= `EXE_RES_MOVE;
        w_addr  <= inst[20:16];
        we      <= `writeEnable;
        valid   <= `InstValid;
        rs_read <= 1'b0;
        rt_read <= 1'b0;
      end else if (inst[31:21] == 11'b01000000100 && inst[10:0] == 11'b00000000000) begin
        aluop   <= `EXE_MTC0_OP;//读rt输入cp0
        alusel  <= `EXE_RES_NOP;
        we      <= `writeDisable;
        valid   <= `InstValid;
        rs_read <= 1'b1;
        rs_addr <= inst[20:16];
        rt_read <= 1'b0;
      end
    end  //if
  end  //always

  //确定源操作数1
  always @(*) begin
    stallreq_for_reg1_loadrelate <= `NoStop;
    if (rst) begin
      reg1 <= `zeroword;
    end else if (pre_inst_is_load && ex_w_addr == rs_addr && rs_read) begin
      stallreq_for_reg1_loadrelate <= `Stop;
    end else if (rs_read && ex_we && (ex_w_addr == rs_addr)) begin
      reg1 <= ex_w_data;  //若读取的寄存器就是上一条指令在EX要写的寄存器，就直接把EX的结果赋给reg1
    end else if (rs_read && mem_we && (mem_w_addr == rs_addr)) begin
      reg1 <= mem_w_data;  //若读取的寄存器就是上上条指令在MEM要写的寄存器，就直接把MEM的结果赋给reg1
    end else if (rs_read) begin
      reg1 <= rs_data;  //若读了rs，读出来的就是源操作数1
    end else if (!rs_read) begin
      reg1 <= imm;  //否则源操作数1是立即数
    end else begin
      reg1 <= `zeroword;
    end
  end

  //确定源操作数2
  always @(*) begin
    if (rst) begin
      reg2 <= `zeroword;
    end else if (pre_inst_is_load && ex_w_addr == rt_addr && rt_read) begin
      stallreq_for_reg2_loadrelate <= `Stop;
    end else if (rt_read && ex_we && (ex_w_addr == rt_addr)) begin
      reg2 <= ex_w_data;  //若读取的寄存器就是上一条指令在EX要写的寄存器，就直接把EX的结果赋给reg2
    end else if (rt_read && mem_we && (mem_w_addr == rt_addr)) begin
      reg2 <= mem_w_data;  //若读取的寄存器就是上上条指令在MEM要写的寄存器，就直接把MEM的结果赋给reg2
    end else if (rt_read) begin
      reg2 <= rt_data;  //若读了rt，读出来的就是源操作数2
    end else if (!rt_read) begin
      reg2 <= imm;  //否则源操作数2是立即数
    end else begin
      reg2 <= `zeroword;
    end
  end

  assign stallreq = stallreq_for_reg1_loadrelate | stallreq_for_reg2_loadrelate;

  always @(*) begin
    if (rst) begin
      delay_o <= `NotInDelaySlot;
    end else begin
      delay_o <= delay_i;
    end
  end

  //我总感觉valid这变量没卵用，只起到了挤占内存、增加代码量的作用。
  //我打算在所有的指令都加上后，如果这个还是没有表现出作用来，就尝试把它删了。
  //希望我到时候记得这件事吧。如果这三行注释没删掉，那我应该就是忘了
endmodule
