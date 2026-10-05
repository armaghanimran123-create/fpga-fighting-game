module top (
    input  wire        CLOCK_50,
    input  wire [3:0]  KEY,
    input  wire [9:0]  SW,
    input  wire [35:0] GPIO,

    output wire        VGA_HS,
    output wire        VGA_VS,
    output wire        VGA_CLK,
    output wire        VGA_BLANK_N,
    output wire        VGA_SYNC_N,
    output wire [7:0]  VGA_R,
    output wire [7:0]  VGA_G,
    output wire [7:0]  VGA_B,

    output wire [6:0]  HEX0,
    output wire [6:0]  HEX1,
    output wire [6:0]  HEX2,
    output wire [6:0]  HEX3,
    output wire [6:0]  HEX4,
    output wire [6:0]  HEX5,

    output wire [9:0]  LEDR
);

    // we start with the control signals
    wire rst_n        = SW[0];      // UP = run
    wire sw_clk_debug = SW[1];      // 0 = 60 Hz, 1 = manual step
    wire sw_overlay   = SW[9];      // hitbox/hurtbox overlay
    wire key_step     = KEY[3];     // debug frame-step key (active-low)

    // next, we move to clock / frame tick 

    wire clk_25mhz;
    wire game_en;
    clock_divider u_clkdiv (
        .clk_50mhz (CLOCK_50),
        .rst_n     (rst_n),
        .sw_debug  (sw_clk_debug),
        .key_step  (key_step),
        .clk_25mhz (clk_25mhz),
        .game_en   (game_en)
    );

    // next, the raw buttons (active-LOW -> active-HIGH)

    wire p1_raw_left  = ~KEY[0];
    wire p1_raw_right = ~KEY[1];
    wire p1_raw_atk   = ~KEY[2];

    wire p2_raw_left  = ~GPIO[1];
    wire p2_raw_right = ~GPIO[3];
    wire p2_raw_atk   = ~GPIO[5];

    // now, the debounce and the frame-aligned edges 

    wire p1_left_out , p1_left_press , p1_left_rel , p1_left_hold ;
    wire p1_right_out, p1_right_press, p1_right_rel, p1_right_hold;
    wire p1_atk_out  , p1_atk_press  , p1_atk_rel  , p1_atk_hold  ;
    wire p2_left_out , p2_left_press , p2_left_rel , p2_left_hold ;
    wire p2_right_out, p2_right_press, p2_right_rel, p2_right_hold;
    wire p2_atk_out  , p2_atk_press  , p2_atk_rel  , p2_atk_hold  ;

    debounce u_p1l(.clk(CLOCK_50),.rst_n(rst_n),.game_en(game_en),.btn_in(p1_raw_left),
        .btn_out(p1_left_out),.btn_press(p1_left_press),.btn_release(p1_left_rel),.btn_hold(p1_left_hold));
    debounce u_p1r(.clk(CLOCK_50),.rst_n(rst_n),.game_en(game_en),.btn_in(p1_raw_right),
        .btn_out(p1_right_out),.btn_press(p1_right_press),.btn_release(p1_right_rel),.btn_hold(p1_right_hold));
    debounce u_p1a(.clk(CLOCK_50),.rst_n(rst_n),.game_en(game_en),.btn_in(p1_raw_atk),
        .btn_out(p1_atk_out),.btn_press(p1_atk_press),.btn_release(p1_atk_rel),.btn_hold(p1_atk_hold));
    debounce u_p2l(.clk(CLOCK_50),.rst_n(rst_n),.game_en(game_en),.btn_in(p2_raw_left),
        .btn_out(p2_left_out),.btn_press(p2_left_press),.btn_release(p2_left_rel),.btn_hold(p2_left_hold));
    debounce u_p2r(.clk(CLOCK_50),.rst_n(rst_n),.game_en(game_en),.btn_in(p2_raw_right),
        .btn_out(p2_right_out),.btn_press(p2_right_press),.btn_release(p2_right_rel),.btn_hold(p2_right_hold));
    debounce u_p2a(.clk(CLOCK_50),.rst_n(rst_n),.game_en(game_en),.btn_in(p2_raw_atk),
        .btn_out(p2_atk_out),.btn_press(p2_atk_press),.btn_release(p2_atk_rel),.btn_hold(p2_atk_hold));

    // next up is the round manager

    wire [3:0] game_state;
    wire       p1_on_left;
    wire [1:0] p1_rounds_won, p2_rounds_won;
    wire [1:0] countdown_val;
    wire       round_start, game_active;
    wire       p1_wins_match, p2_wins_match;
    wire       p1_ko, p2_ko, draw_ko;

    wire p1_any_btn = p1_left_press | p1_right_press | p1_atk_press;

    round_manager u_round (
        .clk(CLOCK_50), .rst_n(rst_n), .game_en(game_en),
        .p1_btn_left(p1_left_press), .p1_btn_right(p1_right_press), .p1_btn_atk(p1_atk_press),
        .p2_btn_left(p2_left_press), .p2_btn_right(p2_right_press),
        .p1_ko(p1_ko), .p2_ko(p2_ko), .draw_ko(draw_ko),
        .p1_btn_any(p1_any_btn),
        .game_state(game_state), .p1_on_left(p1_on_left),
        .p1_rounds_won(p1_rounds_won), .p2_rounds_won(p2_rounds_won),
        .countdown_val(countdown_val), .round_start(round_start),
        .game_active(game_active),
        .p1_wins_match(p1_wins_match), .p2_wins_match(p2_wins_match)
    );

    // now, we deal with spawn / facing 

    localparam LEFT_SPAWN  = 10'd100;
    localparam RIGHT_SPAWN = 10'd476;
    wire [9:0] p1_spawn = p1_on_left ? LEFT_SPAWN  : RIGHT_SPAWN;
    wire [9:0] p2_spawn = p1_on_left ? RIGHT_SPAWN : LEFT_SPAWN;
    wire p1_face_r = p1_on_left;
    wire p2_face_r = ~p1_on_left;

    // Player FSMs now

    wire [9:0] p1_x, p2_x;
    wire [3:0] p1_state, p2_state;
    wire [1:0] p1_block_pts, p2_block_pts;
    wire p1_hit_v, p2_hit_v, p1_is_sp, p2_is_sp, p1_blk, p2_blk;
    wire [9:0] p1_hbx,p1_hby,p1_hbw,p1_hbh, p2_hbx,p2_hby,p2_hbw,p2_hbh;
    wire [9:0] p1_hux,p1_huy,p1_huw,p1_huh, p2_hux,p2_huy,p2_huw,p2_huh;

    wire p1_hit_basic,p1_hit_sp,p1_en_blk,p1_en_gb,p1_atk_conn;
    wire p2_hit_basic,p2_hit_sp,p2_en_blk,p2_en_gb,p2_atk_conn;

    player_fsm u_p1 (
        .clk(CLOCK_50), .rst_n(rst_n), .game_en(game_en),
        .btn_left(p1_left_out), .btn_right(p1_right_out),
        .btn_atk_press(p1_atk_press), .btn_atk_held(p1_atk_out), .btn_atk_rel(p1_atk_rel),
        .facing_right(p1_face_r), .x_init(p1_spawn),
        .round_start(round_start), .game_active(game_active),
        .got_hit_basic(p1_hit_basic), .got_hit_special(p1_hit_sp),
        .enter_blockstun(p1_en_blk), .enter_guardbreak(p1_en_gb), .atk_connected(p1_atk_conn),
        .opponent_x(p2_x),
        .pos_x(p1_x),
        .hitbox_x(p1_hbx), .hitbox_y(p1_hby), .hitbox_w(p1_hbw), .hitbox_h(p1_hbh),
        .hitbox_valid(p1_hit_v), .is_special(p1_is_sp),
        .hurtbox_x(p1_hux), .hurtbox_y(p1_huy), .hurtbox_w(p1_huw), .hurtbox_h(p1_huh),
        .state(p1_state), .block_points(p1_block_pts), .is_blocking(p1_blk),
        .charged_ready()
    );

    player_fsm u_p2 (
        .clk(CLOCK_50), .rst_n(rst_n), .game_en(game_en),
        .btn_left(p2_left_out), .btn_right(p2_right_out),
        .btn_atk_press(p2_atk_press), .btn_atk_held(p2_atk_out), .btn_atk_rel(p2_atk_rel),
        .facing_right(p2_face_r), .x_init(p2_spawn),
        .round_start(round_start), .game_active(game_active),
        .got_hit_basic(p2_hit_basic), .got_hit_special(p2_hit_sp),
        .enter_blockstun(p2_en_blk), .enter_guardbreak(p2_en_gb), .atk_connected(p2_atk_conn),
        .opponent_x(p1_x),
        .pos_x(p2_x),
        .hitbox_x(p2_hbx), .hitbox_y(p2_hby), .hitbox_w(p2_hbw), .hitbox_h(p2_hbh),
        .hitbox_valid(p2_hit_v), .is_special(p2_is_sp),
        .hurtbox_x(p2_hux), .hurtbox_y(p2_huy), .hurtbox_w(p2_huw), .hurtbox_h(p2_huh),
        .state(p2_state), .block_points(p2_block_pts), .is_blocking(p2_blk),
        .charged_ready()
    );

    // hit detection next.

    hit_detection u_hit (
        .clk(CLOCK_50), .rst_n(rst_n), .game_en(game_en),
        .p1_hitbox_valid(p1_hit_v),
        .p1_hitbox_x(p1_hbx), .p1_hitbox_y(p1_hby), .p1_hitbox_w(p1_hbw), .p1_hitbox_h(p1_hbh),
        .p1_is_special(p1_is_sp),
        .p1_hurtbox_x(p1_hux), .p1_hurtbox_y(p1_huy), .p1_hurtbox_w(p1_huw), .p1_hurtbox_h(p1_huh),
        .p1_is_blocking(p1_blk), .p1_block_points(p1_block_pts),
        .p2_hitbox_valid(p2_hit_v),
        .p2_hitbox_x(p2_hbx), .p2_hitbox_y(p2_hby), .p2_hitbox_w(p2_hbw), .p2_hitbox_h(p2_hbh),
        .p2_is_special(p2_is_sp),
        .p2_hurtbox_x(p2_hux), .p2_hurtbox_y(p2_huy), .p2_hurtbox_w(p2_huw), .p2_hurtbox_h(p2_huh),
        .p2_is_blocking(p2_blk), .p2_block_points(p2_block_pts),
        .p1_got_hit_basic(p1_hit_basic), .p1_got_hit_special(p1_hit_sp),
        .p1_enter_blockstun(p1_en_blk), .p1_enter_guardbreak(p1_en_gb),
        .p2_got_hit_basic(p2_hit_basic), .p2_got_hit_special(p2_hit_sp),
        .p2_enter_blockstun(p2_en_blk), .p2_enter_guardbreak(p2_en_gb),
        .p1_atk_connected(p1_atk_conn), .p2_atk_connected(p2_atk_conn),
        .p1_ko(p1_ko), .p2_ko(p2_ko), .draw_ko(draw_ko)
    );

    // VGA

    wire [9:0] pixel_x, pixel_y;
    wire       vga_active;
    vga_controller u_vga (
        .clk_25mhz(clk_25mhz), .rst_n(rst_n),
        .h_sync(VGA_HS), .v_sync(VGA_VS),
        .pixel_x(pixel_x), .pixel_y(pixel_y), .active(vga_active)
    );

    wire [7:0] pixel_color;
    vga_renderer u_render (
        .clk_25mhz(clk_25mhz), .rst_n(rst_n),
        .pixel_x(pixel_x), .pixel_y(pixel_y), .active(vga_active),
        .game_state(game_state), .p1_on_left(p1_on_left),
        .p1_rounds_won(p1_rounds_won), .p2_rounds_won(p2_rounds_won),
        .p1_block_pts(p1_block_pts), .p2_block_pts(p2_block_pts),
        .countdown_val(countdown_val),
        .p1_x(p1_x), .p1_state(p1_state), .p1_facing_right(p1_face_r),
        .p2_x(p2_x), .p2_state(p2_state), .p2_facing_right(p2_face_r),
        .sw_debug(sw_overlay),
        .p1_hitbox_valid(p1_hit_v),
        .p1_hitbox_x(p1_hbx), .p1_hitbox_y(p1_hby), .p1_hitbox_w(p1_hbw), .p1_hitbox_h(p1_hbh),
        .p1_hurtbox_x(p1_hux), .p1_hurtbox_y(p1_huy), .p1_hurtbox_w(p1_huw), .p1_hurtbox_h(p1_huh),
        .p2_hitbox_valid(p2_hit_v),
        .p2_hitbox_x(p2_hbx), .p2_hitbox_y(p2_hby), .p2_hitbox_w(p2_hbw), .p2_hitbox_h(p2_hbh),
        .p2_hurtbox_x(p2_hux), .p2_hurtbox_y(p2_huy), .p2_hurtbox_w(p2_huw), .p2_hurtbox_h(p2_huh),
        .p1_wins_match(p1_wins_match), .p2_wins_match(p2_wins_match),
        .pixel_color(pixel_color)
    );

    // 3-3-2 -> per channel, there are 8 bits (replicate bits to fill the DAC range)

    assign VGA_R = {pixel_color[7:5], pixel_color[7:5], pixel_color[7:6]};
    assign VGA_G = {pixel_color[4:2], pixel_color[4:2], pixel_color[4:3]};
    assign VGA_B = {pixel_color[1:0], pixel_color[1:0], pixel_color[1:0], pixel_color[1:0]};

    assign VGA_CLK     = clk_25mhz;
    assign VGA_BLANK_N = vga_active;
    assign VGA_SYNC_N  = 1'b0;

    // 7-segment 

    seg7_driver u_seg (
        .game_state(game_state), .p1_on_left(p1_on_left),
        .p1_rounds_won(p1_rounds_won), .p2_rounds_won(p2_rounds_won),
        .p1_wins_match(p1_wins_match), .p2_wins_match(p2_wins_match),
        .HEX5(HEX5), .HEX4(HEX4), .HEX3(HEX3), .HEX2(HEX2), .HEX1(HEX1), .HEX0(HEX0)
    );

    // lastly, the LEDs

    led_driver u_led (
        .clk(CLOCK_50), .rst_n(rst_n), .game_en(game_en),
        .game_state(game_state), .p1_on_left(p1_on_left),
        .p1_rounds_won(p1_rounds_won), .p2_rounds_won(p2_rounds_won),
        .LEDR(LEDR)
    );

endmodule
