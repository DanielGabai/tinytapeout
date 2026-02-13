/* Top level file for the game
   Contains the game-state FSM 
   
   Input Switch Map:
   0 - MSB of User Input
   1 - User Input
   2 - LSB of User Input
   3
   4
   5
   6 - Submit Answer
   7 - Start / End Game
   */

module top (
    input logic clk,
    input logic rst_n,

    input  logic [7:0] ui_in,    // Input Switches
    output logic [7:0] uo_out   // Seven Seg Output

);

typedef enum logic [2:0] { // FSM States
    RST,
    LOAD_SEED,
    LOAD_REG_FILE
} state_t;

state_t state, next_state;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        state <= RST;
    end else begin
        state <= next_state;
    end
end

always_comb begin
    next_state = state;
    case (state) 
        RST : next_state = LOAD_SEED;
        LOAD_SEED : next_state = LOAD_REG_FILE;
        LOAD_REG_FILE : next_state = LOAD_REG_FILE;
    endcase
end

endmodule