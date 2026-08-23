`timescale 1ns / 1ps

module mac_engine (
    input  logic               clk,
    input  logic               rst_n,
    input  logic               enable,
    input  logic               clear_accum,
    input  logic signed [7:0]  pixel_in,
    input  logic signed [7:0]  weight_in,
    output logic signed [31:0] accum_out,
    output logic               valid_out
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            accum_out <= 32'sd0;
            valid_out <= 1'b0;
        end else begin
            valid_out <= 1'b0;
            if (clear_accum) begin
                accum_out <= 32'sd0;
            end else if (enable) begin
                // DSP slice multiplication and accumulation
                accum_out <= accum_out + (pixel_in * weight_in);
                valid_out <= 1'b1;
            end
        end
    end
endmodule