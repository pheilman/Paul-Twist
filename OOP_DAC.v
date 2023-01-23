`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Twist Bioscience
// Engineer: Paul Heilman
// 
// Create Date:    07:44:37 12/08/2022 
// Design Name:    CLIO_Interface
// Module Name:    OOP_DAC 
// Project Name:   CLIO DNA Chip
// Target Devices: 
// Tool versions: 
// Description: Loads 16 bit DAC that sets the voltage on the flow cell lid or
//              Out-Of-Plane cathode. May serve to set the bulk voltage in the 
//              electrolyte mixture.  Just sends the setting repeatedly.
//              SYNC_N is low for 32 clocks and that is the value loaded.
//              Then SYNC_N is high for 32 clocks and the DAC_DATA is ignored. 
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module OOP_DAC(
    input  clk48mhz,
    input  wire [15:0] OOP_DAC_VALUE,
    input  rstn,
    output DAC_CLK,
    output reg DAC_DATA,
    output reg DAC_SYNC_N
    );

	// Shared basic clock
	reg   [31:0]   clk_div;
   always @(posedge clk48mhz)
   begin
   if (rstn) 
	   clk_div        <= clk_div + 1;
	else
      clk_div        <= 0;
   end
   
   assign DAC_CLK = clk_div[6];              // Slow the clock down, no need to update the OP cathode fast.
   
   reg [23:0] DAC_SHIFT = 0;
   reg [7:0]  count     = 0;
   
   always @(posedge clk48mhz)
   begin
      if (clk_div[6:0] == 0)
      begin
         count <= count + 1; 
         DAC_DATA <= DAC_SHIFT[23];
         DAC_SHIFT <= {DAC_SHIFT[22:0], 1'b0};  // Shift the bits up
         if (count == 0) begin
            DAC_SYNC_N <= 0;
            DAC_SHIFT  <= {8'h00,OOP_DAC_VALUE};     //Not power down and DAC setting payload
         end
         if (count == 24)
            DAC_SYNC_N <= 1;
      end
   end   
endmodule
