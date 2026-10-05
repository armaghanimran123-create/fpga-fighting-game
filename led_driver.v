module led_driver (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        game_en,
    input  wire [3:0]  game_state,
    input  wire        p1_on_left,
    input  wire [1:0]  p1_rounds_won,
    input  wire [1:0]  p2_rounds_won,
    output reg  [9:0]  LEDR
);

    localparam GS_MENU       = 4'd0;
    localparam GS_COUNTDOWN  = 4'd1;
    localparam GS_PLAYING    = 4'd2;
    localparam GS_ROUND_END  = 4'd3;
    localparam GS_GAME_OVER  = 4'd4;

    // ~2 Hz Blink for game over.

    localparam BLINK_HALF = 30;
    reg [5:0] blink_ctr;
    reg       blink_on;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            blink_ctr <= 0;
            blink_on  <= 0;
        end else if (game_en) begin
            if (blink_ctr == BLINK_HALF - 1) begin
                blink_ctr <= 0;
                blink_on  <= ~blink_on;
            end else blink_ctr <= blink_ctr + 1'b1;
        end
    end

    wire [1:0] left_rounds  = p1_on_left ? p1_rounds_won : p2_rounds_won;
    wire [1:0] right_rounds = p1_on_left ? p2_rounds_won : p1_rounds_won;

    always @(*) begin
        case (game_state)
            GS_COUNTDOWN, GS_PLAYING, GS_ROUND_END: begin
                LEDR[9]   = (left_rounds  >= 2'd1);
                LEDR[8]   = (left_rounds  >= 2'd2);
                LEDR[7]   = (left_rounds  >= 2'd3);
                LEDR[6:3] = 4'b0000;
                LEDR[2]   = (right_rounds >= 2'd1);
                LEDR[1]   = (right_rounds >= 2'd2);
                LEDR[0]   = (right_rounds >= 2'd3);
            end
            GS_GAME_OVER: LEDR = {10{blink_on}};
            default:      LEDR = 10'b0;   // MENU and anything else
        endcase
    end

endmodule
