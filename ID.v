`include "defines.v"
module ID(
    input  wire                 rst,
    input  wire [`InstAddrBus]  pc,
    input  wire [`InstBus]      inst,

    //读取的regfile的值
    input  wire [`RegBus]       rs_data,
    input  wire [`RegBus]       rt_data,

    //来自EX段的运算结果定向
    input  wire                 ex_we,
    input  wire [`RegBus]       ex_w_data,
    input  wire [`RegAddrBus]   ex_w_addr,

    //来自MEM段的操作结果定向
    input  wire                 mem_we,
    input  wire [`RegBus]       mem_w_data,
    input  wire [`RegAddrBus]   mem_w_addr,

    //输出到regfile的值
    output reg                  rs_read,
    output reg                  rt_read,
    output reg [`RegAddrBus]    rs_addr,
    output reg [`RegAddrBus]    rt_addr,

    //送到EX的信息
    output reg [`AluOpBus]      aluop,  //要进行的运算子类型
    output reg [`AluSelBus]     alusel, //要进行的运算类型
    output reg [`RegBus]        reg1,   //操作数1
    output reg [`RegBus]        reg2,   //操作数2
    output reg [`RegAddrBus]    w_addr, //ID的指令要写入的目的寄存器地址
    output reg                  we      //ID的指令是否要写入目的寄存器
);

    //取得指令的指令码和功能码，用于判断是什么指令
    wire [5:0] op = inst[31:26];    //指令码
    wire [4:0] op2= inst[10:6];
    wire [5:0] op3= inst[5:0];      //功能码
    wire [4:0] op4= inst[20:16];

    reg[`RegBus] imm;//立即数
    reg valid;//指令是否有效（这变量感觉没有用啊喂）

    //译码
    always @(*) begin//先赋初值，都赋为0
      aluop   <= `EXE_NOP_OP;
      alusel  <= `EXE_RES_NOP;//说真的我觉得这个也没用
      we      <= `writeDisable;
      rs_read <= 1'b0;
      rt_read <= 1'b0;
      imm<=`zeroword;
      if(rst)begin//复位的话这些都是0
        w_addr  <= `NOPRegAddr;
        rs_addr <= `NOPRegAddr;
        rt_addr <= `NOPRegAddr;
        valid   <= `InstValid;
      end else begin
        w_addr <= inst[15:11];    //默认写入地址:rd
        rs_addr <= inst[25:21];   //默认读取地址1:rs
        rt_addr <= inst[20:16];   //默认读取地址2:rt
        valid <= `InstInvalid;    //译码完成前指令无效

        case(op)
          `EXE_SPECIAL_INST:begin//special类指令
            case(op2)
              5'b00000:begin
                case (op3)
                  `EXE_OR:begin
                    we<=`writeEnable;//需要写
                    aluop<=`EXE_OR_OP;//子运算：或
                    alusel<=`EXE_RES_LOGIC;//逻辑运算
                    rs_read<=1'b1;//需读rs
                    rt_read<=1'b1;//需读rt
                    valid=`InstValid;//指令有效
                  end 
                  `EXE_AND:begin
                    we<=`writeEnable;
                    aluop<=`EXE_AND_OP;
                    alusel<=`EXE_RES_LOGIC;
                    rs_read<=1'b1;
                    rt_read<=1'b1;
                    valid=`InstValid;
                  end
                  `EXE_XOR:begin
                    we<=`writeEnable;
                    aluop<=`EXE_XOR_OP;
                    alusel<=`EXE_RES_LOGIC;
                    rs_read<=1'b1;
                    rt_read<=1'b1;
                    valid=`InstValid;
                  end
                  `EXE_NOR:begin
                    we<=`writeEnable;
                    aluop<=`EXE_NOR_OP;
                    alusel<=`EXE_RES_LOGIC;
                    rs_read<=1'b1;
                    rt_read<=1'b1;
                    valid=`InstValid;
                  end
                  `EXE_SLLV:begin
                    we<=`writeEnable;
                    aluop<=`EXE_SLL_OP;//子运算：左移
                    alusel<=`EXE_RES_SHIFT;//移位运算
                    rs_read<=1'b1;
                    rt_read<=1'b1;
                    valid=`InstValid;
                  end
                  `EXE_SRLV:begin
                    we<=`writeEnable;
                    aluop<=`EXE_SRL_OP;
                    alusel<=`EXE_RES_SHIFT;
                    rs_read<=1'b1;
                    rt_read<=1'b1;
                    valid=`InstValid;
                  end
                  `EXE_SRAV:begin
                    we<=`writeEnable;
                    aluop<=`EXE_SRA_OP;
                    alusel<=`EXE_RES_SHIFT;
                    rs_read<=1'b1;
                    rt_read<=1'b1;
                    valid=`InstValid;
                  end
                  `EXE_SYNC:begin
                    we<=`writeEnable;
                    aluop<=`EXE_NOP_OP;
                    alusel<=`EXE_RES_NOP;
                    rs_read<=1'b0;
                    rt_read<=1'b1;
                    valid=`InstValid;
                  end
                  `EXE_MFHI:begin
                    we<=`writeEnable;
                    aluop<=`EXE_MFHI_OP;
                    alusel<=`EXE_RES_MOVE;//移动指令
                    rs_read<=1'b0;
                    rt_read<=1'b0;
                    valid=`InstValid;
                  end
                  `EXE_MFLO:begin
                    we<=`writeEnable;
                    aluop<=`EXE_MFLO_OP;
                    alusel<=`EXE_RES_MOVE;
                    rs_read<=1'b0;
                    rt_read<=1'b0;
                    valid=`InstValid;
                  end
                  `EXE_MTHI:begin
                    aluop<=`EXE_MTHI_OP;
                    rs_read<=1'b1;
                    rt_read<=1'b0;
                    valid=`InstValid;
                  end
                  `EXE_MTLO:begin
                    aluop<=`EXE_MTLO_OP;
                    rs_read<=1'b1;
                    rt_read<=1'b0;
                    valid=`InstValid;
                  end
                  `EXE_MOVN:begin
                    aluop<=`EXE_MOVN_OP;
                    alusel<=`EXE_RES_MOVE;
                    rs_read<=1'b1;
                    rt_read<=1'b1;
                    valid=`InstValid;
                    if(reg2!=`zeroword)begin//reg2应该就是读到rt的值
                      we<=`writeEnable;
                    end else begin
                      we<=`writeDisable;
                    end
                  end
                  `EXE_MOVZ:begin
                    aluop<=`EXE_MOVZ_OP;
                    alusel<=`EXE_RES_MOVE;
                    rs_read<=1'b1;
                    rt_read<=1'b1;
                    valid=`InstValid;
                    if(reg2==`zeroword)begin
                      we<=`writeEnable;
                    end else begin
                      we<=`writeDisable;
                    end
                  end
                  default :begin
                    
                  end
                endcase //case op3
              end
              default :begin
                
              end
            endcase //case op2
          end
          `EXE_ORI: begin//与立即数的或运算
            we<=`writeEnable;//需要写
            aluop<=`EXE_OR_OP;//子运算：或
            alusel<=`EXE_RES_LOGIC;//逻辑运算
            rs_read<=1'b1;//需读rs
            rt_read<=1'b0;//不用读rt
            imm<={16'h0,inst[15:0]};//无符号扩展立即数
            w_addr<=inst[20:16];//结果写进rt
            valid=`InstValid;//指令有效
          end
          `EXE_ANDI:begin
            we<=`writeEnable;
            aluop<=`EXE_AND_OP;
            alusel<=`EXE_RES_LOGIC;
            rs_read<=1'b1;
            rt_read<=1'b0;
            imm<={16'h0,inst[15:0]};
            w_addr<=inst[20:16];
            valid=`InstValid;
          end
          `EXE_XORI:begin
            we<=`writeEnable;
            aluop<=`EXE_XOR_OP;
            alusel<=`EXE_RES_LOGIC;
            rs_read<=1'b1;
            rt_read<=1'b0;
            imm<={16'h0,inst[15:0]};
            w_addr<=inst[20:16];
            valid=`InstValid;
          end
          `EXE_LUI:begin
            we<=`writeEnable;
            aluop<=`EXE_OR_OP;
            alusel<=`EXE_RES_LOGIC;
            rs_read<=1'b1;
            rt_read<=1'b0;
            imm<={inst[15:0],16'h0};//立即数（左移16位）
            w_addr<=inst[20:16];
            valid=`InstValid;
          end
          `EXE_PREF:begin
            we<=`writeDisable;
            aluop<=`EXE_NOP_OP;
            alusel<=`EXE_RES_NOP;
            rs_read<=1'b0;
            rt_read<=1'b0;
            valid=`InstValid;
          end
          default begin
            
          end
        endcase //case op

        if(inst[31:21]==11'b00000000000)begin//立即数移位指令
          if(op3==`EXE_SLL)begin
            we<=`writeEnable;
            aluop<=`EXE_SLL_OP;//逻辑左移
            alusel<=`EXE_RES_SHIFT;//移位运算
            rs_read<=1'b0;//与rs无关
            rt_read<=1'b1;
            imm[4:0]<=inst[10:6];//立即数sa
            valid=`InstValid;
          end else if(op3==`EXE_SRL)begin
            we<=`writeEnable;
            aluop<=`EXE_SRL_OP;//逻辑右移
            alusel<=`EXE_RES_SHIFT;
            rs_read<=1'b0;
            rt_read<=1'b1;
            imm[4:0]<=inst[10:6];
            valid=`InstValid;
          end else if(op3==`EXE_SRA)begin
            we<=`writeEnable;
            aluop<=`EXE_SRA_OP;//算术右移
            alusel<=`EXE_RES_SHIFT;
            rs_read<=1'b0;
            rt_read<=1'b1;
            imm[4:0]<=inst[10:6];
            valid=`InstValid;
          end
        end
      end   //if
    end   //always

    //确定源操作数1
    always @(*) begin
        if(rst)begin
          reg1<=`zeroword;
        end else if(rs_read && ex_we &&(ex_w_addr==rs_addr))begin
          reg1<=ex_w_data;  //若读取的寄存器就是上一条指令在EX要写的寄存器，就直接把EX的结果赋给reg1
        end else if(rs_read && mem_we &&(mem_w_addr==rs_addr))begin
          reg1<=mem_w_data;//若读取的寄存器就是上上条指令在MEM要写的寄存器，就直接把MEM的结果赋给reg1
        end else if(rs_read)begin
          reg1<=rs_data;    //若读了rs，读出来的就是源操作数1
        end else if(!rs_read)begin
          reg1<=imm;        //否则源操作数1是立即数
        end else begin
          reg1<=`zeroword;
        end
    end

    //确定源操作数2
    always @(*) begin
        if(rst)begin
          reg2<=`zeroword;
        end else if(rt_read && ex_we &&(ex_w_addr==rt_addr))begin
          reg2<=ex_w_data;  //若读取的寄存器就是上一条指令在EX要写的寄存器，就直接把EX的结果赋给reg2
        end else if(rt_read && mem_we &&(mem_w_addr==rt_addr))begin
          reg2<=mem_w_data;//若读取的寄存器就是上上条指令在MEM要写的寄存器，就直接把MEM的结果赋给reg2
        end else if(rt_read)begin
          reg2<=rt_data;    //若读了rt，读出来的就是源操作数2
        end else if(!rt_read)begin
          reg2<=imm;        //否则源操作数2是立即数
        end else begin
          reg2<=`zeroword;
        end
    end

    //我总感觉valid和alusel这俩变量没卵用，只起到了挤占内存、增加代码量的作用。
    //我打算在所有的指令都加上后，如果这两个还是没有表现出作用来，就尝试把它们删了。
    //希望我到时候记得这件事吧。如果这三行注释没删掉，那我应该就是忘了
endmodule