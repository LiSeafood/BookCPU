`include "defines.v"
module hilo (//WB段的HILO寄存器
    input  wire clk,
    input  wire rst,

    //写端口
    input  wire             we,
    input  wire [`RegBus]   hi_i,
    input  wire [`RegBus]   lo_i,

    //读端口
    output reg [`RegBus]    hi_o,
    output reg [`RegBus]    lo_o
);

    always @(posedge clk) begin
        if(rst)begin
          hi_o<=`zeroword;
          lo_o<=`zeroword;
        end else if(we)begin
          hi_o<=hi_i;
          lo_o<=lo_i;
        end
    end
endmodule //hilo