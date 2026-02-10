module vga_timing(
    parameter H_VISIBLE = 640,
    parameter H_FRONT_PORCH = 16,
    parameter H_SYNC_PULSE = 96,
    parameter H_BACK_PORCH = 48,
    parameter H_TOTAL = H_VISIBLE + H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH,
    
    parameter V_VISIBLE = 480,
    parameter V_FRONT_PORCH = 10,
    parameter V_SYNC_PULSE = 2,
    parameter V_BACK_PORCH = 33,
    parameter V_TOTAL = V_VISIBLE + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH,
    )(
    input wire i_clk,
    input wire i_rst_n,

    output reg [9:0] o_hcount,
    output reg [9:0] o_vcount,
    output reg o_hsync,
    output reg o_vsync,
    output wire o_video_on
);

    // Clock divider 100Mhz -> 25Mhz
    reg [1:0] r_clk_div;
    wire w_pix_tick = (r_clk_div == 2'b00);
    
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n)
            r_clk_div <= 0;
        else
            r_clk_div <= r_clk_div + 1;
    end

    // Horizontal counter
    reg [9:0] r_h_count;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n)
            r_h_count <= 0;
        else if (w_pix_tick) begin
            if (r_h_count == H_TOTAL - 1)
                r_h_count <= 0;
            else
                r_h_count <= r_h_count + 1;
        end
    end
    
    // Vertical counter
    reg [9:0] r_v_count;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n)
            r_v_count <= 0;
        else if (w_pix_tick && r_h_count == H_TOTAL - 1) begin
            if (r_v_count == V_TOTAL - 1)
                r_v_count <= 0;
            else
                r_v_count <= r_v_count + 1;
        end
    end

    // Sync signals
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_hsync <= 1;
            o_vsync <= 1;
        end else if (w_pix_tick) begin
            o_hsync <= (r_h_count < (H_VISIBLE + H_FRONT_PORCH)) || 
                     (r_h_count >= (H_VISIBLE + H_FRONT_PORCH + H_SYNC_PULSE));
            o_vsync <= (r_v_count < (V_VISIBLE + V_FRONT_PORCH)) || 
                     (r_v_count >= (V_VISIBLE + V_FRONT_PORCH + V_SYNC_PULSE));
        end
    end

    // Video on and pixel coordinates
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_video_on <= 0;
            o_hcount <= 0;
            o_vcount <= 0;
        end else if (w_pix_tick) begin
            o_video_on <= (r_h_count < H_VISIBLE) && (r_v_count < V_VISIBLE);
            o_hcount <= r_h_count;
            o_vcount <= r_v_count;
        end
    end

endmodule
