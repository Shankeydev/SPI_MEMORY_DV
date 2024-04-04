
interface spi_if;
  
    logic wr,clk,rst;
  	logic [7:0] addr_in, data_in;
  	logic [7:0] data_out;
    logic done, err;
  
endinterface