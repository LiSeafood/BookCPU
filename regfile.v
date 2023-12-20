`include "defines.v"
//寄存器
module regfile(
    input wire clk,
    input wire rst,
    //写端口
    input wire we,
    input wire [4:0] waddr,
    input wire [31:0] wdata,
    //读端口1
    input wire re1,
    input wire [4:0] raddr1,
    output reg [31:0] rdata1,
    //读端口2
    input wire re2,
    input wire [4:0] raddr2,
    output reg [31:0] rdata2
);

    reg [31:0] reg_array [31:0];//32个32位寄存器
    initial reg_array [32'h0]=32'h0;

    // 写端口的操作
    always @ (posedge clk) begin
        if(!rst)begin
          if (we && waddr!=5'b0) begin
            reg_array[waddr] <= wdata;
          end//不复位、可写、写入数据非空时写入
        end
    end

    // 读端口1
    always @( *) begin
        if(rst == `RstEnable || raddr1 ==5'b0)begin
          rdata1 <= `zeroword;//复位或空地址则读出空数据
        end else if((raddr1 ==waddr)&& we && re1)begin
          rdata1<=wdata;//写后读，直接把写数据赋给读数据
        end else if(re1)begin
          rdata1<=reg_array[raddr1];//正常读取
        end else begin
          rdata1 <= `zeroword;
        end
    end

    // 读端口2
    always @( *) begin
        if(rst == `RstEnable || raddr2 ==5'b0)begin
          rdata2 <= `zeroword;//复位或空地址则读出空数据
        end else if((raddr2 ==waddr)&& we && re2)begin
          rdata2<=wdata;//写后读，直接把写数据赋给读数据
        end else if(re2)begin
          rdata2<=reg_array[raddr2];//正常读取
        end else begin
          rdata2 <= `zeroword;
        end
    end
endmodule