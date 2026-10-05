module round_manager (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        game_en,

    // MENU inputs (frame-aligned press pulses)

    input  wire        p1_btn_left,
    input  wire        p1_btn_right,
    input  wire        p1_btn_atk,      // P1 confirm
    input  wire        p2_btn_left,
    input  wire        p2_btn_right,

    // Round Results from hit_detection
    input  wire        p1_ko,
    input  wire        p2_ko,
    input  wire        draw_ko,

    // For menu return

    input  wire        p1_btn_any,

    // The Outputs
    output reg  [3:0]  game_state,
    output reg         p1_on_left,
    output reg  [1:0]  p1_rounds_won,
    output reg  [1:0]  p2_rounds_won,
    output reg  [1:0]  countdown_val,   // 3,2,1,0(=START/GO)
    output reg         round_start,     // 1-frame: reset characters to spawn
    output reg         game_active,     // 1 = live gameplay
    output reg         p1_wins_match,
    output reg         p2_wins_match
);

    localparam GS_MENU       = 4'd0;
    localparam GS_COUNTDOWN  = 4'd1;
    localparam GS_PLAYING    = 4'd2;
    localparam GS_ROUND_END  = 4'd3;
    localparam GS_GAME_OVER  = 4'd4;

    localparam CD_FRAMES = 48;   // ~0.8 s per countdown digit
    localparam RE_FRAMES = 72;   // ~1.2 s "KO" pause before the next round

    reg [7:0] cd_ctr;
    reg [1:0] cd_digit;
    reg [7:0] re_ctr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            game_state    <= GS_MENU;
            p1_on_left    <= 1'b1;
            p1_rounds_won <= 0;
            p2_rounds_won <= 0;
            countdown_val <= 2'd3;
            round_start   <= 0;
            game_active   <= 0;
            p1_wins_match <= 0;
            p2_wins_match <= 0;
            cd_ctr        <= 0;
            cd_digit      <= 2'd3;
            re_ctr        <= 0;
        end else begin
            round_start <= 0;                  // default the pulse off every cycle

            if (game_en) begin
                case (game_state)


                    GS_MENU: begin
                        game_active   <= 0;
                        p1_rounds_won <= 0;
                        p2_rounds_won <= 0;
                        p1_wins_match <= 0;
                        p2_wins_match <= 0;

                        // Side arrangement (last write wins on a tie -> deterministic)
                        if (p1_btn_left)  p1_on_left <= 1'b1;
                        if (p1_btn_right) p1_on_left <= 1'b0;
                        if (p2_btn_left)  p1_on_left <= 1'b0;
                        if (p2_btn_right) p1_on_left <= 1'b1;

                        if (p1_btn_atk) begin
                            game_state    <= GS_COUNTDOWN;
                            cd_digit      <= 2'd3;
                            cd_ctr        <= 0;
                            countdown_val <= 2'd3;
                            round_start   <= 1'b1;
                        end
                    end

                   
                    GS_COUNTDOWN: begin
                        game_active <= 0;
                        if (cd_ctr == CD_FRAMES - 1) begin
                            cd_ctr <= 0;
                            if (cd_digit == 2'd0) begin
                                game_state  <= GS_PLAYING;
                                game_active <= 1'b1;
                            end else begin
                                cd_digit      <= cd_digit - 1'b1;
                                countdown_val <= cd_digit - 1'b1;
                            end
                        end else cd_ctr <= cd_ctr + 1'b1;
                    end

                  
                    GS_PLAYING: begin
                        game_active <= 1'b1;

                        if (draw_ko) begin
                            // neither scores; replay the round
                            game_active <= 0;
                            game_state  <= GS_ROUND_END;
                            re_ctr      <= 0;
                        end else if (p2_ko) begin
                            // P1 wins this round
                            game_active <= 0;
                            re_ctr      <= 0;
                            if (p1_rounds_won == 2'd2) begin
                                p1_rounds_won <= 2'd3;
                                p1_wins_match <= 1'b1;
                                game_state    <= GS_GAME_OVER;
                            end else begin
                                p1_rounds_won <= p1_rounds_won + 1'b1;
                                game_state    <= GS_ROUND_END;
                            end
                        end else if (p1_ko) begin
                            // P2 wins this round
                            game_active <= 0;
                            re_ctr      <= 0;
                            if (p2_rounds_won == 2'd2) begin
                                p2_rounds_won <= 2'd3;
                                p2_wins_match <= 1'b1;
                                game_state    <= GS_GAME_OVER;
                            end else begin
                                p2_rounds_won <= p2_rounds_won + 1'b1;
                                game_state    <= GS_ROUND_END;
                            end
                        end
                    end

                    
                    GS_ROUND_END: begin
                        game_active <= 0;
                        if (re_ctr == RE_FRAMES - 1) begin
                            game_state    <= GS_COUNTDOWN;
                            cd_digit      <= 2'd3;
                            cd_ctr        <= 0;
                            countdown_val <= 2'd3;
                            round_start   <= 1'b1;
                        end else re_ctr <= re_ctr + 1'b1;
                    end

                
                    GS_GAME_OVER: begin
                        game_active <= 0;
                        if (p1_btn_any) begin
                            game_state    <= GS_MENU;
                            p1_rounds_won <= 0;
                            p2_rounds_won <= 0;
                            p1_wins_match <= 0;
                            p2_wins_match <= 0;
                        end
                    end

                    default: game_state <= GS_MENU;
                endcase
            end
        end
    end

endmodule
