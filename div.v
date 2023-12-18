`include "defines.v"
//使用试商法实现除法的模块
//对于k位的除法，需要k个周期
//MIPS32的除法是32位的，所以需要32个周期
module div (
    input  wire  clk,
    input  wire  rst,

    input  wire          sign,//是否有符号
    input  wire  [31:0]  reg1,//运算数1（被除数）
    input  wire  [31:0]  reg2,//运算数2（除数）
    input  wire          start,//开始
    input  wire          cancel,//取消（中断）

    output reg [63:0]    result,//运算结果
    output reg           done//运算是否完成
);
    
    wire[32:0]  div_temp;
    reg [5:0]   cnt;        //记录运算轮次
    reg [64:0]  dividend;   //
    reg [1:0]   state;      //运算状态
    reg [31:0]  divisor;
    reg [31:0]  t1;         
    reg [31:0]  t2;

    assign div_temp = {1'b0,dividend[63:32]} - {1'b0,divisor};

    always @(posedge clk) begin
        if(rst)begin
          state<=`DivFree;
          done<=`DivResultNotReady;
          result<={`zeroword,`zeroword};
        end else begin
          case (state)
            `DivFree:begin
              if(start && !cancel)begin//除法开始，没有取消
                if(reg2==`zeroword)begin
                  state<=`DivByZero;//除数为0
                end else begin
                  state<=`DivOn;
                  cnt<=6'b000000;
                  if(sign &&reg1[31])begin
                    t1= ~reg1+1;//有符号数，被除数为负数
                  end else begin
                    t1= reg1;
                  end
                  if(sign &&reg2[31])begin
                    t2= ~reg2+1;//有符号数，除数为负数
                  end else begin
                    t2= reg2;
                  end
                  dividend<={`zeroword,t1};
                  dividend[32:1] <= t1;
                  divisor<=t2;
                end
              end  
            end 
            `DivByZero:begin
              dividend<={`zeroword,`zeroword};
              state<= `DivEnd;
            end
            `DivOn:begin
              if(!cancel)begin
                if(cnt!=6'b100000)begin//周期不到32说明还没算完
                  if(div_temp[32])begin
                    dividend<={dividend[63:0],1'b0};//左移一位
                  end else begin
                    dividend={div_temp[31:0],dividend[31:0],1'b1};
                  end
                  cnt<=cnt+1;
                end else begin    //算完力
                  if(sign &&(reg1[31]^reg2[31]))begin
                    dividend[31:0] <= ~dividend[31:0]+1;
                  end
                  if(sign &&(reg1[31]^dividend[64]))begin
                    dividend[64:33]<= ~dividend[64:33]+1;
                  end
                  state<=`DivEnd;
                  cnt<=6'b000000;
                end 
              end else begin
                state<=`DivFree;    //除法被取消了，直接回到free状态
              end
            end 
            `DivEnd:begin
              result<={dividend[64:33],dividend[31:0]};
              done<=`DivResultReady;
              if(!start)begin
                state<=`DivFree;
                done<=`DivResultNotReady;
                result<={`zeroword,`zeroword};
              end
            end
            default: begin
              
            end
          endcase
        end
    end
endmodule //div