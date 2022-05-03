`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:  Twist Bioscience, Inc.
// Engineer: Paul Heilman
// 
// Create Date:    14:28:16 04/14/2015 
// Design Name:    OK_D128
// Module Name:    dpram8K_a16_b16
// Project Name:   OK_D128
// Target Devices: Spartan 6
// Tool versions:  ISE 14.7 
// Description: Dual port memory for storing adjust data. Written
//              by USB interface and read internally by column advances. Sixteen
//              bits on USB side, 16 bits on application side. 
//              Do the selection for reading with a delayed/registered address.
//
//  8 K Bytes => 4 K 16 bit words        4 K 16 bit words
//                Having 4096 locations means we can store 1 swatch
//						for Titin.  Using the automatically generated memory uses 4 blocks
//
// Revision 1.0 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module dpram8K_a16_b16(
    input          clk,
    input          wea,
    input  [11:0]  addra,
    input  [15:0]  dia,
    output [15:0]  doa,
    input  [11:0]  addrb,
    output [15:0]  dob
    );
assign doa = 0;
assign dob = 0;

/*
Adjust_Memory dpram2 (
  .clka(clk), .wea(wea),  .addra(addra), .dina(dia), .douta(doa),   
  .clkb(clk), .web(1'b0), .addrb(addrb), .dinb(),    .doutb(dob) );
*/
endmodule
/*
module dpram8K_a16_b16(
    input          clk,
    input          wea,
    input  [12:0]  addra,
    input  [15:0]  dia,
    output [15:0]  doa,
    input  [12:0]  addrb,
    output [15:0]  dob
    );

wire [15:0] doa_sel0, doa_sel1, doa_sel2, doa_sel3; 
reg  [15:0] doa_r ;
reg   [1:0] addra_r; 

assign doa = doa_r;
always @(posedge clk)
begin
	addra_r <= addra[1:0];
end

always @(addra_r[1:0])
      case (addra_r[1:0])
         2'b00: begin
            doa_r      = doa_sel0;
            end
         2'b01: begin
            doa_r      = doa_sel1;
            end
         2'b10: begin
            doa_r      = doa_sel2;
            end
         2'b11: begin
            doa_r      = doa_sel3;
            end
      endcase	
		
wire [15:0] wea_sel;

assign  wea_sel[0]  = wea && (!addra[1] && !addra[0]);
assign  wea_sel[1]  = wea && (!addra[1] &&  addra[0]);
assign  wea_sel[2]  = wea && ( addra[1] && !addra[0]);
assign  wea_sel[3]  = wea && ( addra[1] &&  addra[0]); 

wire [15:0] dob_sel0, dob_sel1, dob_sel2, dob_sel3;
reg  [15:0] dob_r;
reg   [1:0] addrb_r;

assign dob = dob_r;
always @(posedge clk)
begin
	addrb_r <= addrb[1:0];
end
	
always @(addrb_r)
      case (addrb_r)
         2'b00: begin
            dob_r      = dob_sel0;
            end
         2'b01: begin
            dob_r      = dob_sel1;
            end
         2'b10: begin
            dob_r      = dob_sel2;
            end
         2'b11: begin
            dob_r      = dob_sel3;
            end            
      endcase		

dpram2K_a8_b8 dpram0 (
  .clka(clk),	.wea(wea_sel[0]),	.addra(addra[12:2]),	.dina(dia[7:0]),	.douta(doa_sel0[7:0]),
  .clkb(clk),  .web(1'b0),       .addrb(addrb[12:2]), .dinb(),          .doutb(dob_sel0[7:0])  );

dpram2K_a8_b8 dpram1 (
  .clka(clk),  .wea(wea_sel[0]), .addra(addra[12:2]), .dina(dia[15:8]), .douta(doa_sel0[15:8]), 
  .clkb(clk),  .web(1'b0),       .addrb(addrb[12:2]), .dinb(),          .doutb(dob_sel0[15:8]) );

dpram2K_a8_b8 dpram2 (
  .clka(clk),  .wea(wea_sel[1]), .addra(addra[12:2]), .dina(dia[7:0]),  .douta(doa_sel1[7:0]),
  .clkb(clk),  .web(1'b0),       .addrb(addrb[12:2]), .dinb(),          .doutb(dob_sel1[7:0]) );

dpram2K_a8_b8 dpram3 (
  .clka(clk), .wea(wea_sel[1]),  .addra(addra[12:2]), .dina(dia[15:8]), .douta(doa_sel1[15:8]),
  .clkb(clk), .web(1'b0),        .addrb(addrb[12:2]), .dinb(),          .doutb(dob_sel1[15:8]) );

dpram2K_a8_b8 dpram4 (
  .clka(clk), .wea(wea_sel[2]),  .addra(addra[12:2]), .dina(dia[7:0]),  .douta(doa_sel2[7:0]),
  .clkb(clk), .web(1'b0),        .addrb(addrb[12:2]), .dinb(),          .doutb(dob_sel2[7:0]) );

dpram2K_a8_b8 dpram5 (
  .clka(clk), .wea(wea_sel[2]),  .addra(addra[12:2]), .dina(dia[15:8]), .douta(doa_sel2[15:8]),  
  .clkb(clk), .web(1'b0),        .addrb(addrb[12:2]), .dinb(),          .doutb(dob_sel2[15:8]) );

dpram2K_a8_b8 dpram6 (
  .clka(clk), .wea(wea_sel[3]),  .addra(addra[12:2]), .dina(dia[7:0]),  .douta(doa_sel3[7:0]), 
  .clkb(clk), .web(1'b0),        .addrb(addrb[12:2]), .dinb(),          .doutb(dob_sel3[7:0]) );

dpram2K_a8_b8 dpram7 (
  .clka(clk), .wea(wea_sel[3]),  .addra(addra[12:2]), .dina(dia[15:8]), .douta(doa_sel3[15:8]),   
  .clkb(clk), .web(1'b0),        .addrb(addrb[12:2]), .dinb(),          .doutb(dob_sel3[15:8]) );

endmodule
*/

