`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:  Twist Bioscience, Inc.
// Engineer: Paul Heilman
// 
// Create Date:    14:28:16 03/22/2021 
// Design Name:    OK_Q
// Module Name:    dpram128K_a16_b256
// Project Name:   OK_Q
// Target Devices: Spartan 6
// Tool versions:  ISE 14.7 
// Description: Dual port memory for storing bitmap data. Written
//              by USB interface and read internally by column advances. Sixteen
//              bits on USB side, 256 bits on application side. 
//              Do the selection for reading with a delayed/registered address.
//
//  128 K Bytes => 64 K 16 bit words        4 K 256 bit words
//                Having 4096 locations means we can store 1 swatch
//						for Titin.  Uses 64 RAM blocks.
//
//                Trying using automatic IPGEN version, have to add source of the .xco file
//
// Revision 1.0 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module dpram132K_a16_b256(
    input          clk,
    input          wea,
    input  [14:0]  addra,
    input  [15:0]  dia,
    output [15:0]  doa,
    input  [11:0]  addrb,
    output [255:0] dob
    );

assign dob = 0;
assign doa = 0;
/*Bitmap_Memory dpram0 (
  .clka(clk), .wea(wea),  .addra(addra), .dina(dia), .douta(doa),   
  .clkb(clk), .web(1'b0), .addrb(addrb), .dinb(),    .doutb(dob) );
*/
endmodule
