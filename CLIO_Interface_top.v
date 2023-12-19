//------------------------------------------------------------------------
// CLIO_Interface_top.v
//
// Verilog source for the control of a CLIO chip.
//
//
// Revisions     3.4 - Fixed pattern ram addressing on app side
//
// Things to fix:
//               
// ti_clk is 48 MHz
//
//------------------------------------------------------------------------

`default_nettype none
`timescale 1ns / 1ps

module CLIO_Interface_top(
	input  wire [7:0]  hi_in,
	output wire [1:0]  hi_out,
	inout  wire [15:0] hi_inout,
	inout  wire        hi_aa,
	
	output wire [9:1]  debug,        // To TAG Connect header
   output wire [15:0] logic_anal,   // To posts for logic analyzer
   output wire [1:0]  logic_clk,    // Clock lines to logic analyzer
   
   output wire        DAC_CLK,      // Flowcell lid DAC, also called out of plane
   output wire        DAC_SYNC_N,
   output wire        DAC_DATA,
	
   output wire        ADC_CS_N,     // Data acquistion ADC with diff inputs and
   output wire        ADC_CLK,      // variable gain amplifiers. 8 channels.
   input wire         ADC_SDO,
   output wire        ADC_SDI,
   output wire        ADC_RST_N,
   
	input  wire        pzt_clim_n,   // Excess current on +120 or +5 to head
	output wire        shdn_5v,      // Turns off +5 to head
	output wire        shdn_120v,    // Turns off +120 to head
	input  wire        pzt_err_n,    // Excess DC current through head
    
	output wire        strobe,
	output wire [2:1]  spare_,
   input  wire        DAC_EN_IN,    // Square wave from NI DAQ, forwarded to CLIO, different pin on different vintages
  // input  wire [2:1]  pd,           // Adjacent pins, also pulldown 
   input  wire [1:0]  version,      // Pins near ground, = 11 for CLIO 2, 01 for CLIO 3
   output wire        waste2,
	output wire        i2c_sda,
	output wire        i2c_scl,
	output wire        hi_muxsel,

	input  wire        clk1,
	output wire [7:0]  led,
	output wire        waste,
	output wire        valve_on,              // Turns on purge valve, pushes ink through head to prime
   output wire        float_flow,            // Disconnects voltage setting to flow cell lid
	output wire        ok_led,
	output wire        fc_top_led,
	output wire        power_led,
   output wire        heat_on,
   output wire        amp_en,                // When high, opens relay to enable amp
	output wire        asic_clk,
   output wire        DAC_EN_OUT,            // Output to SMA for testing
             
   output wire        CLIO_RSTN,             // Global reset for CLIO   
   output wire        DAC_EN,                // Global external DAC enable line, to allow pulsing.
   output wire        MCLK,                  // Master, fastest, clock to CLIO                
	output wire [7:0]  asic_data,             // Actual data to CLIO synth locations
   output wire        FRAME,
   output wire        CCLK,
   input  wire        SPI_MISO,              // New SPI input wire
   output wire        SPI_MOSI,              // Actual SPI output wire to chip
   output wire        SPI_SCLK,              // Actual SPI clock wire
   output wire        SPI_CS,                // CS to CLIO, active low
   output wire        VSSN_EN,               // Turns on -1.0V supply 
   output wire        VSS22N_EN,             // Turns on -2.2V supply for DACs on CLIO
   output wire        VDD_EN,                // Turns on  1.0V supply for logic on CLIO (First)
   output wire        VDD15_EN,              // Turns on  1.5V supply for HSTL interface on CLIO
   output wire        VDD22_EN,              // Turns on  2.2V supply for DACs on CLIO
   output wire        VDD18_EN_N,            // Turns on  1.8V supply for HSTL interface on CLIO, active low, into PMOS
   output wire        VTT_EN,                // Turns on  0.75 supply for termination voltage for HSTL interface
 //	output wire        adc_cs,
	output wire        adc_chsel,
 //	output wire        adc_clk,
 //	input  wire        adc_dout, 
 //  input  wire        K_A_INPUT,             // Trigger signal from K & A Synthesizer
 //	output wire [13:0] dac,                   // New 14 bit Twist Bio Inkjet DAC   
	output wire        dac_clk						// and its clock.     
	);

wire        ti_clk;
wire [30:0] ok1;
wire [16:0] ok2;

wire [15:0] WireIn10, WireIn11, WireIn12, WireIn13, WireIn14, WireIn15, WireIn16, WireIn17;
wire [15:0] WireIn18, WireIn19, WireIn1A, WireIn1B, WireIn1C, WireIn1D, WireIn1E, WireIn1F;
wire [15:0] TrigIn40, TrigIn41, TrigIn42, TrigIn43, TrigIn44, TrigIn45, TrigIn46, TrigIn47;
wire [15:0] TrigIn48, TrigIn49, TrigIn4A, TrigIn4B, TrigIn4C, TrigIn4D, TrigIn4E, TrigOut60;

wire [11:0] pattern_addr;               // For 4096 printing columns
wire [3:0]  nozzle_addr;                // For 16 nozzle adjust columns
wire        pattern_reset,  pattern_write, pattern_read;
wire [15:0] pattern_r_data, pattern_w_data;
reg  [14:0] pattern_u_addr;

wire        adjust_reset,  adjust_write, adjust_read;
wire [15:0] adjust_r_data, adjust_w_data;

reg  [11:0] adjust_u_addr;
reg         flow_write, flow_read, flow_v_write;
reg  [14:0] flow_w_addr = 0;
reg  [14:0] flow_vw_addr = 0;                                 // Address to capture values in smaller memory
reg  [14:0] flow_r_addr, flow_v_addr;                         // Reading from the backside of dual port RAM
wire [15:0] flow_counter, flow_w_data, flow_r_data;           // Number of entries in flowcell current FIFO.
wire [15:0] flow_v_data;                                      // Flow cell voltage data from dual port memory. 
wire        flow_v_read;                                      // Pulses as voltage values are read from computer side

wire        nozzle_reset,  nozzle_write, nozzle_read;
wire [15:0] nozzle_r_data, nozzle_w_data;
reg  [11:0] nozzle_u_addr;

wire        reg_reset, reg_write, reg_read;
wire [15:0] reg_r_data, reg_w_data;
reg  [9:0]  reg_r_addr, reg_w_addr;

reg  [15:0] reg_low_store;

wire        sreg_reset, sreg_write, sreg_read;
wire [15:0] sreg_r_data, sreg_w_data;
reg  [9:0]  sreg_r_addr, sreg_w_addr;

reg  [15:0] sreg_low_store;

wire        cpu_dac_enable, cpu_prbs_select, cpu_clock_invert;
wire        frame_int;

wire [31:0] reg_dev_status;
reg  [31:0] reg_dev_control;
reg  [31:0] sreg_dev_control = 0;
wire [31:0] reg_fpga_version;
wire [31:0] reg_pulse_counter;
wire [31:0] reg_max_delay;

reg  [31:0] reg_divider  = 32'h0000_0020;    // 1300 Hz based on 48 MHz clock (Titan)
reg  [31:0] reg_dc_value = 32'h0006_0000;    // Minimal, 4 V
// Pre-load the simple 5 segment waveform for use on jetting stand
reg  [31:0] reg_segment1 = 32'h3400_0071;   // Slope_Length
reg  [31:0] reg_segment2 = 32'h0000_00A4;    // 3.5 us plateau, according to Stephanie
reg  [31:0] reg_segment3 = 32'hcc00_0071;
reg  [31:0] reg_segment4 = 32'h0000_005A;
reg  [31:0] reg_segment5 = 32'h0000_0071;
reg  [31:0] reg_segment6 = 32'h0000_0088;
reg  [31:0] reg_segment7 = 32'h0000_0000;
reg  [31:0] reg_segment8 = 32'h0000_0100;    // 5 usec between pulses.
reg  [31:0] reg_adc_setpoint = 930;          // 30 degree C setpoint
reg  [31:0] reg_adc_value , reg_adc_hs_value;
wire [15:0] adc_value, adc_hs_value;
wire [31:0] jet_stand1, jet_stand2, jet_stand3, jet_stand4;
wire [31:0] jet_stand5, jet_stand6, jet_stand7, jet_stand8;
wire [31:0] dac_act1, dac_act2, dac_act3, dac_act4, dac_act5;

wire [255:0] pattern_column;
wire [15:0]  adjust_column;
wire        drive_flow,internal_select_dac_en,heat_en,below;
wire        internal_dac_en;
reg   [8:0] rst_counter = 0;
reg         rstn = 0;

always @ (posedge ti_clk)
   begin
      if (rst_counter != 8'hff)
         begin
            rstn <= 1'b0;  
            rst_counter <= rst_counter + 1; 
          end
       else
          begin
             rstn <= 1'b1;
          end
   end

// Need to keep the router happy by creating a clock signal to 
// be sent outside. Need to check the actual clock edges for 
// the DAC. 
ODDR2 ODDR2_inst(
 .D0(1), .D1(0), .C0(ti_clk), .C1(~ti_clk), .Q(dac_clk) );
// Flipped clock phase back, didn't help to get centered in data
// Problem was they did not document the need for >8 MCLK long CCLK signal  
// MCLK goes to zero when CPU power shutdown

ODDR2 ODDR2_CLIO(
  .D0((~cpu_clock_invert && !cpu_power_shutdown)), .D1(cpu_clock_invert && !cpu_power_shutdown), .C0(ti_clk), .C1(~ti_clk), .Q(MCLK) );
// Could provide signal based flipping of clocks by putting the signal into
// the D0 and D1 ports. 
 
ODDR2 ODDR2_debug1(
  .D0((~cpu_clock_invert && !cpu_power_shutdown)), .D1(cpu_clock_invert && !cpu_power_shutdown), .C0(ti_clk), .C1(~ti_clk), .Q(debug[1]) );

wire   sreg_heat_en = sreg_dev_control[0];
wire adc_cs;
//assign ADC_CLK   = adc_clk; // Connections to 8 channel ADC ADS8688
//assign ADC_CS_N  = !adc_cs;  // 
//assign ADC_SDI   = (clk_div[26]^clk_div[10]^clk_div[11]);// ? 1'bz : 1'b0 ;
//assign ADC_RST_N = rstn;
//assign adc_dout  = ADC_SDO; // Data coming in ADC

assign heat_on   = below && (heat_en || sreg_heat_en) || ADC_SDO ;

always @(posedge ti_clk) 
begin
  reg_adc_value <= adc_value;
  reg_adc_hs_value <= adc_hs_value;
end

OOP_DAC dac_interface(
    .clk48mhz(ti_clk),
    .rstn(rstn),    
    .OOP_DAC_VALUE(OOP_DAC),        // Word written to the DAC 
    .DAC_CLK(DAC_CLK),
    .DAC_DATA(DAC_DATA),
    .DAC_SYNC_N(DAC_SYNC_N)
    );

wire [15:0] adc_value0;
wire [15:0] adc_value1;
wire [15:0] adc_value2;
wire [15:0] adc_value3;
wire [15:0] adc_value4;
wire [15:0] adc_value5;
wire [15:0] adc_value6;
reg [15:0] adc_value7 = 7;

// Serial connection to octal ADC
// Minimum gain at the moment but the noise is already a few bits
octal_adc_interface current_adc(
    .clk48mhz(ti_clk),
    .rstn(rstn),
    .channel0(adc_value0),
    .channel1(adc_value1),
    .channel2(adc_value2),
    .channel3(adc_value3),
    .channel4(adc_value4),
    .channel5(adc_value5),    
    .channel6(adc_value6),
    .ADC_CLK(ADC_CLK),
    .ADC_CS_N(ADC_CS_N),
    .ADC_SDI(ADC_SDI),
    .ADC_RST_N(ADC_RST_N),
    .ADC_SDO(ADC_SDO)
    );
    
// Instantiate the module
DAC_Enable_Pulse_Gen internal_dac_enable(
    .clk48mhz(ti_clk), 
    .rstn(rstn), 
    .Trigger(cpu_dac_enable), 
    .On_Length(WireIn13), 
    .Off_Length(WireIn14), 
    .Number_Of_Pulses(WireIn15), 
    .clk_1ms(clk_1ms),
    .Internal_DAC_Enable(internal_dac_en)
    );

   
wire [15:0] OOP_DAC, OOP_DAC_Enabled;
// DAC value sent out is always from the OK values when internal dac en is low.
assign OOP_DAC_Enabled = internal_dac_en ? WireIn12 : 16'h7fff ; // When DAC Enable is low, set OOP Dac to 0 volts (midscale)
assign OOP_DAC = internal_select_dac_en  ? OOP_DAC_Enabled : WireIn12;

assign DAC_EN = internal_select_dac_en ? internal_dac_en : dac_en_filt;
assign DAC_EN_OUT = DAC_EN;                  // Goes to SMA P12 for testing

reg dac_ext_r, dac_ext_rr, dac_en_filt;
always @(posedge ti_clk)
begin
   if (clk_1ms == 1)
   begin
      dac_ext_r <= DAC_EN_IN;
      dac_ext_rr <= dac_ext_r;
      dac_en_filt <= dac_ext_r & dac_ext_rr;
   end
end

      
reg dac_en_r = 0;
reg dac_en_rr = 0;
reg dac_en_pulse =0;
reg flow_count_en = 0;
wire clk_1ms;

always @(posedge ti_clk)
begin
  // if (rstn)
   begin
      dac_en_r <= cpu_dac_enable && internal_select_dac_en;
      dac_en_rr <= dac_en_r;
      dac_en_pulse <= dac_en_r && !dac_en_rr;
      if (dac_en_pulse == 1)
      begin
         flow_w_addr <= 0;
         flow_count_en <= 1;
         flow_r_addr <= 1;   // Reset read pointer for flowcell currents
         flow_v_addr <= 1;   // Reset read pointer for flowcell voltages 
      end
      else
      if (clk_1ms == 1) 
      begin
         if (flow_count_en) //(flow_w_addr < 16002)) // && flow_count_en)
         begin
            flow_write <= 1;
            flow_w_addr <= flow_w_addr + 1;
            if (flow_w_addr > 16000)
               flow_count_en <= 0;
         end
      end
      else
      begin      
         flow_write <= 0;
         // flow_count_en <= 0;
      end
      if (pattern_read == 1'b1)
         flow_r_addr <= flow_r_addr + 1;
      if (flow_v_read == 1'b1)
         flow_v_addr <= flow_v_addr + 1;
   end
end

/* always @(posedge ti_clk)
begin
   if (dac_en_pulse == 1)
   begin
      flow_vw_addr <= 0;
      flow_v_addr <= 1;
   end
   else
   if (clk_1ms == 1)
   begin
      if (flow_vw_addr < 8002)
      begin
         flow_v_write <= 1;
         flow_vw_addr <= flow_vw_addr + 1;
      end
   end
   else
      flow_v_write <= 0;
   if (flow_v_read == 1'b1)
      flow_v_addr <= flow_v_addr + 1;
end */
   

// pattern_read is high for each read of flowcell current


dpram_32k_a16_b16 flowcell_current_log (
  .clka(ti_clk),                 // input clka
  .wea(flow_write),              // input [0 : 0] wea
  .addra(flow_w_addr),           // input [13 : 0] addra
  .dina(adc_value5),             // input [15 : 0] dina
  .clkb(ti_clk),                 // input clkb
  .enb(1),                       // input [0 : 0] B side is always enabled
  .addrb(flow_r_addr),           // input [13 : 0] addrb
  .doutb(flow_r_data)            // output [15 : 0] doutb
);
  
// pattern_read is high for each read of flowcell voltage
dpram_8k_a16_b16 flowcell_voltage_log (
  .clka(ti_clk),                 // input clka
  .wea(flow_write),              // input [0 : 0] wea
  .addra(flow_w_addr[13:1]),     // input [12 : 1] addra, only advances every other millisecond
  .dina(adc_value6),             // input [15 : 0] dina, the ADC value for the flowcell voltage
  .clkb(ti_clk),                 // input clkb
  .enb(1),                       // input [0 : 0] B side is always enabled 
  .addrb(flow_v_addr),           // input [12 : 0] addrb
  .doutb(flow_v_data)            // output [15 : 0] doutb
);
// 16k locations was too big to fit  

   
   
wire cpu_power_shutdown;
wire dac_only;

//assign spare[2] = pzt_clim_n;
//assign spare[1] = pzt_err_n;   
         
assign cpu_dac_enable         = WireIn10[0];  // Controlled by cpu to toggle dacs and make pulse waveforms
assign cpu_prbs_select        = WireIn10[1];  // Controlled to select PRBS for BER testing
assign cpu_clock_invert       = WireIn10[2];  // Controlled to invert MCLK going to CLIO
assign cpu_power_shutdown     = WireIn10[3];  // Turns off all power supplies to the CLIO
assign clear_transfer_counter = WireIn10[4];  // Clears the SPI transaction counter
assign dac_only               = WireIn10[5];  // Only send 1 column to frame buffer, the DAC values 
assign drive_flow             = WireIn10[6];  // Disconnect Flow Cell drive and turn off LED
assign internal_select_dac_en = WireIn10[7];  // Generate DAC Enable pulses using internal pulse generator (ignoring NI)
assign reg_reset     = TrigIn44[0];
assign pattern_reset = TrigIn45[0];
assign sreg_reset    = TrigIn46[0];
assign adjust_reset  = TrigIn47[0];
assign nozzle_reset  = TrigIn48[0];

/*   
// Instantiate the pattern RAM, 128 KBytes, 16 bit on USB side, 256 bit on Application side

always @(posedge ti_clk) 
begin
	if (pattern_reset == 1'b1) begin
		pattern_u_addr <= 0;
	end 
   else 
   begin
		if ((pattern_write == 1'b1) || (  pattern_read == 1'b1))
			pattern_u_addr <= pattern_u_addr + 1;
	end
end
 		
wire [255:0] app_rddata;  
assign pattern_column = app_rddata;
// Instantiate the RAM
dpram132K_a16_b256 pattern_ram(.clk(ti_clk),             // Common clock
                          .wea(pattern_write),         
                          .addra(pattern_u_addr),
                          .dia(pattern_w_data),
                          .doa(pattern_r_data), 
                          .addrb(pattern_addr),
                          .dob(app_rddata));             
*/

// Instantiate the adjust RAM, 8 KBytes, 16 bit on USB side, 16 bit on Application side
// It uses the same read address from the Application side as the pattern memory since
// both the pattern and the location adjustment are on the same column. 



always @(posedge ti_clk) 
begin
	if (adjust_reset == 1'b1) begin
		adjust_u_addr <= 0;
	end 
   else 
   begin
		if ((adjust_write == 1'b1) || (  adjust_read == 1'b1))
			adjust_u_addr <= adjust_u_addr + 1;
	end
end
 		
wire [15:0] adj_rddata;  
assign adjust_column = adj_rddata;
/* // Instantiate the RAM
dpram8K_a16_b16 adjust_ram(.clk(ti_clk),             // Common clock S
                          .wea(adjust_write),         
                          .addra(adjust_u_addr),
                          .dia(adjust_w_data),
                          .doa(adjust_r_data), 
                          .addrb(pattern_addr),  // Same column as pattern 
                          .dob(adj_rddata)); 
*/                                                    
                                                

   reg  [31:0] reg_length   = 2250;    // 2250 bytes in a column, 18,000 bits 0x8ca
   reg  [31:0] reg_delay    = 10001;   // Number of columns in frame buffer, 10,000 switch + 1 DAC 
   wire [15:0] read_byte_count, read_count;
   wire [15:0] write_word_count; 
   wire [7:0] dout;   
   wire frame_rd_en;      
   wire dac_ready;
/* FIFO moved into Frame State machine to handle byte swizzling
// FIFO created by Core Generator, doesn't work when asked to do 16 to 8 conversion   
// Frame FIFO to load the switches in the CLIO switch matrix
// Also does the 16 bit to 8 bit conversion
// Needs two clock inputs to do width conversion.

fifo_16w_32768deep frame_fifo(
  .rst(rst),                        // input rst
  .clk(ti_clk),                     // input wr_clk
  //.rd_clk(ti_clk),                // input rd_clk
  .din(adjust_w_data),              // input [15 : 0] din
  .wr_en(adjust_write),             // input wr_en
  .rd_en(frame_rd_en),              // input rd_en
  .dout(dout),                      // output [15 : 0] dout
  .full(),                          // output full
  .empty(),                         // output empty
  .data_count(read_count)          // output [15 : 0] rd_data_count
//  .data_count(write_word_count)     // output [14 : 0] wr_data_count, useless, need to look at read side
);
   
assign read_byte_count = read_count << 1; 
assign write_word_count = read_count;

*/
// New request, load only the first column of the frame buffer, the DAC values, by
// creating a new FRAME pulse
// Dominique request to try ramping up the DAC values.

always@(posedge ti_clk)
begin
   if (dac_only)
      reg_delay <= 1;     // Just send the 1 DAC column
   else
      reg_delay <= 10001; // # of columns in frame buffer, 10,000 switch columns + 1 DAC column
end

Frame_State frame_state(
   .rst(rst),
   .ti_clk(ti_clk),
   .din(adjust_w_data),
   .wr_en(adjust_write),
   .dout(dout),
   .reg_length(reg_length),
   .reg_delay(reg_delay),
   .read_byte_count(read_byte_count),
   .frame_rd_en(frame_rd_en),
   .dac_ready(dac_ready),
   .FRAME(frame_int),
   .frame_state(fr_state),
   .CCLK(CCLK)
   );
   
wire [2:0] fr_state;
//assign debug[9:2] = {asic_data[4:0], CCLK, FRAME};       

reg [31:0] tx_counter = 32'h0000_0000; // Counter of bytes sent to CLIO
reg cclk_reg; 
reg [15:0] cclk_counter = 0;

always @(posedge ti_clk)
begin
   cclk_reg <= CCLK;
   if (FRAME == 1'b1)
   begin
      tx_counter <= 0;
      cclk_counter <= 0;
   end
   else
   begin
   if (frame_rd_en == 1'b1)
   begin
      tx_counter <= tx_counter + 1;
   end
   if (CCLK==1 && cclk_reg == 0) 
   begin
      cclk_counter <= cclk_counter + 1;
   end
   end
end

assign asic_data = (cpu_prbs_select)? col     : dout; //WireIn12[7:0] ; // col[7:0]; // col    // Toggle all switches
assign FRAME     = (cpu_prbs_select)? frame_r : frame_int; 


assign CLIO_RSTN = (cpu_power_shutdown)? 0 : rstn;      // Turn off line when power is shutdown

// assign DAC_EN = cpu_dac_enable && dac_ready;
// DAC_EN_IN input moves between CLIO2 to CLIO3, select the correct one based on version pins
//assign DAC_EN = (version[1])? DAC_EN_IN[2] : DAC_EN_IN[3] ;       // Signal from NI DAQ forwarded to CLIO chip.

//assign DAC_EN = DAC_EN_IN;                                       // Only version 3 boards, FPGA pins used for logic analyzer

// P(x) = x^8+x^6+x^5+x^4+1 
   
// For now, turning on all power supplies.   
assign VSSN_EN    = (cpu_power_shutdown)? 0 : 1;
assign VSS22N_EN  = (cpu_power_shutdown)? 0 : 1;
assign VDD_EN     = (cpu_power_shutdown)? 0 : 1;
assign VDD15_EN   = 1; // (cpu_power_shutdown)? 0 : 1;  // Leave 1.5V active to run the ADC
assign VDD22_EN   = (cpu_power_shutdown)? 0 : 1;
assign VDD18_EN_N = (cpu_power_shutdown)? 1 : 0;
assign VTT_EN     = (cpu_power_shutdown)? 0 : 1; 
assign power_led  = (cpu_power_shutdown)? 1 : 0;

assign fc_top_led = ~drive_flow;                      // Turns active low LED on when flow cell is driven,
                                                      // the analog switch is normally open. This keeps the cathode from
                                                      // being driven to -2.5V at power up.
assign float_flow = (~drive_flow)? 1'bz : 1'b0;       // Invert the signal to control the external analog switch. 
                                                      // Need to make it open drain to pullup to 3V for switch operation.
assign ok_led     = o_SPI_MOSI;                       // Indicates SPI activity

// Turning off SPI outputs when power is turned off. Could solve the latchup problem.
assign SPI_SCLK   = (cpu_power_shutdown)? 0 : o_SPI_CLK;
//assign spare[1] = o_SPI_MOSI;
assign SPI_MOSI   = (cpu_power_shutdown)? 0 : o_SPI_MOSI;                                    
assign SPI_CS     = (cpu_power_shutdown)? 0 : rr_TX_Ready; //o_SPI_CS_n;      

assign strobe = o_SPI_MOSI; 
assign spare_[2] = o_SPI_CLK;
assign spare_[1] = rr_TX_Ready;
assign i_SPI_MISO = SPI_MISO;  
   
reg [34:0] clk_div = 0;
reg [7:0]  col;
reg      frame_r;
wire     fb;

assign fb=col[7]^col[5]^col[4]^col[3];

always @(posedge ti_clk)
begin
   clk_div <= clk_div + 1;
   if (clk_div[25:0] == 0)
      begin
         frame_r <= 1'b1;
         col     <= 8'h55;             // Create a pattern with 0s and 1s. Will be reported back.
      end
   else
      begin
         frame_r <= 1'b0;
         col     <= {col[6:0], fb};     // Shift in the new feedback value to make prbs pattern
      end
end
                                              
                                                  
// Instantiate the Nozzle RAM, 2 KBytes, 16 bit on USB side, 256 bit on Application side
// The read address from the Application side advances 16 times for each pattern column
// It repeats at each pattern column location. Designed to compensate for Y-Bow.

always @(posedge ti_clk) 
begin
	if (nozzle_reset == 1'b1) begin
		nozzle_u_addr <= 0;
	end 
   else 
   begin
		if ((nozzle_write == 1'b1) || (  nozzle_read == 1'b1))
			nozzle_u_addr <= nozzle_u_addr + 1;
	end
end
 		
wire [15:0] noz_rddata, nozzle_column;  
assign nozzle_column = noz_rddata;
// Instantiate the RAM
/*
dpram2K_a16_b256 nozzle_ram(.clk(ti_clk),             // Common clock
                          .wea(nozzle_write),         
                          .addra(nozzle_u_addr),
                          .dia(nozzle_w_data),
                          //.doa(nozzle_r_data),           // Stolen for FIFO testing 
                          .addrb(nozzle_addr),           // Generated near main pulse 
                          .dob(noz_rddata)); 
*/
// Opal Kelly board LED    D9          D8         D7         D6            D5         D4        D3      D2 (blinky)
assign   led         = { ~DAC_EN,~version[1], ~version[0], ~SPI_SCLK, ~SPI_MISO, ~SPI_CS, ~SPI_MOSI, clk_div[24]} ;

assign waste2 = version[1] && version[0];   // Adjacent pins to DAC_EN_IN, may be connected with solder

// SPI Interface, FIFO fills from Nozzle write and is read back by Nozzle read
// First Word Fall Through is needed on the write to SPI side.
// Switched to conventional FIFO for the read side.
 

wire [15:0] SPI_w_data, spi_read_count, spi_write_count, w_fifo_out;
wire SPI_data_av, clk_toggle;                                                    
              
wire rst, w_fifo_empty;
assign rst = !rstn;           
                                        
wire w_master_ready, w_TX_Ready;
wire o_RX_DV, o_SPI_MOSI, i_SPI_MISO, i_TX_DV, o_SPI_CLK;
wire  o_SPI_CS_n;
wire [15:0] o_RX_Word;
reg read_fifo, r_TX_Ready, rr_TX_Ready;
reg [6:0] clk_counter;   
reg [2:0] word_counter = 0;
reg [15:0] transfer_counter = 0;
wire clear_transfer_counter;

            // Need to shift later to include final clock edge
                              
fifo_16w_32768deep SPI_write_fifo(
  .clk(ti_clk),               // input clk
  .rst(rst),                  // input rst
  .din(nozzle_w_data),        // input [15 : 0] din
  .wr_en(nozzle_write),       // input wr_en
  .rd_en(read_fifo),          // input rd_en
  .dout(w_fifo_out),          // output [15 : 0] dout
  .full(),                    // output full
  .empty(w_fifo_empty),       // output empty
  .data_count(spi_write_count) // output [15 : 0] data_count
);          

fifo_16w_32768deep_no_fwft SPI_read_fifo(
  .clk(ti_clk),               // input clk
  .rst(rst),                  // input rst
  .din(o_RX_Word),            // input [15 : 0] din
  .wr_en(o_RX_DV),            // input wr_en
  .rd_en(nozzle_read),        // input rd_en
  .dout(nozzle_r_data),       // output [15 : 0] dout
  .full(),                    // output full
  .empty(),                   // output empty
  .data_count(spi_read_count) // output [15 : 0] data_count
);                           

always @(posedge ti_clk)
begin
   r_TX_Ready <= w_TX_Ready;
 //  rr_TX_Ready <= r_TX_Ready;
   read_fifo <= i_TX_DV;
   if (clear_transfer_counter)
      transfer_counter <= 0;
   if (~read_fifo)
      clk_counter <= clk_counter + 1;              // Single clock stretch needed to complete last SCLK edge
   if (i_TX_DV && rr_TX_Ready)
      word_counter <= 0;
   if (read_fifo)
      word_counter <= word_counter + 1;            // Break the CS at third word to allow packed operation
   if ((word_counter == 3) && i_TX_DV)
   begin
      word_counter <= 0;
      transfer_counter <= transfer_counter +1;
      rr_TX_Ready <= 1;
   end
      else
      rr_TX_Ready <= r_TX_Ready;
end
assign i_TX_DV = (clk_counter[6:0]==0) && !w_fifo_empty;  // Need a pulse to start the SPI interface

// debug outputs are numbered 9-1, ti_clk is on pin 0. Shows up as D0 on scope. So shift them up by 1, debug[2] is D1 on scope
assign debug[9:2] = {w_fifo_empty,SPI_SCLK,SPI_MOSI, word_counter[0],SPI_MISO, i_TX_DV, SPI_CS,read_fifo};  
assign logic_anal[7:0] =     {  1'b0,       ADC_CLK,ADC_SDI, 1'b0,           ADC_SDO,  1'b0 , ADC_CS_N, clk_counter[0]  };                                                                                    
                           //{w_fifo_empty,SPI_SCLK,SPI_MOSI, word_counter[0],SPI_MISO, i_TX_DV, SPI_CS,clk_counter[0]}; 
/*
    .ADC_CLK(ADC_CLK),
    .ADC_CS_N(ADC_CS_N),
    .ADC_SDI(ADC_SDI),
    .ADC_RST_N(ADC_RST_N),
    .ADC_SDO(ADC_SDO) */ 
assign logic_anal[15:8] = {5'b01010,DAC_SYNC_N,DAC_DATA,DAC_CLK}; 
assign logic_clk  = clk_div[15:14]; 

  // Instantiate Master
  SPI_Master_Reference           // Ti_CLK (48 MHz) is divided by 4, thus 1.28us/word  
  SPI_Master_Inst 
   (
   // Control/Data Signals,
   .i_Rst_L(rstn),               // FPGA Reset
   .i_Clk(ti_clk),               // FPGA Clock
   
   // TX (MOSI) Signals
   .i_TX_Word(w_fifo_out),       // Word to transmit
   .i_TX_DV(i_TX_DV),            // Data Valid Level
   .o_TX_Ready(w_TX_Ready),      // Transmit Ready for Word
   
   // RX (MISO) Signals
   .o_RX_DV(o_RX_DV),            // Data Valid pulse (1 clock cycle)
   .o_RX_Word(o_RX_Word),        // Word received on MISO

   // SPI Interface
   .o_SPI_Clk(o_SPI_CLK),
   .i_SPI_MISO(i_SPI_MISO),
   .o_SPI_MOSI(o_SPI_MOSI)
   );

                                   
//Other than printing registers available to software
always @(posedge ti_clk) 
begin
	if (sreg_reset == 1'b1) begin
		sreg_r_addr <= 10'd0;
      sreg_w_addr <= 10'd0;
	end 
   else 
   begin
      if (sreg_write == 1'b1)   
      	sreg_w_addr <= sreg_w_addr + 1;
			
		if (sreg_read  == 1'b1)
			sreg_r_addr <= sreg_r_addr + 1;
	end
	if (sreg_w_addr[0] == 1'b0)   // low 16 bits, comes first 
		sreg_low_store = sreg_w_data;		
end

// Register writing
always @(posedge ti_clk)
begin 
	if (sreg_w_addr[9:8] == 0 && sreg_w_addr[0] == 1'b1) begin
		case (sreg_w_addr[7:1])
      // 0x00 - 0x0C
		7'b0_0000_00: sreg_dev_control  			<= {sreg_w_data, sreg_low_store};  
      7'b0_0000_01: reg_adc_setpoint         <= {sreg_w_data, sreg_low_store};     
		default: begin
		         end
	   endcase
   end
end

reg [31:0] sreg_data;

// Register reading, accessing quad (32 bit) registers with a word (16 bit) address.
assign sreg_r_data = (sreg_r_addr[0] == 1'b0) ? sreg_data[31:16] : sreg_data[15:0];

always @(posedge ti_clk)
begin 
	if (sreg_r_addr[9:8] == 0) begin
		case (sreg_r_addr[7:1])
      // 0x0-0xC
      7'b0_0000_00: sreg_data <= sreg_dev_control;          
      7'b0_0000_01: sreg_data <= reg_adc_setpoint;         // Readback setpoint
      7'b0_0000_10: sreg_data <= reg_adc_value;            // ADC value from printhead
      7'b0_0000_11: sreg_data <= reg_adc_hs_value;         // ADC value from heat sink
		default: begin
					sreg_data <= 32'hfacecafe;
		         end
	   endcase
   end
end



//Printing registers, passed down to Q256_mgt
always @(posedge ti_clk) 
begin
	if (reg_reset == 1'b1) begin
		reg_r_addr <= 10'd0;
      reg_w_addr <= 10'd0;
	end 
   else 
   begin
      if (reg_write == 1'b1)   
      	reg_w_addr <= reg_w_addr + 1;
			
		if (reg_read  == 1'b1)
			reg_r_addr <= reg_r_addr + 1;
	end
	if (reg_w_addr[0] == 1'b0)   // low 16 bits, comes first 
		reg_low_store = reg_w_data;		
end

// Register writing
always @(posedge ti_clk)
begin 
	if (reg_w_addr[9:8] == 0 && reg_w_addr[0] == 1'b1) begin
		case (reg_w_addr[7:1])
		7'b0_0000_01: reg_dev_control  			<= {reg_w_data, reg_low_store};   
		// 0x10-0x1C 
		7'b0_0001_00: reg_length   <= {reg_w_data, reg_low_store} ; // # of bytes in a column
	// 	7'b0_0001_01: reg_delay    <= {reg_w_data, reg_low_store};  // # of columns in a frame Contolled by bit in control word
	   7'b0_0001_10: reg_divider  <= {reg_w_data, reg_low_store};  // Encoder and clock divider
	 //  7'b0_0001_11: reg_tx_count <= {reg_w_data, reg_low_store};  // Keep track of # of bytes sent 
		// 0x20-0x2C
		7'b0_0010_00: reg_segment1 <= {reg_w_data, reg_low_store}; 	// Waveform length and slope
		7'b0_0010_01: reg_segment2 <= {reg_w_data, reg_low_store};
		7'b0_0010_10: reg_segment3 <= {reg_w_data, reg_low_store};
		7'b0_0010_11: reg_segment4 <= {reg_w_data, reg_low_store};
		// 0x30-0x3C
		7'b0_0011_00: reg_segment5 <= {reg_w_data, reg_low_store};
		7'b0_0011_01: reg_segment6 <= {reg_w_data, reg_low_store};  
		7'b0_0011_10: reg_segment7 <= {reg_w_data, reg_low_store}; 
		7'b0_0011_11: reg_segment8 <= {reg_w_data, reg_low_store}; 		
      // 0x40-0x4C      
  
		default: begin
		         end
	   endcase
   end
end

reg [31:0] reg_data;

// Register reading, accessing quad (32 bit) registers with a word (16 bit) address.
assign reg_r_data = (reg_r_addr[0] == 1'b0) ? reg_data[31:16] : reg_data[15:0];

always @(posedge ti_clk)
begin 
	if (reg_r_addr[9:8] == 0) begin
		case (reg_r_addr[7:1])
		7'b0_0000_00: reg_data <= reg_dev_status;
		7'b0_0000_01: reg_data <= reg_dev_control;
		7'b0_0000_10: reg_data <= reg_fpga_version;
		7'b0_0000_11: reg_data <= reg_adc_setpoint;        //ADC desired value, 1024 = 25C, 930 = 30C
		// 0x10-0x1C 
		7'b0_0001_00: reg_data <= reg_length; 					// # of bytes in a column
		7'b0_0001_01: reg_data <= reg_delay;               // # of columns in a frame
	   7'b0_0001_10: reg_data <= reg_divider;             // Encoder and clock divider
	   7'b0_0001_11: reg_data <= tx_counter;            // Keep track of # of bytes sent 
		// 0x20-0x2C
		7'b0_0010_00: reg_data <= reg_segment1; 				// Waveform length and slope
		7'b0_0010_01: reg_data <= reg_segment2;
		7'b0_0010_10: reg_data <= reg_segment3;
		7'b0_0010_11: reg_data <= reg_segment4;
		// 0x30-0x3C
		7'b0_0011_00: reg_data <= reg_segment5;
		7'b0_0011_01: reg_data <= reg_segment6;  
		7'b0_0011_10: reg_data <= reg_segment7; 
		7'b0_0011_11: reg_data <= reg_segment8; 
      // 0x40-0x4C          additional waveform segments to be added
      7'b0_0101_00: reg_data <= reg_adc_value;            // ADC value from printhead
      7'b0_0101_01: reg_data <= reg_adc_hs_value;         // ADC value from heat sink
      7'b0_0101_10: reg_data <= reg_pulse_counter;        // Total number of PSO pulses since trigger
      7'b0_0101_11: reg_data <= reg_max_delay;            // Maximum number of clock pulse between PSO
      // 0x50-0x5C

		default: begin
					reg_data <= 32'hdeadbeef;                 // Go with the classic
		         end
	   endcase
   end
end

wire [15:0]  debug_control, debug_status; // = 16'b0000_0000_0000_0000;
assign debug_control = WireIn11;
assign jet_stand1 = {WireIn13 , WireIn12};
assign jet_stand2 = {WireIn15 , WireIn14};
assign jet_stand3 = {WireIn17 , WireIn16};
assign jet_stand4 = {WireIn19 , WireIn18};
assign jet_stand5 = {WireIn1B , WireIn1A};
assign jet_stand6 = {WireIn1D , WireIn1C};
assign jet_stand7 = {WireIn1F , WireIn1E};

// Instantiate the okHost and connect endpoints.
assign hi_muxsel  = 1'b0;
assign i2c_sda    = 1'bz;			// These are floated to not interfere 
assign i2c_scl    = 1'bz;			// with existing Opal Kelly I2C interface.

wire [17*48-1:0]  ok2x;
okHost okHI(
	.hi_in(hi_in), .hi_out(hi_out), .hi_inout(hi_inout), .hi_aa(hi_aa), .ti_clk(ti_clk),
	.ok1(ok1), .ok2(ok2));

okWireOR # (.N(48)) wireOR (ok2, ok2x);

okWireIn     ep10 (.ok1(ok1),                           .ep_addr(8'h10), .ep_dataout(WireIn10)); // CPU control of DAC ENABLE bit 0
okWireIn     ep11 (.ok1(ok1),                           .ep_addr(8'h11), .ep_dataout(WireIn11)); // Reset Frame 
okWireIn     ep12 (.ok1(ok1),                           .ep_addr(8'h12), .ep_dataout(WireIn12)); // OOP DAC Value
okWireIn     ep13 (.ok1(ok1),                           .ep_addr(8'h13), .ep_dataout(WireIn13)); // DAC_On_Length
okWireIn     ep14 (.ok1(ok1),                           .ep_addr(8'h14), .ep_dataout(WireIn14)); // DAC_Off_Length
okWireIn     ep15 (.ok1(ok1),                           .ep_addr(8'h15), .ep_dataout(WireIn15)); // DAC_Pulses
okWireIn     ep16 (.ok1(ok1),                           .ep_addr(8'h16), .ep_dataout(WireIn16)); // Length 3
okWireIn     ep17 (.ok1(ok1),                           .ep_addr(8'h17), .ep_dataout(WireIn17)); // Slope 3
okWireIn     ep18 (.ok1(ok1),                           .ep_addr(8'h18), .ep_dataout(WireIn18)); // Length 4
okWireIn     ep19 (.ok1(ok1),                           .ep_addr(8'h19), .ep_dataout(WireIn19)); // Slope 4
okWireIn     ep1A (.ok1(ok1),                           .ep_addr(8'h1A), .ep_dataout(WireIn1A)); // Length 5 
okWireIn     ep1B (.ok1(ok1),                           .ep_addr(8'h1B), .ep_dataout(WireIn1B)); // Slope 5 
okWireIn     ep1C (.ok1(ok1),                           .ep_addr(8'h1C), .ep_dataout(WireIn1C)); // Length 6 
okWireIn     ep1D (.ok1(ok1),                           .ep_addr(8'h1D), .ep_dataout(WireIn1D)); // Slope 6 
okWireIn     ep1E (.ok1(ok1),                           .ep_addr(8'h1E), .ep_dataout(WireIn1E)); // Length 7 
okWireIn     ep1F (.ok1(ok1),                           .ep_addr(8'h1F), .ep_dataout(WireIn1F)); // Slope 7 

okWireOut 	 ep20 (.ok1(ok1), .ok2(ok2x[ 1*17 +: 17 ]), .ep_addr(8'h20), .ep_datain(WireIn10));  
okWireOut 	 ep21 (.ok1(ok1), .ok2(ok2x[ 9*17 +: 17 ]), .ep_addr(8'h21), .ep_datain(read_byte_count));  
okWireOut 	 ep22 (.ok1(ok1), .ok2(ok2x[11*17 +: 17 ]), .ep_addr(8'h22), .ep_datain(WireIn12));
okWireOut 	 ep23 (.ok1(ok1), .ok2(ok2x[12*17 +: 17 ]), .ep_addr(8'h23), .ep_datain(WireIn13));  // Write count is odd, always has a 1
okWireOut 	 ep24 (.ok1(ok1), .ok2(ok2x[13*17 +: 17 ]), .ep_addr(8'h24), .ep_datain(WireIn14));
okWireOut 	 ep25 (.ok1(ok1), .ok2(ok2x[14*17 +: 17 ]), .ep_addr(8'h25), .ep_datain(WireIn15));
okWireOut 	 ep26 (.ok1(ok1), .ok2(ok2x[15*17 +: 17 ]), .ep_addr(8'h26), .ep_datain(cclk_counter));
okWireOut 	 ep27 (.ok1(ok1), .ok2(ok2x[16*17 +: 17 ]), .ep_addr(8'h27), .ep_datain(flow_w_addr));      // Number of flowcell current measurements in FIFO
okWireOut 	 ep28 (.ok1(ok1), .ok2(ok2x[17*17 +: 17 ]), .ep_addr(8'h28), .ep_datain(transfer_counter));
okWireOut 	 ep29 (.ok1(ok1), .ok2(ok2x[18*17 +: 17 ]), .ep_addr(8'h29), .ep_datain(dac_act4[31:16]));
okWireOut 	 ep2A (.ok1(ok1), .ok2(ok2x[19*17 +: 17 ]), .ep_addr(8'h2A), .ep_datain(spi_write_count));   // Used on software side
okWireOut    ep2B (.ok1(ok1), .ok2(ok2x[21*17 +: 17 ]), .ep_addr(8'h2B), .ep_datain(spi_read_count));    // Used on software side
okWireOut    ep2C (.ok1(ok1), .ok2(ok2x[22*17 +: 17 ]), .ep_addr(8'h2C), .ep_datain(DAC_EN));            // 
okWireOut 	 ep30 (.ok1(ok1), .ok2(ok2x[40*17 +: 17 ]), .ep_addr(8'h30), .ep_datain(adc_value0));        // Current for +1.25 supply     0.5A --> 3.4V 
okWireOut 	 ep31 (.ok1(ok1), .ok2(ok2x[41*17 +: 17 ]), .ep_addr(8'h31), .ep_datain(adc_value1));        // Current for +1.8 supply      +/- 4.096 FS
okWireOut 	 ep32 (.ok1(ok1), .ok2(ok2x[42*17 +: 17 ]), .ep_addr(8'h32), .ep_datain(adc_value2));        // Current for +2.2 supply
okWireOut 	 ep33 (.ok1(ok1), .ok2(ok2x[43*17 +: 17 ]), .ep_addr(8'h33), .ep_datain(adc_value3));        // Inverted current for =2.2 supply
okWireOut 	 ep34 (.ok1(ok1), .ok2(ok2x[44*17 +: 17 ]), .ep_addr(8'h34), .ep_datain(adc_value4));        // Inverted current for -1.25 supply
okWireOut 	 ep35 (.ok1(ok1), .ok2(ok2x[45*17 +: 17 ]), .ep_addr(8'h35), .ep_datain(adc_value5));        // Flow cell current, 1V = 1 mA
okWireOut 	 ep36 (.ok1(ok1), .ok2(ok2x[46*17 +: 17 ]), .ep_addr(8'h36), .ep_datain(adc_value6));        // Flow cell voltage (ignores floating)
okWireOut 	 ep37 (.ok1(ok1), .ok2(ok2x[47*17 +: 17 ]), .ep_addr(8'h37), .ep_datain(flow_r_addr));        // Spare


okTriggerIn  ep40 (.ok1(ok1),                           .ep_addr(8'h40), .ep_clk(ti_clk), .ep_trigger(TrigIn40));
okTriggerIn  ep41 (.ok1(ok1),                           .ep_addr(8'h41), .ep_clk(ti_clk), .ep_trigger(TrigIn41));
okTriggerIn  ep42 (.ok1(ok1),                           .ep_addr(8'h42), .ep_clk(ti_clk), .ep_trigger(TrigIn42));
okTriggerIn  ep43 (.ok1(ok1),                           .ep_addr(8'h43), .ep_clk(ti_clk), .ep_trigger(TrigIn43));
okTriggerIn  ep44 (.ok1(ok1),                           .ep_addr(8'h44), .ep_clk(ti_clk), .ep_trigger(TrigIn44));
okTriggerIn  ep45 (.ok1(ok1),                           .ep_addr(8'h45), .ep_clk(ti_clk), .ep_trigger(TrigIn45));
okTriggerIn  ep46 (.ok1(ok1),                           .ep_addr(8'h46), .ep_clk(ti_clk), .ep_trigger(TrigIn46));
okTriggerIn  ep47 (.ok1(ok1),                           .ep_addr(8'h47), .ep_clk(ti_clk), .ep_trigger(TrigIn47));
okTriggerIn  ep48 (.ok1(ok1),                           .ep_addr(8'h48), .ep_clk(ti_clk), .ep_trigger(TrigIn48));
okTriggerIn  ep49 (.ok1(ok1),                           .ep_addr(8'h49), .ep_clk(ti_clk), .ep_trigger(TrigIn49));
okTriggerIn  ep4A (.ok1(ok1),                           .ep_addr(8'h4A), .ep_clk(ti_clk), .ep_trigger(TrigIn4A));
okTriggerIn  ep4B (.ok1(ok1),                           .ep_addr(8'h4B), .ep_clk(ti_clk), .ep_trigger(TrigIn4B));
okTriggerIn  ep4C (.ok1(ok1),                           .ep_addr(8'h4C), .ep_clk(ti_clk), .ep_trigger(TrigIn4C));
okTriggerIn  ep4D (.ok1(ok1),                           .ep_addr(8'h4D), .ep_clk(ti_clk), .ep_trigger(TrigIn4D));
okTriggerIn  ep4E (.ok1(ok1),                           .ep_addr(8'h4E), .ep_clk(ti_clk), .ep_trigger(TrigIn4E));
//okTriggerOut ep60 (.ok1(ok1), .ok2(ok2x[ 0*17 +: 17 ]), .ep_addr(8'h60), .ep_clk(clk1), .ep_trigger(TrigOut60));

okPipeIn     ep84 (.ok1(ok1), .ok2(ok2x[  5*17 +: 17 ]), .ep_addr(8'h84), .ep_write(reg_write),     .ep_dataout(reg_w_data));
okPipeIn     ep85 (.ok1(ok1), .ok2(ok2x[ 20*17 +: 17 ]), .ep_addr(8'h85), .ep_write(pattern_write), .ep_dataout(flow_w_data));
okPipeIn     ep86 (.ok1(ok1), .ok2(ok2x[  6*17 +: 17 ]), .ep_addr(8'h86), .ep_write(sreg_write),    .ep_dataout(sreg_w_data));
okPipeIn     ep87 (.ok1(ok1), .ok2(ok2x[ 23*17 +: 17 ]), .ep_addr(8'h87), .ep_write(adjust_write),  .ep_dataout(adjust_w_data));
okPipeIn     ep88 (.ok1(ok1), .ok2(ok2x[ 24*17 +: 17 ]), .ep_addr(8'h88), .ep_write(nozzle_write),  .ep_dataout(nozzle_w_data));

okPipeOut    epA4 (.ok1(ok1), .ok2(ok2x[ 10*17 +: 17 ]), .ep_addr(8'ha4), .ep_read(reg_read),       .ep_datain(reg_r_data));
okPipeOut    epA5 (.ok1(ok1), .ok2(ok2x[ 30*17 +: 17 ]), .ep_addr(8'ha5), .ep_read(pattern_read),   .ep_datain(flow_r_data)); /* Flowcell current 1 ms samples */
okPipeOut    epA6 (.ok1(ok1), .ok2(ok2x[  7*17 +: 17 ]), .ep_addr(8'ha6), .ep_read(flow_v_read),    .ep_datain(flow_v_data)); /* Flowcell voltage 1 ms samples */
okPipeOut    epA7 (.ok1(ok1), .ok2(ok2x[  8*17 +: 17 ]), .ep_addr(8'ha7), .ep_read(adjust_read),    .ep_datain(adjust_r_data)); /* adjust_u_addr*/
okPipeOut    epA8 (.ok1(ok1), .ok2(ok2x[ 25*17 +: 17 ]), .ep_addr(8'ha8), .ep_read(nozzle_read),    .ep_datain(nozzle_r_data)); /* nozzle_u_addr*/

endmodule
