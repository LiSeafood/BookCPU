`include "defines.v"
module min_sopc (
    input  wire clk,
    input  wire rst 
);

    //连接指令存储器
    wire [`InstAddrBus] inst_addr;
    wire [`InstBus]      inst;
    wire                rom_ce;
    
    //连接数据存储器
    wire mem_we_i;
    wire[`RegBus] mem_addr_i;
    wire[`RegBus] mem_data_i;
    wire[`RegBus] mem_data_o;
    wire[3:0] mem_sel_i;  
    wire mem_ce_i;  

    //中断、异常信号
    wire[5:0] int;
    wire timer_int;

    assign int = {5'b00000, timer_int};

    //例化top
    top top0(
        .clk(clk),
        .rst(rst),

        .rom_data_i(inst),
        .rom_addr_o(inst_addr),
        .rom_ce_o(rom_ce),

        .int_i(int),

        .ram_we_o(mem_we_i),
		.ram_addr_o(mem_addr_i),
		.ram_sel_o(mem_sel_i),
		.ram_data_o(mem_data_i),
		.ram_data_i(mem_data_o),
		.ram_ce_o(mem_ce_i),
        
		.timer_int_o(timer_int)		
    );

    //例化指令存储器rom
    rom rom0(
        .ce(rom_ce),
        .addr(inst_addr),
        .inst(inst)
    );

    //例化数据存储器ram
    ram ram0(
		.clk(clk),
		.ce(mem_ce_i),	
		.we(mem_we_i),
		.addr(mem_addr_i),
		.sel(mem_sel_i),
		.data_i(mem_data_i),
		.data_o(mem_data_o)
	);


endmodule //min_spoc