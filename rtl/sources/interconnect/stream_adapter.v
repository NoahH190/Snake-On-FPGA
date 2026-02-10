// ============================================================================
// Project:     Real-Time Streaming Graphics System
// Module:      stream_adapter
// Description: Converts serial byte stream to AXI-Stream packets
// 
// Author:      Noah Harman (adapted from Krishang Krishang Talsania)
// Created:     2025-02-10
// Revision:    0.1 - 2025-02-10 - Buffer clearing fix
//
// Revisions:
//   0.0 - 2025-02-10 - Initial creation
// ============================================================================

`timescale 1ns/1ps

module stream_adapter #(
    parameter PACKET_SIZE = 8,
    parameter DATA_WIDTH = 64
)(
    input  wire                  i_clk,
    input  wire                  i_rst_n,
    
    input  wire [7:0]            i_uart_data,
    input  wire                  i_uart_valid,
    
    output reg [DATA_WIDTH-1:0]  o_m_axis_tdata,
    output reg                   o_m_axis_tvalid,
    output reg                   o_m_axis_tlast,
    input  wire                  i_m_axis_tready
);

    reg [2:0] r_byte_count;
    reg [DATA_WIDTH-1:0] r_packet_buffer;
    reg [7:0] r_first_byte;  // Store first byte for debug print
    
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_byte_count <= 0;
            r_packet_buffer <= 0;
            o_m_axis_tvalid <= 0;
            o_m_axis_tlast <= 0;
            r_first_byte <= 0;
        end else begin
            // Accumulate bytes from UART
            if (i_uart_valid && !o_m_axis_tvalid) begin
                // Shift right, insert byte at MSB
                r_packet_buffer <= {i_uart_data, r_packet_buffer[DATA_WIDTH-1:8]};
                
                // Store first byte (packet type)
                if (r_byte_count == 0) begin
                    r_first_byte <= i_uart_data;
                end
                
                r_byte_count <= r_byte_count + 1;
                
                // Debug print
                $display("[ADAPTER] Byte %0d: 0x%02h -> buffer=0x%016h", 
                         r_byte_count, i_uart_data, {i_uart_data, r_packet_buffer[DATA_WIDTH-1:8]});
                
                // When full packet assembled
                if (r_byte_count == PACKET_SIZE - 1) begin
                    o_m_axis_tdata <= {i_uart_data, r_packet_buffer[DATA_WIDTH-1:8]};
                    o_m_axis_tvalid <= 1;
                    o_m_axis_tlast <= 1;
                    r_byte_count <= 0;
                    
                    // Show correct packet type (first byte we received)
                    $display("[ADAPTER] ✓ Packet complete: 0x%016h (type=0x%02h)", 
                             {i_uart_data, r_packet_buffer[DATA_WIDTH-1:8]},
                             r_first_byte);  // Use stored first byte
                end
            end
            
            // Clear valid when downstream accepts packet
            if (o_m_axis_tvalid && i_m_axis_tready) begin
                o_m_axis_tvalid <= 0;
                o_m_axis_tlast <= 0;
                r_packet_buffer <= 0;  // Clear buffer for next packet
            end
        end
    end
endmodule