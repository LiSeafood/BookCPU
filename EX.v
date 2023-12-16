`include "defines.v"
module EX(
    input  wire rst,

    //id_ex段送来的信息
    input  wire [`AluOpBus] aluop,
    input  wire [`AluSelBus] alusel,
    input  wire [`RegBus]   reg1,
    input  wire [`RegBus]   reg2,
    input  wire [`RegAddrBus]   w_addr_i,
    input  wire we_i,

    //HILO模块传来的HI、LO寄存器的值
    input  wire [`RegBus] hi_i,
    input  wire [`RegBus] lo_i,

    //WB段关于HI、LO寄存器的数据相关问题
    input  wire           wb_hilo_i,//WB阶段的指令是否要写HI、LO寄存器
    input  wire [`RegBus] wb_hi_i,//要写进HI的值
    input  wire [`RegBus] wb_lo_i,//要写进LO的值

    //MEM段关于HI、LO寄存器的数据相关问题
    input  wire           mem_hilo_i,//MEM阶段的指令是否要写HI、LO寄存器
    input  wire [`RegBus] mem_hi_i,//要写进HI的值
    input  wire [`RegBus] mem_lo_i,//要写进LO的值

    //EX段的指令对HI、LO寄存器的写操作请求
    output reg            hilo_o,
    output reg [`RegBus]  hi_o,
    output reg [`RegBus]  lo_o,

    //EX段的执行结果
    output reg we_o,//执行指令最终是否要写
    output reg [`RegAddrBus]    w_addr_o,//执行指令最终要写入的寄存器地址
    output reg [`RegBus]    w_data_o//执行指令最终要写的值
);

    reg [`RegBus] logicout; //逻辑运算结果
    reg [`RegBus] shiftout; //移位运算结果
    reg [`RegBus] moveout;  //移动运算结果
    reg [`RegBus] HI;       //保存HI的最新值
    reg [`RegBus] LO;       //保持LO的最新值

    //处理HILO的值及数据相关问题
    always @(*) begin
      if(rst)begin
        {HI,LO}<={`zeroword,`zeroword};
      end else if(mem_hilo_i)begin
        {HI,LO}<={mem_hi_i,mem_lo_i};//MEM段的指令要写HI、LO寄存器
      end else if(wb_hilo_i)begin
        {HI,LO}<={wb_hi_i,wb_lo_i};//WB段的指令要写HI、LO寄存器
      end else begin
        {HI,LO}<={hi_i,lo_i};
      end
    end

    //逻辑运算
    always @(*) begin
        if(rst)begin
          logicout<=`zeroword;
        end else begin
          case(aluop)
            `EXE_OR_OP:begin//或
              logicout<=reg1|reg2;
            end
            `EXE_AND_OP:begin//与
              logicout<=reg1&reg2;
            end
            `EXE_NOR_OP:begin//或非
              logicout<=~(reg1|reg2);
            end
            `EXE_XOR_OP:begin//异或
              logicout<=reg1^reg2;
            end
            default:begin
              logicout<=`zeroword;
            end
          endcase
        end //if
    end //always

    //移位运算
    always @(*) begin
      if(rst)begin
        shiftout<=`zeroword;
      end else begin
        case (aluop)
          `EXE_SLL_OP:begin//逻辑左移
            shiftout<= reg2<<reg1[4:0];
          end
          `EXE_SRL_OP:begin//逻辑右移
            shiftout<= reg2>>reg1[4:0];
          end
          `EXE_SRA_OP:begin//算术右移
            shiftout<=({32{reg2[31]}}<<(6'd32-{1'b0,reg1[4:0]}))|reg2>>reg1[4:0];
          end
        endcase
        end //if
    end //always

    //移动运算
    always @(*) begin
      if(rst)begin
        moveout <= `zeroword;
      end else begin
        case (aluop)
          `EXE_MFHI_OP:begin
            moveout<=HI;
          end
          `EXE_MFLO_OP:begin
            moveout<=LO;
          end
          `EXE_MOVZ_OP:begin
            moveout<=reg1;
          end
          `EXE_MOVN_OP:begin
            moveout<=reg1;
          end
          default :begin
            
          end
        endcase
      end
    end

    //依据alusel选择运算结果
    always @(*) begin
        w_addr_o<=w_addr_i;
        we_o<=we_i;
        case(alusel)
          `EXE_RES_LOGIC:begin
            w_data_o<=logicout;
          end
          `EXE_RES_SHIFT:begin
            w_data_o<=shiftout;
          end
          `EXE_RES_MOVE:begin
            w_data_o<=moveout;
          end
          default :begin
            w_data_o<=`zeroword;
          end
        endcase
    end

    //MTHI、MTLO指令对HI、LO寄存器的写操作
    always @(*) begin
      if(rst)begin
        hilo_o<=`writeDisable;
        hi_o<=`zeroword;
        lo_o<=`zeroword;
      end else if(aluop==`EXE_MTHI_OP)begin
        hilo_o<=`writeEnable;
        hi_o<=reg1;//写HI寄存器
        lo_o<=LO;//LO寄存器保持不变
      end else if(aluop==`EXE_MTLO_OP)begin
        hilo_o<=`writeEnable;
        hi_o<=HI;//HI寄存器保持不变
        lo_o<=reg1;//写LO寄存器
      end else begin
        hilo_o<=`writeDisable;
        hi_o<=`zeroword;
        lo_o<=`zeroword;
      end
    end

endmodule