`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Twist Bioscience
// Engineer: Paul Heilman
// 
// Create Date:    11:48:44 08/13/2015 
// Design Name: 
// Module Name:    ADC_SPI 
// Project Name:   ASIC Printhead
// Target Devices: 
// Tool versions: 14.7
// Description: Added heatsink measurement by toggling ADC channel select.
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module ADC_SPI(
    input            clk48mhz,
    input            rstn,
    output           adc_clk,
    input            adc_dout,
    output           adc_chsel,
    output           adc_cs,
    output  [15:0]   adc_value,
    output  [15:0]   adc_hs_value,
    input   [15:0]   adc_setpoint,
    output           below
    );

	// Shared basic clock
	reg   [31:0]   clk_div;
   always @(posedge clk48mhz)
   if (rstn) 
	   clk_div        <= clk_div + 1;
	else
      clk_div        <= 0;
   
   assign adc_cs    = conv;
   assign adc_chsel = count[4] ^ count[3];
   assign adc_clk   = clk_div[4];
   assign adc_value = tmp;
   assign adc_hs_value = tmp_hs;
   
   assign below = adc_value > adc_setpoint;
   
   //register declarations
    reg conv =0;
    reg rdy;
    reg [4:0] count =0;
    reg [11:0] data_temp =0;
    reg [15:0] tmp = 0;
    reg [15:0] tmp_hs = 0;
    
    //The clock counter. Starts at 0, so clock is from 0-15 instead of 1-16.
    always @(posedge clk48mhz)
    begin
      if  (clk_div[4:0] == 0) 
      begin
         count <= count + 1;
    
         //Assert the CONV signal
         conv <=  (&count[3:1]);
    
         //Shift the serial data into a 12-bit register. 
         //Afterwards, convert it to parallel if the count is 13 or 29(end of data stream)
         begin
               data_temp  <= {data_temp[10:0], adc_dout};
            if (count == 13)
                tmp <= data_temp;
            if (count == 29)
                tmp_hs <= data_temp;
         end
       end
    end
        
endmodule
