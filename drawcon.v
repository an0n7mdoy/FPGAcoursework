`timescale 1ns / 1ps

module drawcon #(
    parameter [11:0] KEY = 12'h000          // transparent colour in the sprite
)(
    input        pixclk,                    // NEW: same clock as the VGA / BRAM
    input        player,
    input  [10:0] blkpos_x,
    input  [10:0] blkpos_y,
    input  [10:0] twopos_x,
    input  [10:0] twopos_y,
    output [3:0] draw_r,
    output [3:0] draw_g,
    output [3:0] draw_b,
    input  [10:0] curr_x,
    input  [10:0] curr_y
);

// ---------------- background ----------------
reg [3:0] bg_r, bg_g, bg_b;
always @* begin
    if ((curr_x < 11'd10) || (curr_x > 11'd1430) ||
        (curr_y < 11'd10) || (curr_y > 11'd890))
        {bg_r, bg_g, bg_b} = 12'hFFF;
    else
        {bg_r, bg_g, bg_b} = 12'h000;
end

// ---------------- sprite addressing ----------------
// Sprite is 48x48, centred on the marble position.
// The BRAM has 1 clock of latency, so we look up the NEXT pixel (curr_x + 1)
// and register the "inside sprite" flags; data and flags then line up with
// curr_x on the following clock.


// next pixels x position
wire [10:0] nx = curr_x + 11'd1;

// my sprite x
wire signed [11:0] my_sx  = $signed({1'b0, nx})     - $signed({1'b0, blkpos_x}) + 12'sd24;
wire signed [11:0] my_sy  = $signed({1'b0, curr_y}) - $signed({1'b0, blkpos_y}) + 12'sd24;
wire signed [11:0] two_sx = $signed({1'b0, nx})     - $signed({1'b0, twopos_x}) + 12'sd24;
wire signed [11:0] two_sy = $signed({1'b0, curr_y}) - $signed({1'b0, twopos_y}) + 12'sd24;

// is the pixel inside balls radius??
wire my_in  = (my_sx  >= 0) && (my_sx  < 48) && (my_sy  >= 0) && (my_sy  < 48);
wire two_in = (two_sx >= 0) && (two_sx < 48) && (two_sy >= 0) && (two_sy < 48);

// sprite address = is pixel inside balls radius? yes = render marble(row*48 + col) : no = 0
wire [11:0] my_addr  = my_in  ? (my_sy[5:0]  * 12'd48 + my_sx[5:0])  : 12'd0;
wire [11:0] two_addr = two_in ? (two_sy[5:0] * 12'd48 + two_sx[5:0]) : 12'd0;

// delay the inside-the-box flags by one clock, to match the ROM's one-clock delay
reg my_in_q, two_in_q;
always @(posedge pixclk) begin
    my_in_q  <= my_in;
    two_in_q <= two_in;
end

// ---------------- instantiate sprite ROM ----------------
wire [11:0] my_pix, two_pix;

marble marble_inst (
    .clka (pixclk), .addra(my_addr),  .douta(my_pix),
    .clkb (pixclk), .addrb(two_addr), .doutb(two_pix)
);

// Opponent tint: blue channel -> red, red channel -> green and blue
wire [3:0] two_r = two_pix[3:0];     // old blue becomes red
wire [3:0] two_g = two_pix[11:8];    // old red becomes green
wire [3:0] two_b = two_pix[11:8];    // old red becomes blue
wire [11:0] two_red = {two_r, two_g, two_b};

// marble pixel counts only if we're inside its box and the pixel isn't the transparent colour
wire my_opaque  = my_in_q  && (my_pix  != KEY);
wire two_opaque = two_in_q && (two_pix != KEY);

reg [11:0] out_rgb;

// priority chain. My marble is drawn on top, then the opponent, then the background.
always @* begin
    if      (my_opaque)  out_rgb = my_pix;
    else if (two_opaque) out_rgb = two_red;
    else                 out_rgb = {bg_r, bg_g, bg_b};
end

assign {draw_r, draw_g, draw_b} = out_rgb;

endmodule