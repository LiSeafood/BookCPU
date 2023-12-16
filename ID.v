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

    //取得指令的指令码和功能码
    wire [5:0] op = inst[31:26];
    wire [4:0] op2= inst[10:6];
    wire [5:0] op3= inst[5:0];
    wire [4:0] op4= inst[20:16];

    reg[`RegBus] imm;//立即数
    reg valid;//指令是否有效

    //译码
    always @(*) begin//先赋初值，都赋为0
        aluop <= `EXE_NOP_OP;
        alusel <= `EXE_RES_NOP;
        we <= `writeDisable;
        valid <= `InstValid;
        rs_read <= 1'b0;
        rt_read <= 1'b0;
        imm<=`zeroword;
        if(rst)begin//复位的话这些都是0
          w_addr <= `NOPRegAddr;
          rs_addr <= `NOPRegAddr;
          rt_addr <= `NOPRegAddr;
        end else begin
          w_addr <= inst[15:11];
          rs_addr <= inst[25:21];
          rt_addr <= inst[20:16];

          case(op)
            `EXE_ORI: begin//ori rs与立即数的或运算
              we<=`writeEnable;//需要写
              aluop<=`EXE_OR_OP;//子运算：或
              alusel<=`EXE_RES_LOGIC;//逻辑运算
              rs_read<=1'b1;//需读rs
              rt_read<=1'b0;//不用读rt
              imm<={16'h0,inst[15:0]};//无符号扩展立即数
              w_addr<=inst[20:16];//结果写进rt
              valid=`InstValid;//指令有效
            end
            default begin
              
            end
          endcase
        end
    end

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
    
endmodule