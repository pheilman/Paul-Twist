`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:       Twist Bioscience
// Engineer:      Paul Heilman
// 
// Create Date:   11:54:44 3/23/2015 
// Project Name:  D128 ASIC Printhead driver
// Tool versions: 14.7
// Description:   D128 initial control inserted in Slave Management module.
//
// Revision 2.3 - Waveform, transfer and allon working
// Revision 3.4 - Fixed off by one of shift register data, needed to prime with first bit
// Revision 7.1 - Closed loop head heater control added. 
// Revision B.1 - Changed divider structure for interferometer, trigger table is actual divider, not an adjustment
//
// control_reg bit details
// bit   values   description
//  0    0 (def)  Internal clock (Idle jet or jetting stand)
//       1        External clock (encoder input for printing)
//  1    0 (def)  Idle
//       1        Start on 0->1 transition, reset on 1->0 
//  2    0 (def)  One pass through the pattern memory
//       1        Loop back to beginning of pattern memory after LENGTH
//  3    0 (def)  Disable power (no printhead power)
//       1        Enable power 
//  4    0 (def)  Purge valve off 
//       1        Purge valve on
//  5    0 (def)  Jet pattern nozzles only             Debug register only
//       1        Jet ALL nozzles by using ALL ON
//  6    0 (def)  Pattern from memory                  Debug register only
//       1        Fixed pattern
//  7    0 (def)  Heater is off
//       1        Heater controller based on setpoint ++++++++++++++++++

//  6-16 0 (def)           
//
//  status_reg bit details
//  bit  values   description
//   0   0        Head current OK       (pzt_clim)
//       1        Head current overload (bad)
//   1   0        Head not shorted OK  (pzt_error)
//       1        Head Shorted-DC path (very bad)
//
//  Need five machines: 
//     Power on controller: 5 Volts, then 48 Volts, then enable amplifier                             
//     Master divider, runs on encoder or internal clock
//		 ASIC control signals, started by master divider
//     Waveform generator, started by ASIC controller    Done   
//     All-on timer, pulses allon every 400 usec
// At each step master divider starts the ASIC controller to send out the nozzle pattern,
// then starts the waveform generator. 
// When waveform generation is complete, master divider advances the pattern step.
// The master divider generates an address up to length and loops if commanded. 
//////////////////////////////////////////////////////////////////////////////////
module Q256_mgt(
	input         clk48mhz,
   input         rstn,
	output [13:0] dac,
   input  [31:0] control_reg,
	input  [15:0] debug_control,
	output [15:0] debug_status,
   output [31:0] status_reg,
   output [31:0] version_reg,
   output [31:0] pulse_counter,
   output [31:0] max_delay,
	input  [31:0] dc_value_reg,
	input  [31:0] divider_reg,
   input  [31:0] length_reg,
	input  [31:0] delay_reg,

	output [15:0] pattern_addr,
	input  [255:0] pattern_column,
   input  [15:0]  adjust_column,
   output [3:0]   nozzle_addr,
   input  [255:0] nozzle_column, 
					
   input  [31:0] segment1,
   input  [31:0] segment2,
   input  [31:0] segment3,
   input  [31:0] segment4,
	input  [31:0] segment5,
	input  [31:0] segment6,
	input  [31:0] segment7,
	input  [31:0] segment8,	

   input  [31:0] jet_stand1,
   input  [31:0] jet_stand2,
   input  [31:0] jet_stand3,
   input  [31:0] jet_stand4,
	input  [31:0] jet_stand5,
	input  [31:0] jet_stand6,
	input  [31:0] jet_stand7,
   
   input  [15:0] spi_tx_data,
   output [15:0] spi_rx_data,
	
   output [31:0] monitor1,
   output [31:0] monitor2,
   output [31:0] monitor3,
   output [31:0] monitor4,	
	output [31:0] monitor5,
					
   input         PSO,

//	output [7:0]  LED,
	output [8:1]  ASIC_DATA,
	output        ASIC_CLOCK,
	output        ASIC_LATCH,
	output        ASIC_POLARITY,
   output        ASIC_BLANKING,
              
   output        WASTE,
	output        valve_on,
   output        heat_en,
   input         sreg_heat_en,
   input         heat_on,
	output        shdn_5v,
	output        shdn_120v,
	input         pzt_err_n,
	input         pzt_clim_n,	     
	output        amp_en,
	output        ok_led,
	output        jet_led,
	output        spare_led
	);
   
	parameter     sr_length = 32;                            // 32 long shift registers in Q heads, 64 long in D heads.
   parameter     power_delay = 48000000;                    // 1 second at 48 MHz clock frequency
	
   reg [31:0]    clk_div = 0;
	
   reg [6:0]     sr_div;
   reg [31:0]    out_shift[7:0];
	reg			  jet_enable_q, start_pulse;
	reg           start_waveform = 0;
      
   // Signal Assignments from input registers   
   wire          ext_encoder        = control_reg[0] || debug_control[0]; 
   wire          jet_enable         = control_reg[1] || debug_control[1];
	wire          loop_pattern       = control_reg[2] || debug_control[2];
	wire          power_on           = control_reg[3] || debug_control[3];
	wire          valve              = control_reg[4] || debug_control[4];
	wire          jet_all            =                   debug_control[5];
	wire          fixed_pattern      =                   debug_control[6];
   wire          heat               = control_reg[7] || debug_control[7];
	wire          jet_stand          =                   debug_control[8];  // Selects external encoder (PSO) to start waveform and 
                                                                           // uses Front_Panel editable waveform shape.
	
	reg  [31:0]   dac_ramp;
	wire [31:0]   segment [8:1];
	reg  [15:0]   segment_length, segment_slope;
	reg  [4:0]    i;
   // Was a reg 
	reg                      ASIC_CLOCK, ASIC_LATCH;
	reg [8:1]                ASIC_DATA;
   
   assign   version_reg = 32'h0001_0001; //  Major Version (if registers change) Minor Version (operation/bug

	// Power sequence
	// 5 Volts then 120 Volts then enable amplifier. 1 second delay between each step
	// The individual supplies wind up hiccuping until power is good as the 
	// capacitance is charged on the other side of the switch. The pzt_clim_n signal
	// winds up indicating error when the supplies are off and as they power up.
	// The pzt_clim_n signal is valid after the 120V supply is stable so I gate it with
	// the enable amplifier signal and it only indicates valid over current 
	// situations. 
   // MUST RAMP DAC UP AND DOWN TO AVOID JETTING WHEN RELAY CHATTERS
	reg enable_amp = 0;
   reg enable_5v = 0;
   reg enable_120v= 0;
	reg [31:0] delay_compare;
	assign   shdn_5v    = !enable_5v;
	assign   shdn_120v  = !enable_120v;	
	begin
	always @(posedge clk48mhz)
	if (rstn == 1'b0) begin
			enable_amp  <= 1'b0;
			enable_120v <= 1'b0;
			enable_5v   <= 1'b0;
		end
	else
	begin
		if (power_on) begin
			if (enable_5v == 0) begin
				enable_5v <= 1'b1;
				delay_compare <= clk_div + power_delay;
			end
			if ((enable_5v == 1'b1) && (enable_120v == 1'b0) && (clk_div == delay_compare ) ) begin
				enable_120v <= 1'b1;
				delay_compare <= clk_div + power_delay;
			end
			if ((enable_120v == 1'b1) && (clk_div == delay_compare))
				enable_amp <= 1'b1;
			end
		else
			begin // Power_on off
				if (enable_amp == 1'b1) begin
					enable_amp <= 1'b0;
					delay_compare <= clk_div + power_delay;	
				end
				if ((enable_amp == 1'b0) && (enable_120v == 1'b1) && (clk_div == delay_compare)) begin
					enable_120v <= 1'b0;
					delay_compare <= clk_div + power_delay;			
				end
				if ((enable_120v == 1'b0) && (clk_div == delay_compare))
					enable_5v <= 1'b0;
			end
		end
	end
	
	// Shared basic clocks
	reg	pos_x_q, pos_x_qq, PSO_pulse;
	always @(posedge clk48mhz)
	begin
	   clk_div        <= clk_div + 1;
		jet_enable_q   <= jet_enable;	
		start_pulse    <= !jet_enable_q && jet_enable;     // Make a single clock pulse from SW driven level
		pos_x_q        <= PSO;
		pos_x_qq       <= pos_x_q;
		PSO_pulse      <= !pos_x_qq && pos_x_q;            // Make a single pulse from the external PSO signal
	end
	
	// Transfer, allon and waveform timing
   // Provides 1 us delay between transfer and waveform start.
	reg    enable_allon, waveform_complete_q;
	reg [7:0] waveform_delay_cntr;
	
	always @(posedge clk48mhz)
	begin
		waveform_complete_q <= waveform_complete;		
		if (!waveform_complete_q && waveform_complete)
		   enable_allon <= 1;
		if (!transfer_complete_q && transfer_complete)
			waveform_delay_cntr <= 48;
		if (waveform_delay_cntr != 0)
			waveform_delay_cntr <= waveform_delay_cntr - 1;
		if (start_column)
		begin
			start_transfer <= 1;
			enable_allon   <= 0;
		end
		else
		if (waveform_delay_cntr == 1) 
			start_waveform <= 1;
		else
		begin
			start_waveform <= 0;
			start_transfer <= 0;
		end
	end
	wire [31:0] dc_value;
	assign segment[1] = (jet_stand) ? jet_stand1 : segment1;
	assign segment[2] = (jet_stand) ? jet_stand2 : segment2;
	assign segment[3] = (jet_stand) ? jet_stand3 : segment3;
	assign segment[4] = (jet_stand) ? jet_stand4 : segment4;
	assign segment[5] = (jet_stand) ? jet_stand5 : segment5;	
   assign segment[6] = (jet_stand) ? jet_stand6 : segment6;	
   assign segment[7] = (jet_stand) ? jet_stand7 : segment7;
   assign segment[8] = segment8;
	assign dc_value   = dc_value_reg;
	
	// Waveform generator
	// Creates a series of ramps and plateaus. Each segment has a length
	// and a slope. The slope is signed so it can be positive or negative.
	// An improvement will be to create a slow ramp back to DC value after 
	// the waveform is finished. Also to only move one 32 bit value by selecting 
	// it from the upper structure. 
   // Also can be started, while on the jetting stand, by a single PSO pulse
   always @(posedge clk48mhz or negedge rstn)
     begin
        if (rstn == 1'b0 || jet_enable == 1'b0) 
          begin
			//	strobe <= 0;
				i <= 1;
				dac_ramp <= dc_value;
            waveform_complete <= 1'b1;
				segment_length <= segment[1][15:0];
            segment_slope  <= segment[1][31:16];
			 end
			else
			if (start_waveform == 1'b1 || (jet_stand && PSO_pulse))
			begin 
				waveform_complete <= 1'b0;
				segment_length <= 0;
				i <= 1;
			end
			else
			if (waveform_complete == 1'b0)
				begin
					if (i == 2)
					begin
					//	strobe <= 1;
					end	
					else
					begin
					//	strobe <= 0;
					end
					if (segment_length == 0)
						begin
							segment_length <= segment[i][15:0];
							segment_slope  <= segment[i][31:16];
							if ( i <= 8 )
									i <= i + 1;
							else
							begin
								// Completed all segments
								waveform_complete <= 1'b1;				// Finish and stop waveform, one pass
								dac_ramp <= dc_value;    // Slam DAC value back midpoint (needs cleaning)
							end
						end	
					else
						begin
							segment_length <= segment_length - 1;
							dac_ramp <= dac_ramp + {{16{segment_slope[15]}}, segment_slope};
						end
				end
			end

   // Assign output signals
	assign 	dac         = dac_ramp[22:7];  // Dac output from waveform generator.
	// Opal Kelly board LED    D9      D8             D7:6        D5               D4               D3           D2 (blinky)
  // assign   LED         = { !heat_on,!sreg_heat_en, i[1:0] ,   1'b1       , 1'b0             , start_column,   clk_div[24]} ;
	assign 	ok_led      = !( pzt_err_n && pzt_clim_n);  // Power is on and OK
   assign   jet_led     = !( print_active && clk_div[23]);
	assign   valve_on    = valve;
   assign   heat_en     = heat;
   assign   spare_led   = ext_encoder;                  // Idle jetting when we are using clock and ext_encoder is low
		
   assign   ASIC_POLARITY  = 1'b1;
   assign   ASIC_BLANKING  = !jet_all;      
   assign   WASTE       = debug_control[7] ;
 //  assign   spare       = clk_div[10:9];
	assign   amp_en      =  ! enable_amp;  // Using the NO contact, turn relay off to enable amplifier
   assign   status_reg  = {16'h1234,pattern_addr[7:0],4'b1010,1'b0,1'b1,!pzt_err_n,!pzt_clim_n};
	assign   pattern_addr = pattern_addr_reg;  // Passes address (column) up to actual RAM storage
   assign   nozzle_addr  = nozzle_addr_reg;
	assign   debug_status = {pattern_addr[3:0],divide_counter[3:0],delay_counter[3:0],
	   //   pattern_active, delay_active,1'b0,!pzt_err_n,
			enable_amp,enable_120v,!pzt_err_n,!pzt_clim_n};	
	
   assign   monitor1    =  {16'h1234};
   assign   monitor2    =  segment2;
   assign   monitor3    =  segment3;
   assign   monitor4    =  segment4;
	assign   monitor5    =  pattern_column[31:0];
  
	reg 			start_transfer = 0;
   

// assign spare[1] = PSO_pulse;

//-----------------------------------------------------------------------
// Master State Machine 11/19 PMH
//    Moved out to seperate module to enhance simulation
//    Changing to pure trigger table operation to handle dither for 
//    interferometer. At Dominique's suggestion.
//-----------------------------------------------------------------------
wire [15:0] pattern_counter;
wire [31:0] delay_counter;
wire [31:0] divide_counter;

	Master_State Master(
		.clk48mhz(clk48mhz),
      .rstn(rstn),
      .jet_enable(jet_enable),
      .start_pulse(start_pulse),
      .start_column(start_column),
      .loop_pattern(loop_pattern),
      .ext_encoder(ext_encoder),
      .count_enable_x(PSO_pulse),
      .length_reg(length_reg),
      .divider_reg(divider_reg),
      .delay_reg(delay_reg),
      .print_active(print_active),
      .delay_counter(delay_counter),
      .divide_counter(divide_counter),
      .pattern_counter(pattern_counter),
      .pulse_counter(pulse_counter),
      .max_delay(max_delay),      
      .adjust_column(adjust_column)
		 );

   // Serial data out to the ASICs in the printhead
   // There are 8 32 bit long shift registers with a latch to move 
	// the values out to control the nozzles. 256 bits from the memory.
	// The timing is 1 ns setup needed and a maximum (?) of 22 ns of hold. 
	// So change the data on the negative clock. The maximum clock 
	// rate is 16 MHz. There is no minimum clock rate. Typ is 4 MHz.
   // So divide the 48 MHz by eight. Takes less than 6 us 
	// to clock all 32 bits into the registers. I will do it before
	// each cycle. Avoids the priming problem for the first column.
	// When transfer is complete, latch, then a 1 us pause, report complete 
	// and the master controller starts the waveform generator.
   // Looks like Q wants data changed on rising edge and uses falling 
   // edge of clock to shift in.
   
   // Distribute the even and odd nozzle values to go into seperate shift registers for Q
   // The 256 bit wide pattern_column is in print order as it will go onto the chip. 
   // Q heads are like two 128 nozzle heads operating adjacent, the evens and the odds. 
   // The data has to be split up before sending it over, the evens and the odds. 
   
   // Big addition to be done is 16 print fills and pulses. Nozzle adjust address will be
   // which column we are on. Then the nozzle adjust array will be filled with which nozzles to 
   // enable, just like pattern_column. 
   
   // The nozzle adjust memory will be used here, after a start_transfer command from the master state
   // machine. The nozzle memory is initialized with all nozzles active at location 7 so when the 
   // testing prints are made there will be adjustment possible in both directions. 
   // The distance between each nozzle column will be 8 PSO pulses or 1.58 um. 
   
   wire     [255:0] even_odd_interleave;
   wire     [255:0] enabled_nozzles;                  // Combination of nozzle_adjust and pattern_column in nozzle order
   
   assign   enabled_nozzles = pattern_column & nozzle_column;                 // 

genvar g,h;
generate
   for (h=0; h<4  ; h=h+1) begin
      for (g=0; g<32 ; g=g+1) begin
         assign even_odd_interleave[h*64+g]     = enabled_nozzles[h*64+g*2+0];  // Mapping from nozzle order to Dimatix shift registers
         assign even_odd_interleave[h*64+g+32]  = enabled_nozzles[h*64+g*2+1];  // Loading the next shift register from every other bit
      end
	end
endgenerate

  reg 	      transfer_complete, transfer_complete_q;	
  reg  [2:0]   asic_clk_q;
  reg [15:0]   pattern_addr_reg = 0;
  reg  [3:0]   nozzle_addr_reg = 0;
  reg			   waveform_complete = 1;

   always @(posedge clk48mhz)
     begin
	  if (rstn == 1'b0  || jet_enable == 1'b0) begin
			transfer_complete <= 1;
			pattern_addr_reg  <= 0;
         nozzle_addr_reg   <= 0;
     end
	  else
     if (start_transfer) begin            // Resync on rising edge of sync pulse 
		  transfer_complete <= 0;
        nozzle_addr_reg   <= 0;           // Start at the 0th nozzle column
		  pattern_addr_reg  <= pattern_counter;	// Update address after loading local shift registers
        sr_div <= 0;
		  asic_clk_q <= 2'b11;              // Prime to send out first data on first clock rising edge
		  ASIC_CLOCK <= 1'b1;
        end
     else
	  begin
	  	  transfer_complete_q <= transfer_complete;
		  ASIC_LATCH <= !transfer_complete_q && transfer_complete;
		  asic_clk_q <= asic_clk_q + 1;
	     if (transfer_complete == 0)
        begin
        ASIC_CLOCK   <= asic_clk_q[1];
        if (asic_clk_q[1:0] == 0)
          begin		 
             if (sr_div == sr_length-1)
                begin
                   transfer_complete <= 1'b1;           
                end
             else
                begin
                   out_shift[0]  <= {out_shift[0][30:0], 1'b0}; // Shifting MSB into printhead first
                   out_shift[1]  <= {out_shift[1][30:0], 1'b0};
                   out_shift[2]  <= {out_shift[2][30:0], 1'b0};
                   out_shift[3]  <= {out_shift[3][30:0], 1'b0};
                   out_shift[4]  <= {out_shift[4][30:0], 1'b0};
                   out_shift[5]  <= {out_shift[5][30:0], 1'b0};
                   out_shift[6]  <= {out_shift[6][30:0], 1'b0};
                   out_shift[7]  <= {out_shift[7][30:0], 1'b0};                   
						 sr_div <= sr_div + 1;
                end
           end
		  else
		    begin  // Change data on rising edge of clock
	         ASIC_DATA  <= {out_shift[7][31], out_shift[6][31], out_shift[5][31], out_shift[4][31],
                           out_shift[3][31], out_shift[2][31], out_shift[1][31], out_shift[0][31]};			  
		    end
     end
     else
	  begin  // Transfer complete == 1, between columns, load the shift registers
	     ASIC_CLOCK <= 1'b1;
        // Unusual mapping by Dimatix, Data1 for jets 1-63, Data5 for jets 2-64.
        // Things get a little bit confusing due to 0 to 1 mapping. 
	     ASIC_DATA  <= { out_shift[7][31],                // Jets #194-256
                        out_shift[5][31],                // Jets #130-192
                        out_shift[3][31],                // Jets #66-128
                        out_shift[1][31],                // Jets #2-64
                        out_shift[6][31],                // Jets #193-255
                        out_shift[4][31],                // Jets #129-191
                        out_shift[2][31],                // Jets #65-127
                        out_shift[0][31]};               // Jets #1-63
  		  if (fixed_pattern) begin
				out_shift[0] <=  {clk_div[25],7'h73,clk_div[25],7'h72,clk_div[25],7'h71,clk_div[25],7'h70};   // Nozzles active and toggling
		      out_shift[1] <=  {clk_div[25],7'h77,clk_div[25],7'h76,clk_div[25],7'h75,clk_div[25],7'h74};   // for the jetting stand.
				out_shift[2] <=  {clk_div[25],7'h7b,clk_div[25],7'h7a,clk_div[25],7'h79,clk_div[25],7'h78};   // 
		      out_shift[3] <=  {clk_div[25],7'h7f,clk_div[25],7'h7e,clk_div[25],7'h7d,clk_div[25],7'h7c};   // 
				out_shift[4] <=  {clk_div[25],7'h83,clk_div[25],7'h82,clk_div[25],7'h81,clk_div[25],7'h80};   //  
		      out_shift[5] <=  {clk_div[25],7'h87,clk_div[25],7'h86,clk_div[25],7'h85,clk_div[25],7'h84};   // 
				out_shift[6] <=  {clk_div[25],7'h8b,clk_div[25],7'h8a,clk_div[25],7'h89,clk_div[25],7'h88};   //  
		      out_shift[7] <=  {clk_div[25],7'h8f,clk_div[25],7'h8e,clk_div[25],7'h8d,clk_div[25],7'h8c};   //             
       
		  end
		  else 
	     begin         
		     out_shift[0] <= even_odd_interleave[31:0];                         // Odd Nozzles #1-63 
		     out_shift[1] <= even_odd_interleave[63:32];                        // Even Nozzles #2-64
           out_shift[2] <= even_odd_interleave[95:64];                        // Odd Nozzles #65-127
           out_shift[3] <= even_odd_interleave[127:96];                       // Even Nozzles #66-128
           out_shift[4] <= even_odd_interleave[159:128];
           out_shift[5] <= even_odd_interleave[191:160];
           out_shift[6] <= even_odd_interleave[223:192];
           out_shift[7] <= even_odd_interleave[255:224];
		  end
	  end	  
   end 
end	  
        
endmodule
