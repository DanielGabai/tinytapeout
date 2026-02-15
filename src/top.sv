/* Top level file for the game
   Contains the game-state FSM 
   
   Input Switch Map:
   0 - MSB of User Input   | MSB of Seed & Delay Input
   1 - User Input          | Seed & Delay Input
   2 - LSB of User Input   | Seed & Delay Input
   3                       | Seed & Delay Input
   4                       | Seed Input & LSB of Delay Input
   5                       | LSB of Seed Input
   6 - Submit Answer
   7 - Start / End Game

   Game Loop:
   1) All switches must be low to start, flip 7 high
   2) Enter seed value on switches[0:5], flip 6 high then low
   3) Game starts
   4) Flash a number on the seven seg; Wait for user input

   FSM Rules:
   1) If switch[7] ever goes low, go to reset state
   2) Switch[6] must be flipped high then low to detect input
    - Requires an intermediary state to catch correctly
   3) 
   */

module tt_um_memory_game_top (
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