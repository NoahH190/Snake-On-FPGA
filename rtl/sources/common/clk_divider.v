`timescale 1ns/1ps

module clk_divider #(
    parameter CLK_FREQ = 100_000_000,  // Input clock frequency (Hz)
    parameter BAUD_RATE = 115200        // Desired baud rate
)(
    input  wire i_clk,
    input  wire i_rst_n,
    output reg  o_baud_tick
);

    // Calculate divisor: CLK_FREQ / (BAUD_RATE * 16)
    // *16 because we oversample at 16x baud rate
    localparam DIVISOR = CLK_FREQ / (BAUD_RATE * 16);
    
    reg [$clog2(DIVISOR)-1:0] r_counter;
    
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_counter <= 0;
            o_baud_tick <= 0;
        end else begin
            if (r_counter == DIVISOR - 1) begin
                r_counter <= 0;
                o_baud_tick <= 1;
            end else begin
                r_counter <= r_counter + 1;
                o_baud_tick <= 0;
            end
        end
    end
endmodule