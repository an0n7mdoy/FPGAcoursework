// eth_crc32.vh
// IEEE 802.3 CRC-32, reflected form (poly 0xEDB88320), one RMII dibit per call.
// Usage: init to 32'hFFFFFFFF, feed every dibit from dest MAC to end of payload.
//   TX: transmit ~crc, LSB first.
//   RX: also feed the 4 FCS bytes; a good frame leaves crc == 32'hDEBB20E3.
function [31:0] crc32_dibit;
    input [31:0] crc_in;
    input [1:0]  d;        // d[0] is the bit sent/received first
    integer i;
    reg [31:0] c;
    begin
        c = crc_in;
        for (i = 0; i < 2; i = i + 1)
            c = (c[0] ^ d[i]) ? ((c >> 1) ^ 32'hEDB88320) : (c >> 1);
        crc32_dibit = c;
    end
endfunction
