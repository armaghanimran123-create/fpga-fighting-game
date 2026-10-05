module vga_renderer (
    input  wire        clk_25mhz,
    input  wire        rst_n,

    input  wire [9:0]  pixel_x,
    input  wire [9:0]  pixel_y,
    input  wire        active,

    input  wire [3:0]  game_state,
    input  wire        p1_on_left,
    input  wire [1:0]  p1_rounds_won,
    input  wire [1:0]  p2_rounds_won,
    input  wire [1:0]  p1_block_pts,
    input  wire [1:0]  p2_block_pts,
    input  wire [1:0]  countdown_val,

    input  wire [9:0]  p1_x,
    input  wire [3:0]  p1_state,
    input  wire        p1_facing_right,

    input  wire [9:0]  p2_x,
    input  wire [3:0]  p2_state,
    input  wire        p2_facing_right,

    input  wire        sw_debug,
    input  wire        p1_hitbox_valid,
    input  wire [9:0]  p1_hitbox_x, p1_hitbox_y, p1_hitbox_w, p1_hitbox_h,
    input  wire [9:0]  p1_hurtbox_x, p1_hurtbox_y, p1_hurtbox_w, p1_hurtbox_h,
    input  wire        p2_hitbox_valid,
    input  wire [9:0]  p2_hitbox_x, p2_hitbox_y, p2_hitbox_w, p2_hitbox_h,
    input  wire [9:0]  p2_hurtbox_x, p2_hurtbox_y, p2_hurtbox_w, p2_hurtbox_h,

    input  wire        p1_wins_match,
    input  wire        p2_wins_match,

    output reg  [7:0]  pixel_color
);

    // the States
 
    localparam S_IDLE=0,S_MOVE_FWD=1,S_MOVE_BWD=2,S_ATK_STARTUP=3,S_ATK_ACTIVE=4,
               S_ATK_RECOVERY=5,S_SP_STARTUP=6,S_SP_ACTIVE=7,S_SP_RECOVERY=8,
               S_HITSTUN=9,S_BLOCKSTUN=10,S_GUARDBREAK=11;
    localparam GS_MENU=0,GS_COUNTDOWN=1,GS_PLAYING=2,GS_ROUND_END=3,GS_GAME_OVER=4;

    localparam SPRITE_W = 64, SPRITE_H = 240, SPRITE_TOP = 240;

    // now the colours (RRRGGGBB)

    localparam COL_BLACK   = 8'b000_000_00;
    localparam COL_WHITE   = 8'b111_111_11;
    localparam COL_SKY1    = 8'b010_010_11;  // upper sky
    localparam COL_SKY2    = 8'b011_100_11;  // mid sky
    localparam COL_SKY3    = 8'b101_110_11;  // lower sky (haze)
    localparam COL_GROUND  = 8'b011_010_00;
    localparam COL_GRND_LN = 8'b100_011_00;

    localparam COL_P1      = 8'b001_010_11;  // blue
    localparam COL_P1_DK   = 8'b000_001_10;
    localparam COL_P2      = 8'b111_010_01;  // red/orange
    localparam COL_P2_DK   = 8'b100_000_00;

    localparam COL_STARTUP = 8'b111_110_00;  // yellow  (windup)
    localparam COL_ACTIVE  = 8'b111_000_00;  // red     (active)
    localparam COL_RECOVER = 8'b011_001_00;  // brown   (recovery)
    localparam COL_HIT     = 8'b111_111_11;  // white flash (hitstun)
    localparam COL_BLOCK   = 8'b000_011_11;  // cyan    (blockstun)
    localparam COL_GBREAK  = 8'b111_000_11;  // magenta (guard break)
    localparam COL_ARM     = 8'b111_101_00;

    localparam COL_HITBOX  = 8'b111_000_00;
    localparam COL_HURTBOX = 8'b111_111_00;
    localparam COL_PIP     = 8'b111_111_11;
    localparam COL_PIP_OFF = 8'b001_001_01;
    localparam COL_WIN_PIP = 8'b111_110_00;
    localparam COL_GOLD    = 8'b111_101_00;

    function automatic in_rect;
        input [9:0] px, py, rx, ry, rw, rh;
        in_rect = (px >= rx) && (px < rx + rw) && (py >= ry) && (py < ry + rh);
    endfunction

    // 8x8 bitmap font
    
    localparam G_0=0,G_1=1,G_2=2,G_3=3,G_P=4,G_M=5,G_E=6,G_N=7,G_U=8,G_V=9,
               G_S=10,G_W=11,G_I=12,G_G=13,G_O=14,G_K=15,G_DASH=16,G_SPC=17;

    reg [7:0] font [0:17][0:7];
    integer fi;
    initial begin
        font[G_0][0]=8'b01111100;font[G_0][1]=8'b11000110;font[G_0][2]=8'b11001110;font[G_0][3]=8'b11011110;font[G_0][4]=8'b11110110;font[G_0][5]=8'b11100110;font[G_0][6]=8'b01111100;font[G_0][7]=8'b00000000;
        font[G_1][0]=8'b00011000;font[G_1][1]=8'b00111000;font[G_1][2]=8'b00011000;font[G_1][3]=8'b00011000;font[G_1][4]=8'b00011000;font[G_1][5]=8'b00011000;font[G_1][6]=8'b01111110;font[G_1][7]=8'b00000000;
        font[G_2][0]=8'b01111100;font[G_2][1]=8'b11000110;font[G_2][2]=8'b00001110;font[G_2][3]=8'b00111100;font[G_2][4]=8'b01110000;font[G_2][5]=8'b11100000;font[G_2][6]=8'b11111110;font[G_2][7]=8'b00000000;
        font[G_3][0]=8'b01111100;font[G_3][1]=8'b11000110;font[G_3][2]=8'b00001110;font[G_3][3]=8'b00111100;font[G_3][4]=8'b00001110;font[G_3][5]=8'b11000110;font[G_3][6]=8'b01111100;font[G_3][7]=8'b00000000;
        font[G_P][0]=8'b11111100;font[G_P][1]=8'b11000110;font[G_P][2]=8'b11000110;font[G_P][3]=8'b11111100;font[G_P][4]=8'b11000000;font[G_P][5]=8'b11000000;font[G_P][6]=8'b11000000;font[G_P][7]=8'b00000000;
        font[G_M][0]=8'b11000110;font[G_M][1]=8'b11101110;font[G_M][2]=8'b11111110;font[G_M][3]=8'b11010110;font[G_M][4]=8'b11000110;font[G_M][5]=8'b11000110;font[G_M][6]=8'b11000110;font[G_M][7]=8'b00000000;
        font[G_E][0]=8'b11111110;font[G_E][1]=8'b11000000;font[G_E][2]=8'b11000000;font[G_E][3]=8'b11111100;font[G_E][4]=8'b11000000;font[G_E][5]=8'b11000000;font[G_E][6]=8'b11111110;font[G_E][7]=8'b00000000;
        font[G_N][0]=8'b11000110;font[G_N][1]=8'b11100110;font[G_N][2]=8'b11110110;font[G_N][3]=8'b11011110;font[G_N][4]=8'b11001110;font[G_N][5]=8'b11000110;font[G_N][6]=8'b11000110;font[G_N][7]=8'b00000000;
        font[G_U][0]=8'b11000110;font[G_U][1]=8'b11000110;font[G_U][2]=8'b11000110;font[G_U][3]=8'b11000110;font[G_U][4]=8'b11000110;font[G_U][5]=8'b11000110;font[G_U][6]=8'b01111100;font[G_U][7]=8'b00000000;
        font[G_V][0]=8'b11000110;font[G_V][1]=8'b11000110;font[G_V][2]=8'b11000110;font[G_V][3]=8'b11000110;font[G_V][4]=8'b01101100;font[G_V][5]=8'b00111000;font[G_V][6]=8'b00010000;font[G_V][7]=8'b00000000;
        font[G_S][0]=8'b01111100;font[G_S][1]=8'b11000110;font[G_S][2]=8'b11000000;font[G_S][3]=8'b01111100;font[G_S][4]=8'b00000110;font[G_S][5]=8'b11000110;font[G_S][6]=8'b01111100;font[G_S][7]=8'b00000000;
        font[G_W][0]=8'b11000110;font[G_W][1]=8'b11000110;font[G_W][2]=8'b11000110;font[G_W][3]=8'b11010110;font[G_W][4]=8'b11111110;font[G_W][5]=8'b11101110;font[G_W][6]=8'b11000110;font[G_W][7]=8'b00000000;
        font[G_I][0]=8'b01111110;font[G_I][1]=8'b00011000;font[G_I][2]=8'b00011000;font[G_I][3]=8'b00011000;font[G_I][4]=8'b00011000;font[G_I][5]=8'b00011000;font[G_I][6]=8'b01111110;font[G_I][7]=8'b00000000;
        font[G_G][0]=8'b01111100;font[G_G][1]=8'b11000110;font[G_G][2]=8'b11000000;font[G_G][3]=8'b11001110;font[G_G][4]=8'b11000110;font[G_G][5]=8'b11000110;font[G_G][6]=8'b01111100;font[G_G][7]=8'b00000000;
        font[G_O][0]=8'b01111100;font[G_O][1]=8'b11000110;font[G_O][2]=8'b11000110;font[G_O][3]=8'b11000110;font[G_O][4]=8'b11000110;font[G_O][5]=8'b11000110;font[G_O][6]=8'b01111100;font[G_O][7]=8'b00000000;
        font[G_K][0]=8'b11000110;font[G_K][1]=8'b11001100;font[G_K][2]=8'b11011000;font[G_K][3]=8'b11110000;font[G_K][4]=8'b11011000;font[G_K][5]=8'b11001100;font[G_K][6]=8'b11000110;font[G_K][7]=8'b00000000;
        font[G_DASH][0]=8'b00000000;font[G_DASH][1]=8'b00000000;font[G_DASH][2]=8'b00000000;font[G_DASH][3]=8'b01111110;font[G_DASH][4]=8'b00000000;font[G_DASH][5]=8'b00000000;font[G_DASH][6]=8'b00000000;font[G_DASH][7]=8'b00000000;
        font[G_SPC][0]=8'b0;font[G_SPC][1]=8'b0;font[G_SPC][2]=8'b0;font[G_SPC][3]=8'b0;font[G_SPC][4]=8'b0;font[G_SPC][5]=8'b0;font[G_SPC][6]=8'b0;font[G_SPC][7]=8'b0;
    end

    // the frame counter (for animation). It advances once per visible frame.
    
    reg [7:0] frame_cnt;
    reg       was_top;
    always @(posedge clk_25mhz or negedge rst_n) begin
        if (!rst_n) begin frame_cnt <= 0; was_top <= 0; end
        else begin
            if (pixel_x == 0 && pixel_y == 0) begin
                if (!was_top) frame_cnt <= frame_cnt + 1'b1;
                was_top <= 1'b1;
            end else was_top <= 0;
        end
    end

    // computed inline per text block is below

    // the countdown / KO text (2 cells, scale 6 = 48px cells)

    localparam T_SC = 6;
    localparam T_CELL = 8*T_SC;                 // 48
    localparam T_BX = (640 - 2*T_CELL)/2;       // 272
    localparam T_BY = (480 - T_CELL)/2 - 30;    // a bit above centre
    wire t_in   = in_rect(pixel_x,pixel_y,T_BX,T_BY,2*T_CELL,T_CELL);
    wire [9:0] t_rx = pixel_x - T_BX;
    wire [9:0] t_ry = pixel_y - T_BY;
    wire       t_right = (t_rx >= T_CELL);
    wire [2:0] t_col = (t_rx - (t_right?T_CELL:0))/T_SC;
    wire [2:0] t_row = t_ry/T_SC;

    reg [4:0] t_glyph;
    reg       t_two;       // 1 = two-letter word (GO/KO), 0 = single digit
    always @(*) begin
        t_glyph = G_SPC; t_two = 0;
        if (game_state == GS_ROUND_END) begin
            t_two = 1; t_glyph = t_right ? G_O : G_K;          // "KO"
        end else if (game_state == GS_COUNTDOWN) begin
            if (countdown_val == 2'd0) begin
                t_two = 1; t_glyph = t_right ? G_O : G_G;      // "GO"
            end else begin
                t_two = 0;
                t_glyph = (countdown_val==2'd3) ? G_3 :
                          (countdown_val==2'd2) ? G_2 : G_1;
            end
        end
    end
    wire t_show_cell = t_two ? 1'b1 : ~t_right;   // single digit uses left cell
    wire text_cd_on = t_in && t_show_cell &&
                      ((game_state==GS_COUNTDOWN)||(game_state==GS_ROUND_END)) &&
                      font[t_glyph][t_row][7 - t_col];

    // now the "MENU" title (4 cells, scale 6) 

    localparam M_SC = 6, M_CELL = 8*M_SC;       // 48
    localparam M_BX = (640 - 4*M_CELL)/2;       // 128
    localparam M_BY = 48;
    wire m_in = in_rect(pixel_x,pixel_y,M_BX,M_BY,4*M_CELL,M_CELL);
    wire [9:0] m_rx = pixel_x - M_BX;
    wire [1:0] m_ci = m_rx / M_CELL;            // 0..3
    wire [2:0] m_col = (m_rx % M_CELL)/M_SC;
    wire [2:0] m_row = (pixel_y - M_BY)/M_SC;
    reg [4:0] m_glyph;
    always @(*) case (m_ci)
        2'd0: m_glyph=G_M; 2'd1: m_glyph=G_E; 2'd2: m_glyph=G_N; default: m_glyph=G_U;
    endcase
    wire text_menu_on = m_in && (game_state==GS_MENU) &&
                        font[m_glyph][m_row][7 - m_col];


    // the menu side labels "P1"/"P2" (2 cells, scale 5)

    localparam L_SC = 5, L_CELL = 8*L_SC;       // 40
    localparam L_BY = 300;
    localparam L_LX = 130;                       // left label origin
    localparam L_RX = 470;                       // right label origin
    // left label
    wire ll_in = in_rect(pixel_x,pixel_y,L_LX,L_BY,2*L_CELL,L_CELL);
    wire [9:0] ll_rx = pixel_x - L_LX;
    wire       ll_right = (ll_rx >= L_CELL);
    wire [2:0] ll_col = (ll_rx-(ll_right?L_CELL:0))/L_SC;
    wire [2:0] ll_row = (pixel_y-L_BY)/L_SC;
    wire [4:0] ll_glyph = ll_right ? (p1_on_left?G_1:G_2) : G_P;
    wire text_ll_on = ll_in && (game_state==GS_MENU) &&
                      font[ll_glyph][ll_row][7-ll_col];
    // right label
    wire lr_in = in_rect(pixel_x,pixel_y,L_RX,L_BY,2*L_CELL,L_CELL);
    wire [9:0] lr_rx = pixel_x - L_RX;
    wire       lr_right = (lr_rx >= L_CELL);
    wire [2:0] lr_col = (lr_rx-(lr_right?L_CELL:0))/L_SC;
    wire [2:0] lr_row = (pixel_y-L_BY)/L_SC;
    wire [4:0] lr_glyph = lr_right ? (p1_on_left?G_2:G_1) : G_P;
    wire text_lr_on = lr_in && (game_state==GS_MENU) &&
                      font[lr_glyph][lr_row][7-lr_col];

    // the Game-over "P1 WINS"/"P2 WINS" (7 cells, scale 5)

    localparam GO_SC=5, GO_CELL=8*GO_SC;        // 40
    localparam GO_BX=(640-7*GO_CELL)/2;         // 40
    localparam GO_BY=40;
    wire go_in = in_rect(pixel_x,pixel_y,GO_BX,GO_BY,7*GO_CELL,GO_CELL);
    wire [9:0] go_rx = pixel_x - GO_BX;
    wire [2:0] go_ci = go_rx / GO_CELL;         // 0..6
    wire [2:0] go_col = (go_rx % GO_CELL)/GO_SC;
    wire [2:0] go_row = (pixel_y-GO_BY)/GO_SC;
    reg [4:0] go_glyph;
    always @(*) case (go_ci)
        3'd0: go_glyph = G_P;
        3'd1: go_glyph = p1_wins_match ? G_1 : G_2;
        3'd2: go_glyph = G_SPC;
        3'd3: go_glyph = G_W;
        3'd4: go_glyph = G_I;
        3'd5: go_glyph = G_N;
        default: go_glyph = G_S;
    endcase
    wire text_go_on = go_in && (game_state==GS_GAME_OVER) &&
                      font[go_glyph][go_row][7-go_col];

        // the HUD pips
   
    localparam PIP_SZ=12, PIP_SP=18, PIP_Y=10;
    localparam P1_PIP_X=20, P2_PIP_X=640-20-3*PIP_SP;
    function automatic pip_on;
        input [9:0] px,py,bx; input [1:0] pts; input integer idx;
        pip_on = in_rect(px,py, bx+idx*PIP_SP, PIP_Y, PIP_SZ, PIP_SZ);
    endfunction
    wire p1_pip_box = pip_on(pixel_x,pixel_y,P1_PIP_X,p1_block_pts,0)|pip_on(pixel_x,pixel_y,P1_PIP_X,p1_block_pts,1)|pip_on(pixel_x,pixel_y,P1_PIP_X,p1_block_pts,2);
    wire p2_pip_box = pip_on(pixel_x,pixel_y,P2_PIP_X,p2_block_pts,0)|pip_on(pixel_x,pixel_y,P2_PIP_X,p2_block_pts,1)|pip_on(pixel_x,pixel_y,P2_PIP_X,p2_block_pts,2);
    wire p1_pip_lit = (pip_on(pixel_x,pixel_y,P1_PIP_X,p1_block_pts,0)&&(0<p1_block_pts))|(pip_on(pixel_x,pixel_y,P1_PIP_X,p1_block_pts,1)&&(1<p1_block_pts))|(pip_on(pixel_x,pixel_y,P1_PIP_X,p1_block_pts,2)&&(2<p1_block_pts));
    wire p2_pip_lit = (pip_on(pixel_x,pixel_y,P2_PIP_X,p2_block_pts,0)&&(0<p2_block_pts))|(pip_on(pixel_x,pixel_y,P2_PIP_X,p2_block_pts,1)&&(1<p2_block_pts))|(pip_on(pixel_x,pixel_y,P2_PIP_X,p2_block_pts,2)&&(2<p2_block_pts));

    localparam WPIP_Y=30, WPIP_SZ=10;
    wire p1_win_box=in_rect(pixel_x,pixel_y,P1_PIP_X,WPIP_Y,WPIP_SZ,WPIP_SZ)&&(p1_rounds_won>0)|in_rect(pixel_x,pixel_y,P1_PIP_X+PIP_SP,WPIP_Y,WPIP_SZ,WPIP_SZ)&&(p1_rounds_won>1)|in_rect(pixel_x,pixel_y,P1_PIP_X+2*PIP_SP,WPIP_Y,WPIP_SZ,WPIP_SZ)&&(p1_rounds_won>2);
    wire p2_win_box=in_rect(pixel_x,pixel_y,P2_PIP_X,WPIP_Y,WPIP_SZ,WPIP_SZ)&&(p2_rounds_won>0)|in_rect(pixel_x,pixel_y,P2_PIP_X+PIP_SP,WPIP_Y,WPIP_SZ,WPIP_SZ)&&(p2_rounds_won>1)|in_rect(pixel_x,pixel_y,P2_PIP_X+2*PIP_SP,WPIP_Y,WPIP_SZ,WPIP_SZ)&&(p2_rounds_won>2);

   
    // now the sprites as well as animation
    
    wire in_p1 = in_rect(pixel_x,pixel_y,p1_x,SPRITE_TOP,SPRITE_W,SPRITE_H);
    wire in_p2 = in_rect(pixel_x,pixel_y,p2_x,SPRITE_TOP,SPRITE_W,SPRITE_H);

    // attack "arm" rectangle thrust forward during an attack
    function automatic [9:0] arm_len_f;
        input [3:0] st;
        case (st)
            S_ATK_STARTUP, S_SP_STARTUP : arm_len_f = 10'd18;
            S_ATK_ACTIVE                : arm_len_f = 10'd48;
            S_SP_ACTIVE                 : arm_len_f = 10'd84;
            S_ATK_RECOVERY              : arm_len_f = 10'd34;
            S_SP_RECOVERY               : arm_len_f = 10'd60;
            default                     : arm_len_f = 10'd0;
        endcase
    endfunction
    localparam ARM_Y = SPRITE_TOP + 70, ARM_H = 26;

    wire [9:0] p1_arm_len = arm_len_f(p1_state);
    wire p1_arm = (p1_arm_len!=0) &&
        (p1_facing_right ? in_rect(pixel_x,pixel_y,p1_x+SPRITE_W,ARM_Y,p1_arm_len,ARM_H)
                         : (p1_x>p1_arm_len) && in_rect(pixel_x,pixel_y,p1_x-p1_arm_len,ARM_Y,p1_arm_len,ARM_H));
    wire [9:0] p2_arm_len = arm_len_f(p2_state);
    wire p2_arm = (p2_arm_len!=0) &&
        (p2_facing_right ? in_rect(pixel_x,pixel_y,p2_x+SPRITE_W,ARM_Y,p2_arm_len,ARM_H)
                         : (p2_x>p2_arm_len) && in_rect(pixel_x,pixel_y,p2_x-p2_arm_len,ARM_Y,p2_arm_len,ARM_H));

    // walking stripe: animate when moving

    wire p1_walk = (p1_state==S_MOVE_FWD)||(p1_state==S_MOVE_BWD);
    wire p2_walk = (p2_state==S_MOVE_FWD)||(p2_state==S_MOVE_BWD);
    wire p1_stripe = (((pixel_y + frame_cnt) >> 3) & 1'b1);
    wire p2_stripe = (((pixel_y + frame_cnt) >> 3) & 1'b1);

    reg [7:0] p1_col, p2_col;
    always @(*) begin
        // P1
        case (p1_state)
            S_ATK_STARTUP,S_SP_STARTUP: p1_col = COL_STARTUP;
            S_ATK_ACTIVE, S_SP_ACTIVE : p1_col = COL_ACTIVE;
            S_ATK_RECOVERY,S_SP_RECOVERY: p1_col = COL_RECOVER;
            S_HITSTUN  : p1_col = COL_HIT;
            S_BLOCKSTUN: p1_col = COL_BLOCK;
            S_GUARDBREAK:p1_col = COL_GBREAK;
            S_MOVE_FWD,S_MOVE_BWD: p1_col = p1_stripe ? COL_P1 : COL_P1_DK;
            default    : p1_col = COL_P1;
        endcase
        // P2
        case (p2_state)
            S_ATK_STARTUP,S_SP_STARTUP: p2_col = COL_STARTUP;
            S_ATK_ACTIVE, S_SP_ACTIVE : p2_col = COL_ACTIVE;
            S_ATK_RECOVERY,S_SP_RECOVERY: p2_col = COL_RECOVER;
            S_HITSTUN  : p2_col = COL_HIT;
            S_BLOCKSTUN: p2_col = COL_BLOCK;
            S_GUARDBREAK:p2_col = COL_GBREAK;
            S_MOVE_FWD,S_MOVE_BWD: p2_col = p2_stripe ? COL_P2 : COL_P2_DK;
            default    : p2_col = COL_P2;
        endcase
    end


    // the debug overlay borders


    function automatic border;
        input [9:0] px,py,bx,by,bw,bh;
        border = (bw>0)&&(bh>0)&&
                 (px>=bx)&&(px<bx+bw)&&(py>=by)&&(py<by+bh)&&
                 ((px==bx)||(px==bx+bw-1)||(py==by)||(py==by+bh-1));
    endfunction
    wire dbg_p1_hit  = sw_debug && p1_hitbox_valid && border(pixel_x,pixel_y,p1_hitbox_x,p1_hitbox_y,p1_hitbox_w,p1_hitbox_h);
    wire dbg_p2_hit  = sw_debug && p2_hitbox_valid && border(pixel_x,pixel_y,p2_hitbox_x,p2_hitbox_y,p2_hitbox_w,p2_hitbox_h);
    wire dbg_p1_hurt = sw_debug && border(pixel_x,pixel_y,p1_hurtbox_x,p1_hurtbox_y,p1_hurtbox_w,p1_hurtbox_h);
    wire dbg_p2_hurt = sw_debug && border(pixel_x,pixel_y,p2_hurtbox_x,p2_hurtbox_y,p2_hurtbox_w,p2_hurtbox_h);

    // the background and the ground
    
    wire [7:0] sky = (pixel_y < 160) ? COL_SKY1 : (pixel_y < 320) ? COL_SKY2 : COL_SKY3;
    wire in_ground   = (pixel_y >= 462);
    wire in_grnd_ln  = (pixel_y >= 462 && pixel_y < 466);

    // menu side boxes (behind labels)
    wire in_lbox = in_rect(pixel_x,pixel_y,110,210,80,80);
    wire in_rbox = in_rect(pixel_x,pixel_y,450,210,80,80);


    // this is the final pixel priority

    always @(*) begin
        if (!active) begin
            pixel_color = COL_BLACK;

        end else if (game_state == GS_MENU) begin
            if (in_lbox)       pixel_color = p1_on_left ? COL_P1 : COL_P2;
            else if (in_rbox)  pixel_color = p1_on_left ? COL_P2 : COL_P1;
            else               pixel_color = sky;
            if (text_menu_on || text_ll_on || text_lr_on) pixel_color = COL_WHITE;

        end else begin
            // world
            if (in_grnd_ln)     pixel_color = COL_GRND_LN;
            else if (in_ground) pixel_color = COL_GROUND;
            else                pixel_color = sky;

            // characters: arm shows where it sticks out past the body
            if      (in_p1)              pixel_color = p1_col;
            else if (in_p2)              pixel_color = p2_col;
            else if (p1_arm)             pixel_color = COL_ARM;
            else if (p2_arm)             pixel_color = COL_ARM;

            // HUD
            if      (p1_pip_lit) pixel_color = COL_PIP;
            else if (p1_pip_box) pixel_color = COL_PIP_OFF;
            else if (p2_pip_lit) pixel_color = COL_PIP;
            else if (p2_pip_box) pixel_color = COL_PIP_OFF;
            if (p1_win_box || p2_win_box) pixel_color = COL_WIN_PIP;

            // big text
            if (text_cd_on) pixel_color = COL_WHITE;
            if (game_state == GS_GAME_OVER && text_go_on) pixel_color = COL_GOLD;

            // debug overlay (topmost)
            if (dbg_p1_hurt) pixel_color = COL_HURTBOX;
            if (dbg_p2_hurt) pixel_color = COL_HURTBOX;
            if (dbg_p1_hit)  pixel_color = COL_HITBOX;
            if (dbg_p2_hit)  pixel_color = COL_HITBOX;
        end
    end

endmodule
