`include "defines.v"
//相当于书中的pc模块
module IF(
    input wire                  clk,//时钟信号
    input wire                  rst,//复位信号
    output reg[`InstAddrBus]    pc,
    output reg                  ce
);

    always @ (posedge clk) begin
        if (rst) begin
            pc <= 32'h00000000;//复位时pc为0
        end else begin
            pc <= pc + 4'h4;//pc每周期+4
        end
    end

    always @ (posedge clk) begin
        if (rst) begin
            ce <= 1'b0;//复位时禁用指令存储器
        end else begin
            ce <= 1'b1;//指令存储器可用
        end
    end
endmodule