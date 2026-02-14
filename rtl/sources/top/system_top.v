// ============================================================================
// Project:     Real-Time Streaming Graphics System
// Module:      system_top
// Description: Top-level integration of all subsystems
// 
// Author:      Noah Harman (adapted from Krishang Krishang Talsania)
// Created:     2025-02-10
// Revision:    0.1 - 2025-02-10 - Imported from Phase 7
//
// Revisions:
//   0.0 - 2025-02-10 - Imported 
// ============================================================================

module system_top (
    input  wire       i_clk,
    input  wire       i_rst_n,
    input  wire       i_uart_rx,
    
    output wire [3:0] o_vga_r,
    output wire [3:0] o_vga_g,
    output wire [3:0] o_vga_b,
    output wire       o_vga_hsync,
    output wire       o_vga_vsync,
    
    output wire [15:0] o_led
);

    // ========== UART → AXI-Stream Chain ==========
    wire w_baud_tick;
    wire [7:0] w_uart_data;
    wire w_uart_valid;
    
    clk_divider #(
        .CLK_FREQ(100_000_000), 
        .BAUD_RATE(115200)
    ) baud_gen (
        .i_clk(i_clk), 
        .i_rst_n(i_rst_n), 
        .o_baud_tick(w_baud_tick)
    );
    
    uart_rx uart_receiver (
        .i_clk(i_clk), 
        .i_rst_n(i_rst_n), 
        .i_baud_tick(w_baud_tick),
        .i_rx(i_uart_rx), 
        .o_data(w_uart_data), 
        .o_data_valid(w_uart_valid)
    );
    
    wire [63:0] w_uart_axis_tdata;
    wire w_uart_axis_tvalid, w_uart_axis_tlast, w_uart_axis_tready;
    
    stream_adapter uart_converter (
        .i_clk(i_clk), 
        .i_rst_n(i_rst_n),
        .i_uart_data(w_uart_data), 
        .i_uart_valid(w_uart_valid),
        .o_m_axis_tdata(w_uart_axis_tdata), 
        .o_m_axis_tvalid(w_uart_axis_tvalid),
        .o_m_axis_tlast(w_uart_axis_tlast), 
        .i_m_axis_tready(w_uart_axis_tready)
    );
    
    // ========== Control Plane ==========
    wire [1:0] w_ctrl_state;
    wire w_system_active;
    wire w_reset_pulse;
    wire [4:0] w_active_count;
    wire w_halt_condition;
    
    // Extract start button from UART (button 9 or SELECT)
    wire w_start_button = w_uart_axis_tvalid && 
                       (w_uart_axis_tdata[7:0] == 8'h01) && 
                       (w_uart_axis_tdata[15:8] == 8'h09);
    
    system_controller state_manager (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_start_button(w_start_button),
        .i_active_count(w_active_count),
        .i_halt_condition(w_halt_condition),
        .o_ctrl_state(w_ctrl_state),
        .o_system_active(w_system_active),
        .o_reset_pulse(w_reset_pulse)
    );
    
    // ========== Scheduler Core ==========
    wire [63:0] w_timer_axis_tdata;
    wire w_timer_axis_tvalid, w_timer_axis_tlast, w_timer_axis_tready;
    
    scheduler_core event_generator ( /*MISSING*/
        .clk(i_clk),
        .rst_n(i_rst_n),
        .system_active(w_system_active),  // Only generate events when active
        .active_count(w_active_count),
        .m_axis_tdata(w_timer_axis_tdata),
        .m_axis_tvalid(w_timer_axis_tvalid),
        .m_axis_tlast(w_timer_axis_tlast),
        .m_axis_tready(w_timer_axis_tready)
    );
    
    // ========== Packet Merger ==========
    wire [63:0] w_merged_axis_tdata;
    wire w_merged_axis_tvalid, w_merged_axis_tlast, w_merged_axis_tready;
    
    stream_arbiter packet_combiner (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_s_axis0_tdata(w_uart_axis_tdata),
        .i_s_axis0_tvalid(w_uart_axis_tvalid),
        .i_s_axis0_tlast(w_uart_axis_tlast),
        .o_s_axis0_tready(w_uart_axis_tready),
        .i_s_axis1_tdata(w_timer_axis_tdata),
        .i_s_axis1_tvalid(w_timer_axis_tvalid),
        .i_s_axis1_tlast(w_timer_axis_tlast),
        .o_s_axis1_tready(w_timer_axis_tready),
        .o_m_axis_tdata(w_merged_axis_tdata),
        .o_m_axis_tvalid(w_merged_axis_tvalid),
        .o_m_axis_tlast(w_merged_axis_tlast),
        .i_m_axis_tready(w_merged_axis_tready)
    );
    
    // ========== Packet Router ==========
    wire [63:0] w_player_tdata, w_bullet_tdata, w_unused_tdata, w_enemy_tdata;
    wire w_player_tvalid, w_bullet_tvalid, w_unused_tvalid, w_enemy_tvalid;
    wire w_player_tlast, w_bullet_tlast, w_unused_tlast, w_enemy_tlast;
    wire w_player_tready, w_bullet_tready, w_unused_tready, w_enemy_tready;
    
    stream_router router (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_s_axis_tdata(w_merged_axis_tdata),
        .i_s_axis_tvalid(w_merged_axis_tvalid),
        .i_s_axis_tlast(w_merged_axis_tlast),
        .o_s_axis_tready(w_merged_axis_tready),
        .o_m_axis_port0_tdata(w_player_tdata),
        .o_m_axis_port0_tvalid(w_player_tvalid),
        .o_m_axis_port0_tlast(w_player_tlast),
        .i_m_axis_port0_tready(w_player_tready),
        .o_m_axis_port1_tdata(w_bullet_tdata),
        .o_m_axis_port1_tvalid(w_bullet_tvalid),
        .o_m_axis_port1_tlast(w_bullet_tlast),
        .i_m_axis_port1_tready(1'b1),
        .o_m_axis_port2_tdata(w_unused_tdata),
        .o_m_axis_port2_tvalid(w_unused_tvalid),
        .o_m_axis_port2_tlast(w_unused_tlast),
        .i_m_axis_port2_tready(1'b1),
        .o_m_axis_port3_tdata(w_enemy_tdata),
        .o_m_axis_port3_tvalid(w_enemy_tvalid),
        .o_m_axis_port3_tlast(w_enemy_tlast),
        .i_m_axis_port3_tready(w_enemy_tready)
    );
    
    // ========== VGA Timing ==========
    wire [9:0] w_pixel_x, w_pixel_y;
    wire w_video_on;
    
    vga_timing vga_tim (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .o_hcount(w_pixel_x),
        .o_vcount(w_pixel_y),
        .o_hsync(o_vga_hsync),
        .o_vsync(o_vga_vsync),
        .o_video_on(w_video_on)
    );
    
    // ========== LFSR (Random Food Position Generator) ==========
    wire [3:0] w_lfsr_x, w_lfsr_y;
    
    lsfr food_rng (
        .i_clk(i_clk),
        .i_rst(~i_rst_n),
        .o_x_data(w_lfsr_x),
        .o_y_data(w_lfsr_y)
    );
    
    // Scale 4-bit LFSR (0-15) to screen coordinates
    // x * 38 → range 0–570 (fits 640px minus 16px food sprite)
    // y * 28 → range 0–420 (fits 480px minus 16px food sprite)
    wire [9:0] w_food_spawn_x = w_lfsr_x * 10'd38;
    wire [9:0] w_food_spawn_y = w_lfsr_y * 10'd28;
    
    // ========== Render Snake Head ==========
    wire [3:0] w_snake_r, w_snake_g, w_snake_b;
    wire [9:0] w_snake_x, w_snake_y;
    
    render_object_snake_head snake_head (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n && !w_reset_pulse),  // Reset on system restart
        .i_s_axis_tdata(w_player_tdata),
        .i_s_axis_tvalid(w_player_tvalid && w_system_active),  // Only move when active
        .i_s_axis_tlast(w_player_tlast),
        .o_s_axis_tready(w_player_tready),
        .i_pixel_x(w_pixel_x),
        .i_pixel_y(w_pixel_y),
        .i_video_on(w_video_on),
        .o_vga_r(w_snake_r),
        .o_vga_g(w_snake_g),
        .o_vga_b(w_snake_b),
        .o_obj0_x(w_snake_x),
        .o_obj0_y(w_snake_y)
    );
    
    // ========== Food-Snake Collision Detection (AABB) ==========
    // Snake head sprite: 64x48, Food sprite: 16x16
    wire [9:0] w_food_x, w_food_y;
    
    wire w_food_ate = (w_snake_x < w_food_x + 10'd16) &&
                      (w_snake_x + 10'd64 > w_food_x) &&
                      (w_snake_y < w_food_y + 10'd16) &&
                      (w_snake_y + 10'd48 > w_food_y);
    
    // ========== Render Food ==========
    wire [3:0] w_food_r, w_food_g, w_food_b;
    
    render_object_food food (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n && !w_reset_pulse),  // Reset on system restart
        .i_food_x(w_food_spawn_x),
        .i_food_y(w_food_spawn_y),
        .i_ate(w_food_ate),
        .i_pixel_x(w_pixel_x),
        .i_pixel_y(w_pixel_y),
        .i_video_on(w_video_on),
        .o_vga_r(w_food_r),
        .o_vga_g(w_food_g),
        .o_vga_b(w_food_b),
        .o_obj0_x(w_food_x),
        .o_obj0_y(w_food_y)
    );
    
    // ========== Render Object 1 ==========
    wire [3:0] w_obj1_r, w_obj1_g, w_obj1_b;
    wire [9:0] w_obj1_x, w_obj1_y;
    wire w_obj1_active;
    wire w_collision_detected;
    
    render_object_1 object_1 ( /*MISSING*/
        .clk(i_clk),
        .rst_n(i_rst_n && !w_reset_pulse),  // Reset on system restart
        .trigger(w_food_ate && w_system_active),    // Only trigger when active
        .spawn_x(w_snake_x),
        .spawn_y(w_snake_y),
        .collision_detected(w_collision_detected),
        .pixel_x(w_pixel_x),
        .pixel_y(w_pixel_y),
        .video_on(w_video_on),
        .vga_r(w_obj1_r),
        .vga_g(w_obj1_g),
        .vga_b(w_obj1_b),
        .obj1_x(w_obj1_x),
        .obj1_y(w_obj1_y),
        .obj1_active(w_obj1_active)
    );
    
    // ========== Render Group ==========
    wire [3:0] w_group_r, w_group_g, w_group_b;
    wire [9:0] w_group_x, w_group_y;
    wire [2:0] w_hit_row;
    wire [3:0] w_hit_col;
    
    render_group element_group ( /*MISSING*/
        .clk(i_clk),
        .rst_n(i_rst_n && !w_reset_pulse),  // Reset on system restart
        .s_axis_tdata(w_enemy_tdata),
        .s_axis_tvalid(w_enemy_tvalid && w_system_active),  // Only move when active
        .s_axis_tlast(w_enemy_tlast),
        .s_axis_tready(w_enemy_tready),
        .collision_detected(w_collision_detected),
        .hit_row(w_hit_row[1:0]),
        .hit_col(w_hit_col[2:0]),
        .pixel_x(w_pixel_x),
        .pixel_y(w_pixel_y),
        .video_on(w_video_on),
        .vga_r(w_group_r),
        .vga_g(w_group_g),
        .vga_b(w_group_b),
        .group_x(w_group_x),
        .group_y(w_group_y),
        .active_count(w_active_count),
        .halt_condition(w_halt_condition)
    );
    
    // ========== Spatial Intersection ==========
    spatial_intersect collider (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_obj1_x(w_obj1_x),
        .i_obj1_y(w_obj1_y),
        .i_obj1_active(w_obj1_active && w_system_active),
        .i_group_x(w_group_x),
        .i_group_y(w_group_y),
        .o_collision_detected(w_collision_detected),
        .o_hit_row(w_hit_row),
        .o_hit_col(w_hit_col)
    );
    
    // ========== Status Indicator ==========
    status_indicator status ( /*MISSING*/
        .clk(i_clk),
        .rst_n(i_rst_n),
        .event_count(5'd24 - w_active_count),
        .ctrl_state(w_ctrl_state),
        .led(o_led)
    );
    
    // ========== VGA Mixer ==========
    // Priority: snake head > food > obj1 > group > background
    reg [3:0] r_mixed_r, r_mixed_g, r_mixed_b;
    
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_mixed_r <= 4'h0;
            r_mixed_g <= 4'h0;
            r_mixed_b <= 4'h0;
        end else begin
            if (!w_video_on) begin
                r_mixed_r <= 4'h0;
                r_mixed_g <= 4'h0;
                r_mixed_b <= 4'h0;
            end else if (w_snake_r != 4'h0 || w_snake_g != 4'h0 || w_snake_b != 4'h0) begin
                r_mixed_r <= w_snake_r;
                r_mixed_g <= w_snake_g;
                r_mixed_b <= w_snake_b;
            end else if (w_food_r != 4'h0 || w_food_g != 4'h0 || w_food_b != 4'h0) begin
                r_mixed_r <= w_food_r;
                r_mixed_g <= w_food_g;
                r_mixed_b <= w_food_b;
            end else if (w_obj1_r != 4'h0 || w_obj1_g != 4'h0 || w_obj1_b != 4'h0) begin
                r_mixed_r <= w_obj1_r;
                r_mixed_g <= w_obj1_g;
                r_mixed_b <= w_obj1_b;
            end else if (w_group_r != 4'h0 || w_group_g != 4'h0 || w_group_b != 4'h0) begin
                r_mixed_r <= w_group_r;
                r_mixed_g <= w_group_g;
                r_mixed_b <= w_group_b;
            end else begin
                r_mixed_r <= 4'h0;
                r_mixed_g <= 4'h0;
                r_mixed_b <= 4'h0;
            end
        end
    end
    
    assign o_vga_r = r_mixed_r;
    assign o_vga_g = r_mixed_g;
    assign o_vga_b = r_mixed_b;

endmodule