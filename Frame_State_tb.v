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

   //wire [14:0]   write_word_count;
   reg [15:0] din;
   wire [7:0] dout;
	// Outputs
   reg [31:0]track_read_count;
	wire frame_rd_en;
	wire DAC_EN;
	wire FRAME;
	wire CCLK;
   reg wr_en;

   reg [32:0] clk_loop;
   
	// Instantiate the Unit Under Test (UUT)
	Frame_State #(4) uut (
		.rst(rst), 
		.ti_clk(ti_clk), 
		.reg_length(reg_length), 
		.reg_delay(reg_delay),
      .din(din),
      .wr_en(wr_en),
      .dout(dout),      
		.read_byte_count(read_byte_count),
  //    .write_word_count(write_word_count),
		.frame_rd_en(frame_rd_en), 
		.dac_ready(dac_ready), 
		.FRAME(FRAME), 
      .frame_state(frame_state),
		.CCLK(CCLK)
	);

   assign DAC_EN = dac_ready;
   
   wire [31:0] read_byte_count;
   wire [2:0] frame_state;
   wire [7:0] increm;
   
   assign increm = clk_loop[7:0] + 1;
   
	initial begin
		// Initialize Inputs
		rst = 1;
		ti_clk = 0;
      wr_en  = 0;
      din = 0;
		reg_length = 8;      // # of bytes
		reg_delay = 3;       // # of columns   
    //  read_byte_count = reg_length * reg_delay;       
      #5 ti_clk = 1;
      #5 ti_clk = 0;
		// Wait 10 ns for global reset to finish
		#10;
      rst              = 0; 


      for (clk_loop = 0; clk_loop <= (3); clk_loop = clk_loop + 1)	
		begin
			#5 ti_clk       = !ti_clk;	 		
      end        
// First load the FIFO
      for (clk_loop = 0; clk_loop <= ((reg_length * reg_delay) * 2); clk_loop = clk_loop + 2)	
		begin
			#5 ti_clk       = !ti_clk;	 		
         din             = {clk_loop[7:0], increm};
         #5 ti_clk       = !ti_clk;
         wr_en           = 1;
      end  
      wr_en = 0;

		// Add stimulus here
      
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
         track_read_count <= reg_length * reg_delay;
      end
      if (frame_rd_en == 1) begin
         track_read_count <= track_read_count -1;
      end
end
endmodule

