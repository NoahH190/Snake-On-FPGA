module stream_arbiter (
    input  wire        i_clk,
    input  wire        i_rst_n,
    
    // ===== Input Port 0 (Higher Priority - UART/Player Input) =====
    input  wire [63:0] i_s_axis0_tdata,
    input  wire        i_s_axis0_tvalid,
    input  wire        i_s_axis0_tlast,
    output wire        o_s_axis0_tready,
    
    // ===== Input Port 1 (Lower Priority - Timer/Enemy Movement) =====
    input  wire [63:0] i_s_axis1_tdata,
    input  wire        i_s_axis1_tvalid,
    input  wire        i_s_axis1_tlast,
    output wire        o_s_axis1_tready,
    
    // ===== Merged Output =====
    output reg  [63:0] o_m_axis_tdata,
    output reg         o_m_axis_tvalid,
    output reg         o_m_axis_tlast,
    input  wire        i_m_axis_tready
);

    // ========== Sequential Priority Arbiter ==========
    // Registered output for better synthesis and timing
    // Port 0 (UART) always takes precedence over Port 1 (Timer)
    
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_m_axis_tdata  <= 64'h0;
            o_m_axis_tvalid <= 1'b0;
            o_m_axis_tlast  <= 1'b0;
        end else begin
            if (i_s_axis0_tvalid) begin
                // UART packet has priority - forward it
                o_m_axis_tdata  <= i_s_axis0_tdata;
                o_m_axis_tvalid <= i_s_axis0_tvalid;
                o_m_axis_tlast  <= i_s_axis0_tlast;
            end else begin
                // No UART packet - forward Timer packet
                o_m_axis_tdata  <= i_s_axis1_tdata;
                o_m_axis_tvalid <= i_s_axis1_tvalid;
                o_m_axis_tlast  <= i_s_axis1_tlast;
            end
        end
    end
    
    // ========== Backpressure Routing ==========
    // Forward ready signal back to the active source
    
    // Port 0 always gets ready signal (high priority)
    assign o_s_axis0_tready = i_m_axis_tready;
    
    // Port 1 only gets ready when Port 0 is not valid (low priority)
    assign o_s_axis1_tready = i_m_axis_tready && !i_s_axis0_tvalid;

endmodule