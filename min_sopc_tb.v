`include "defines.v"
`timescale 1ns/1ps//时间单位1ns，精度1ps
//tb文件，把信号传进sopc
module min_sopc_tb ();

    reg clk50;
    reg rst;

    //每隔10ns,clk信号翻转一次，一个周期是20ns对应50MHz
    initial begin
        clk50=1'b0;
        forever begin
            #10 clk50=~clk50;
        end
    end

    //初始复位信号有效,195ns后无效，开始运行；1000ns后停止
    initial begin
        rst =`RstEnable;
        #195 rst=`RstDisable;
        #2005 $stop;
    end

    min_sopc min_sopc0(
        .clk(clk50),
        .rst(rst)
    );
endmodule //min_sopc_tb