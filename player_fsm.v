module player_fsm #(
    parameter SCREEN_W       = 640,
    parameter SPRITE_W       = 64,
    parameter SPRITE_H       = 240,
    parameter SPRITE_TOP     = 240,            // sprite top y (bottom-aligned at 479)
    parameter MOVE_FWD_SPEED = 3,
    parameter MOVE_BWD_SPEED = 2,
    // Attack frame data (Table 1)
    parameter ATK_STARTUP    = 5,
    parameter ATK_ACTIVE     = 2,
    parameter ATK_RECOVERY   = 17,
    parameter SP_STARTUP     = 14,
    parameter SP_ACTIVE      = 2,
    parameter SP_RECOVERY    = 31,

    // the defender stun durations (chosen so guard-break > special startup, making
    // the guard-break -> special-cancel a guaranteed KO) 

    parameter HITSTUN_BASIC  = 18,
    parameter BLOCKSTUN      = 20,
    parameter GUARDBREAK     = 34,

    // Charge time for the hold-and-release special (clearly human-discernible).

    parameter CHARGE_FRAMES  = 45,             // 0.75 s at 60 Hz
    parameter SP_FWD_PX       = 40,            // total forward travel of special

    // Hitbox geometry (relative to the sprite, facing right)

    parameter ATK_HITBOX_W   = 48,
    parameter ATK_HITBOX_H   = 60,
    parameter ATK_HITBOX_Y   = 70,             // relative to sprite top
    parameter SP_HITBOX_W    = 84,
    parameter SP_HITBOX_H    = 70,
    parameter SP_HITBOX_Y    = 60,

    // Hurtbox (body, slightly inset)

    parameter HURTBOX_X_OFF  = 4,
    parameter HURTBOX_W      = 56,
    parameter HURTBOX_H      = 220,
    parameter HURTBOX_Y_OFF  = 10
)(
    input  wire        clk,            // 50 MHz
    input  wire        rst_n,
    input  wire        game_en,        // frame tick (60 Hz or debug step)

    // Conditioned button inputs (all frame-aligned, see debounce.v)

    input  wire        btn_left,       // level
    input  wire        btn_right,      // level
    input  wire        btn_atk_press,  // 1-frame press pulse (used for cancel)
    input  wire        btn_atk_held,   // level (used to accumulate charge)
    input  wire        btn_atk_rel,    // 1-frame release pulse (commits attack)

    // Context

    input  wire        facing_right,   // 1 = facing right
    input  wire [9:0]  x_init,         // spawn x
    input  wire        round_start,    // pulse: reset character to spawn
    input  wire        game_active,    // 0 = freeze all gameplay

    // Hit-resolution inputs from hit_detection (all 1-frame pulses)

    input  wire        got_hit_basic,    // we were hit by a basic attack
    input  wire        got_hit_special,  // we were hit by a special attack (KO)
    input  wire        enter_blockstun,  // we blocked (block points remained)
    input  wire        enter_guardbreak, // we blocked with 0 block points
    input  wire        atk_connected,    // OUR basic attack connected this frame

    // Wall / no-cross collision

    input  wire [9:0]  opponent_x,

    // Position output

    output reg  [9:0]  pos_x,

    // Active hitbox (valid only during active frames)

    output wire [9:0]  hitbox_x,
    output wire [9:0]  hitbox_y,
    output wire [9:0]  hitbox_w,
    output wire [9:0]  hitbox_h,
    output wire        hitbox_valid,
    output wire        is_special,       // current attack is the special

    // Hurtbox (always valid; grows forward during recovery)

    output wire [9:0]  hurtbox_x,
    output wire [9:0]  hurtbox_y,
    output wire [9:0]  hurtbox_w,
    output wire [9:0]  hurtbox_h,

    // State outputs

    output reg  [3:0]  state,
    output reg  [1:0]  block_points,
    output wire        is_blocking,      // moving backward == blocking
    output wire        charged_ready     // charge complete (visual cue)
);

    // State encodingg

    localparam S_IDLE         = 4'd0;
    localparam S_MOVE_FWD     = 4'd1;
    localparam S_MOVE_BWD     = 4'd2;
    localparam S_ATK_STARTUP  = 4'd3;
    localparam S_ATK_ACTIVE   = 4'd4;
    localparam S_ATK_RECOVERY = 4'd5;
    localparam S_SP_STARTUP   = 4'd6;
    localparam S_SP_ACTIVE    = 4'd7;
    localparam S_SP_RECOVERY  = 4'd8;
    localparam S_HITSTUN      = 4'd9;
    localparam S_BLOCKSTUN    = 4'd10;
    localparam S_GUARDBREAK   = 4'd11;

    localparam CHARGE_MAX = 7'd100;

    reg [5:0] frame_ctr;       // counts down within timed states
    reg [6:0] atk_charge;      // frames ATTACK held continuously
    reg       atk_did_connect; // basic attack hit/blocked -> cancel eligible
    reg [7:0] sp_move_left;    // remaining forward pixels for special

    assign charged_ready = (atk_charge >= CHARGE_FRAMES);

    // Forward-input helper (left/right mapped to fwd/bwd by facing)
    wire move_fwd_in = (btn_right &&  facing_right) || (btn_left  && !facing_right);
    wire move_bwd_in = (btn_left  &&  facing_right) || (btn_right && !facing_right);

   
    // NOW main sequential FSM
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= S_IDLE;
            pos_x           <= x_init;
            block_points    <= 2'd3;
            frame_ctr       <= 0;
            atk_charge      <= 0;
            atk_did_connect <= 0;
            sp_move_left    <= 0;
        end else if (round_start) begin
            state           <= S_IDLE;
            pos_x           <= x_init;
            block_points    <= 2'd3;
            frame_ctr       <= 0;
            atk_charge      <= 0;
            atk_did_connect <= 0;
            sp_move_left    <= 0;
        end else if (game_en && game_active) begin

            // Charge accumulator (runs regardless of state)

            if (btn_atk_held) begin
                if (atk_charge < CHARGE_MAX) atk_charge <= atk_charge + 1'b1;
            end else begin
                atk_charge <= 0;
            end

            // Defender reactions take priority over everything

            if (got_hit_special) begin
                state     <= S_HITSTUN;
                frame_ctr <= 6'd63;            // long freeze; round_manager resets
            end else if (got_hit_basic) begin
                state     <= S_HITSTUN;
                frame_ctr <= HITSTUN_BASIC - 1;
                if (block_points > 0) block_points <= block_points - 1'b1;
            end else if (enter_guardbreak) begin
                state     <= S_GUARDBREAK;
                frame_ctr <= GUARDBREAK - 1;   // block points already 0
            end else if (enter_blockstun) begin
                state     <= S_BLOCKSTUN;
                frame_ctr <= BLOCKSTUN - 1;
                if (block_points > 0) block_points <= block_points - 1'b1;
            end else begin
                // Latch "my attack connected" for cancel eligibility
                if (atk_connected) atk_did_connect <= 1'b1;

                case (state)
                    
                    S_IDLE: begin
                        if (btn_atk_rel) begin
                            if (atk_charge >= CHARGE_FRAMES) begin
                                state        <= S_SP_STARTUP;
                                frame_ctr    <= SP_STARTUP - 1;
                                sp_move_left <= SP_FWD_PX;
                            end else begin
                                state           <= S_ATK_STARTUP;
                                frame_ctr       <= ATK_STARTUP - 1;
                                atk_did_connect <= 0;
                            end
                        end else if (move_fwd_in) state <= S_MOVE_FWD;
                        else if (move_bwd_in)      state <= S_MOVE_BWD;
                    end

                    
                    S_MOVE_FWD: begin
                        if (facing_right) begin
                            if (pos_x + SPRITE_W + MOVE_FWD_SPEED < opponent_x)
                                pos_x <= pos_x + MOVE_FWD_SPEED;
                            else
                                pos_x <= opponent_x - SPRITE_W;          // touch, no cross
                        end else begin
                            if (pos_x > opponent_x + SPRITE_W + MOVE_FWD_SPEED)
                                pos_x <= pos_x - MOVE_FWD_SPEED;
                            else
                                pos_x <= opponent_x + SPRITE_W;
                        end

                        if (btn_atk_rel) begin
                            if (atk_charge >= CHARGE_FRAMES) begin
                                state        <= S_SP_STARTUP;
                                frame_ctr    <= SP_STARTUP - 1;
                                sp_move_left <= SP_FWD_PX;
                            end else begin
                                state           <= S_ATK_STARTUP;
                                frame_ctr       <= ATK_STARTUP - 1;
                                atk_did_connect <= 0;
                            end
                        end else if (!move_fwd_in)
                            state <= move_bwd_in ? S_MOVE_BWD : S_IDLE;
                    end

                
                    S_MOVE_BWD: begin
                        if (facing_right) begin
                            if (pos_x > MOVE_BWD_SPEED) pos_x <= pos_x - MOVE_BWD_SPEED;
                            else                        pos_x <= 0;
                        end else begin
                            if (pos_x + SPRITE_W + MOVE_BWD_SPEED < SCREEN_W)
                                pos_x <= pos_x + MOVE_BWD_SPEED;
                            else
                                pos_x <= SCREEN_W - SPRITE_W;
                        end

                        if (btn_atk_rel) begin
                            if (atk_charge >= CHARGE_FRAMES) begin
                                state        <= S_SP_STARTUP;
                                frame_ctr    <= SP_STARTUP - 1;
                                sp_move_left <= SP_FWD_PX;
                            end else begin
                                state           <= S_ATK_STARTUP;
                                frame_ctr       <= ATK_STARTUP - 1;
                                atk_did_connect <= 0;
                            end
                        end else if (!move_bwd_in)
                            state <= move_fwd_in ? S_MOVE_FWD : S_IDLE;
                    end

                    
                    S_ATK_STARTUP: begin
                        if (frame_ctr == 0) begin
                            state     <= S_ATK_ACTIVE;
                            frame_ctr <= ATK_ACTIVE - 1;
                        end else frame_ctr <= frame_ctr - 1'b1;
                    end

                    S_ATK_ACTIVE: begin
                        if (frame_ctr == 0) begin
                            state     <= S_ATK_RECOVERY;
                            frame_ctr <= ATK_RECOVERY - 1;
                        end else frame_ctr <= frame_ctr - 1'b1;
                    end

                    S_ATK_RECOVERY: begin
                        // Cancel into special: press ATTACK after a connect
                        if (btn_atk_press && atk_did_connect) begin
                            state           <= S_SP_STARTUP;
                            frame_ctr       <= SP_STARTUP - 1;
                            sp_move_left     <= SP_FWD_PX;
                            atk_did_connect <= 0;
                        end else if (frame_ctr == 0) begin
                            state <= S_IDLE;
                        end else frame_ctr <= frame_ctr - 1'b1;
                    end

                    
                    S_SP_STARTUP: begin
                        if (sp_move_left > 0) begin
                            if (facing_right) begin
                                if (pos_x + SPRITE_W + 1 < opponent_x) begin
                                    pos_x        <= pos_x + 1'b1;
                                    sp_move_left <= sp_move_left - 1'b1;
                                end
                            end else begin
                                if (pos_x > opponent_x + SPRITE_W + 1) begin
                                    pos_x        <= pos_x - 1'b1;
                                    sp_move_left <= sp_move_left - 1'b1;
                                end
                            end
                        end
                        if (frame_ctr == 0) begin
                            state     <= S_SP_ACTIVE;
                            frame_ctr <= SP_ACTIVE - 1;
                        end else frame_ctr <= frame_ctr - 1'b1;
                    end

                    S_SP_ACTIVE: begin
                        if (frame_ctr == 0) begin
                            state     <= S_SP_RECOVERY;
                            frame_ctr <= SP_RECOVERY - 1;
                        end else frame_ctr <= frame_ctr - 1'b1;
                    end

                    S_SP_RECOVERY: begin
                        if (frame_ctr == 0) state <= S_IDLE;
                        else                 frame_ctr <= frame_ctr - 1'b1;
                    end

                    
                    S_HITSTUN, S_BLOCKSTUN, S_GUARDBREAK: begin
                        if (frame_ctr == 0) state <= S_IDLE;
                        else                 frame_ctr <= frame_ctr - 1'b1;
                    end

                    default: state <= S_IDLE;
                endcase
            end
        end
    end


    // Hitbox (combinational, valid during active frames)
    
    assign is_special   = (state == S_SP_STARTUP) || (state == S_SP_ACTIVE) ||
                          (state == S_SP_RECOVERY);
    assign hitbox_valid = (state == S_ATK_ACTIVE) || (state == S_SP_ACTIVE);

    wire sp_box = (state == S_SP_ACTIVE);
    wire [9:0] hbw = sp_box ? SP_HITBOX_W : ATK_HITBOX_W;
    wire [9:0] hbh = sp_box ? SP_HITBOX_H : ATK_HITBOX_H;
    wire [9:0] hby = sp_box ? SP_HITBOX_Y : ATK_HITBOX_Y;

    assign hitbox_x = facing_right ? (pos_x + SPRITE_W)
                                   : ((pos_x > hbw) ? (pos_x - hbw) : 10'd0);
    assign hitbox_y = SPRITE_TOP + hby;
    assign hitbox_w = hbw;
    assign hitbox_h = hbh;

    
    // Hurtbox (combinational). During recovery, the extended limb is vulnerable,
    // so the hurtbox grows in the facing direction by the relevant attack width,
    
    wire in_recovery = (state == S_ATK_RECOVERY) || (state == S_SP_RECOVERY);
    wire [9:0] rec_ext = (state == S_SP_RECOVERY) ? SP_HITBOX_W : ATK_HITBOX_W;

    wire [9:0] base_x  = pos_x + HURTBOX_X_OFF;

    // facing right: extend to the right;  facing left: extend to the left
    assign hurtbox_x = (!in_recovery)        ? base_x :
                       ( facing_right)        ? base_x :
                       (pos_x > rec_ext)      ? (pos_x - rec_ext) : 10'd0;

    assign hurtbox_w = (!in_recovery) ? HURTBOX_W :
                       ( facing_right) ? (SPRITE_W + rec_ext - HURTBOX_X_OFF)
                                       : (HURTBOX_X_OFF + HURTBOX_W + rec_ext);

    assign hurtbox_y = SPRITE_TOP + HURTBOX_Y_OFF;
    assign hurtbox_h = HURTBOX_H;

    
    assign is_blocking = (state == S_MOVE_BWD);

endmodule
