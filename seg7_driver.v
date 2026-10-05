module seg7_driver (
    input  wire [3:0]  game_state,
    input  wire        p1_on_left,
    input  wire [1:0]  p1_rounds_won,
    input  wire [1:0]  p2_rounds_won,
    input  wire        p1_wins_match,
    input  wire        p2_wins_match,
    output reg  [6:0]  HEX5,  // leftmost
    output reg  [6:0]  HEX4,
    output reg  [6:0]  HEX3,
    output reg  [6:0]  HEX2,
    output reg  [6:0]  HEX1,
    output reg  [6:0]  HEX0   // rightmost
);

    localparam GS_MENU       = 4'd0;
    localparam GS_COUNTDOWN  = 4'd1;
    localparam GS_PLAYING    = 4'd2;
    localparam GS_ROUND_END  = 4'd3;
    localparam GS_GAME_OVER  = 4'd4;

    localparam SEG_OFF  = 7'b111_1111;
    localparam SEG_0    = 7'b100_0000;
    localparam SEG_1    = 7'b111_1001;
    localparam SEG_2    = 7'b010_0100;
    localparam SEG_3    = 7'b011_0000;
    localparam SEG_P    = 7'b000_1100;
    localparam SEG_V    = 7'b100_0001;  // 'U'-shape used as V
    localparam SEG_S    = 7'b001_0010;
    localparam SEG_DASH = 7'b011_1111;

    function automatic [6:0] dig;
        input [1:0] d;
        case (d)
            2'd0: dig = SEG_0;
            2'd1: dig = SEG_1;
            2'd2: dig = SEG_2;
            default: dig = SEG_3;
        endcase
    endfunction

    wire [6:0] left_num  = p1_on_left ? SEG_1 : SEG_2;
    wire [6:0] right_num = p1_on_left ? SEG_2 : SEG_1;

    always @(*) begin
        case (game_state)
            GS_MENU: begin
                HEX5 = SEG_P;  HEX4 = left_num;
                HEX3 = SEG_OFF; HEX2 = SEG_OFF;
                HEX1 = SEG_P;  HEX0 = right_num;
            end

            GS_COUNTDOWN, GS_PLAYING, GS_ROUND_END: begin
                HEX5 = SEG_P; HEX4 = left_num;
                HEX3 = SEG_V; HEX2 = SEG_S;
                HEX1 = SEG_P; HEX0 = right_num;
            end

            GS_GAME_OVER: begin
                // "P w - 3 - L"
                HEX5 = SEG_P;
                HEX4 = p1_wins_match ? SEG_1 : SEG_2;
                HEX3 = SEG_DASH;
                HEX2 = SEG_3;
                HEX1 = SEG_DASH;
                HEX0 = p1_wins_match ? dig(p2_rounds_won) : dig(p1_rounds_won);
            end

            default: begin
                HEX5 = SEG_OFF; HEX4 = SEG_OFF; HEX3 = SEG_OFF;
                HEX2 = SEG_OFF; HEX1 = SEG_OFF; HEX0 = SEG_OFF;
            end
        endcase
    end

endmodule
