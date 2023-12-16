`include "defines.v"
module MEM(
    input  wire rst,

    //来自ex_mem的信息
    input  wire                 we_i,
    input  wire [`RegAddrBus]   w_addr_i,
    input  wire [`RegBus]       w_data_i,
    input  wire [`RegBus]       hi_i,
    input  wire [`RegBus]       lo_i,
    input  wire                 hilo_i,//是否要写

    //MEM的结果
    output reg                  we_o,
    output reg [`RegAddrBus]    w_addr_o,
    output reg [`RegBus]        w_data_o,
    output reg [`RegBus]        hi_o,
    output reg [`RegBus]        lo_o,
    output reg                  hilo_o
);

    always @(*) begin
        if(rst)begin
          we_o<=`writeDisable;
          w_addr_o<=`NOPRegAddr;
          w_data_o<=`zeroword;
          hi_o<=`zeroword;
          lo_o<=`zeroword;
          hilo_o<=`writeDisable;
        end else begin
          we_o<=we_i;
          w_addr_o<=w_addr_i;
          w_data_o<=w_data_i;
          hi_o<=hi_i;
          lo_o<=lo_i;
          hilo_o<=hilo_i;
        end
    end

endmodule