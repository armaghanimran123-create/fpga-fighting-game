module debounce #(
    parameter DEBOUNCE_MS  = 10,
    parameter CLK_FREQ_HZ  = 50_000_000,
    parameter HOLD_FRAMES  = 45
)(
    input  wire clk,        // 50 MHz
    input  wire rst_n,
    input  wire game_en,    // frame tick
    input  wire btn_in,     // raw button (active-HIGH after top-level inversion).
    output reg  btn_out,
    output reg  btn_press,
    output reg  btn_release,
    output reg  btn_hold
);

    localparam integer DEBOUNCE_CYCLES = (CLK_FREQ_HZ / 1000) * DEBOUNCE_MS;

    // 1. Synchronize and debounce to glitch-free level

    reg btn_sync0, btn_sync1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin btn_sync0 <= 0; btn_sync1 <= 0; end
        else        begin btn_sync0 <= btn_in; btn_sync1 <= btn_sync0; end
    end

    reg [20:0] db_ctr;
    reg        db_level;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            db_ctr   <= 0;
            db_level <= 0;
        end else if (btn_sync1 == db_level) begin
            db_ctr <= 0;
        end else begin
            db_ctr <= db_ctr + 1'b1;
            if (db_ctr == DEBOUNCE_CYCLES - 1) begin
                db_level <= btn_sync1;
                db_ctr   <= 0;
            end
        end
    end

    // 2. Frame-domain edge detection aswell as hold counter 
    reg        level_prev_frame;
    reg [6:0]  hold_ctr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_out          <= 0;
            btn_press        <= 0;
            btn_release      <= 0;
            btn_hold         <= 0;
            level_prev_frame <= 0;
            hold_ctr         <= 0;
        end else if (game_en) begin
            btn_out          <= db_level;
            btn_press        <=  db_level & ~level_prev_frame;
            btn_release      <= ~db_level &  level_prev_frame;
            level_prev_frame <= db_level;

            if (!db_level) begin
                hold_ctr <= 0;
                btn_hold <= 0;
            end else begin
                if (hold_ctr < HOLD_FRAMES) hold_ctr <= hold_ctr + 1'b1;
                btn_hold <= (hold_ctr >= HOLD_FRAMES - 1);
            end
        end

        // Between game_en ticks the flip-flops simply hold their values, so the
        // press/release pulses stayy valid for one frame to be exact

    end

endmodule
