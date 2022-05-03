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
    input rst,
    input ti_clk,
    input [31:0] reg_length,
    input [31:0] reg_delay,
    input [31:0] read_byte_count,
    output frame_rd_en,
    output dac_ready,
    output FRAME,
    output CCLK
    );

   reg Frame_r, Col_Clock_r, DAC_Enable_r, rd_en_r;
   reg [15:0] Bytes_to_Send;
   reg [15:0] Cols_to_Send;
   reg [31:0] DAC_to_Send;
   reg [8:0]  CCLKs_to_Send;
   reg [31:0] DAC_length = 8;  // Changed to DAC_READY to allow top level computer to control
   reg [8:0] CCLK_length = 24; // CCLK must last a minimum of 8 MCLKs. Surprise!

   wire frame_rd_en, rd_en;
   parameter Idle       = 2'b00;
   parameter Loading    = 2'b01;
   parameter Col_Clock  = 2'b10;
   parameter DAC_Enable = 2'b11;
   reg [1:0] frame_state = Idle;
     
   always@(posedge ti_clk)
      if (rst) begin
         frame_state <= Idle;
         Frame_r     <= 1'b0;
         Col_Clock_r <= 1'b0;
         DAC_Enable_r <= 1'b1;
         Bytes_to_Send <= 0;
         rd_en_r <= 1'b0;
         
      end
      else
      case (frame_state)
         Idle: begin
            rd_en_r        <= 1'b0;
            Bytes_to_Send <= reg_length;        // # of bytes to send 
            Cols_to_Send <= reg_delay;          // # of columns to send
            DAC_to_Send  <= DAC_length; 
            CCLKs_to_Send <= CCLK_length;       // Minimum length of the column clock for CLIO internal transfer
            if (read_byte_count >= (reg_length - 1))     // Has the FIFO been filled with enough words to start sending?
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
            Frame_r <= 1'b0;
            if (Bytes_to_Send == 1)
            begin
               rd_en_r <= 1'b1;
               frame_state <= Col_Clock;
               CCLKs_to_Send <= CCLK_length;               
            end
            else
            begin
               frame_state  <= Loading; 
               rd_en_r      <= 1'b1;
               Bytes_to_Send <= Bytes_to_Send - 1;
               Col_Clock_r <= 1'b0;
            end
         end
         Col_Clock : begin                   // Huge change, must generate a minimum 8 MCLK pulse
            Col_Clock_r <= 1'b1;             // Column clock is the final transmission to move data
            rd_en_r <= 1'b0;                 // Stop reading from FIFO during column clock
            if (CCLKs_to_Send == 1)          // Finished sending the CCLK signal, Pac Micro has done transfer 
            begin
            Col_Clock_r <= 1'b0;             // Done sending column clock
               if (Cols_to_Send == 1)        // ??? Didn't Fix the final column to get it sent 5/2/22
                  begin
                     frame_state <= DAC_Enable;
                  end
               else
               begin
                  if (read_byte_count >= (reg_length - 1) )  // Has the FIFO been filled with one full column?
                  begin                    
                     frame_state <= Loading;
                     Cols_to_Send <= Cols_to_Send - 1;
                     Bytes_to_Send <= reg_length;
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
