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

    //EX段的执行结果
    output reg we_o,//执行指令最终是否要写
    output reg [`RegAddrBus]    w_addr_o,//执行指令最终要写入的寄存器地址
    output reg [`RegBus]    w_data_o//执行指令最终要写的值
);

    reg [`RegBus] logicout; //逻辑运算结果
    reg [`RegBus] shiftout; //移位运算结果

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
          default :begin
            w_data_o<=`zeroword;
          end
        endcase
    end

endmodule