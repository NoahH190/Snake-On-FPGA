module system_controller (
    input  wire        i_clk,
    input  wire        i_rst_n,
    
    // ===== Control Inputs =====
    input  wire        i_start_button,                       // Press to start/restart
    input  wire        [$clog2(GRID_SIZE):0]  i_active_count, // Maximum snake size (grid size)
    input  wire        i_halt_condition,                     // Termination trigger
    
    // ===== State Outputs =====
    output reg  [1:0]  o_ctrl_state,
    output wire        o_system_active,          // Enable system operation
    output wire        o_reset_pulse             // Pulse to reset entities
);

    // ========== State Definitions ==========
    localparam STATE_MENU     = 2'b00;  // Waiting to start
    localparam STATE_PLAYING  = 2'b01;  // System in progress
    localparam STATE_VICTORY  = 2'b10;  // Snake reached maximum size
    localparam STATE_GAMEOVER = 2'b11;  // Snake collided with itself
    localparam GRID_SIZE      = 100;
    
    // System is only active during PLAYING state
    assign o_system_active = (o_ctrl_state == STATE_PLAYING);
    
    // ========== Button Debouncing ==========
    reg r_start_button_prev;
    reg r_start_button_prev2;
    wire w_start_pressed;
    
    // Debounce: detect rising edge after 2 clock cycles
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_start_button_prev <= 0;
            r_start_button_prev2 <= 0;
        end else begin
            r_start_button_prev2 <= r_start_button_prev;
            r_start_button_prev <= i_start_button;
        end
    end
    
    assign w_start_pressed = r_start_button_prev && !r_start_button_prev2;
    
    // ========== Reset Pulse Generator ==========
    reg r_reset_triggered;
    reg [3:0] r_reset_counter;
    
    assign o_reset_pulse = (r_reset_counter > 0);
    
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_reset_counter <= 0;
        end else begin
            if (r_reset_triggered) begin
                r_reset_counter <= 15;  // Hold reset for 15 cycles
            end else if (r_reset_counter > 0) begin
                r_reset_counter <= r_reset_counter - 1;
            end
        end
    end
    
    // ========== State Machine ==========
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_ctrl_state <= STATE_MENU;
            r_reset_triggered <= 0;
        end else begin
            r_reset_triggered <= 0;  // Default: no reset
            
            case (o_ctrl_state)
                // ===== MENU State =====
                STATE_MENU: begin
                    if (w_start_pressed) begin
                        o_ctrl_state <= STATE_PLAYING;
                        r_reset_triggered <= 1;  // Reset entities
                    end
                end
                
                // ===== PLAYING State =====
                STATE_PLAYING: begin
                    if (i_active_count == 0) begin
                        // Snake cleared whole grid
                        o_ctrl_state <= STATE_VICTORY;
                    end else if (i_halt_condition) begin
                        // Snake collided with itself
                        o_ctrl_state <= STATE_GAMEOVER;
                    end
                end
                
                // ===== VICTORY State =====
                STATE_VICTORY: begin
                    if (w_start_pressed) begin
                        o_ctrl_state <= STATE_MENU;
                    end
                end
                
                // ===== GAMEOVER State =====
                STATE_GAMEOVER: begin
                    if (w_start_pressed) begin
                        o_ctrl_state <= STATE_MENU;
                    end
                end
                
                default: begin
                    o_ctrl_state <= STATE_MENU;
                end
            endcase
        end
    end

endmodule