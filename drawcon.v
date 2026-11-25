`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03.11.2022 16:50:09
// Design Name: 
// Module Name: drawcon
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module drawcon(
    input player,
    input [10:0] blkpos_x,
    input [10:0] blkpos_y,
    input [10:0] twopos_x,
    input [10:0] twopos_y,
    output [3:0] draw_r,
    output [3:0] draw_g,
    output [3:0] draw_b,
    input [10:0] curr_x,
    input [10:0] curr_y
    );
    
reg [3:0] blk_r, blk_b, blk_g;
reg [3:0] bg_r, bg_g, bg_b;


// background colour
always@* begin
    if((curr_x < 11'd10) || (curr_x > 11'd1430) || (curr_y < 11'd10) || (curr_y > 11'd890)) begin
        bg_r <= 4'b1111;
        bg_g <= 4'b1111;
        bg_b <= 4'b1111;
    end
    else begin
        bg_r <= 4'b0000;
        bg_g <= 4'b0000;
        bg_b <= 4'b0000;
    end
end

// square colours: player 1 is always pink, player 2 always green
wire [11:0] my_colour    = player ? 12'h9F9 : 12'hF9F;
wire [11:0] their_colour = player ? 12'hF9F : 12'h9F9;

// marble radius = 24 px (radius squared = 576)
localparam signed [23:0] R_SQ = 24'sd576;

// offset of the current pixel from each marble's centre
wire signed [11:0] my_dx  = $signed({1'b0, curr_x}) - $signed({1'b0, blkpos_x});
wire signed [11:0] my_dy  = $signed({1'b0, curr_y}) - $signed({1'b0, blkpos_y});
wire signed [11:0] two_dx = $signed({1'b0, curr_x}) - $signed({1'b0, twopos_x});
wire signed [11:0] two_dy = $signed({1'b0, curr_y}) - $signed({1'b0, twopos_y});

// squared distance from each centre
wire signed [23:0] my_d2  = my_dx*my_dx   + my_dy*my_dy;
wire signed [23:0] two_d2 = two_dx*two_dx + two_dy*two_dy;

// marble colour: circles centred on blkpos / twopos, mine drawn on top of theirs
always@* begin
    if (my_d2 <= R_SQ) begin
        {blk_r, blk_g, blk_b} = my_colour;
    end else if (two_d2 <= R_SQ) begin
        {blk_r, blk_g, blk_b} = their_colour;
    end else begin
        {blk_r, blk_g, blk_b} = 12'h000;
    end
end

assign draw_r = (blk_r != 4'b0000) ? blk_r : bg_r;
assign draw_g = (blk_g != 4'b0000) ? blk_g : bg_g; 
assign draw_b = (blk_b != 4'b0000) ? blk_b : bg_b;

//    // background colour
//    always@* begin
//        if((curr_x < 11'd10) || (curr_x > 11'd1430) || (curr_y < 11'd10) || (curr_y > 11'd890)) begin
//            bg_r <= 4'b1111;
//            bg_g <= 4'b1111;
//            bg_b <= 4'b1111;
//        end
//        else begin
//            bg_r <= 4'b0000;
//            bg_g <= 4'b0000;
//            bg_b <= 4'b0000;
//        end
//    end
    
//    // block colour
//    always@* begin
//        if((curr_x < blkpos_x) || (curr_x > (blkpos_x+50)) || (curr_y < blkpos_y) || (curr_y > (blkpos_y+50))) begin
//            blk_r <= 4'b0000;
//            blk_g <= 4'b0000;
//            blk_b <= 4'b0000;
//        end 
//        else begin
//            blk_r <= 4'b1111;
//            blk_g <= 4'b1001;
//            blk_b <= 4'b1111;
//        end
//    end
    
//    assign draw_r = (blk_r != 4'b0000) ? blk_r : bg_r;
//    assign draw_g = (blk_g != 4'b0000) ? blk_g : bg_g;
//    assign draw_b = (blk_b != 4'b0000) ? blk_b : bg_b;    
    
    
endmodule
