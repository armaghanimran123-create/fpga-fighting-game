module hit_detection (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        game_en,

    // Player 1 Geometry / Status

    input  wire        p1_hitbox_valid,
    input  wire [9:0]  p1_hitbox_x, p1_hitbox_y, p1_hitbox_w, p1_hitbox_h,
    input  wire        p1_is_special,
    input  wire [9:0]  p1_hurtbox_x, p1_hurtbox_y, p1_hurtbox_w, p1_hurtbox_h,
    input  wire        p1_is_blocking,
    input  wire [1:0]  p1_block_points,

    // Player 2 Geometry / status

    input  wire        p2_hitbox_valid,
    input  wire [9:0]  p2_hitbox_x, p2_hitbox_y, p2_hitbox_w, p2_hitbox_h,
    input  wire        p2_is_special,
    input  wire [9:0]  p2_hurtbox_x, p2_hurtbox_y, p2_hurtbox_w, p2_hurtbox_h,
    input  wire        p2_is_blocking,
    input  wire [1:0]  p2_block_points,

    // Defender Reactions (1-frame pulses)

    output reg         p1_got_hit_basic,
    output reg         p1_got_hit_special,
    output reg         p1_enter_blockstun,
    output reg         p1_enter_guardbreak,
    output reg         p2_got_hit_basic,
    output reg         p2_got_hit_special,
    output reg         p2_enter_blockstun,
    output reg         p2_enter_guardbreak,

    // Attacker "my basic attack connected" (1-frame pulses).

    output reg         p1_atk_connected,
    output reg         p2_atk_connected,

    // Round Results (1-frame pulses)

    output reg         p1_ko,            // P1 knocked out -> P2 wins round
    output reg         p2_ko,            // P2 knocked out -> P1 wins round
    output reg         draw_ko
);

    // AABB overlap test

    function automatic overlap;
        input [9:0] ax, ay, aw, ah;
        input [9:0] bx, by, bw, bh;
        overlap = (ax < bx + bw) && (ax + aw > bx) &&
                  (ay < by + bh) && (ay + ah > by);
    endfunction

    // Raw overlaps (this is combinational)

    wire p1_hits_p2_raw = p1_hitbox_valid &&
        overlap(p1_hitbox_x, p1_hitbox_y, p1_hitbox_w, p1_hitbox_h,
                p2_hurtbox_x, p2_hurtbox_y, p2_hurtbox_w, p2_hurtbox_h);

    wire p2_hits_p1_raw = p2_hitbox_valid &&
        overlap(p2_hitbox_x, p2_hitbox_y, p2_hitbox_w, p2_hitbox_h,
                p1_hurtbox_x, p1_hurtbox_y, p1_hurtbox_w, p1_hurtbox_h);

    // Per-attacker "already connected this active window" latch

    reg p1_latch, p2_latch;

    wire p1_new = p1_hits_p2_raw && !p1_latch;   // P1's attack newly reaches P2
    wire p2_new = p2_hits_p1_raw && !p2_latch;   // P2's attack newly reaches P1

    // Simultaneous special KO?

    wire p1_sp_ko = p1_new && !p2_is_blocking && p1_is_special; // P1 KOs P2
    wire p2_sp_ko = p2_new && !p1_is_blocking && p2_is_special; // P2 KOs P1
    wire double_ko = p1_sp_ko && p2_sp_ko;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            p1_got_hit_basic    <= 0; p1_got_hit_special  <= 0;
            p1_enter_blockstun  <= 0; p1_enter_guardbreak <= 0;
            p2_got_hit_basic    <= 0; p2_got_hit_special  <= 0;
            p2_enter_blockstun  <= 0; p2_enter_guardbreak <= 0;
            p1_atk_connected    <= 0; p2_atk_connected    <= 0;
            p1_ko <= 0; p2_ko <= 0; draw_ko <= 0;
            p1_latch <= 0; p2_latch <= 0;
        end else if (game_en) begin
            // defaults: all pulses low
            p1_got_hit_basic    <= 0; p1_got_hit_special  <= 0;
            p1_enter_blockstun  <= 0; p1_enter_guardbreak <= 0;
            p2_got_hit_basic    <= 0; p2_got_hit_special  <= 0;
            p2_enter_blockstun  <= 0; p2_enter_guardbreak <= 0;
            p1_atk_connected    <= 0; p2_atk_connected    <= 0;
            p1_ko <= 0; p2_ko <= 0; draw_ko <= 0;

            // P1's attack reaches P2.

            if (p1_new) begin
                p1_latch <= 1'b1;
                if (!p1_is_special) p1_atk_connected <= 1'b1; // basic -> cancel ok
                if (p2_is_blocking) begin
                    if (p2_block_points == 2'd0) p2_enter_guardbreak <= 1'b1;
                    else                         p2_enter_blockstun  <= 1'b1;
                end else if (p1_is_special) begin
                    p2_got_hit_special <= 1'b1;
                    if (!double_ko) p2_ko <= 1'b1;
                end else begin
                    p2_got_hit_basic <= 1'b1;
                end
            end
            if (!p1_hitbox_valid) p1_latch <= 1'b0;

            // P2's attack reaches P1

            if (p2_new) begin
                p2_latch <= 1'b1;
                if (!p2_is_special) p2_atk_connected <= 1'b1;
                if (p1_is_blocking) begin
                    if (p1_block_points == 2'd0) p1_enter_guardbreak <= 1'b1;
                    else                         p1_enter_blockstun  <= 1'b1;
                end else if (p2_is_special) begin
                    p1_got_hit_special <= 1'b1;
                    if (!double_ko) p1_ko <= 1'b1;
                end else begin
                    p1_got_hit_basic <= 1'b1;
                end
            end
            if (!p2_hitbox_valid) p2_latch <= 1'b0;

            // Simultaneous special KO is a draw

            if (double_ko) draw_ko <= 1'b1;
        end
    end

endmodule
