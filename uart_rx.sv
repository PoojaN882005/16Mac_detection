`timescale 1ns / 1ps

// ============================================================================
// UART RECEIVER
// ============================================================================
module uart_rx #(
    parameter int CLK_FREQ  = 50_000_000,
    parameter int BAUD_RATE = 115_200
)(
    input  logic       clk,
    input  logic       rst,
    input  logic       rx,
    output logic [7:0] rx_data,
    output logic       rx_done
);
    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    
    typedef enum logic [1:0] {IDLE, START, DATA, STOP} state_t;
    state_t state = IDLE;

    logic [15:0] clk_count = 0;
    logic [2:0]  bit_index = 0;

    always_ff @(posedge clk) begin
        if (rst) begin
            state     <= IDLE;
            rx_done   <= 0;
            clk_count <= 0;
            bit_index <= 0;
        end else begin
            rx_done <= 0;
            
            case (state)
                IDLE: begin
                    clk_count <= 0;
                    bit_index <= 0;
                    if (rx == 0) state <= START;
                end
                START: begin
                    if (clk_count == (CLKS_PER_BIT - 1)/2) begin
                        if (rx == 0) begin
                            clk_count <= 0;
                            state     <= DATA;
                        end else begin
                            state <= IDLE;
                        end
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end
                DATA: begin
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count          <= 0;
                        rx_data[bit_index] <= rx;
                        
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1;
                        end else begin
                            bit_index <= 0;
                            state     <= STOP;
                        end
                    end
                end
                STOP: begin
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        rx_done   <= 1;
                        clk_count <= 0;
                        state     <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule


