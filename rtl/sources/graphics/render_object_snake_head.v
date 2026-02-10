// ============================================================================
// Project:     Real-Time Streaming Graphics System
// Module:      render_object_snake
// Description: Controllable rendering entity with position state
// 
// Author:      Noah Harman (Adapted from Krishang Krishang Talsania)
// Created:     2026-02-04
// Revision:    0.2 - 2026-02-08 - Change to velocity mechanicse
//
// Revisions:
// 0.1 - 2026-02-04 - Base
// 0.2 - 2026-02-08 - Change to velocity mechanics
// ============================================================================

module render_object_snake_head (
    input  wire        i_clk,
    input  wire        i_rst_n,
    
    // From packet router (Port 0 - Control input)
    input  wire [63:0] i_s_axis_tdata,
    input  wire        i_s_axis_tvalid,
    input  wire        i_s_axis_tlast,
    output wire        o_s_axis_tready,
    
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
    localparam OBJ_WIDTH = 64;
    localparam OBJ_HEIGHT = 48;
    
    // Movement parameters
    localparam VELOCITY = 8;
    
    // Screen boundaries
    localparam MAX_X = 640 - OBJ_WIDTH;  // 640 - OBJ_WIDTH
    localparam MAX_Y = 480 - OBJ_HEIGHT;  // 480 - OBJ_HEIGHT
    
    assign o_s_axis_tready = 1'b1;  // Always ready

    // Extract packet fields
    wire [7:0] w_direction = i_s_axis_tdata[15:8];   // Byte 1: Direction
    reg [7:0] r_hold_direction; 

    // Hold direction until new input is detected
    always @(*) begin 
        if (w_direction != r_hold_direction) r_hold_direction <= w_direction;
    end
    
    // Process input packets - movement control
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_obj0_x <= 10'd320 - (OBJ_WIDTH/2);
            o_obj0_y <= 10'd450;
        end else begin
            if (i_s_axis_tvalid && i_s_axis_tlast) begin
                // Movement based on direction
                case (r_hold_direction)
                    8'd1: begin  // Up
                        if (o_obj0_y > VELOCITY)
                            o_obj0_y <= o_obj0_y - VELOCITY;
                    end
                    8'd2: begin  // Down
                        if (o_obj0_y < MAX_Y)
                            o_obj0_y <= o_obj0_y + VELOCITY;
                    end
                    8'd3: begin  // Left
                        if (o_obj0_x > VELOCITY)
                            o_obj0_x <= o_obj0_x - VELOCITY;
                    end
                    8'd4: begin  // Right
                        if (o_obj0_x < MAX_X)
                            o_obj0_x <= o_obj0_x + VELOCITY;
                    end
                    default: ; // No movement
                endcase
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