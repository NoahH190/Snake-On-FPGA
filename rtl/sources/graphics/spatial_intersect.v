// ============================================================================
// Project:     Real-Time Streaming Graphics System
// Module:      spatial_intersect
// Description: Real-time overlap detection for moving AABBs
// 
// Author:      Noah Harman (Adapted from Krishang Krishang Talsania)
// Created:     2026-02-04
// Revision:    0.2 - 2025-01-08 - Dynamic grid position tracking
// ============================================================================

module spatial_intersect (
    input  wire        i_clk,
    input  wire        i_rst_n,
    
    // ===== Projectile Position =====
    input  wire [9:0]  i_obj1_x,
    input  wire [9:0]  i_obj1_y,
    input  wire        i_obj1_active,
    
    // ===== Moving Grid Position =====
    input  wire [9:0]  i_group_x,
    input  wire [9:0]  i_group_y,
    
    // ===== Collision Output =====
    output reg         o_collision_detected,
    output reg  [2:0]  o_hit_row,    // 0-2 (3 rows)
    output reg  [3:0]  o_hit_col     // 0-7 (8 columns)
);

    // ========== Constants ==========
    localparam GRID_COLS = 8;
    localparam GRID_ROWS = 3;
    localparam GROUP_ELEMENT_SIZE = 12;
    localparam SPACING = 60;
    localparam OBJ1_WIDTH = 4;
    localparam OBJ1_HEIGHT = 8;
    
    // ========== Collision Detection Logic ==========
    integer row, col;
    reg [9:0] r_element_x, r_element_y;
    reg r_overlap_x, r_overlap_y;
    reg [2:0] r_temp_hit_row;
    reg [3:0] r_temp_hit_col;
    reg r_temp_collision;
    
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_collision_detected <= 0;
            o_hit_row <= 0;
            o_hit_col <= 0;
        end else if (i_obj1_active) begin
            // Reset collision flags
            r_temp_collision = 0;
            r_temp_hit_row = 0;
            r_temp_hit_col = 0;
            
            // Check collision with all possible element positions
            // render_group will determine if the element is actually alive
            for (row = 0; row < GRID_ROWS; row = row + 1) begin
                for (col = 0; col < GRID_COLS; col = col + 1) begin
                    // Calculate element position relative to moving grid
                    r_element_x = i_group_x + (col * SPACING);
                    r_element_y = i_group_y + (row * SPACING);
                    
                    // Check X overlap
                    r_overlap_x = (i_obj1_x < r_element_x + GROUP_ELEMENT_SIZE) &&
                               (i_obj1_x + OBJ1_WIDTH > r_element_x);
                    
                    // Check Y overlap
                    r_overlap_y = (i_obj1_y < r_element_y + GROUP_ELEMENT_SIZE) &&
                               (i_obj1_y + OBJ1_HEIGHT > r_element_y);
                    
                    // If both X and Y overlap, we have a potential hit
                    if (r_overlap_x && r_overlap_y && !r_temp_collision) begin
                        r_temp_collision = 1;
                        r_temp_hit_row = row;
                        r_temp_hit_col = col;
                    end
                end
            end
            
            // Output the collision result
            o_collision_detected <= r_temp_collision;
            o_hit_row <= r_temp_hit_row;
            o_hit_col <= r_temp_hit_col;
            
        end else begin
            o_collision_detected <= 0;
        end
    end

endmodule