`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   10:57:36 08/14/2015
// Design Name:   ADC_SPI
// Module Name:   Z:/Documents/Twist/OK_D128_2/ADC_SPI_tb.v
// Project Name:  OK_D128_2_0
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: ADC_SPI
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module ADC_SPI_tb;

	// Inputs
	reg clk48mhz;
	reg rstn;
	reg adc_dout;
	reg [15:0] adc_setpoint;
   
   reg [20:0] clk_loop;

	// Outputs
	wire adc_clk;
	wire adc_chsel;
	wire adc_cs;
	wire [15:0] adc_value, adc_hs_value;
	wire heat_on;

	// Instantiate the Unit Under Test (UUT)
	ADC_SPI uut (
		.clk48mhz(clk48mhz), 
		.rstn(rstn), 
		.adc_clk(adc_clk), 
		.adc_dout(adc_dout), 
		.adc_chsel(adc_chsel), 
		.adc_cs(adc_cs), 
		.adc_value(adc_value),
      .adc_hs_value(adc_hs_value),
		.adc_setpoint(adc_setpoint), 
		.below(heat_on)
	);

	initial begin
		// Initialize Inputs
		clk48mhz = 0;
		rstn = 0;
		adc_dout = 0;
		adc_setpoint       = 16'h7000; // Warm

		// Wait 100 ns for global reset to finish
		#100;
        
		// Add stimulus here
	   #5  clk48mhz       = 0;
	   #5  clk48mhz       = 1; 		
	   #5  clk48mhz       = 0;
	   #5  clk48mhz       = 1;
		rstn           = 1; 
	   #5  clk48mhz       = 0;
	   #5  clk48mhz       = 1;
	   #5;		
		clk48mhz       = 0;
	for (clk_loop = 0; clk_loop <= 200; clk_loop = clk_loop + 1)	
		begin
			#5 clk48mhz       = !clk48mhz;	
		end		

	   #10  clk48mhz       = 0;
	   #10  clk48mhz       = 1; 		
	   #10  clk48mhz       = 0;
	   #10  clk48mhz       = 1;
		rstn           = 1; 
	   #10  clk48mhz       = 0;
	   #10  clk48mhz       = 1;
		clk48mhz       = 0;
	for (clk_loop = 0; clk_loop <= 10000; clk_loop = clk_loop + 1)	
		begin
			#5 clk48mhz       = !clk48mhz;	
		end		
  end

      
endmodule

