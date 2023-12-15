`include "defines.v"
module EX(
    input  wire rst,

    //id_ex段送来的信息
    input  wire [`AluOpBus] aluop,
    input  wire [`AluOpBus] alusel,
    input  wire [`RegBus]   reg1,
    input  wire [`RegBus]   reg2,
    input  wire [`RegAddrBus]   w_addr_i,
    input  wire we_i,

    //EX段的执行结果
    output reg we_o,//执行指令最终是否要写
    output reg [`RegAddrBus]    w_addr_o,//执行指令最终要写入的寄存器地址
    output reg [`RegBus]    w_data_o//执行指令最终要写的值
);

    reg [`RegBus] logicout;

    //依据aluop进行子运算
    always @(*) begin
        if(rst)begin
          logicout<=`zeroword;
        end else begin
          case(aluop)
            `EXE_OR_OP:begin//或
              logicout<=reg1|reg2;
            end
            default:begin
              logicout<=`zeroword;
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
          default :begin
            w_data_o<=`zeroword;
          end
        endcase
    end

endmodule