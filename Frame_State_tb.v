`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   20:44:29 12/28/2021
// Design Name:   Frame_State
// Module Name:   Y:/Documents/Twist/FPGA_Code/CLIO_Interface/source_Interferometer/Frame_State_tb.v
// Project Name:  CLIO_Control
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: Frame_State
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module Frame_State_tb;

	// Inputs
	reg rst;
	reg ti_clk;
	reg [31:0]reg_length;
	reg [31:0]reg_delay;
	reg [31:0]read_byte_count;
   wire [14:0]   write_word_count;

	// Outputs
	wire frame_rd_en;
	wire DAC_EN;
	wire FRAME;
	wire CCLK;
   wire wr_en;

   reg [32:0] clk_loop;
   
	// Instantiate the Unit Under Test (UUT)
	Frame_State uut (
		.rst(rst), 
		.ti_clk(ti_clk), 
		.reg_length(reg_length), 
		.reg_delay(reg_delay),
   //   .din(din),
   //   .wr_en(wr_en),
   //   .dout(dout),      
		.read_byte_count(read_byte_count),
  //    .write_word_count(write_word_count),
		.frame_rd_en(frame_rd_en), 
		.dac_ready(dac_ready), 
		.FRAME(FRAME), 
		.CCLK(CCLK)
	);
   reg wr_en_r = 0;
   assign wr_en = wr_en_r;
   assign DAC_EN = dac_ready;
   
	initial begin
		// Initialize Inputs
		rst = 1;
		ti_clk = 0;
		reg_length = 6;      // # of bytes
		reg_delay = 3;       // # of columns   
      read_byte_count = reg_length * reg_delay;       

		// Wait 10 ns for global reset to finish
		#10;

		// Add stimulus here
	   #5  ti_clk       = 1;
	   #5  ti_clk       = 0;
		rst              = 0; 

      for (clk_loop = 0; clk_loop <= ((reg_length * reg_delay) * 10); clk_loop = clk_loop + 1)	
		begin
			#5 ti_clk       = !ti_clk;	 		
      end  

      for (clk_loop = 0; clk_loop <= ((reg_length * reg_delay) * 10); clk_loop = clk_loop + 1)	
		begin
			#5 ti_clk       = !ti_clk;	 		
      end  

		// Add stimulus here

	end
      
      
always @(posedge ti_clk)
begin
      if (dac_ready == 1)
      begin
         read_byte_count <= reg_length * reg_delay;
      end
      if (frame_rd_en == 1) begin
         read_byte_count <= read_byte_count -1;
      end
end
endmodule

