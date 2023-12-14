`include "defines.v"
module if_id(
    input wire clk,
    input wire rst,

    //来自IF的信号
    input wire[`InstAddrBus] if_pc,
    input wire[`InstBus]     if_inst,

    //去往ID的信号
    output reg[`InstAddrBus] id_pc,
    output reg[`InstBus]     id_inst
);

    always @(posedge clk) begin
        if(rst)begin
          id_pc<=`zeroword;//复位时pc为0
          id_inst<=`zeroword;//指令为空
        end else begin//其余时刻向下传递数据
          id_pc<=if_pc;
          id_inst<=if_inst;
        end
    end
endmodule