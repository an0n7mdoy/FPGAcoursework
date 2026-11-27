`timescale 1ns / 1ps

module tile_map (
    input  wire        clk,
    input  wire [10:0] px,        // current pixel x (0..1439)
    input  wire [10:0] py,        // current pixel y (0..899)
    output reg  [1:0]  tile_type, // see localparams below
    output reg         in_map     // 1 if pixel lies inside the tile area
);

    // Tile encodings
    localparam [1:0] FLOOR = 2'd0,
                     WALL  = 2'd1,
                     LAVA  = 2'd2,
                     ICE   = 2'd3;

    localparam COLS     = 18;
    localparam ROWS     = 10;
    localparam TILE     = 80;
    localparam Y_OFFSET = 100;

    // ---------- Map definition ----------
    // '#' = wall, '.' = floor, 'L' = lava, 'I' = ice
    function [COLS*8-1:0] get_row(input integer r);
        case (r)
            0: get_row = "##################";
            1: get_row = "#................#";
            2: get_row = "#..LLL......III..#";
            3: get_row = "#..LLL......III..#";
            4: get_row = "#......##........#";
            5: get_row = "#......##........#";
            6: get_row = "#..III.....LLL...#";
            7: get_row = "#..III.....LLL...#";
            8: get_row = "#................#";
            9: get_row = "##################";
            default: get_row = "..................";
        endcase
    endfunction

    function [1:0] decode(input [7:0] c);
        case (c)
            "#":     decode = WALL;
            "L":     decode = LAVA;
            "I":     decode = ICE;
            default: decode = FLOOR;
        endcase
    endfunction

    // ---------- Build the ROM ----------
    reg [1:0] tiles [0:ROWS*COLS-1];
    integer r, c;
    reg [COLS*8-1:0] row;

    initial begin
        for (r = 0; r < ROWS; r = r + 1) begin
            row = get_row(r);
            for (c = 0; c < COLS; c = c + 1)
                tiles[r*COLS + c] = decode(row[(COLS-1-c)*8 +: 8]);
        end
    end

    // ---------- Pixel -> tile lookup ----------
    wire [10:0] y_rel    = py - Y_OFFSET;
    wire [4:0]  tile_col = px    / TILE;
    wire [4:0]  tile_row = y_rel / TILE;
    wire        valid    = (py >= Y_OFFSET) && (py < Y_OFFSET + ROWS*TILE)
                           && (px < COLS*TILE);

    wire [7:0]  index    = tile_row * COLS + tile_col;

    always @(posedge clk) begin
        in_map    <= valid;
        tile_type <= valid ? tiles[index] : FLOOR;
    end

endmodule