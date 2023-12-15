`include "defines.v"
module min_sopc (
    input  wire clk,
    input  wire rst 
);

    //连接指令存储器
    wire [`InstAddrBus] inst_addr;
    wire [`InstBus]      inst;
    wire                rom_ce;

    //例化top
    top top0(
        .clk(clk),
        .rst(rst),
        .rom_data_i(inst),
        .rom_addr_o(inst_addr),
        .rom_ce_o(rom_ce)
    );

    //例化指令存储器rom
    rom rom0(
        .ce(rom_ce),
        .addr(inst_addr),
        .inst(inst)
    );

endmodule //min_spoc