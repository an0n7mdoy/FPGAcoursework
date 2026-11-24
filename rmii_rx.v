// rmii_rx.v - receives the frames sent by rmii_tx (same N) and checks their CRC.
//   ok  pulses for one clock when a good frame arrives; payload is then updated
//   bad pulses for one clock when a frame has a wrong CRC or EtherType
module rmii_rx #(
    parameter N = 46                       // payload bytes, must match rmii_tx
) (
    input  wire           clk,             // 50 MHz
    input  wire           crs_dv,          // from PHY: "frame on RXD"
    input  wire [1:0]     rxd,             // from PHY: 2 bits per clock
    output reg            ok      = 0,
    output reg            bad     = 0,
    output reg  [8*N-1:0] payload = 0      // last good payload
);
    `include "eth_crc32.vh"

    localparam BYTES = 14 + N + 4;         // bytes after the SFD: MACs, type, payload, CRC

    // Register the PHY outputs straight off the pins
    reg       dv  = 0;
    reg [1:0] d   = 0;
    always @(posedge clk) begin
        dv <= crs_dv;
        d  <= rxd;
    end

    reg [8*BYTES-1:0] sr;                  // received bytes, byte 0 ends up lowest
    reg [31:0]        crc;
    reg [9:0]         pos    = 0;
    reg               armed  = 0;          // line has been idle, ready for a frame
    reg               active = 0;

    wire [8*BYTES-1:0] sr_next  = {d, sr[8*BYTES-1:2]};     // new dibit in at the top
    wire [31:0]        crc_next = crc32_dibit(crc, d);

    always @(posedge clk) begin
        ok  <= 0;
        bad <= 0;
        if (!dv) armed <= 1;

        if (!active) begin
            // Preamble is 01 01 01 ..., the SFD ends with 11: data starts next clock
            if (armed && dv && d == 2'b11) begin
                active <= 1;
                armed  <= 0;
                pos    <= 0;
                crc    <= 32'hFFFFFFFF;
            end
        end else begin
            sr  <= sr_next;
            crc <= crc_next;
            pos <= pos + 1;
            if (pos == 4*BYTES - 1) begin                   // last dibit of the frame
                active <= 0;
                // Good frame: CRC leaves the fixed residue, and the type is ours
                if (crc_next == 32'hDEBB20E3 && sr_next[8*12 +: 16] == 16'hB588) begin
                    ok      <= 1;
                    payload <= sr_next[8*14 +: 8*N];
                end else begin
                    bad <= 1;
                end
            end
        end
    end
endmodule
