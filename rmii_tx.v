// rmii_tx.v - sends one Ethernet frame over RMII (100 Mb/s) each time 'start' is high.
// Frame: preamble | SFD | dest FF:FF:FF:FF:FF:FF | src 02:00:00:00:00:01 | type 88B5 | payload | CRC
module rmii_tx #(
    parameter N = 46                       // payload bytes (46 is the Ethernet minimum)
) (
    input  wire           clk,             // 50 MHz
    input  wire           start,           // ignored while busy
    input  wire [8*N-1:0] payload,         // byte 0 = payload[7:0]
    output reg            tx_en = 0,       // to PHY: "frame on TXD"
    output reg  [1:0]     txd   = 0,       // to PHY: 2 bits per clock
    output wire           busy
);
    `include "eth_crc32.vh"

    localparam HEAD  = 22;                 // preamble 7 + SFD 1 + MACs 12 + type 2
    localparam DATA  = 4 * (HEAD + N);     // dibits before the CRC
    localparam TOTAL = DATA + 16 + 48;     // + CRC (16 dibits) + inter-frame gap (48 clocks)

    // The frame up to the CRC. Byte 0 is in the lowest bits so it shifts out first,
    // which is why this reads backwards: preamble on the right, payload on the left.
    wire [8*(HEAD+N)-1:0] frame = {payload,
                                   8'hB5, 8'h88,                              // type 0x88B5
                                   8'h01, 8'h00, 8'h00, 8'h00, 8'h00, 8'h02,  // src MAC
                                   {6{8'hFF}},                                // dest MAC
                                   8'hD5,                                     // SFD
                                   {7{8'h55}}};                               // preamble

    reg [8*(HEAD+N)-1:0] sr;               // frame being shifted out
    reg [31:0]           crc;
    reg [9:0]            pos    = 0;       // dibit number within the frame
    reg                  active = 0;
    assign busy = active;

    always @(posedge clk) begin
        if (!active) begin
            if (start) begin
                sr     <= frame;
                crc    <= 32'hFFFFFFFF;
                pos    <= 0;
                active <= 1;
            end
        end else begin
            pos <= pos + 1;
            if (pos < DATA) begin                          // frame data
                tx_en <= 1;
                txd   <= sr[1:0];
                sr    <= sr >> 2;
                if (pos >= 32)                             // CRC skips preamble + SFD
                    crc <= crc32_dibit(crc, sr[1:0]);
            end else if (pos < DATA + 16) begin            // CRC, inverted, LSB first
                txd <= ~crc[1:0];
                crc <= crc >> 2;
            end else if (pos < TOTAL) begin                // gap between frames
                tx_en <= 0;
                txd   <= 0;
            end else begin
                active <= 0;
            end
        end
    end
endmodule
