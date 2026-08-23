// ============================================================================
// UART TRANSMITTER
// ============================================================================
module uart_tx #(
    parameter int CLK_FREQ  = 50_000_000,
    parameter int BAUD_RATE = 115_200
)(
    input  logic       clk,
    input  logic       rst,
    input  logic       tx_start,
    input  logic [7:0] tx_data,
    output logic       tx,
    output logic       tx_busy,
    output logic       tx_done
);
    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    
    typedef enum logic [1:0] {IDLE, START, DATA, STOP} state_t;
    state_t state = IDLE;

    logic [15:0] clk_count = 0;
    logic [2:0]  bit_index = 0;
    logic [7:0]  data_reg  = 0;

    always_ff @(posedge clk) begin
        if (rst) begin
            state     <= IDLE;
            tx        <= 1;
            tx_busy   <= 0;
            tx_done   <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx      <= 1;
                    tx_done <= 0;
                    if (tx_start) begin
                        data_reg  <= tx_data;
                        tx_busy   <= 1;
                        state     <= START;
                        clk_count <= 0;
                    end else begin
                        tx_busy <= 0;
                    end
                end
                START: begin
                    tx <= 0;
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        state     <= DATA;
                        bit_index <= 0;
                    end
                end
                DATA: begin
                    tx <= data_reg[bit_index];
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1;
                        end else begin
                            state <= STOP;
                        end
                    end
                end
                STOP: begin
                    tx <= 1;
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        tx_done   <= 1;
                        tx_busy   <= 0;
                        state     <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule
