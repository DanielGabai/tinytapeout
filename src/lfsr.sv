/* 8-bit Linear Feedback Shift Register
   Used to generate pseudo-random sequences
   Shifts to the left
   Incoming bit is XOR of bits 8,6,5,2
   To generate sequence, watch bits 7, 4, 1
   */

module lfsr (
    input logic clk,
    input logic rst_n,
    input logic load,
    input logic en,

    input logic [7:0] seed,
    output logic [2:0] r_out
);
logic [7:0] r_store;
always_ff @(posedge clk) begin
    if (!rst_n) begin
        r_store <= 8'd1;
    end else if (load && ~en) begin
        r_store <= (seed == 8'd0) ? (8'd1) : seed;
    end else if (en) begin
        r_store <= { r_store[6:0], (r_store[7] ^ r_store[5] ^ r_store[4] ^ r_store[1]) };
    end
end

assign r_out = {r_store[6], r_store[3], r_store[0]};

endmodule