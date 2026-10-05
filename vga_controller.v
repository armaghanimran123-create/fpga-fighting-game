module vga_controller (
    input  wire        clk_25mhz,
    input  wire        rst_n,
    output reg         h_sync,
    output reg         v_sync,
    output wire [9:0]  pixel_x,
    output wire [9:0]  pixel_y,
    output wire        active
);

    // firstly, the 640x480 @ 60Hz timing parameters

    
    // Horizontal: total 800 pixels
    localparam H_VISIBLE  = 640;
    localparam H_FRONT    = 16;
    localparam H_SYNC_W   = 96;
    localparam H_BACK     = 48;
    localparam H_TOTAL    = 800;  // 640+16+96+48

    // Vertical: total 525 lines

    localparam V_VISIBLE  = 480;
    localparam V_FRONT    = 10;
    localparam V_SYNC_W   = 2;
    localparam V_BACK     = 33;
    localparam V_TOTAL    = 525;  // 480+10+2+33

    reg [9:0] h_ctr;
    reg [9:0] v_ctr;

    // now we move to Horizontal counter
 
    always @(posedge clk_25mhz or negedge rst_n) begin
        if (!rst_n) h_ctr <= 0;
        else if (h_ctr == H_TOTAL - 1) h_ctr <= 0;
        else h_ctr <= h_ctr + 1;
    end

    
    // the vertical counter (increments at end of each horizontal line)
    
    always @(posedge clk_25mhz or negedge rst_n) begin
        if (!rst_n) v_ctr <= 0;
        else if (h_ctr == H_TOTAL - 1) begin
            if (v_ctr == V_TOTAL - 1) v_ctr <= 0;
            else v_ctr <= v_ctr + 1;
        end
    end

    
    // Sync the signals (active-low for standard VGA).
    
    always @(posedge clk_25mhz or negedge rst_n) begin
        if (!rst_n) begin
            h_sync <= 1;
            v_sync <= 1;
        end else begin
            h_sync <= ~(h_ctr >= H_VISIBLE + H_FRONT &&
                        h_ctr <  H_VISIBLE + H_FRONT + H_SYNC_W);
            v_sync <= ~(v_ctr >= V_VISIBLE + V_FRONT &&
                        v_ctr <  V_VISIBLE + V_FRONT + V_SYNC_W);
        end
    end

    
    // the active area as well as the pixel coordinates
    
    assign active  = (h_ctr < H_VISIBLE) && (v_ctr < V_VISIBLE);
    assign pixel_x = h_ctr;
    assign pixel_y = v_ctr;

endmodule
