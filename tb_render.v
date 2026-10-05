`timescale 1ns/1ps
module tb_render;
    reg clk=0, rst_n=0;
    always #5 clk=~clk;

    // Renderer Inputs (regs we set per scene)

    reg [3:0] game_state;
    reg       p1_on_left;
    reg [1:0] p1_rw, p2_rw, p1_bp, p2_bp, cd_val;
    reg [9:0] p1_x, p2_x;
    reg [3:0] p1_st, p2_st;
    reg       p1_fr, p2_fr, sw_dbg;
    reg       p1_hv, p2_hv;
    reg [9:0] p1_hbx,p1_hby,p1_hbw,p1_hbh, p1_hux,p1_huy,p1_huw,p1_huh;
    reg [9:0] p2_hbx,p2_hby,p2_hbw,p2_hbh, p2_hux,p2_huy,p2_huw,p2_huh;
    reg       p1_win, p2_win;

    wire [9:0] px, py; wire active, hs, vs;
    vga_controller u_vga(.clk_25mhz(clk),.rst_n(rst_n),.h_sync(hs),.v_sync(vs),
        .pixel_x(px),.pixel_y(py),.active(active));

    wire [7:0] col;
    vga_renderer u_r(
        .clk_25mhz(clk),.rst_n(rst_n),.pixel_x(px),.pixel_y(py),.active(active),
        .game_state(game_state),.p1_on_left(p1_on_left),
        .p1_rounds_won(p1_rw),.p2_rounds_won(p2_rw),
        .p1_block_pts(p1_bp),.p2_block_pts(p2_bp),.countdown_val(cd_val),
        .p1_x(p1_x),.p1_state(p1_st),.p1_facing_right(p1_fr),
        .p2_x(p2_x),.p2_state(p2_st),.p2_facing_right(p2_fr),
        .sw_debug(sw_dbg),
        .p1_hitbox_valid(p1_hv),.p1_hitbox_x(p1_hbx),.p1_hitbox_y(p1_hby),.p1_hitbox_w(p1_hbw),.p1_hitbox_h(p1_hbh),
        .p1_hurtbox_x(p1_hux),.p1_hurtbox_y(p1_huy),.p1_hurtbox_w(p1_huw),.p1_hurtbox_h(p1_huh),
        .p2_hitbox_valid(p2_hv),.p2_hitbox_x(p2_hbx),.p2_hitbox_y(p2_hby),.p2_hitbox_w(p2_hbw),.p2_hitbox_h(p2_hbh),
        .p2_hurtbox_x(p2_hux),.p2_hurtbox_y(p2_huy),.p2_hurtbox_w(p2_huw),.p2_hurtbox_h(p2_huh),
        .p1_wins_match(p1_win),.p2_wins_match(p2_win),
        .pixel_color(col));

    integer fd, r;

    // Dump exactly ONE active frame to `fname`

    task dump_frame; input [256*8:1] fname; begin
        fd = $fopen(fname,"wb");
        // wait for start of a fresh frame (py==0 && px==0)
        @(posedge clk);
        while(!(px==0&&py==0)) @(posedge clk);
        // capture one full frame
        r=0;
        while(!(px==0&&py==0) || r==0) begin
            if (active) $fwrite(fd,"%c",col);
            @(posedge clk);
            r=1;
            if (px==0&&py==0) r=2;
        end

        // r==2 Means we Wrapped to Next frame Start, but to be Safe, Capture until wrap.

        $fclose(fd);
    end endtask

    // simpler robust dumper: count active pixels = 640*480
    task dump; input [256*8:1] fname; integer cnt; begin
        fd=$fopen(fname,"wb");
        @(posedge clk); while(!(px==0&&py==0)) @(posedge clk);  // align to frame start
        cnt=0;
        while(cnt < 640*480) begin
            if (active) begin $fwrite(fd,"%c",col); cnt=cnt+1; end
            @(posedge clk);
        end
        $fclose(fd);
    end endtask

    initial begin
        rst_n=0; repeat(4) @(posedge clk); rst_n=1;
        // defaults
        p1_rw=0;p2_rw=0;p1_bp=3;p2_bp=3;cd_val=3;
        p1_x=150;p2_x=426;p1_st=0;p2_st=0;p1_fr=1;p2_fr=0;sw_dbg=0;
        p1_hv=0;p2_hv=0;p1_win=0;p2_win=0;
        p1_hbx=0;p1_hby=0;p1_hbw=0;p1_hbh=0;p1_hux=0;p1_huy=0;p1_huw=0;p1_huh=0;
        p2_hbx=0;p2_hby=0;p2_hbw=0;p2_hbh=0;p2_hux=0;p2_huy=0;p2_huw=0;p2_huh=0;

        // Scene 0: MENU

        game_state=0; p1_on_left=1;
        dump("/tmp/scene0_menu.bin");

        // Scene 1: PLAYING Idle

        game_state=2; p1_x=150;p2_x=426;p1_st=0;p2_st=0;p1_bp=3;p2_bp=2;
        p1_rw=1;p2_rw=0;
        dump("/tmp/scene1_play.bin");

        // Scene 2: PLAYING, P1 special-active attacking P2, debug overlay ON

        game_state=2; p1_x=380;p2_x=444;p1_st=7;/*SP_ACTIVE*/ p2_st=9;/*HITSTUN*/
        p1_bp=3;p2_bp=1; sw_dbg=1;
        p1_hv=1; p1_hbx=380+64; p1_hby=240+60; p1_hbw=84; p1_hbh=70;
        p1_hux=380+4; p1_huy=250; p1_huw=56; p1_huh=220;
        p2_hv=0; p2_hux=444+4; p2_huy=250; p2_huw=56; p2_huh=220;
        dump("/tmp/scene2_hit_dbg.bin");

        // Scene 3: GAME OVER, P1 wins

        game_state=4; p1_win=1;p2_win=0; p1_rw=3;p2_rw=1; sw_dbg=0;
        p1_hv=0;p2_hv=0;
        dump("/tmp/scene3_gameover.bin");

        // Scene 4: COUNTDOWN "3"

        game_state=1; cd_val=3; p1_x=100;p2_x=476;p1_st=0;p2_st=0;
        dump("/tmp/scene4_countdown.bin");

        $display("DUMPED all scenes");
        $finish;
    end
endmodule
