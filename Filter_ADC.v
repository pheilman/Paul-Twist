`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Twist Bioscience
// Engineer: Paul Heilman
// 
// Create Date:    15:17:00 03/07/2023 
// Design Name: 
// Module Name:    Filter_ADC 
// Project Name:   CLIO interface
// Description:    Simple running average filter for noisy ADC readings. 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module Filter_ADC(
    input clk48mhz,
    input rstn,
    input next,
    input [15:0] adc_input,
    output [15:0] filter_output
    );
reg [15:0] memory8,memory7,memory6,memory5,memory4,memory3,memory2,memory1,memory0;
reg [15:0] sum = 0; 
reg [15:0] sub = 0;

assign filter_output = adc_input; //memory0; //sum[7:0];
always @(posedge clk48mhz)
begin 
   if (next)
   begin
      sub     <= adc_input - memory8;
      sum     <= memory1;
      memory0 <= adc_input;
      memory1 <= memory0;
      memory2 <= memory1;
      memory3 <= memory2;
      memory4 <= memory3;
      memory5 <= memory4;
      memory6 <= memory5;
      memory7 <= memory6;
      memory8 <= memory7;
   end   
end
endmodule
