`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    09:32:03 12/12/2022 
// Design Name: 
// Module Name:    octal_adc_interface 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: Reads 16 bit ADC values from the multi channel ADS8688
//       Reference is 4.096V (internal) with default 2.5x is +/- 10.24V full scale.
//        Channel    Measures       Maximum  Vout 
//           0       +1.25V         0.5A     3.4V
//           1       +1.8V          0.5A     3.4V
//           2       +2.2V          0.5A     3.4V
//           3       -2.2V         -0.5A     3.4V
//           4       -1.25V        -0.5A     3.4V
//           5       Flowcell I     1 mA     1.0V
//           6       Flowcell V    +/-2.5V   +/-2.5V
//      Going to use manual selection of ADC 
//      The loop will be as follows:
//  SDI   Select 0      Select 1      Select 2 ...  Select 7      Select 0
//  SDO           Data 7        Data 0        Data 1        Data 6
//
//           Select 0     0xC000
//           Select 1     0xC400
//           Select 7     0xDC00
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module octal_adc_interface(
    input  clk48mhz,
    input  rstn,
    output [15:0] channel0,      // +1V25 Current
    output [15:0] channel1,      // +1V8 Current
    output [15:0] channel2,      // +2V2 Current
    output [15:0] channel3,      // -2V2 Current
    output [15:0] channel4,      // -1V25 Current
    output [15:0] channel5,      // Flowcell Current
    output [15:0] channel6,      // Flowcell Voltage
    output [15:0] channel7,
    output ADC_CLK,
    output ADC_CS_N,
    output ADC_SDI,
    output ADC_RST_N,
    input  ADC_SDO
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
   
   assign ADC_CLK    = !clk_div[3];        // Slow the clock down. Falling edge triggered
   assign ADC_RST_N  = rstn;
   
   assign channel0   = ADC_REG0;
   assign channel1   = ADC_REG1;
   assign channel2   = ADC_REG2;
   assign channel3   = ADC_REG3;
   assign channel4   = ADC_REG4;
   assign channel5   = ADC_REG5;
   assign channel6   = ADC_REG6;
   assign channel7   = ADC_REG7;
   
   reg [2:0] channel_select = 0;          // Selects the data to be received in next cycle
   reg [15:0]  ADC_REG;
   reg [15:0]  ADC_REG0, ADC_REG1, ADC_REG2, ADC_REG3, ADC_REG4, ADC_REG5, ADC_REG6, ADC_REG7;
   reg [15:0]  ADC_DATA;
   reg         adc_cs_n;
   
   wire ADC_SDI, ADC_CS_N;
   assign ADC_SDI = ADC_COMMAND[15];
   assign ADC_CS_N = adc_cs_n;
   
   
   reg [15:0] ADC_COMMAND = {3'b110,3'b000,10'b0000000000};     // Channel 0 is selected 
   reg [5:0]  count     = 0;
   reg [2:0]  channel   = 0;
   always @(posedge clk48mhz)
   begin
      if (clk_div[3:0] == 0)
      begin
         count       <= count + 1; 
      //   ADC_SDI     <= ADC_COMMAND[15];
         ADC_COMMAND <= {ADC_COMMAND[14:0], 1'b0};  // Shift the bits up
         ADC_DATA    <= {ADC_DATA[14:0],ADC_SDO};
         if (count == 0) begin
            adc_cs_n <= 0;     
            ADC_COMMAND <= {3'b110,channel,10'b0000000000};
         end
         if (count == 32) begin
            channel <= channel + 1;
            adc_cs_n <= 1;
            if (channel == 0)    ADC_REG7  <= ADC_DATA;  // The selected channel data was sent on the previous transmission
            if (channel == 1)    ADC_REG0  <= ADC_DATA;  // When we are sending channel 1 selection, we get back channel 0 data.            
            if (channel == 2)    ADC_REG1  <= ADC_DATA;
            if (channel == 3)    ADC_REG2  <= ADC_DATA;
            if (channel == 4)    ADC_REG3  <= ADC_DATA;            
            if (channel == 5)    ADC_REG4  <= ADC_DATA;
            if (channel == 6)    ADC_REG5  <= ADC_DATA;            
            if (channel == 7)    ADC_REG6  <= ADC_DATA;
         end
            
      end
   end   
endmodule
