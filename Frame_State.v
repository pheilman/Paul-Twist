`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    20:13:45 12/28/2021 
// Design Name: 
// Module Name:    Frame_State 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: Column Clock is at the end of each column sent. There are
//                      10,001 total columns sent, and 10,001 column clocks sent. 
//
//////////////////////////////////////////////////////////////////////////////////
module Frame_State(
    input  rst,
    input  ti_clk,
    input  [31:0] reg_length,
    input  [31:0] reg_delay,
    output [31:0] read_byte_count,
    input  [15:0] din,
    input  wr_en,
    output [7:0] dout,
    output frame_rd_en,
    output dac_ready,
    output FRAME,
    output frame_state,
    output CCLK
    );
    
parameter CCLKs = 24;
wire [15:0] dout_word;
wire [15:0] read_count;

fifo_16w_32768deep frame_fifo(
  .rst(rst),                        // input rst
  .clk(ti_clk),                     // input clk
  .din(din),                        // input [15 : 0] din
  .wr_en(wr_en),                    // input wr_en
  .rd_en(frame_rd_en),              // input rd_en
  .dout(dout_word),                 // output [15 : 0] dout
  .full(),                          // output full
  .empty(),                         // output empty
  .data_count(read_count)           // output [15 : 0] data_count, easier than dual clock
);

// The byte lane selection is done here, that is why the extra state was added
assign dout = (frame_state == Loading_Hi) ? dout_word[15:8] : dout_word[7:0] ;
// Double the data count to get bytes, always written and read as a pair
assign read_byte_count = read_count << 1;

   reg Frame_r, Col_Clock_r, DAC_Enable_r, rd_en_r;
   reg [15:0] Words_to_Send;
   reg [15:0] Cols_to_Send;
   reg [31:0] DAC_to_Send;
   reg [8:0]  CCLKs_to_Send;
   reg [31:0] DAC_length = 8;  // Changed to DAC_READY to allow top level computer to control
   reg [8:0] CCLK_length = CCLKs; // Simulation shorten from 24// CCLK must last a minimum of 8 MCLKs. Surprise!

   wire  rd_en;
   parameter Idle       = 3'b000;
   parameter Loading    = 3'b001;
   parameter Col_Clock  = 3'b010;
   parameter DAC_Enable = 3'b011;
   parameter Loading_Hi = 3'b100;
   reg [2:0] frame_state = Idle;
     
   always@(posedge ti_clk)
      if (rst) begin
         frame_state <= Idle;
         Frame_r     <= 1'b0;
         Col_Clock_r <= 1'b0;
         DAC_Enable_r <= 1'b1;
         Words_to_Send <= 0;
         rd_en_r <= 1'b0;
         
      end
      else
      case (frame_state)
         Idle: begin
            rd_en_r        <= 1'b0;
            Words_to_Send <= reg_length >> 1;        // # of words to send 
            Cols_to_Send <= reg_delay;          // # of columns to send
            DAC_to_Send  <= DAC_length; 
            CCLKs_to_Send <= CCLK_length;       // Minimum length of the column clock for CLIO internal transfer
            if (read_byte_count >= (reg_length -1  ))     // Has the FIFO been filled with enough words to start sending?
            begin
               frame_state <= Loading;
               Frame_r     <= 1'b1;                // Single state Frame pulse
               rd_en_r <= 1'b0;             
               DAC_Enable_r <= 1'b0;               
            end
            else
            begin
               frame_state <= Idle;
            end
         end
         Loading : begin
            Frame_r <= 1'b0;        // Only 1 cycle of frame pulse
            Col_Clock_r <= 1'b0;    // Deassert column clock so loading starts again            
            rd_en_r <= 1'b0;
            frame_state <= Loading_Hi;
            // Adjust the mux for the data values here, always do the high byte
         end
         Loading_Hi : begin
            if (Words_to_Send == 1)
            begin
               rd_en_r <= 1'b1;
               frame_state <= Col_Clock;
               CCLKs_to_Send <= CCLK_length;
            end
            else
            begin
               frame_state  <= Loading; 
               rd_en_r      <= 1'b1;
               Words_to_Send <= Words_to_Send - 1;
               Col_Clock_r <= 1'b0;
            end
         end
         Col_Clock : begin                   // Huge change, must generate a minimum 8 MCLK pulse
                                             // Column clock is how we throttle, can't leave until a full frame is 
                                             // available
            Col_Clock_r <= 1'b1;             // Column clock is the final transmission to move data, and halts loading
            rd_en_r <= 1'b0;                 // Stop reading from FIFO during column clock
            if (CCLKs_to_Send == 1)          // Finished sending the minimum CCLK signal, Pac Micro has done transfer 
            begin
               if (Cols_to_Send == 1)        // If this was the final column, leave
                  begin
                     Col_Clock_r <= 1'b0;             // Done sending column clock
                     frame_state <= DAC_Enable;
                  end
               else  // Not the final column, don't start loading until there is a full column available
               begin
                  if (read_byte_count >= (reg_length - 1) )  // Has the FIFO been filled with one full column?
                  begin                    
                     frame_state <= Loading;
                     Cols_to_Send <= Cols_to_Send - 1;
                     Words_to_Send <= reg_length >> 1;
                  end
               end
            end
            else
            begin
               CCLKs_to_Send <= CCLKs_to_Send - 1;
            end
         end
         DAC_Enable : begin
            if (DAC_to_Send == 0)
            begin 
               DAC_Enable_r <= 1'b1; // Short delay after final CCLK load
               frame_state <= Idle;
            end
            else
            begin
               DAC_Enable_r <= 1'b0;
               DAC_to_Send <= DAC_to_Send - 1;
            end
         end
            default : begin  //Fault Recovery
               frame_state <= Idle;
               Frame_r <= 1'b0;
            end   
         endcase

assign frame_rd_en = rd_en_r;
assign FRAME = Frame_r;
assign CCLK = Col_Clock_r;
assign dac_ready = DAC_Enable_r;

endmodule
