`include "defines.v"
//这个模块旨在控制流水线的暂停，包括stall信号的产生和传递
//所以这个模块跳出三界之外，不在五段之中。当然，它还是受top.v控制的。
//这版CPU只能从ID和EX段接受暂停信号，因为其它的操作都可以在一个时钟周期内完成
//有没有觉得这个原因很捞？我也觉得。不过我参考的书籍就是这么设计的。
module ctrl (
    input  wire rst,
    input  wire id_stall,   //来自ID段的暂停信号
    input  wire ex_stall,   //来自EX段的暂停信号
    output reg [5:0] stall  //发往各段的暂停信号
);

    always @(*) begin
        if(rst)begin
          stall <= 6'b000000;
        end else if(ex_stall)begin
          stall <= 6'b001111;//把EX段和它前面的阶段都暂停
        end else if(id_stall)begin
         stall  <= 6'b000111;//把ID段和它前面的阶段都暂停
        end else begin
          stall <= 6'b000000;
        end
    end
endmodule //ctrl