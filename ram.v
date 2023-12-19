`include "defines.v"
module ram (
    input wire clk,
    input wire ce,
    input wire we,
    input wire [`DataAddrBus] addr,
    input wire [3:0] sel,
    input wire [`DataBus] data_i,
    output reg [`DataBus] data_o
);

  //为了方便对数据存储器按字节寻址，用4个8位存储器代替一个32位存储器
  reg [`ByteWidth] data_mem0[0:`DataMemNum-1];
  reg [`ByteWidth] data_mem1[0:`DataMemNum-1];
  reg [`ByteWidth] data_mem2[0:`DataMemNum-1];
  reg [`ByteWidth] data_mem3[0:`DataMemNum-1];

  //写操作
  always @(posedge clk) begin
    if (!ce) begin
      //data_o <= ZeroWord;
    end else if (we) begin
      if (sel[3]) begin
        data_mem3[addr[`DataMemNumLog2+1:2]] <= data_i[31:24];
      end
      if (sel[2]) begin
        data_mem2[addr[`DataMemNumLog2+1:2]] <= data_i[23:16];
      end
      if (sel[1]) begin
        data_mem1[addr[`DataMemNumLog2+1:2]] <= data_i[15:8];
      end
      if (sel[0]) begin
        data_mem0[addr[`DataMemNumLog2+1:2]] <= data_i[7:0];
      end
    end
  end

  //读操作
  always @(*) begin
    if (!ce) begin
      data_o <= `zeroword;
    end else if (!we) begin
      data_o <= {
        data_mem3[addr[`DataMemNumLog2+1:2]],
        data_mem2[addr[`DataMemNumLog2+1:2]],
        data_mem1[addr[`DataMemNumLog2+1:2]],
        data_mem0[addr[`DataMemNumLog2+1:2]]
      };
    end else begin
      data_o <= `zeroword;
    end
  end

endmodule  //ram
