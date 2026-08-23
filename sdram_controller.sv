`timescale 1ns / 1ps

module sdram_controller(
    input wire clk, rst_n,  
    input wire rw, rw_en,       
    input wire [23:0] f_addr,   // THE FIX: Unlocked full 24-bit logical addressing!
    input wire [15:0] f2s_data, 
    output wire [15:0] s2f_data, 
    output wire s2f_data_valid, 
    output reg f2s_data_valid, ready, 
    
    output wire s_cs_n, s_ras_n, s_cas_n, s_we_n, 
    output wire [12:0] s_addr, 
    output wire [1:0] s_ba, 
    output wire LDQM, HDQM, 
    inout [15:0] s_dq 
);  

    localparam[3:0] start=0, precharge_init=1, refresh_1=2, refresh_2=3, load_mode_reg=4,
                    idle=5, read=6, read_data=7, write=8, write_burst=9, refresh=10, delay=11;
                            
    localparam[3:0] t_RP=2, t_RC=4, t_MRD=2, t_RCD=2, t_WR=2, t_CL=3; 
                    
    localparam[3:0] cmd_precharge=4'b0010, cmd_NOP=4'b1111, cmd_activate=4'b0011,
                    cmd_write=4'b0100, cmd_read=4'b0101, cmd_setmode=4'b0000, cmd_refresh=4'b0001;
                          
    reg[3:0] state_q, state_d, nxt_q, nxt_d, cmd_q, cmd_d;
    reg[15:0] delay_ctr_q, delay_ctr_d; 
    reg[10:0] refresh_ctr_q=0, refresh_ctr_d; 
    reg refresh_flag_q, refresh_flag_d;
    reg rw_d, rw_q, rw_en_q, rw_en_d;
    
    reg[12:0] s_addr_q, s_addr_d;
    reg[1:0] s_ba_q, s_ba_d;
    reg tri_q, tri_d;
    
    reg[23:0] f_addr_q, f_addr_d; // Updated to 24 bits
    reg[15:0] f2s_data_q, f2s_data_d;
    reg[15:0] s2f_data_q, s2f_data_d;
    reg s2f_data_valid_q, s2f_data_valid_d;

    always @(posedge clk, negedge rst_n) begin
        if(!rst_n) begin
            state_q<=start; nxt_q<=start; cmd_q<=cmd_NOP; delay_ctr_q<=0; refresh_ctr_q<=0;
            s_addr_q<=0; tri_q<=0; rw_q<=0; rw_en_q<=0; s_ba_q<=0; f_addr_q<=0;
            f2s_data_q<=0; s2f_data_q<=0; s2f_data_valid_q<=0; refresh_flag_q<=0;
        end else begin
            state_q<=state_d; nxt_q<=nxt_d; cmd_q<=cmd_d; delay_ctr_q<=delay_ctr_d;
            refresh_ctr_q<=refresh_ctr_d; s_addr_q<=s_addr_d; tri_q<=tri_d; refresh_flag_q<=refresh_flag_d;
            s_ba_q<=s_ba_d; f_addr_q<=f_addr_d; rw_q<=rw_d; f2s_data_q<=f2s_data_d; 
            s2f_data_q<=s2f_data_d; s2f_data_valid_q<=s2f_data_valid_d; rw_en_q<=rw_en_d;
        end
    end
    
    always @* begin
        state_d=state_q; nxt_d=nxt_q; cmd_d=cmd_NOP; delay_ctr_d=delay_ctr_q; ready=0; 
        s_addr_d=s_addr_q; s_ba_d=s_ba_q; f_addr_d=f_addr_q; rw_d=rw_q;
        f2s_data_d=f2s_data_q; s2f_data_d=s2f_data_q; tri_d=0; s2f_data_valid_d=1'b0;
        f2s_data_valid=1'b0; rw_en_d=rw_en_q;
        
        refresh_flag_d=refresh_flag_q;
        refresh_ctr_d=refresh_ctr_q+1'b1;
        
        if(refresh_ctr_q==350) begin 
            refresh_ctr_d=0; refresh_flag_d=1;
        end
        
        case(state_q)
            delay: begin 
                delay_ctr_d=delay_ctr_q-1'b1;
                if(delay_ctr_d==0) state_d=nxt_q;    
                if(nxt_q==write) tri_d=1;
            end
            start: begin 
                state_d=delay; nxt_d=precharge_init; delay_ctr_d=16'd10_000; 
                s_addr_d=0; s_ba_d=0;
            end
            precharge_init: begin 
                state_d=delay; nxt_d=refresh_1; delay_ctr_d=t_RP-1; cmd_d=cmd_precharge; s_addr_d[10]=1'b1;
            end
            refresh_1: begin state_d=delay; nxt_d=refresh_2; delay_ctr_d=t_RC-1; cmd_d=cmd_refresh; end
            refresh_2: begin state_d=delay; nxt_d=load_mode_reg; delay_ctr_d=t_RC-1; cmd_d=cmd_refresh; end
            load_mode_reg: begin
                state_d=delay; nxt_d=idle; delay_ctr_d=t_MRD-1; cmd_d=cmd_setmode;
                s_addr_d=13'b000_0_00_011_0_000; 
                s_ba_d=2'b00; 
            end
            idle: begin 
                ready=rw_en_q? 0:1;
                if(rw_en_q) begin 
                    state_d=delay; cmd_d=cmd_activate; delay_ctr_d=t_RCD-1;
                    nxt_d=rw_q?read:write; rw_en_d=1'b0;
                    // THE FIX: Properly map Bank and Row Addresses
                    s_ba_d = f_addr_q[23:22];  
                    s_addr_d = f_addr_q[21:9]; 
                end else if(refresh_flag_q || rw_en) begin  
                    state_d=delay; nxt_d=refresh; delay_ctr_d=t_RP-1; cmd_d=cmd_precharge; 
                    s_addr_d[10]=1'b1; refresh_flag_d=0;
                    if(rw_en) begin rw_en_d=rw_en; f_addr_d=f_addr; rw_d=rw; end
                end
            end 
            refresh: begin state_d=delay; nxt_d=idle; delay_ctr_d=t_RC-1; cmd_d=cmd_refresh; end                    
            read: begin 
                state_d=delay; delay_ctr_d=t_CL; cmd_d=cmd_read;
                // THE FIX: Properly map Bank and Column Addresses
                s_ba_d = f_addr_q[23:22];
                s_addr_d = {4'b0000, f_addr_q[8:0]}; 
                s_addr_d[10]=1'b0; nxt_d=read_data;
            end
            read_data: begin 
                s2f_data_d = s_dq; 
                s2f_data_valid_d = 1'b1; 
                state_d = delay; nxt_d = idle; delay_ctr_d = t_RP-1; cmd_d = cmd_precharge;
            end        
            write: begin  
                f2s_data_d=f2s_data; f2s_data_valid=1'b1; 
                // THE FIX: Properly map Bank and Column Addresses
                s_ba_d = f_addr_q[23:22];
                s_addr_d = {4'b0000, f_addr_q[8:0]};
                s_addr_d[10]=1'b0; tri_d=1'b1; cmd_d=cmd_write; state_d=write_burst;
            end
            write_burst: begin    
                tri_d=0; f2s_data_valid=1'b0; state_d=delay; nxt_d=idle; delay_ctr_d=t_RP+t_WR-1; cmd_d=cmd_precharge;
            end
            default: state_d=start;
        endcase
    end
    
    assign s_cs_n=cmd_q[3], s_ras_n=cmd_q[2], s_cas_n=cmd_q[1], s_we_n=cmd_q[0]; 
    assign LDQM=1'b0, HDQM=1'b0;
    assign s_addr=s_addr_q; assign s_ba=s_ba_q;
    assign s_dq=tri_q? f2s_data_q:16'hzzzz; 
    assign s2f_data=s2f_data_q; assign s2f_data_valid=s2f_data_valid_q;
endmodule