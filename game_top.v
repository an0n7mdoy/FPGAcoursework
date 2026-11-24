`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: game_top
// Description: Marble movement driven by the on-board ADXL362 accelerometer.
//   - 24-bit signed fixed point, 8 fractional bits (1.0 px = 256)
//   - v += a ; pos += v   every 60 Hz tick
//   - friction (~0.94 -> 15/16) when there is no tilt on an axis
//   - speed limit 3.2 px/frame, diagonal tilt scaled by 181/256
//   - BTN[0] (centre) still respawns the block
//   No dashes, no tile friction, no collisions (screen edges still clamp).
//
//   Assumes clk = 100 MHz. For another clock change TICK_DIV = clk_hz / 60.
//////////////////////////////////////////////////////////////////////////////////

module game_top #(
    parameter integer TICK_DIV = 1666667,   // 100 MHz / 60 Hz
    parameter         INVERT_X = 1,         // flip tilt direction if it feels backwards
    parameter         INVERT_Y = 0,
    parameter         SWAP_XY  = 1          // swap sensor axes if board orientation differs
)(
    input pixclk,
    input clk,
    input rst,                  // active low
    input player,
    input [4:0] btn,
    input [10:0] twopos_x, twopos_y,
    // accelerometer SPI
    input  ACL_MISO,
    output ACL_MOSI,
    output ACL_SCLK,
    output ACL_CSN,
    output [3:0] pix_r,
    output [3:0] pix_g,
    output [3:0] pix_b,
    output [10:0] blkpos_x, blkpos_y,
    output hsync,
    output vsync
    );

//internal wires
wire [3:0] draw_r;
wire [3:0] draw_g;
wire [3:0] draw_b;
wire [10:0] curr_x;
wire [10:0] curr_y;

//------------------------------------------------------------------
// Accelerometer
//------------------------------------------------------------------
wire signed [7:0] acl_x, acl_y;

adxl362_ctrl #(.CLK_DIV(25)) acl_inst (
    .clk(clk),
    .rst_n(rst),
    .miso(ACL_MISO),
    .mosi(ACL_MOSI),
    .sclk(ACL_SCLK),
    .csn(ACL_CSN),
    .ax(acl_x),
    .ay(acl_y)
);

//------------------------------------------------------------------
// 60 Hz physics tick (enable pulse in the clk domain)
//------------------------------------------------------------------
reg [20:0] tick_cnt;
reg        tick;

always @(posedge clk) begin
    if (!rst) begin
        tick_cnt <= 0;
        tick     <= 0;
    end else if (tick_cnt == TICK_DIV-1) begin
        tick_cnt <= 0;
        tick     <= 1;
    end else begin
        tick_cnt <= tick_cnt + 1;
        tick     <= 0;
    end
end

//------------------------------------------------------------------
// Tilt -> acceleration
//   deadzone 3 counts (~3 deg), saturates at 48 counts (~48 deg).
//   2 fixed-point units per count -> max 90/256 = 0.35 px/frame^2
//------------------------------------------------------------------
localparam signed [8:0] DEADZONE = 9'sd3;
localparam signed [8:0] TILT_MAX = 9'sd48;

function signed [8:0] shape;
    input signed [8:0] t;
    begin
        if      (t >  TILT_MAX) shape =   TILT_MAX - DEADZONE;
        else if (t >  DEADZONE) shape =   t - DEADZONE;
        else if (t < -TILT_MAX) shape = -(TILT_MAX - DEADZONE);
        else if (t < -DEADZONE) shape =   t + DEADZONE;
        else                    shape = 9'sd0;
    end
endfunction

// Calibration: hold the board flat and still, press BTNU to store the zero point
reg signed [7:0] off_x = 8'sd0, off_y = 8'sd0;
always @(posedge clk) begin
    if (!rst) begin
        off_x <= 8'sd0;
        off_y <= 8'sd0;
    end else if (btn[1]) begin          // btn[1] = BTNU
        off_x <= acl_x;
        off_y <= acl_y;
    end
end

wire signed [8:0] cal_x = acl_x - off_x;
wire signed [8:0] cal_y = acl_y - off_y;
wire signed [8:0] ext_x = SWAP_XY ? cal_y : cal_x;
wire signed [8:0] ext_y = SWAP_XY ? cal_x : cal_y;

wire signed [8:0] tilt_x = INVERT_X ? -ext_x : ext_x;
wire signed [8:0] tilt_y = INVERT_Y ? -ext_y : ext_y;

wire signed [8:0] shp_x = shape(tilt_x);
wire signed [8:0] shp_y = shape(tilt_y);
wire act_x = (shp_x != 0);
wire act_y = (shp_y != 0);
wire diag  = act_x & act_y;

wire signed [10:0] acc_x_lin = shp_x <<< 1;
wire signed [10:0] acc_y_lin = shp_y <<< 1;
wire signed [22:0] acc_x_dg  = acc_x_lin * 12'sd181;
wire signed [22:0] acc_y_dg  = acc_y_lin * 12'sd181;

wire signed [10:0] acc_x = diag ? (acc_x_dg >>> 8) : acc_x_lin;
wire signed [10:0] acc_y = diag ? (acc_y_dg >>> 8) : acc_y_lin;

//------------------------------------------------------------------
// Physics constants (1.0 px = 256)
//------------------------------------------------------------------
localparam signed [23:0] VMAX   = 24'sd819;     // 3.2 px/frame
localparam signed [23:0] VMAX_D = 24'sd579;     // 3.2 * 181/256 per axis on diagonals
localparam signed [23:0] X_MIN  = 24'sd2560;    // 10 px
localparam signed [23:0] X_MAX  = 24'sd353280;  // 1380 px
localparam signed [23:0] Y_MIN  = 24'sd2560;    // 10 px
localparam signed [23:0] Y_MAX  = 24'sd215040;  // 840 px

// friction ~0.94 (15/16 = 0.9375); snap to zero at very low speed
function signed [23:0] fric;
    input signed [23:0] v;
    begin
        if (v < 24'sd16 && v > -24'sd16) fric = 24'sd0;
        else                             fric = v - (v >>> 4);
    end
endfunction

reg signed [23:0] pos_x, pos_y;
reg signed [23:0] vel_x, vel_y;
reg signed [23:0] nvx, nvy, npx, npy, vlim;

always @(posedge clk) begin
    if (!rst || btn[0]) begin
        pos_x <= player ? 24'sd330240 : 24'sd25600;   // 1290 / 100 px
        pos_y <= 24'sd102400;                         // 400 px
        vel_x <= 24'sd0;
        vel_y <= 24'sd0;
    end else if (tick) begin
        vlim = diag ? VMAX_D : VMAX;

        // ---- X axis ----
        nvx = act_x ? (vel_x + acc_x) : fric(vel_x);
        if      (nvx >  vlim) nvx =  vlim;
        else if (nvx < -vlim) nvx = -vlim;
        npx = pos_x + nvx;
        if      (npx < X_MIN) begin npx = X_MIN; nvx = 24'sd0; end
        else if (npx > X_MAX) begin npx = X_MAX; nvx = 24'sd0; end

        // ---- Y axis ----
        nvy = act_y ? (vel_y + acc_y) : fric(vel_y);
        if      (nvy >  vlim) nvy =  vlim;
        else if (nvy < -vlim) nvy = -vlim;
        npy = pos_y + nvy;
        if      (npy < Y_MIN) begin npy = Y_MIN; nvy = 24'sd0; end
        else if (npy > Y_MAX) begin npy = Y_MAX; nvy = 24'sd0; end

        vel_x <= nvx;  vel_y <= nvy;
        pos_x <= npx;  pos_y <= npy;
    end
end

// integer part of the position goes to the renderer
assign blkpos_x = pos_x[18:8];
assign blkpos_y = pos_y[18:8];

drawcon drawcon_inst(
    .player(player),
    .blkpos_x(blkpos_x),
    .blkpos_y(blkpos_y),
    .twopos_x(twopos_x),
    .twopos_y(twopos_y),
    .draw_r(draw_r),
    .draw_g(draw_g),
    .draw_b(draw_b),
    .curr_x(curr_x),
    .curr_y(curr_y)
);

vga vga_inst(
    .clk(pixclk),
    .rst(rst),
    .draw_r(draw_r),
    .draw_g(draw_g),
    .draw_b(draw_b),
    .pix_r(pix_r),
    .pix_g(pix_g),
    .pix_b(pix_b),
    .curr_x(curr_x),
    .curr_y(curr_y),
    .hsync(hsync),
    .vsync(vsync)
);

endmodule