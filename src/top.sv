// `include "lfsr.sv"
// `include "reg_file.sv"
// `include "decoder.sv"
// `include "reg_file.sv"

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
    /* verilator lint_off UNUSEDSIGNAL */
    /* verilator lint_off UNDRIVEN */
    input logic [7:0] uio_in,
    output logic [7:0] uio_out,
    output logic [7:0] uio_oe,
    input logic ena // always 1 when design is powered
    /* verilator lint_on UNUSEDSIGNAL */
    /* verilator lint_on UNDRIVEN */
);



typedef enum logic [2:0] { // FSM States
    // INT -> intermediary state for registering input
    RST,
    LOAD_SEED,
    LOAD_SEED_INT, 
    LOAD_REG_FILE,
    LOAD_DELAY,
    CORRECT_ANS,
    INCORRECT_ANS
} state_t;

state_t state, next_state;

always_ff @(posedge clk) begin
    if (!rst_n || ui_in[7] == 1'b0) begin
        state <= RST; // By a default we are in reset state
    end else begin
        state <= next_state;
    end
end

localparam logic [7:0] CORRECT = 8'b00111001;
localparam logic [7:0] INCORRECT = 8'b01110001;

logic lfsr_en, reg_file_we;
/* verilator lint_off UNDRIVEN */
logic [3:0] reg_file_in_sel, reg_file_out_sel;
/* verilator lint_on UNDRIVEN */
logic [1:0] segment_sel; //0 is decoder_out, 1 is incorrect, 2 is correct 
// If segment_sel is high, we do the F or C, else its just numbers

always_comb begin // Next state logic
    next_state = state;
    // Default signal values
    lfsr_en   = 1'b0;
    lfsr_load = 1'b0;
    reg_file_we = 1'b0;
    segment_sel = 2'b00;
    case (state) 
        RST : begin
            if (ui_in[7] == 1'b1 && ui_in[6:0] == 7'd0) begin
                next_state = LOAD_SEED;
                lfsr_en = 1'b1; // Enable the lfsr
            end else begin
                next_state = RST;
            end
        end
        LOAD_SEED : begin // Check that swtich 6 was flipped high
            if (ui_in[6] == 1'b1) begin
                next_state = LOAD_SEED_INT;
            end else begin
                next_state = LOAD_SEED;
            end
        end
        LOAD_SEED_INT : begin // Switch 6 went from high to low
            if (ui_in[6] == 1'b0) begin
                next_state = LOAD_REG_FILE;
                lfsr_load = 1'b1;
            end else begin
                next_state = LOAD_SEED_INT;
            end
        end
        LOAD_REG_FILE : begin
            lfsr_load = 1'b0;
            if(ui_in[5] == 1'b1) begin
                if(lfsr_r_out == ui_in[7:0]) begin // Matches 
                    next_state = CORRECT_ANS;
                end else begin
                    next_state = INCORRECT_ANS;
                end
            end
            else begin
                next_state = LOAD_REG_FILE;
            end
        end
        CORRECT_ANS : begin
            lfsr_en = 1'b0;
            reg_file_we = 1'b0;
            segment_sel = 2'b10;
            // uo_out = CORRECT; This is wrong but we need a way to drive the decoder?
            next_state = RST;

        end
        INCORRECT_ANS : begin
            lfsr_en = 1'b0;
            reg_file_we = 1'b0;
            segment_sel = 2'b01;
            // uo_out = INCORRECT;
            next_state = RST;
        end
        default : begin
            next_state = state;
            lfsr_en = 1'b0;
            reg_file_we = 1'b0;
            lfsr_load = 1'b0;

        end
    endcase
end

always_comb begin // Conditional logic assignments

end

// Instantiated Module Wires

// LFSR
logic lfsr_load;
logic [2:0] lfsr_r_out;

// Reg File
logic [2:0] reg_file_out_decoder_in;

// Decoder 
logic [6:0] decoder_out;
// Instantiated Modules

// TODO: implement load, en via FSM controls
lfsr lfsr (
    .clk(clk),
    .rst_n(rst_n),
    .en(lfsr_en), 
    .load(lfsr_load),
    .seed(ui_in[5:0]),
    .r_out(lfsr_r_out)
);

// TODO: implement we, in_sel, out_sel via FSM controls
reg_file reg_file (
    .clk(clk),
    .we(reg_file_we),
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
always_comb begin
    if (segment_sel == 2'b10) begin
        uo_out = {CORRECT};
    end
    else if(segment_sel == 2'b01) begin
        uo_out = {INCORRECT};
    end
    else begin
        uo_out = {1'b0, decoder_out};
    end
end
//assign uo_out = {1'b0, decoder_out};

endmodule