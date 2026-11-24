`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 20.04.2021 19:58:02
// Design Name: 
// Module Name: game_top
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


module game_top(
    input pixclk,
    input clk,
    input rst,
    input player,
    input [4:0] btn,
    input [10:0] twopos_x, twopos_y,
    output [3:0] pix_r,
    output [3:0] pix_g,
    output [3:0] pix_b,
    output reg [10:0] blkpos_x, blkpos_y,
    output hsync,
    output vsync
    );

//internal wires
wire [3:0] draw_r;
wire [3:0] draw_g;
wire [3:0] draw_b;
wire [10:0] curr_x;
wire [10:0] curr_y;

//wires for the block
reg [20:0] clk_div;
reg game_clk;

//game clock generation
always@(posedge clk) begin
    if(!rst) begin
        clk_div <= 0;
        game_clk <= 0;
    end else begin
        if (clk_div == 21'd1666666 ) begin
            clk_div <= 0;
            game_clk <= !game_clk;
        end else begin
            clk_div <= clk_div + 1;
        end
    end
end

//block movement
always@(posedge game_clk) begin
    if(btn[0]) begin
        blkpos_x <= player ? 11'd1290 : 11'd100;   // P2 starts right, P1 starts left
        blkpos_y <= 11'd400;
    end else begin
        case(btn[4:1])
            4'b0010: begin//left
                if(blkpos_x > 11'd10) begin
                   blkpos_x <= blkpos_x - 4;
                end
            end
            4'b0100: begin//right
                if(blkpos_x < (11'd1430-11'd50)) begin
                   blkpos_x <= blkpos_x + 4;
                end
            end
            
            4'b1000: begin//up
                if(blkpos_y < (11'd890-11'd50)) begin
                   blkpos_y <= blkpos_y + 4;
                end
            end
            4'b0001: begin//down
                if(blkpos_y > 11'd10) begin
                   blkpos_y <= blkpos_y - 4;
                end
            end
            default: begin
                blkpos_x <= blkpos_x;
                blkpos_y <= blkpos_y; 
            end
        endcase
    end
end
    
             
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

