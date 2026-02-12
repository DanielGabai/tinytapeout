/* 8-bit Linear Feedback Shift Register
   Used to generate pseudo-random sequences
   Shifts to the right
   Incoming bit is XOR of bits 8,6,5,4
   */

module lfsr (
    input logic clk,
    input logic rst_n,
    input logic load,
    input logic [7:0] seed,
    output logic [7:0] r_out
);

always_ff @(posedge clk) begin
    if (!rst_n) begin
        r_out <= 8'd1;
    end else if (load) begin
        r_out <= (seed == 8'd0) ? (8'd1) : seed;
    end else begin
        r_out <= { r_out[6:0], (r_out[7] ^ r_out[5] ^ r_out[4] ^ r_out[1]) };
    end
end

endmodule