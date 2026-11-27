// top.v - two-board Ethernet link test (same bitstream on both boards).
//   7-seg left 4   = good frames received (hex)
//   7-seg right 4  = bad frames received (hex)
module top (
    input  wire        CLK100MHZ,
    input [4:0] btn,
    input rst,
    input sw,
    output [3:0] pix_r,
    output [3:0] pix_g,
    output [3:0] pix_b,
    output hsync,
    output vsync,
    output wire [6:0]  SEG,
    output wire        DP,
    output wire [7:0]  AN,
    output wire        ETH_REFCLK,
    output reg         ETH_RSTN = 0,
    output wire        ETH_TXEN,
    output wire [1:0]  ETH_TXD,
    input  wire        ETH_CRSDV,
    input  wire [1:0]  ETH_RXD,
    input  ACL_MISO,
    output ACL_MOSI,
    output ACL_SCLK,
    output ACL_CSN
);
    // Clocking Wizard IP: clk_out1 = 50 MHz, clk_out2 = 50 MHz at 45 deg (to the PHY)
    wire clk, locked, pixclk;
    clk_wiz_0 clocks (
        .clk_in1  (CLK100MHZ),
        .clk_out1 (clk),
        .clk_out2 (ETH_REFCLK),
        .clk_out3 (pixclk),
        .locked   (locked)                  // high once the clocks are stable
    );


    reg [21:0] twopos;
    wire [21:0] blkpos;
    reg signed [23:0] twovel_x, twovel_y;
    wire signed [23:0] blkvel_x, blkvel_y;
    // Hold the PHY in reset until the clocks are stable, then 1 ms more.
    // ETH_RSTN also acts as the reset for this whole design: TX/RX flush any
    // junk state from before 'locked' within ~1000 clocks, well inside that 1 ms.
    reg [15:0] rst_count = 0;
    always @(posedge clk)
        if (!locked) begin
            rst_count <= 0;
            ETH_RSTN  <= 0;
        end else if (rst_count != 50_000)
            rst_count <= rst_count + 1;
        else
            ETH_RSTN  <= 1;

    // Synchronise the switches to clk
    reg [4:0] bt1 = 0, bt2 = 0;
    reg pl1, player;
    always @(posedge clk) begin
        bt1 <= btn;
        bt2 <= bt1;
        pl1 <= sw;
        player <= pl1;
    end

    // Send a frame every 1 ms (50,000 clocks)
    reg [15:0] timer = 0;
    always @(posedge clk)
        timer <= (timer == 49_999) ? 0 : timer + 1;

    rmii_tx tx (
        .clk     (clk),
        .start   (ETH_RSTN && timer == 0),
        .payload ({298'd0, blkvel_x, blkvel_y, blkpos}),           // 298 0s, [69:46] velx, [45:22] vely, [21:0] pos
        .tx_en   (ETH_TXEN),
        .txd     (ETH_TXD),
        .busy    ()
    );

    // Receive, show the other board's switches, count good and bad frames
    wire         ok, bad;
    wire [367:0] rx_payload;
    rmii_rx rx (
        .clk     (clk),
        .crs_dv  (ETH_CRSDV),
        .rxd     (ETH_RXD),
        .ok      (ok),
        .bad     (bad),
        .payload (rx_payload)
    );

    reg [15:0] good_count = 0, bad_count = 0;
    always @(posedge clk) begin
        if (!ETH_RSTN) begin                // start counting from 0 once the link is up
            good_count <= 0;
            bad_count  <= 0;
        end else begin
            if (ok) begin
                twovel_x   <= rx_payload[69:46];
                twovel_y   <= rx_payload[45:22];
                twopos     <= rx_payload[21:0];
                good_count <= good_count + 1;
            end
            if (bad)
                bad_count <= bad_count + 1;
        end
    end
    
    game_top game (
        .pixclk(pixclk),
        .clk(CLK100MHZ),
        .rst(rst),
        .player(player),
        .btn(bt2),
        .twopos_x(twopos[21:11]),
        .twopos_y(twopos[10:0]),
        .twovel_x(twovel_x),
        .twovel_y(twovel_y),
        .pix_r(pix_r),
        .pix_g(pix_g),
        .pix_b(pix_b),
        .blkpos_x(blkpos[21:11]),
        .blkpos_y(blkpos[10:0]),
        .fvel_x(blkvel_x),
        .fvel_y(blkvel_y),
        .hsync(hsync), .vsync(vsync),
        .ACL_MISO(ACL_MISO),
        .ACL_MOSI(ACL_MOSI),
        .ACL_SCLK(ACL_SCLK),
        .ACL_CSN(ACL_CSN)
    );
    
    seg7_hex display (
        .clk   (clk),
        .value ({good_count, bad_count}),
        .seg   (SEG),
        .an    (AN)
    );
    
    assign DP = 1;                          // decimal points off
endmodule
