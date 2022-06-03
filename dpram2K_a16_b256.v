`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:  Twist Bioscience, Inc.
// Engineer: Paul Heilman
// 
// Create Date:    14:28:16 04/04/2021 
// Design Name:    Pseudo_Q
// Module Name:    dpram2K_a16_b256
// Project Name:   Psuedo_Q
// Target Devices: Spartan 6
// Tool versions:  ISE 14.7 
// Description: Dual port memory for storing Nozzle adjust data. Written
//              by USB interface and read internally by column advances. Sixteen
//              bits on USB side, 256 bits on application side. 
//              Do the selection for reading with a delayed/registered address.
//
//              Uses 8 BRAM, rather than the expected 1, because the largest width
//              is 32 bits, so 256 bits takes 8 blocks of memory.
//              Might be a good use of distributed RAM. And there is a need to 
//              do the swizzling, either here or in software. Probably written as
//              a word for each nozzle, then read as each bit in the words for all 
//              the nozzles. Sort of a natural match as the 32 bit width matches
//              the width of the 8 shift registers in the head. 
//
// 2 K Bytes => 256 16 bit words        16 256 bit words
//              Having 256 locations means we can store information
//              for all 256 nozzles
//
// Revision 1.0 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module dpram2K_a16_b256(
    input          clk,
    input          wea,
    input  [7:0]  addra,
    input  [15:0]  dia,
    output [15:0]  doa,
    input  [3:0]   addrb,
    output [255:0] dob
    );

Nozzle_Memory dpram1 (
  .clka(clk),
  .wea(wea),
  .addra(addra),
  .dina(dia),
  .douta(doa),   
  .clkb(clk),
  .web(1'b0),
  .addrb(addrb),
  .dinb(),
  .doutb(dob) );

endmodule
