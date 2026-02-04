`timescale 1ns/1ps

module uart_rx #(
    parameter DATA_BITS = 8
)(
    input  wire                i_clk,
    input  wire                i_rst_n,
    input  wire                i_baud_tick,   // 16x oversampling tick
    input  wire                i_rx,          // UART RX pin
    
    output reg [DATA_BITS-1:0] o_data,
    output reg                 r_data_valid,
    output reg                 r_frame_error
);

    // FSM states
    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;
    
    reg [1:0] r_state;
    reg [3:0] r_tick_count;      // Count 16 ticks per bit
    reg [2:0] r_bit_count;       // Count data bits
    reg [DATA_BITS-1:0] r_shift_reg;
    
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_state <= IDLE;
            r_data_valid <= 0;
            r_frame_error <= 0;
            r_tick_count <= 0;
            r_bit_count <= 0;
        end else begin
            r_data_valid <= 0;  // Default: pulse for one cycle
            
            if (i_baud_tick) begin
                case (r_state)
                    IDLE: begin
                        if (i_rx == 0) begin  // Start bit detected
                            state <= START;
                            tick_count <= 0;
                        end
                    end
                    
                    START: begin
                        if (r_tick_count == 7) begin  // Sample at middle of bit
                            if (i_rx == 0) begin      // Valid start bit
                                r_state <= DATA;
                                r_tick_count <= 0;
                                r_bit_count <= 0;
                            end else begin
                                r_state <= IDLE;      // False start
                            end
                        end else begin
                            r_tick_count <= r_tick_count + 1;
                        end
                    end
                    
                    DATA: begin
                        if (r_tick_count == 15) begin
                            // Sample data bit
                            r_shift_reg <= {i_rx, r_shift_reg[DATA_BITS-1:1]};
                            r_tick_count <= 0;
                            
                            if (r_bit_count == DATA_BITS - 1) begin
                                r_state <= STOP;
                            end else begin
                                r_bit_count <= r_bit_count + 1;
                            end
                        end else begin
                            r_tick_count <= r_tick_count + 1;
                        end
                    end
                    
                    STOP: begin
                        if (r_tick_count == 15) begin
                            if (i_rx == 1) begin  // Valid stop bit
                                o_data <= r_shift_reg;
                                r_data_valid <= 1;
                                r_frame_error <= 0;
                            end else begin
                                r_frame_error <= 1;
                            end
                            r_state <= IDLE;
                            r_tick_count <= 0;
                        end else begin
                            r_tick_count <= r_tick_count + 1;
                        end
                    end
                endcase
            end
        end
    end
endmodule