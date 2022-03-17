`timescale 1ns / 1ps
`default_nettype none

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    04:39:25 07/25/2015 
// Design Name: 
// Module Name:    tld_sam 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module tld_sam_v4 (
    input wire clk50mhz,
    // Audio I/O
    input wire ear,
    output wire audio_out_left,
    output wire audio_out_right,
    // Video output
    output wire [2:0] r,
    output wire [2:0] g,
    output wire [2:0] b,
    output wire hsync,
	 output wire vsync,
    output wire stdn,
    output wire stdnb,
    // SRAM interface
    output wire [20:0] sram_addr,
    inout wire [7:0] sram_data,
    output wire sram_we_n,
    // PS/2 keyoard interface
    inout wire clkps2,
    inout wire dataps2,
    // mouse interface
    inout wire mousedata,
    inout wire mouseclk,
    //////// sdcard ////////
    output sd_cs_n,
    output sd_clk,
    output sd_mosi,
    input wire sd_miso
//     ,output reg testled
    );

    // bootrom loading
    wire[31:0] host_bootdata;
    wire host_bootdata_req;
    wire host_bootdata_ack;
    wire host_reset;
    wire rom_initialised;
//     wire host_reset;
//     wire rom_initialised;
//     wire[7:0] romwrite_data;
//     wire romwrite_wr;
//     wire[18:0] romwrite_addr;
    
    // Interface with RAM
    wire [18:0] sram_addr_from_sam;
    wire sram_we_n_from_sam;
    
    // Audio and video
    wire [1:0] sam_r, sam_g, sam_b;
    wire sam_bright;
    
	 // scandoubler
	 wire hsync_pal, vsync_pal;
    wire [2:0] ri = {sam_r, sam_bright};
    wire [2:0] gi = {sam_g, sam_bright};
    wire [2:0] bi = {sam_b, sam_bright};

  //ctrl-module
  wire[7:0] disk_data_in0;
  wire[7:0] disk_data_out0;
  wire[31:0] disk_sr;
  wire[31:0] disk_cr;
  wire disk_data_clkout, disk_data_clkin;
  
//   wire[31:0] romaddr_dbg;
//   wire[31:0] debug = romaddr_dbg[31:0];

    assign stdn = 1'b0;  // fijar norma PAL
	assign stdnb = 1'b1; // y conectamos reloj PAL
  wire ear_in_sc;
  wire ear_in = ear_in_sc ^ ear;
    
    wire clk24, clk12, clk6, clk8, clk50m;

    reg [7:0] poweron_reset = 8'h00;
    reg [1:0] scandoubler_ctrl = 2'b00;
    always @(posedge clk6) begin
        poweron_reset <= {poweron_reset[6:0], 1'b1};
        if (poweron_reset[6] == 1'b0)
            scandoubler_ctrl <= sram_data[1:0];
    end
    assign sram_addr = (poweron_reset[7] == 1'b0)? 21'h008FD5 :
//                        rom_initialised ? {2'b00, romwrite_addr} :
                       {2'b00, sram_addr_from_sam};
    assign sram_we_n = (poweron_reset[7] == 1'b0)? 1'b1 : 
//                        rom_initialised ? !romwrite_wr :
                       sram_we_n_from_sam;
                       
    relojes los_relojes (
        .CLK_IN1            (clk50mhz),      // IN
        // Clock out ports
        .CLK_OUT1           (clk24),  // modulo multiplexor de SRAM
        .CLK_OUT2           (clk12),  // ASIC
        .CLK_OUT3           (clk6),   // CPU y teclado PS/2
        .CLK_OUT4           (clk8),   // SAA1099 y DAC
        .CLK_OUT5           (clk50m)  // el resto de stuffo
    );

    samcoupe # (.ROM_IN_RAM(0)) maquina (
        .clk50m(clk50m),
        .clk24(clk24),
        .clk12(clk12),
        .clk6(clk6),
        .clk8(clk8),
        .master_reset_n(poweron_reset[7]),
        // Video output
        .r(sam_r),
        .g(sam_g),
        .b(sam_b),
        .bright(sam_bright),
        .hsync_pal(hsync_pal),
        .vsync_pal(vsync_pal),
        // Audio output
        .ear(~ear_in),
        .audio_out_left(audio_out_left),
        .audio_out_right(audio_out_right),
        // PS/2 keyboard
        .clkps2(host_divert_keyboard ? 1'b1 : clkps2),
        .dataps2(host_divert_keyboard ? 1'b1 : dataps2),
        // PS/2 mouse
        .mousedata(mousedata),
        .mouseclk(mouseclk),
        // SRAM external interface
        .sram_addr(sram_addr_from_sam),
        .sram_data(sram_data),
        .sram_we_n(sram_we_n_from_sam)
//         ,
        // host boot rom
//         .host_bootdata(host_bootdata),
//         .host_bootdata_req(host_bootdata_req),
//         .host_bootdata_ack(host_bootdata_ack),
//         .rom_initialised(rom_initialised)
//         ,.romaddr_dbg(romaddr_dbg)
  );
	 
	wire[7:0] vga_red_o, vga_green_o, vga_blue_o;
	vga_scandoubler #(.CLKVIDEO(12000)) salida_vga (
		.clkvideo(clk12),
		.clkvga(clk24),
		.enable_scandoubling(scandoubler_ctrl[0]),
        .disable_scaneffect(~scandoubler_ctrl[1]),
		.ri(vga_red_o[7:5]),
		.gi(vga_green_o[7:5]),
		.bi(vga_blue_o[7:5]),
		.hsync_ext_n(hsync_pal),
		.vsync_ext_n(vsync_pal),
		.ro(r),
		.go(g),
		.bo(b),
		.hsync(hsync),
		.vsync(vsync)
   );


   wire host_divert_keyboard;

   wire hyper_loading = 1'b0;
   wire [7:0] tape_data;
   reg tape_hreq = 1'b0;
   reg tape_hack = 1'b0;
   wire tape_busy;
   wire tape_ack;

   wire hyperload_fifo_empty;
   reg hyperload_fifo_rd;
   wire[7:0] hyperload_fifo_data;
   wire hyperload_read_data;
   wire hyperload_fifo_full;

   reg[31:0] count;
   always @(posedge clk50m)
     count <= count + 1;

   wire clk6m25 = count[2];
   wire clk390k625 = count[6];
   wire tape_dclk;
   wire tape_reset;
   wire[15:0] dswitch;

   wire host_divert_sdcard;

   fifo #(.RAM_SIZE(512), .ADDRESS_WIDTH(9)) hyperload_fifo_inst(
     .q(hyperload_fifo_data[7:0]),
     .d(tape_data[7:0]),
     .clk(clk50m),
     .write(tape_dclk),
     .reset(tape_reset),

     .read(hyperload_fifo_rd),
     .empty(hyperload_fifo_empty),
     .full(hyperload_fifo_full)
     );

  wire osd_window;
  wire osd_pixel;
  
//     bootloader bootloader_inst(
//       .clk(clk50m),
//       .host_bootdata(host_bootdata),
//       .host_bootdata_ack(host_bootdata_ack),
//       .host_bootdata_req(host_bootdata_req),
//       .host_reset(host_reset),
//       .romwrite_data(romwrite_data),
//       .romwrite_wr(romwrite_wr),
//       .romwrite_addr(romwrite_addr),
//       .rom_initialised(rom_initialised)
//     );


   CtrlModule #(.ROMSIZE_BITS(14)) MyCtrlModule (
     .clk(clk6),	
     .clk26(clk50m),
     .reset_n(1'b1),

     //-- Video signals for OSD
     .vga_hsync(hsync),
     .vga_vsync(vsync),
     .osd_window(osd_window),
     .osd_pixel(osd_pixel),

     //-- PS2 keyboard
     .ps2k_clk_in(clkps2),
     .ps2k_dat_in(dataps2),

     //-- SD card signals
     .spi_clk(sd_clk),
     .spi_mosi(sd_mosi),
     .spi_miso(sd_miso),
     .spi_cs(sd_cs_n),

     //-- DIP switches
     .dipswitches(dswitch),

     //-- Control signals
     .host_divert_keyboard(host_divert_keyboard),
     .host_divert_sdcard(host_divert_sdcard),
     .host_reset(host_reset),
     .host_rom_initialised(rom_initialised),

     // tape interface
//      .ear_in(micout),
     .ear_out(ear_in_sc),
     .clk390k625(clk390k625),

     // disk interface
     .disk_data_in(disk_data_out0),
     .disk_data_out(disk_data_in0),
     .disk_data_clkin(disk_data_clkout),
     .disk_data_clkout(disk_data_clkin),

      // disk interface
      .disk_sr(disk_sr),
      .disk_cr(disk_cr),

      .tape_data_out(tape_data),
      .tape_dclk_out(tape_dclk),
      .tape_reset_out(tape_reset),

      .tape_hreq(tape_hreq),
      .tape_busy(tape_busy),
      .cpu_reset(1'b0)
//       , //TODO

      // init bootrom interface
 /*     .host_bootdata(host_bootdata),
      .host_bootdata_req(host_bootdata_req),
      .host_bootdata_ack(host_bootdata_ack)
      
      ,.debug(debug)
 */     
      // jtag uart interface
//       .juart_rx(juart_rx),
//       .juart_tx(juart_tx)
      ,.debug(0)
   );

   wire[3:0] vga_r_o;
   wire[3:0] vga_g_o;
   wire[3:0] vga_b_o;

   wire[7:0] vga_red_i, vga_green_i, vga_blue_i;

   assign vga_red_i = {sam_r[1:0], 6'h0};
   assign vga_green_i = {sam_g[1:0], 6'h0};
   assign vga_blue_i = {sam_b[1:0], 6'h0};

//    assign r[2:0] = vga_red_o[7:5];
//    assign g[2:0] = vga_green_o[7:5];
//    assign b[2:0] = vga_blue_o[7:5];
//    assign vga_hs = hsync;
//    assign vga_vs = vsync;

   // OSD Overlay
   OSD_Overlay overlay (
     // .clk(clk25),
     .clk(clk50m),
     .red_in(vga_red_i),
     .green_in(vga_green_i),
     .blue_in(vga_blue_i),
     .window_in(1'b1),
     .osd_window_in(osd_window),
     .osd_pixel_in(osd_pixel),
//      .hsync_in(hsync),
     .hsync_in(hsync_pal),
     .red_out(vga_red_o),
     .green_out(vga_green_o),
     .blue_out(vga_blue_o),
     .window_out( ),
     .scanline_ena(1'b0) //scandblr_reg[1])
   );

//    multiboot multiboot(
//      .clk_icap(clk8),
//      .REBOOT(REBOOT)
//    );	 	 
	 
endmodule
