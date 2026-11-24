`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: adxl362_ctrl
// Description: Minimal SPI master (mode 0) for the ADXL362 on the Nexys4 DDR.
//   1. Waits ~5 ms after reset.
//   2. Writes POWER_CTL (0x2D) = 0x02  -> measurement mode.
//   3. Continuously burst-reads XDATA (0x08) and YDATA (0x09).
//
//   Outputs are the 8-bit signed X/Y registers (range +/-2 g, ~16 mg per LSB).
//   Tilting the board by theta gives roughly 64*sin(theta) counts.
//
//   SCLK frequency = clk / (2*CLK_DIV)  ->  100 MHz / 50 = 2 MHz (max is 8 MHz).
//////////////////////////////////////////////////////////////////////////////////

module adxl362_ctrl #(
    parameter integer CLK_DIV = 25
)(
    input  clk,
    input  rst_n,               // active low
    input  miso,
    output reg mosi,
    output reg sclk,
    output reg csn,
    output reg signed [7:0] ax,
    output reg signed [7:0] ay
);

localparam [2:0] S_POWERUP = 3'd0,
                 S_GAP     = 3'd1,
                 S_START   = 3'd2,
                 S_XFER    = 3'd3,
                 S_END     = 3'd4;

reg [2:0]  state;
reg [19:0] wait_cnt;
reg [15:0] div_cnt;
reg [31:0] tx_sh;
reg [31:0] rx_sh;
reg [5:0]  bits_left;
reg [5:0]  nbits;
reg        init_done;

// synchronise MISO
reg miso_s1, miso_s2;
always @(posedge clk) begin
    miso_s1 <= miso;
    miso_s2 <= miso_s1;
end

always @(posedge clk) begin
    if (!rst_n) begin
        state     <= S_POWERUP;
        wait_cnt  <= 0;
        div_cnt   <= 0;
        tx_sh     <= 0;
        rx_sh     <= 0;
        bits_left <= 0;
        nbits     <= 0;
        init_done <= 0;
        mosi      <= 0;
        sclk      <= 0;
        csn       <= 1;
        ax        <= 0;
        ay        <= 0;
    end else begin
        case (state)
            //----------------------------------------------------------
            S_POWERUP: begin
                csn  <= 1;
                sclk <= 0;
                wait_cnt <= wait_cnt + 1;
                if (wait_cnt[19]) begin                 // ~5.2 ms @100 MHz
                    tx_sh <= {8'h0A, 8'h2D, 8'h02, 8'h00}; // write POWER_CTL = measure
                    nbits <= 6'd24;
                    state <= S_START;
                end
            end
            //----------------------------------------------------------
            S_START: begin
                csn       <= 0;
                sclk      <= 0;
                mosi      <= tx_sh[31];
                bits_left <= nbits;
                div_cnt   <= 0;
                state     <= S_XFER;
            end
            //----------------------------------------------------------
            S_XFER: begin
                if (div_cnt == CLK_DIV-1) begin
                    div_cnt <= 0;
                    if (!sclk) begin                    // rising edge: sample
                        sclk      <= 1;
                        rx_sh     <= {rx_sh[30:0], miso_s2};
                        bits_left <= bits_left - 1;
                    end else begin                      // falling edge: shift out
                        sclk <= 0;
                        if (bits_left == 0) begin
                            state <= S_END;
                        end else begin
                            tx_sh <= tx_sh << 1;
                            mosi  <= tx_sh[30];
                        end
                    end
                end else begin
                    div_cnt <= div_cnt + 1;
                end
            end
            //----------------------------------------------------------
            S_END: begin
                csn  <= 1;
                sclk <= 0;
                mosi <= 0;
                if (!init_done) begin
                    init_done <= 1;
                end else begin
                    ax <= rx_sh[15:8];                  // XDATA
                    ay <= rx_sh[7:0];                   // YDATA
                end
                wait_cnt <= 0;
                state    <= S_GAP;
            end
            //----------------------------------------------------------
            S_GAP: begin                                // CS high between transfers
                csn  <= 1;
                sclk <= 0;
                wait_cnt <= wait_cnt + 1;
                if (wait_cnt[15:0] == 16'hFFFF) begin   // ~0.65 ms
                    tx_sh <= {8'h0B, 8'h08, 8'h00, 8'h00}; // read from XDATA, 2 bytes
                    nbits <= 6'd32;
                    state <= S_START;
                end
            end
            default: state <= S_POWERUP;
        endcase
    end
end

endmodule