`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   17:35:10 11/05/2019
// Design Name:   Master_State
// Module Name:   Y:/Documents/Twist/FPGA_Code/OK_D128_Interferometer_B_1/Master_State_TB.v
// Project Name:  OK_D128_Interferometer_B_1
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: Master_State
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module Master_State_TB;

	// Inputs
	reg clk48mhz;
	reg rstn;
	reg jet_enable;
	reg start_pulse;
	reg loop_pattern;
	reg ext_encoder;
	reg count_enable_x;
	reg [31:0] length_reg;
	reg [31:0] divider_reg;
	reg [31:0] delay_reg;
	reg [15:0] adjust_column;
   
   reg [20:0] clk_loop;

	// Outputs
	wire print_active;
	wire start_column;
	wire [15:0] pattern_counter;
   wire [31:0] pulse_counter;
   wire [31:0] max_delay;

	// Instantiate the Unit Under Test (UUT)
	Master_State uut (
		.clk48mhz(clk48mhz), 
		.rstn(rstn), 
		.jet_enable(jet_enable), 
		.start_pulse(start_pulse), 
		.loop_pattern(loop_pattern), 
		.ext_encoder(ext_encoder), 
		.count_enable_x(count_enable_x), 
		.length_reg(length_reg), 
		.divider_reg(divider_reg), 
		.delay_reg(delay_reg), 
		.print_active(print_active), 
		.start_column(start_column), 
		.pattern_counter(pattern_counter), 
      .pulse_counter(pulse_counter),
      .max_delay(max_delay),
		.adjust_column(adjust_column)
	);

	initial begin
		// Initialize Inputs
		clk48mhz = 0;
		rstn = 0;
		jet_enable     = 1;
		start_pulse    = 0;
		loop_pattern   = 0;
		ext_encoder    = 0;
		count_enable_x = 0;
		adjust_column  = 0;     
		divider_reg    =  32'h0000_0000;
		length_reg 		=  32'h0000_0008;
		delay_reg 		=  32'h0000_0004;

		// Wait 100 ns for global reset to finish
		#100;
        
		// Add stimulus here
		// Add stimulus here
		ext_encoder        = 1; // Using external encoder
	   #5  clk48mhz       = 0;
	   #5  clk48mhz       = 1;
		rstn               = 1;  		
	   #5  clk48mhz       = 0;
      start_pulse        = 1;
	   #5  clk48mhz       = 1;
	   #5  clk48mhz       = 0;
      start_pulse        = 0;
	   #5  clk48mhz       = 1;
	   #5;		
      clk48mhz           = 0;
      	for (clk_loop = 0; clk_loop <= 2000; clk_loop = clk_loop + 1)	
		begin
			#5 clk48mhz       = !clk48mhz;	
		end
	end	
always  begin
	for (enc_loop = 0; enc_loop <= 60; enc_loop = enc_loop + 1)
		begin
			#(40 + 10 * (enc_loop % 20)) count_enable_x = 1;  // Create a sawtooth wave of delays in PSO pulse
         #10 count_enable_x = 0 ;
       //  adjust_column <= pattern_counter +2;
		end
		#40 ;
end


     

      

      
endmodule

