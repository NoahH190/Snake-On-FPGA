module lsfr (
    input i_clk,
    input i_rst,
    output reg [3:0] o_x_data,
    output reg [3:0] o_y_data
);

    always @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            o_x_data <= 4'h1;
            o_y_data <= 4'h1;
        end else begin
            o_x_data <= {o_x_data[2], o_x_data[1], o_x_data[0], o_x_data[3] ^ o_x_data[3]};
            o_y_data <= {o_y_data[2], o_y_data[1], o_y_data[0], o_y_data[3] ^ o_y_data[2]};
        end
    end

endmodule