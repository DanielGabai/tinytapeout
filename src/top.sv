`include "lfsr.sv"
`include "reg_file.sv"
`include "decoder.sv"

/* Top level file for the game
   Contains the game-state FSM 
   
   Input Switch Map:
   0 - MSB of User Input   | MSB of Seed Input | MSB of Delay Input
   1 - User Input          | Seed Input        | Delay Input
   2 - LSB of User Input   | Seed Input        | Delay Input
   3                       | Seed Input        | Delay Input
   4                       | Seed Input        | LSB of Delay Input
   5                       | LSB of Seed Input |
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
    output logic [7:0] uo_out,   // Seven Seg Output

    // Below not used
    input logic [7:0] uio_in,
    output logic [7:0] uio_out,
    output logic [7:0] uio_oe,
    input logic ena // always 1 when design is powered
);



typedef enum logic [2:0] { // FSM States
    // INT -> intermediary state for registering input
    RST,
    LOAD_SEED,
    LOAD_SEED_INT, 
    LOAD_REG_FILE,
    LOAD_DELAY
} state_t;

state_t state, next_state;

always_ff @(posedge clk) begin
    if (!rst_n || ui_in[7] == 1'b0) begin
        state <= RST;
    end else begin
        state <= next_state;
    end
end

always_comb begin // Next state logic
    next_state = state;
    case (state) 
        RST : begin
            if (ui_in[7] == 1'b1 && ui_in[6:0] == 7'd0) begin
                next_state = LOAD_SEED;
            end else begin
                next_state = RST;
            end
        end
        LOAD_SEED : begin
            if (ui_in[6] == 1'b1) begin
                next_state = LOAD_SEED_INT;
            end else begin
                next_state = LOAD_SEED;
            end
        end
        LOAD_SEED_INT : begin
            if (ui_in[6] == 1'b0) begin
                next_state = LOAD_REG_FILE;
                lfsr_load = 1'b1;
            end else begin
                next_state = LOAD_SEED_INT;
            end
        end
        LOAD_REG_FILE : begin
            lfsr_load = 1'b0;

        end
    endcase
end

always_comb begin // Conditional logic assignments

end

// Instantiated Module Wires

// LFSR
logic lfsr_load;
logic [7:0] lfsr_r_out;

// Reg File
logic [2:0] reg_file_out_decoder_in;

// Decoder 
logic [6:0] decoder_out;
// Instantiated Modules

// TODO: implement load via FSM controls
lfsr lfsr (
    .clk(clk),
    .rst_n(rst_n),
    .load(lfsr_load),
    .seed(ui_in[5:0]),
    .r_out(lfsr_r_out)
);

// TODO: implement we, in_sel, out_sel via FSM controls
reg_file reg_file (
    .clk(clk),
    .we(reg_file_en),
    .in_reg(lfsr_r_out),
    .in_sel(reg_file_in_sel),
    .out_sel(reg_file_out_sel),
    .out_reg(reg_file_out_decoder_in)
);

decoder decoder (
    .counter(reg_file_out_decoder_in),
    .segments(decoder_out)
);

// Wire assignments
assign uo_out = {1'b0, decoder_out};

endmodule