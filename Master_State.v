`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Twist Bioscience
// Engineer: Paul Heilman
// 
// Create Date:    13:56:34 11/05/2019 
// Design Name: 
// Module Name:    Master_State 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module Master_State(
	input         clk48mhz,
   input         rstn,
   input         jet_enable,
   input         start_pulse,
   input         loop_pattern,
   input         ext_encoder,
   input         count_enable_x,
   input [31:0]  length_reg,
   input [31:0]  divider_reg,
   input [31:0]  delay_reg,
   
   output        print_active,
   output        start_column,
   output [31:0] delay_counter,
   output [31:0] divide_counter,
   output [15:0] pattern_counter,
   output [31:0] pulse_counter,
   output [31:0] max_delay,
   input  [15:0] adjust_column
    );

   // Master state machine
   // First delay to adjust starting point
	// Then divide encoder or clock to get jetting interval
	// Starts data transfer to latches in D128 head
	// Then starts waveform generation
   // New addition is that the divider comparison is adjusted to allow compensation
   // for errors in the encoder. This basically makes a trigger table for every
   // printing location. For interferometer, the trigger table creates the average 
   // division value by dithering. 
   
   // New registers for debugging, pulse counter totalizes the number of pulses during a swath, 
   // max delay keeps track of the largest number of clock pulses between firing pulses. 
   // The debugging counters didn't help much. The failure seems to be happening before the
   // encoder input on the Aerotech. 

	reg         delay_active = 0;
	reg         pattern_active = 0;
	reg 			print_active = 0;    
   reg			start_column = 0;
	reg [31:0] 	delay_counter = 0;
	reg [31:0]  divide_counter = 0;
	reg [15:0] 	pattern_counter = 0;
   reg [31:0]  divider_reg_adj = 2;  
   reg [31:0]  pulse_counter = 0;
   reg [31:0]  max_delay = 0;
   reg [31:0]  max_counter = 0;
   wire        new_is_bigger;
   
   assign      new_is_bigger = max_counter > max_delay;      // Continuously check for need to replace with new high count
	
   always @ (posedge clk48mhz)
   begin
      if (rstn == 1'b0 || jet_enable == 1'b0) begin
			pattern_active <= 0;
			delay_active <= 0;
			print_active <= 0;
			pattern_counter <= 0;
         divider_reg_adj   <= divider_reg + {{16{adjust_column[15]}},adjust_column};         
      end
      else
      if (start_pulse)   // Enable on SW trigger going high                                                                  
         begin
			print_active      <= 1;
			pattern_counter   <= 0;	
			delay_counter     <= 0;
         pulse_counter     <= 0;         // New debugging pulse counter that tracks total PSO pulses received
         max_delay         <= 0;         // New counter of clock pulses between PSO pulses
         max_counter       <= 0;         // Counter between each PSO pulse
         // Adjust divider register that gets used by sign extending and adding
         // Dominique wants to have a divider_reg value of 0 so I better avoid wrap around. 
         divider_reg_adj   <= divider_reg + {{16{adjust_column[15]}},adjust_column};
			if (delay_reg >= 1) begin  
					delay_active    <= 1;
					pattern_active  <= 0;
				end
				else        // Special case for 0 delay
				begin
					pattern_active   <= 1;
					divide_counter   <= divider_reg_adj - 1; // Wait for encoder pulse to print first column					
					delay_active     <= 0;					
				end
		   end                     
      else
		if (print_active) 
			begin
			if (delay_active)
				begin
				if (delay_counter == delay_reg) begin
					pattern_active  <= 1;
					divide_counter  <= divider_reg_adj;     // Print first column immediately after delay
					delay_active    <= 0;
				end
				else 
					if (count_enable_x || !ext_encoder) begin
                     delay_counter <= delay_counter + 1;
                     pulse_counter <= pulse_counter + 1;
               end
				end
			else 
			if (pattern_active) 	
				begin
				if (divide_counter != divider_reg_adj) begin	
					start_column <= 0;
               max_counter <= max_counter + 1;
					if (count_enable_x || !ext_encoder) begin
                     divide_counter <= divide_counter + 1;
                     pulse_counter <= pulse_counter + 1; 
                     max_counter <= 0;    // Restart clock counter every encoder input pulse
                     if (new_is_bigger)
                        max_delay <= max_counter;      // Load new, larger value
               end
            end
				else
				begin
					start_column <= 1;
					divide_counter <= 0;
               // Adjust divider register that gets used by sign extending and adding
               divider_reg_adj <= divider_reg + {{16{adjust_column[15]}},adjust_column};
					pattern_counter  <= pattern_counter + 1;
					if (pattern_counter == length_reg[15:0]) begin    // Completed requested number of columns
						pattern_active <= 0;
						start_column <= 0;
						if (loop_pattern) begin	
							delay_active     <= 1;
							delay_counter    <= 0;
							pattern_counter  <= 0;
						end
						else
						begin
							print_active <= 0;
						end
					end
			   end
			end 
			else // Not print active
			begin
				pattern_counter <= 0;
			end
		end // not start path
    end  // Not reset path 
endmodule
