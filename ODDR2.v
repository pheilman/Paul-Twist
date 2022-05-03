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

ODDR2  ddr2_as_clock_output_thingy (
   .Q(clock_output),   // 1-bit DDR output data
   .C0(pll_output), // 1-bit clock input
   .C1(~pll_output), // 1-bit clock input
   .CE(1'b1), // 1-bit clock enable input
   .D0(1'b1), // 1-bit data input (associated with C0)
   .D1(1'b0), // 1-bit data input (associated with C1)
   .R(1'b0),   // 1-bit reset input
   .S(1'b0)    // 1-bit set input
);
    end
        
endmodule
