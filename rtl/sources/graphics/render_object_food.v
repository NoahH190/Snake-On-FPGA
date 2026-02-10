// ============================================================================
// Project:     Real-Time Streaming Graphics System
// Module:      render_object_snake
// Description: Controllable rendering entity with position state
// 
// Author:      Noah Harman
// Created:     2026-02-04
// Revision:    0.1 - 2026-02-04 - Base
//
// Revisions:
// ============================================================================

module render_object_food (
    input  wire        i_clk,
    input  wire        i_rst_n,
    
    /* From packet router (Port 0 - Control input)
    input  wire [63:0] i_s_axis_tdata,
    input  wire        i_s_axis_tvalid,
    input  wire        i_s_axis_tlast,
    output wire        o_s_axis_tready, */


    // Food location from LFSR
    input  wire [9:0]  i_food_x,
    input  wire [9:0]  i_food_y,
    input  wire        i_ate, 
    
    // VGA pixel query
    input  wire [9:0]  i_pixel_x,
    input  wire [9:0]  i_pixel_y,
    input  wire        i_video_on,
    
    // VGA output
    output reg  [3:0]  o_vga_r,
    output reg  [3:0]  o_vga_g,
    output reg  [3:0]  o_vga_b,
    
    // Object state (for collision/interaction)
    output reg  [9:0]  o_obj0_x,
    output reg  [9:0]  o_obj0_y
);

    // Object sprite size
    localparam OBJ_WIDTH = 16;
    localparam OBJ_HEIGHT = 16;
    
    /* Screen boundaries
    localparam MAX_X = 624;  // 640 - OBJ_WIDTH
    localparam MAX_Y = 464;  // 480 - OBJ_HEIGHT */
    
    // Process input packets - movement control
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_obj0_x <= 10'd320 - (OBJ_WIDTH/2);
            o_obj0_y <= 10'd450;
        end else begin
            if (i_ate) begin
                o_obj0_x <= i_food_x; 
                o_obj0_y <= i_food_y; 
            end
        end
    end
    
    // Draw object sprite (combinational)
    wire w_in_sprite_x = (i_pixel_x >= o_obj0_x) && (i_pixel_x < o_obj0_x + OBJ_WIDTH);
    wire w_in_sprite_y = (i_pixel_y >= o_obj0_y) && (i_pixel_y < o_obj0_y + OBJ_HEIGHT);
    wire w_in_sprite = w_in_sprite_x && w_in_sprite_y && i_video_on;
    
    always @(*) begin
        if (w_in_sprite) begin
            // Green square for object
            o_vga_r = 4'h0;
            o_vga_g = 4'hF; 
            o_vga_b = 4'h0;
        end else begin
            // Transparent (let other layers show through)
            o_vga_r = 4'h0;
            o_vga_g = 4'h0;
            o_vga_b = 4'h0;
        end
    end

endmodule