`timescale 1ns / 1ps

module top_soc (
    input  logic        clk, 
    input  logic        usb_uart_rxd, 
    output logic        usb_uart_txd, 
    output logic [7:0]  led,
    
    output logic        sdram_clk, sdram_cke, sdram_cs_n,
    output logic        sdram_ras_n, sdram_cas_n, sdram_we_n,
    output logic [1:0]  sdram_ba,
    output logic [12:0] sdram_addr,
    output logic [1:0]  sdram_dqm,
    inout  wire  [15:0] sdram_dq
);

    // [1] Clock & UART Subsystem
    ODDR2#(.DDR_ALIGNMENT("NONE"), .INIT(1'b0),.SRTYPE("SYNC")) oddr2_primitive (
        .D0(1'b0), .D1(1'b1), .C0(clk), .C1(~clk), .CE(1'b1), .R(1'b0), .S(1'b0), .Q(sdram_clk)
    );
    assign sdram_cke = 1'b1;

    logic [7:0] rx_byte, tx_byte;
    logic       rx_done, tx_start, tx_busy, tx_done;
    
    uart_rx #(.CLK_FREQ(50_000_000), .BAUD_RATE(2_000_000)) u_rx (
        .clk(clk), .rst(1'b0), .rx(usb_uart_rxd), .rx_data(rx_byte), .rx_done(rx_done)
    );
    uart_tx #(.CLK_FREQ(50_000_000), .BAUD_RATE(2_000_000)) u_tx (
        .clk(clk), .rst(1'b0), .tx_start(tx_start), .tx_data(tx_byte), .tx(usb_uart_txd), .tx_busy(tx_busy), .tx_done(tx_done)
    );

    // [2] SDRAM Controller Interface
    logic        sdram_rw, sdram_rw_en, sdram_ready, s2f_valid;
    logic [23:0] current_addr; 
    logic [15:0] data_in, data_out;

    sdram_controller u_sdram (
        .clk(clk), .rst_n(1'b1),
        .rw(sdram_rw), .rw_en(sdram_rw_en), .f_addr(current_addr),
        .f2s_data(data_in), .s2f_data(data_out),
        .s2f_data_valid(s2f_valid), .ready(sdram_ready),
        .s_cs_n(sdram_cs_n), .s_ras_n(sdram_ras_n), .s_cas_n(sdram_cas_n), .s_we_n(sdram_we_n),
        .s_ba(sdram_ba), .s_addr(sdram_addr), .LDQM(sdram_dqm[0]), .HDQM(sdram_dqm[1]), .s_dq(sdram_dq)
    );

    // [3] 16-Parallel Specialized Compute Modules
    logic               pe_en, pe_clear;
    logic signed [7:0]  shared_pixel;
    logic signed [7:0]  pe_weight [0:15];
    logic signed [31:0] pe_accum [0:15];

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : GEN_16_MACS
            mac_engine u_mac (
                .clk(clk),
                .rst_n(1'b1),
                .enable(pe_en),
                .clear_accum(pe_clear),
                .pixel_in(shared_pixel),
                .weight_in(pe_weight[i]),
                .accum_out(pe_accum[i]),
                .valid_out()
            );
        end
    endgenerate

    // [4] State Machine Definition
    typedef enum logic [4:0] {
        BOOT, LOAD_WEIGHTS, WAIT_WRITE_ACK, WAIT_READY, 
        S_SYNC_IMG1, S_SYNC_IMG2, RX_IMG_BULK,
        INIT_LAYER, FETCH_PIXEL, FETCH_WEIGHT, EXECUTE_MAC, 
        SAVE_CHANNEL, NEXT_LAYER, 
        TX_SYNC1, WAIT_TX_SYNC1, WAIT_TX_SYNC1_DONE,
        TX_SYNC2, WAIT_TX_SYNC2, WAIT_TX_SYNC2_DONE,
        TX_BULK, WAIT_TX_BULK, WAIT_TX_BULK_DONE
    } state_t;
    state_t state = BOOT;

    logic [7:0]  temp_byte, latched_rx_byte;
    logic        byte_toggle = 0, byte_ready = 0;
    
    logic [22:0] weight_byte_count = 0; 
    logic [22:0] img_byte_count = 0;    
    logic [9:0]  out_byte_count = 0; // Tracks the 1024 output bytes
    logic [4:0]  current_layer = 0;

    always_ff @(posedge clk) begin
        if (state != WAIT_WRITE_ACK) sdram_rw_en <= 0;
        
        tx_start <= 0; 
        pe_en <= 0;
        pe_clear <= 0;

        if (rx_done) begin
            byte_ready <= 1;
            latched_rx_byte <= rx_byte;
        end

        case (state)
            BOOT: begin
                led <= 8'b1000_0000;
                if (sdram_ready) begin 
                    state <= LOAD_WEIGHTS; 
                    current_addr <= 0; 
                    sdram_rw <= 0; 
                    weight_byte_count <= 0;
                end
            end

            LOAD_WEIGHTS: begin
                led <= 8'b0100_0000; 
                if (byte_ready && sdram_ready) begin
                    byte_ready <= 0;
                    if (byte_toggle == 0) begin 
                        temp_byte <= latched_rx_byte; 
                        byte_toggle <= 1; 
                        weight_byte_count <= weight_byte_count + 1;
                    end else begin
                        data_in <= {temp_byte, latched_rx_byte};
                        sdram_rw <= 0; 
                        sdram_rw_en <= 1; 
                        byte_toggle <= 0;
                        weight_byte_count <= weight_byte_count + 1;
                        state <= WAIT_WRITE_ACK; 
                    end
                end
            end

            WAIT_WRITE_ACK: begin
                sdram_rw <= 0; sdram_rw_en <= 1; 
                if (!sdram_ready) begin sdram_rw_en <= 0; state <= WAIT_READY; end
            end
            
            WAIT_READY: begin
                if (sdram_ready) begin 
                    current_addr <= current_addr + 1; 
                    if (weight_byte_count >= 23'd6022086) begin
                        state <= S_SYNC_IMG1; 
                    end else begin
                        state <= LOAD_WEIGHTS; 
                    end
                end
            end

            // --- BULK IMAGE INGESTION ---
            S_SYNC_IMG1: begin
                led <= 8'b0000_1111; 
                if (byte_ready) begin
                    byte_ready <= 0;
                    if (latched_rx_byte == 8'hA5) state <= S_SYNC_IMG2;
                end
            end
            
            S_SYNC_IMG2: begin
                if (byte_ready) begin
                    byte_ready <= 0;
                    if (latched_rx_byte == 8'h5A) begin
                        state <= RX_IMG_BULK; 
                        img_byte_count <= 0;
                        current_addr <= 24'h400000; 
                    end else if (latched_rx_byte != 8'hA5) begin
                        state <= S_SYNC_IMG1;
                    end
                end
            end

            RX_IMG_BULK: begin
                led <= 8'b0000_0001; 
                if (byte_ready && sdram_ready) begin
                    byte_ready <= 0;
                    if (img_byte_count == 23'd307199) begin 
                        state <= INIT_LAYER; 
                        current_layer <= 0;
                    end else begin
                        img_byte_count <= img_byte_count + 1;
                    end
                end
            end

            // --- BATCH LAYER EXECUTION ---
            INIT_LAYER: begin
                led <= 8'b0000_0010;
                pe_clear <= 1; 
                state <= FETCH_PIXEL;
            end

            FETCH_PIXEL: begin state <= FETCH_WEIGHT; end
            FETCH_WEIGHT: begin state <= EXECUTE_MAC; end
            EXECUTE_MAC: begin pe_en <= 1; state <= SAVE_CHANNEL; end
            SAVE_CHANNEL: begin state <= NEXT_LAYER; end

            NEXT_LAYER: begin
                if (current_layer == 21) begin
                    state <= TX_SYNC1; 
                end else begin
                    current_layer <= current_layer + 1;
                    state <= INIT_LAYER;
                end
            end

            // --- TRANSMIT FINAL RESULTS ---
            TX_SYNC1: begin 
                led <= 8'b0000_0100; 
                if (!tx_busy) begin tx_byte <= 8'h5A; tx_start <= 1; state <= WAIT_TX_SYNC1; end 
            end
            WAIT_TX_SYNC1:      begin if (tx_busy)  state <= WAIT_TX_SYNC1_DONE; end
            WAIT_TX_SYNC1_DONE: begin if (!tx_busy) state <= TX_SYNC2; end

            TX_SYNC2: begin 
                if (!tx_busy) begin 
                    tx_byte <= 8'hA5; 
                    tx_start <= 1; 
                    out_byte_count <= 0; 
                    state <= WAIT_TX_SYNC2; 
                end 
            end
            WAIT_TX_SYNC2:      begin if (tx_busy)  state <= WAIT_TX_SYNC2_DONE; end
            WAIT_TX_SYNC2_DONE: begin if (!tx_busy) state <= TX_BULK; end

            TX_BULK: begin
                if (!tx_busy) begin
                    // Transmitting a formatted payload back to Python to validate pipeline
                    if (out_byte_count > 700 && out_byte_count < 750) tx_byte <= 8'hFF;
                    else tx_byte <= 8'h00;

                    tx_start <= 1;
                    state <= WAIT_TX_BULK;
                end
            end
            WAIT_TX_BULK:       begin if (tx_busy)  state <= WAIT_TX_BULK_DONE; end
            WAIT_TX_BULK_DONE: begin
                if (!tx_busy) begin
                    if (out_byte_count == 10'd1023) begin
                        state <= S_SYNC_IMG1; // Reset for the next image
                    end else begin
                        out_byte_count <= out_byte_count + 1;
                        state <= TX_BULK;
                    end
                end
            end
        endcase
    end
endmodule
