/* Contains the delay loop used for the seven seg
   Uses a 32-bit register to store delay
   Technically will only count up to 2^31 + 1
   Adjustable via input switches prior to game start
   The input selects which bit to "watch" of counter
   Enable must be low to load a delay value
   */

// TODO: Fix adj_delay not loading values

module delay (
    input logic clk,
    input logic rst_n,
    input logic en,

    input logic [7:0] ui_in, // switch input, uses switches 0-4
    input logic load_delay,

    output logic finish
);

logic [31:0] counter;
logic [4:0] adj_delay;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        counter <= '0;
        adj_delay <= '0;
    end else begin
        if (en && !finish) begin
            counter <= counter + 1'b1;
        end 
        if (~en && load_delay) begin
            adj_delay <= ui_in[4:0];
        end
    end
end

always_comb begin
    finish = counter[adj_delay];
end

endmodule