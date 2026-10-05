
`timescale 1ns/1ps
module tb_core;

    reg clk = 0, rst_n = 0, game_en = 0;
    always #5 clk = ~clk;

    // The Conditioned P1 inputs

    reg p1_left_lvl=0, p1_right_lvl=0;            // movement levels
    reg p1_atk_held=0, p1_atk_press=0, p1_atk_rel=0;
    reg p1_left_press=0, p1_right_press=0;        // menu navigation pulses
    // Conditioned P2 inputs
    reg p2_left_lvl=0, p2_right_lvl=0;
    reg p2_atk_held=0, p2_atk_press=0, p2_atk_rel=0;
    reg p2_left_press=0, p2_right_press=0;

    // The Round Managerr

    wire [3:0] game_state;
    wire       p1_on_left;
    wire [1:0] p1_rw, p2_rw, cd_val;
    wire       round_start, game_active, p1_win, p2_win;
    wire       p1_ko, p2_ko, draw_ko;
    wire p1_any = p1_left_press|p1_right_press|p1_atk_press;

    round_manager u_round(
        .clk(clk),.rst_n(rst_n),.game_en(game_en),
        .p1_btn_left(p1_left_press),.p1_btn_right(p1_right_press),.p1_btn_atk(p1_atk_press),
        .p2_btn_left(p2_left_press),.p2_btn_right(p2_right_press),
        .p1_ko(p1_ko),.p2_ko(p2_ko),.draw_ko(draw_ko),.p1_btn_any(p1_any),
        .game_state(game_state),.p1_on_left(p1_on_left),
        .p1_rounds_won(p1_rw),.p2_rounds_won(p2_rw),.countdown_val(cd_val),
        .round_start(round_start),.game_active(game_active),
        .p1_wins_match(p1_win),.p2_wins_match(p2_win));

    localparam L=10'd100, R=10'd476;
    wire [9:0] p1_spawn = p1_on_left? L:R;
    wire [9:0] p2_spawn = p1_on_left? R:L;
    wire p1_fr = p1_on_left;
    wire p2_fr = ~p1_on_left;

    wire [9:0] p1_x,p2_x; wire [3:0] p1_st,p2_st; wire [1:0] p1_bp,p2_bp;
    wire p1_hv,p2_hv,p1_sp,p2_sp,p1_bk,p2_bk;
    wire [9:0] p1_hbx,p1_hby,p1_hbw,p1_hbh, p2_hbx,p2_hby,p2_hbw,p2_hbh;
    wire [9:0] p1_hux,p1_huy,p1_huw,p1_huh, p2_hux,p2_huy,p2_huw,p2_huh;
    wire p1_hb,p1_hs,p1_eb,p1_eg,p1_ac, p2_hb,p2_hs,p2_eb,p2_eg,p2_ac;

    player_fsm u_p1(
        .clk(clk),.rst_n(rst_n),.game_en(game_en),
        .btn_left(p1_left_lvl),.btn_right(p1_right_lvl),
        .btn_atk_press(p1_atk_press),.btn_atk_held(p1_atk_held),.btn_atk_rel(p1_atk_rel),
        .facing_right(p1_fr),.x_init(p1_spawn),.round_start(round_start),.game_active(game_active),
        .got_hit_basic(p1_hb),.got_hit_special(p1_hs),.enter_blockstun(p1_eb),
        .enter_guardbreak(p1_eg),.atk_connected(p1_ac),.opponent_x(p2_x),
        .pos_x(p1_x),.hitbox_x(p1_hbx),.hitbox_y(p1_hby),.hitbox_w(p1_hbw),.hitbox_h(p1_hbh),
        .hitbox_valid(p1_hv),.is_special(p1_sp),
        .hurtbox_x(p1_hux),.hurtbox_y(p1_huy),.hurtbox_w(p1_huw),.hurtbox_h(p1_huh),
        .state(p1_st),.block_points(p1_bp),.is_blocking(p1_bk),.charged_ready());

    player_fsm u_p2(
        .clk(clk),.rst_n(rst_n),.game_en(game_en),
        .btn_left(p2_left_lvl),.btn_right(p2_right_lvl),
        .btn_atk_press(p2_atk_press),.btn_atk_held(p2_atk_held),.btn_atk_rel(p2_atk_rel),
        .facing_right(p2_fr),.x_init(p2_spawn),.round_start(round_start),.game_active(game_active),
        .got_hit_basic(p2_hb),.got_hit_special(p2_hs),.enter_blockstun(p2_eb),
        .enter_guardbreak(p2_eg),.atk_connected(p2_ac),.opponent_x(p1_x),
        .pos_x(p2_x),.hitbox_x(p2_hbx),.hitbox_y(p2_hby),.hitbox_w(p2_hbw),.hitbox_h(p2_hbh),
        .hitbox_valid(p2_hv),.is_special(p2_sp),
        .hurtbox_x(p2_hux),.hurtbox_y(p2_huy),.hurtbox_w(p2_huw),.hurtbox_h(p2_huh),
        .state(p2_st),.block_points(p2_bp),.is_blocking(p2_bk),.charged_ready());

    hit_detection u_hit(
        .clk(clk),.rst_n(rst_n),.game_en(game_en),
        .p1_hitbox_valid(p1_hv),.p1_hitbox_x(p1_hbx),.p1_hitbox_y(p1_hby),.p1_hitbox_w(p1_hbw),.p1_hitbox_h(p1_hbh),
        .p1_is_special(p1_sp),.p1_hurtbox_x(p1_hux),.p1_hurtbox_y(p1_huy),.p1_hurtbox_w(p1_huw),.p1_hurtbox_h(p1_huh),
        .p1_is_blocking(p1_bk),.p1_block_points(p1_bp),
        .p2_hitbox_valid(p2_hv),.p2_hitbox_x(p2_hbx),.p2_hitbox_y(p2_hby),.p2_hitbox_w(p2_hbw),.p2_hitbox_h(p2_hbh),
        .p2_is_special(p2_sp),.p2_hurtbox_x(p2_hux),.p2_hurtbox_y(p2_huy),.p2_hurtbox_w(p2_huw),.p2_hurtbox_h(p2_huh),
        .p2_is_blocking(p2_bk),.p2_block_points(p2_bp),
        .p1_got_hit_basic(p1_hb),.p1_got_hit_special(p1_hs),.p1_enter_blockstun(p1_eb),.p1_enter_guardbreak(p1_eg),
        .p2_got_hit_basic(p2_hb),.p2_got_hit_special(p2_hs),.p2_enter_blockstun(p2_eb),.p2_enter_guardbreak(p2_eg),
        .p1_atk_connected(p1_ac),.p2_atk_connected(p2_ac),
        .p1_ko(p1_ko),.p2_ko(p2_ko),.draw_ko(draw_ko));

    // State Names

    localparam S_IDLE=0,S_MOVE_FWD=1,S_MOVE_BWD=2,S_ATK_STARTUP=3,S_ATK_ACTIVE=4,
               S_ATK_RECOVERY=5,S_SP_STARTUP=6,S_SP_ACTIVE=7,S_SP_RECOVERY=8,
               S_HITSTUN=9,S_BLOCKSTUN=10,S_GUARDBREAK=11;

    integer pass=0, fail=0;
    task chk; input cond; input [200*8:1] msg; begin
        if (cond) begin pass=pass+1; /* $display("  PASS: %0s",msg); */ end
        else begin fail=fail+1; $display("  ** FAIL: %0s   (state p1=%0d p2=%0d  x p1=%0d p2=%0d  bp %0d/%0d  gs=%0d)",
                                          msg,p1_st,p2_st,p1_x,p2_x,p1_bp,p2_bp,game_state); end
    end endtask

    // Advance Exactly ONE game frame

    task step; begin
        game_en = 1'b1; @(posedge clk); #1; game_en = 1'b0;
        p1_atk_press=0; p1_atk_rel=0; p1_left_press=0; p1_right_press=0;
        p2_atk_press=0; p2_atk_rel=0; p2_left_press=0; p2_right_press=0;
        @(negedge clk);
    end endtask

    task steps; input integer n; integer k; begin for(k=0;k<n;k=k+1) step; end endtask

    // walk P1 Forward Until Adjacent to P2 (push-stop), Optionally Charging

    task p1_approach; input charge; integer g; begin
        p1_right_lvl=1; p1_left_lvl=0; p1_atk_held=charge;
        g=0; while (p1_x < (p2_x-64-3) && g<200) begin step; g=g+1; end
        // a few extra frames to settle against the wall / finish charging
        steps(6);
        p1_right_lvl=0; p1_atk_held=0;
    end endtask

    task p1_tap_attack; begin                       // short press+release = basic
        p1_atk_held=1; p1_atk_press=1; step;        // press frame
        p1_atk_held=0; p1_atk_rel=1;   step;        // release frame (charge<thresh)
    end endtask

    integer g;
    initial begin
        // reset
        rst_n=0; repeat(4) @(posedge clk); rst_n=1; @(negedge clk);

        $display("\n================ EE314 CORE LOGIC TEST ================");

        // 1. Menu

        chk(game_state==GS_idle(),"boot into MENU");
        chk(p1_on_left==1,"P1 starts on left");

        // P2 takes Left -> P1 to Right, then Back
        p2_left_press=1; step; chk(p1_on_left==0,"P2 picks left -> P1 to right");
        p1_left_press=1; step; chk(p1_on_left==1,"P1 picks left -> P1 to left");

        // 2. Confirm -> countdown -> playing

        p1_atk_press=1; step;                       
        chk(game_state==1,"confirm -> COUNTDOWN");

        steps(48*4+8);
        chk(game_state==2,"countdown done -> PLAYING");
        chk(game_active==1,"gameplay active");
        chk(p1_x==100 && p2_x==476,"players at spawn after round_start");

        // 3. Movement (measure steady-state per-frame rate)

        p1_right_lvl=1; steps(3);                  // Enter + Settle into MOVE_FWD.
        begin : fwd_rate
            reg [9:0] xa, xb;
            xa = p1_x; step; xb = p1_x;
            chk(xb-xa==3,"P1 forward 3 px/frame (steady)");
        end
        p1_right_lvl=0; steps(3);
        p1_left_lvl=1; steps(3);                   // Enter + Settle into MOVE_BWD.
        chk(p1_bk==1,"holding backward => is_blocking");
        begin : bwd_rate
            reg [9:0] xa, xb;
            xa = p1_x; step; xb = p1_x;
            chk(xa-xb==2,"P1 backward 2 px/frame (steady)");
        end
        p1_left_lvl=0; steps(2);

        // 4. Basic Attack Whiff (P2 far) + Full Phase Sequence 

        p1_tap_attack;
        steps(1); chk(p1_st==S_ATK_STARTUP,"tap -> ATK_STARTUP");
        steps(5); chk(p1_st==S_ATK_ACTIVE,"-> ATK_ACTIVE");
        steps(2); chk(p1_st==S_ATK_RECOVERY,"-> ATK_RECOVERY");
        chk(p2_bp==3,"whiff: P2 keeps all block points");
        steps(20); chk(p1_st==S_IDLE,"recovery done -> IDLE");

        // 5. HIT: Approach, Basic Attack, P2 Idle

        p1_approach(0);
        chk(p1_x>=p2_x-64-3,"P1 adjacent to P2");
        p1_tap_attack; steps(12);
        chk(p2_st==S_HITSTUN,"basic hits idle P2 -> HITSTUN");
        chk(p2_bp==2,"hit decrements P2 block points 3->2");
        steps(25);                                  // let hitstun clear

        // 6. BLOCK: P2 Holds Backward (Right, Since Facing Left)

        p1_approach(0);                             // Close Distance (P2 idle)
        p2_right_lvl=1;                             // P2 Blocks (Walks Back)
        steps(2);
        chk(p2_bk==1,"P2 holding away => blocking");
        p1_approach(0);                               // RE-Close While P2 Retreats
        p1_tap_attack; steps(12);
        chk(p2_st==S_BLOCKSTUN,"basic vs blocking P2 -> BLOCKSTUN");
        chk(p2_bp==1,"block decrements P2 block points 2->1");
        steps(25);

        // One More Block: 1 -> 0

        p1_approach(0); steps(2);
        p1_tap_attack; steps(12);
        chk(p2_bp==0,"second block 1->0");
        steps(25);

        // 7. GUARD BREAK: Block With 0 Points 

        p1_approach(0); steps(2);
        p1_tap_attack; steps(12);
        chk(p2_st==S_GUARDBREAK,"block with 0 points -> GUARD BREAK");
        p2_right_lvl=0;
        steps(40);

        // 8. SPECIAL Via Cancel (basic connects -> press atk in recovery)

        p1_approach(0);                             // P2 idle, close in
        p1_tap_attack;                              // basic (connects)
        // wait until P1 in recovery and attack has connected
        g=0; while(!(p1_st==S_ATK_RECOVERY) && g<20) begin step; g=g+1; end
        p1_atk_press=1; step;                       // cancel press
        steps(2);
        chk(p1_sp==1 || p1_st==S_SP_STARTUP || p1_st==S_SP_ACTIVE,
            "cancel into SPECIAL from recovery");
        steps(60);                                  // special resolves (KO P2)

        $display("  [after special-cancel] gs=%0d p1_rw=%0d p2_rw=%0d",game_state,p1_rw,p2_rw);

        $display("\n--------- summary so far: %0d passed, %0d failed ---------",pass,fail);

        // 9. Win The Match Via Charged Specials (need P1 to reach 3)
        win_match_for_p1;

        $display("\n================  RESULTS: %0d PASSED, %0d FAILED  ================\n",pass,fail);
        if (fail==0) $display("ALL CORE LOGIC CHECKS PASSED.\n");
        $finish;
    end

    // Helper: GS_MENU value.

    function [3:0] GS_idle; GS_idle = 4'd0; endfunction

    // Keep KO'ing P2 with charged specials until P1 wins the match


    task win_match_for_p1; integer guard; begin
        guard=0;
        while (!p1_win && !p2_win && guard<12) begin

            // Wait for PLAYING

            g=0; while(game_state!=2 && g<400) begin step; g=g+1; end
            if (game_state==2) begin

                // Approach While Charging The Special

                p1_approach(1);

                // Ensure Fully Charged

                p1_atk_held=1; steps(50); 

                // Release -> special -> should KO idle P2

                p1_atk_held=0; p1_atk_rel=1; step;
                steps(60);
            end
            guard=guard+1;
        end
        chk(p1_win==1,"P1 reaches 3 round wins -> match over (GAME_OVER)");
        chk(game_state==4,"game_state == GAME_OVER");

        // Return to Menu on P1 Button

        p1_atk_press=1; step; steps(2);
        chk(game_state==0,"P1 button at game over -> back to MENU");
    end endtask

endmodule
