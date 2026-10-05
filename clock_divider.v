module clock_divider (
    input  wire clk_50mhz,
    input  wire rst_n,
    input  wire sw_debug,    // SW[1]: 0 = 60 Hz, 1 = manual step
    input  wire key_step,    // raw KEY for stepping (active-low on DE1-SoC)
    output reg  clk_25mhz,
    output wire game_en
);

    // the 25 MHz pixel clock

    always @(posedge clk_50mhz or negedge rst_n)
        if (!rst_n) clk_25mhz <= 0;
        else        clk_25mhz <= ~clk_25mhz;

    // 60 Hz enable: 50_000_000 / 60 = 833_333 

    localparam FRAME_COUNT = 833_333;
    reg [19:0] frame_ctr;
    reg        en_60hz;
    always @(posedge clk_50mhz or negedge rst_n) begin
        if (!rst_n) begin
            frame_ctr <= 0;
            en_60hz   <= 0;
        end else if (frame_ctr == FRAME_COUNT - 1) begin
            frame_ctr <= 0;
            en_60hz   <= 1'b1;
        end else begin
            frame_ctr <= frame_ctr + 1'b1;
            en_60hz   <= 0;
        end
    end

    // the manual step: synchronize the async KEY then detect its press edge

    reg key_s0, key_s1, key_prev;
    reg en_step;
    always @(posedge clk_50mhz or negedge rst_n) begin
        if (!rst_n) begin
            key_s0 <= 1'b1; key_s1 <= 1'b1; key_prev <= 1'b1; en_step <= 0;
        end else begin
            key_s0   <= key_step;          // KEY is active-low
            key_s1   <= key_s0;
            key_prev <= key_s1;
            en_step  <= (~key_s1) & key_prev;  // rising edge of "pressed"
        end
    end

    assign game_en = sw_debug ? en_step : en_60hz;

endmodule
