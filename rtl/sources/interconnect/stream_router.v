module stream_router (
    input  wire        i_clk,
    input  wire        i_rst_n,
    
    // ===== Input Stream =====
    input  wire [63:0] i_s_axis_tdata,
    input  wire        i_s_axis_tvalid,
    input  wire        i_s_axis_tlast,
    output reg         o_s_axis_tready,
    
    // ===== Output Port 0 (Player - Type 0x01) =====
    output reg  [63:0] o_m_axis_port0_tdata,
    output reg         o_m_axis_port0_tvalid,
    output reg         o_m_axis_port0_tlast,
    input  wire        i_m_axis_port0_tready,
    
    // ===== Output Port 1 (Bullet - Type 0x02) =====
    output reg  [63:0] o_m_axis_port1_tdata,
    output reg         o_m_axis_port1_tvalid,
    output reg         o_m_axis_port1_tlast,
    input  wire        i_m_axis_port1_tready,
    
    // ===== Output Port 2 (Reserved) =====
    output reg  [63:0] o_m_axis_port2_tdata,
    output reg         o_m_axis_port2_tvalid,
    output reg         o_m_axis_port2_tlast,
    input  wire        i_m_axis_port2_tready,
    
    // ===== Output Port 3 (Enemy - Type 0x03) - NEW! =====
    output reg  [63:0] o_m_axis_port3_tdata,
    output reg         o_m_axis_port3_tvalid,
    output reg         o_m_axis_port3_tlast,
    input  wire        i_m_axis_port3_tready
);

    // Extract packet type from first byte
    wire [7:0] w_packet_type = i_s_axis_tdata[7:0];
    
    // ========== Routing Logic ==========
    always @(*) begin
        // Default: all outputs invalid
        o_m_axis_port0_tvalid = 0;
        o_m_axis_port0_tdata = i_s_axis_tdata;
        o_m_axis_port0_tlast = i_s_axis_tlast;
        
        o_m_axis_port1_tvalid = 0;
        o_m_axis_port1_tdata = i_s_axis_tdata;
        o_m_axis_port1_tlast = i_s_axis_tlast;
        
        o_m_axis_port2_tvalid = 0;
        o_m_axis_port2_tdata = i_s_axis_tdata;
        o_m_axis_port2_tlast = i_s_axis_tlast;
        
        o_m_axis_port3_tvalid = 0;
        o_m_axis_port3_tdata = i_s_axis_tdata;
        o_m_axis_port3_tlast = i_s_axis_tlast;
        
        // Route based on packet type
        case (w_packet_type)
            8'h01: begin
                // Player movement
                o_m_axis_port0_tvalid = i_s_axis_tvalid;
            end
            
            8'h02: begin
                // Bullet control (unused in current design)
                o_m_axis_port1_tvalid = i_s_axis_tvalid;
            end
            
            8'h03: begin
                // Enemy movement - NEW!
                o_m_axis_port3_tvalid = i_s_axis_tvalid;
            end
            
            default: begin
                // Unknown packet type - drop it
            end
        endcase
    end
    
    // ========== Backpressure Logic ==========
    always @(*) begin
        case (w_packet_type)
            8'h01: o_s_axis_tready = i_m_axis_port0_tready;
            8'h02: o_s_axis_tready = i_m_axis_port1_tready;
            8'h03: o_s_axis_tready = i_m_axis_port3_tready;
            default: o_s_axis_tready = 1'b1;  // Always ready for unknown types
        endcase
    end

endmodule