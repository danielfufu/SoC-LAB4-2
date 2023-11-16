// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`default_nettype wire
`include "/home/ubuntu/lab-caravel_fir/rtl/user/fir.v"
`include "/home/ubuntu/lab-caravel_fir/rtl/user/bram11.v"

`define MPRJ_IO_PADS_1 19	/* number of user GPIO pads on user1 side */
`define MPRJ_IO_PADS_2 19	/* number of user GPIO pads on user2 side */
`define MPRJ_IO_PADS (`MPRJ_IO_PADS_1 + `MPRJ_IO_PADS_2)
/*
 *-------------------------------------------------------------
 *
 * user_proj_example
 *
 * This is an example of a (trivially simple) user project,
 * showing how the user project can connect to the logic
 * analyzer, the wishbone bus, and the I/O pads.
 *
 * This project generates an integer count, which is output
 * on the user area GPIO pads (digital output only).  The
 * wishbone connection allows the project to be controlled
 * (start and stop) from the management SoC program.
 *
 * See the testbenches in directory "mprj_counter" for the
 * example programs that drive this user project.  The three
 * testbenches are "io_ports", "la_test1", and "la_test2".
 *
 *-------------------------------------------------------------
 */

module user_proj_example #(
    parameter BITS = 32,
    parameter DELAYS=10,
    parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11
)(
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif

    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output reg wbs_ack_o,
    output reg [31:0] wbs_dat_o,

    // Logic Analyzer Signals
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,

    // IOs
    input  [`MPRJ_IO_PADS-1:0] io_in,
    output [`MPRJ_IO_PADS-1:0] io_out,
    output [`MPRJ_IO_PADS-1:0] io_oeb,

    // IRQ
    output [2:0] irq
);
    // wire clk;
    // wire rst;

    wire [`MPRJ_IO_PADS-1:0] io_in;
    wire [`MPRJ_IO_PADS-1:0] io_out;
    wire [`MPRJ_IO_PADS-1:0] io_oeb;

    // WB responding signals
    wire        wbs_ack_o_fir;
    wire [31:0] wbs_dat_o_fir;
    reg        wbs_ack_o_user;
    reg  [31:0] wbs_dat_o_user;

    wire [3:0]               tap_WE;
    wire                     tap_EN;
    wire [(pDATA_WIDTH-1):0] tap_Di;
    wire [(pADDR_WIDTH-1):0] tap_A;
    wire [(pDATA_WIDTH-1):0] tap_Do;

    // bram for data RAM
    wire [3:0]               data_WE;
    wire                     data_EN;
    wire [(pDATA_WIDTH-1):0] data_Di;
    wire [(pADDR_WIDTH-1):0] data_A;
    wire [(pDATA_WIDTH-1):0] data_Do;

    // AXI LITE
    wire awready;
    wire wready;
    wire awvalid;
    wire [11:0] awaddr;
    wire wvalid;
    wire [31:0] wdata;

    wire arready;
    wire rready;
    wire arvalid;
    wire [11:0] araddr;
    wire rvalid;
    wire [31:0] rdata;

    // AXI stream
    wire ss_tvalid; 
    wire [31:0] ss_tdata; 
    wire ss_tlast; 
    wire ss_tready; 

    wire sm_tready; 
    wire sm_tvalid; 
    wire [31:0] sm_tdata; 
    wire sm_tlast;
	
	wire clk;
    wire rst;

    reg [3:0] delay_cnt;
    wire valid;
    wire [31:0] rdata_user;
    wire [3:0] bram_we;
    wire [31:0] bram_addr;
    wire [31:0] wdata_user;
    wire to_user_bram;

    assign clk = wb_clk_i;
    assign rst = wb_rst_i;
	assign valid = wbs_cyc_i && wbs_stb_i; 
    assign to_user_bram = valid && wbs_adr_i[31:24] == 'h38 ? 1 : 0;
    assign bram_we = to_user_bram ? wbs_sel_i & {4{wbs_we_i}} : 0;
    assign bram_addr = to_user_bram ? (wbs_adr_i - 32'h38000000) >> 2 : 32'h0;
    assign wdata_user = to_user_bram ? wbs_dat_i : 0;

    
    always @(posedge clk) begin
        if(rst) begin
            wbs_ack_o_user <= 0;
        end
        else begin
            if(delay_cnt == DELAYS) begin
				wbs_ack_o_user <= 1;
			end
            else begin
				wbs_ack_o_user <= 0;
			end
        end
    end
	always @(posedge clk) begin
        if (rst) begin
            delay_cnt <= 0;
        end 
		else begin
            if (to_user_bram) begin
                // if (delay_cnt == DELAYS) begin
                if (wbs_ack_o_user) begin
                    delay_cnt <= 0;
                end
                else begin
                    delay_cnt <= delay_cnt + 1;
                end
            end
            else begin
                delay_cnt <= 0;
            end
        end
    end
    always @(posedge clk) begin
        if(rst) begin
            wbs_dat_o_user <= 0;
        end
        else begin
            if(delay_cnt == DELAYS) begin
				wbs_dat_o_user <= rdata_user;
			end
            else begin
				wbs_dat_o_user <= 0;
			end
        end
    end

    bram user_bram (
        .CLK(clk),
        .WE0(bram_we),
        .EN0(1'b1),
        .Di0(wdata_user),
        .Do0(rdata_user),
        .A0(bram_addr)
    );

    always @(*) begin
		wbs_ack_o = 0;
        wbs_dat_o = 0;
        if (valid) begin
            case (wbs_adr_i[31:24])
                'h30: begin
                    wbs_ack_o = wbs_ack_o_fir;
                    wbs_dat_o = wbs_dat_o_fir;
                end
                'h38: begin
                    wbs_ack_o = wbs_ack_o_user;
                    wbs_dat_o = wbs_dat_o_user;
                end
                default: begin
                    wbs_ack_o = 0;
                    wbs_dat_o = 0;
                end
            endcase
        end
    end


   /* always @(posedge wb_clk_i or negedge wb_rst_i) begin
        if (wb_rst_i) begin
            delay_cnt <= 0;
        end 
		else begin
            if (to_user_bram) begin
                // if (delay_cnt == DELAYS) begin
                if (wbs_ack_o_user) begin
                    delay_cnt <= 0;
                end
                else begin
                    delay_cnt <= delay_cnt + 1;
                end
            end
            else begin
                delay_cnt <= 0;
            end
        end
    end*/
	

  
    WBtoAXI wbtoaxi_u (

        wb_clk_i,
        wb_rst_i,
        wbs_stb_i,
        wbs_cyc_i,
        wbs_we_i,
        wbs_sel_i,
        wbs_dat_i,
        wbs_adr_i,
        wbs_ack_o_fir,
        wbs_dat_o_fir,


        awready,
        wready,
        awvalid,
        awaddr,
        wvalid,
        wdata,

        arready,
        rready,
        arvalid,
        araddr,
        rvalid,
        rdata,


        ss_tvalid, 
        ss_tdata, 
        ss_tlast, 
        ss_tready, 

        sm_tready, 
        sm_tvalid, 
        sm_tdata, 
        sm_tlast

    );

    fir fir_v(
        // AXI LITE
        awready,
        wready,
        awvalid,
        awaddr,
        wvalid,
        wdata,

        arready,
        rready,
        arvalid,
        araddr,
        rvalid,
        rdata,

        // AXI stream
        ss_tvalid, 
        ss_tdata, 
        ss_tlast, 
        ss_tready, 

        sm_tready, 
        sm_tvalid, 
        sm_tdata, 
        sm_tlast, 
    
        // bram for tap RAM
        tap_WE,
        tap_EN,
        tap_Di,
        tap_A,
        tap_Do,

        // bram for data RAM
        data_WE,
        data_EN,
        data_Di,
        data_A,
        data_Do,

        wb_clk_i,
        !wb_rst_i
    );


    bram11 data_ram (
        .clk(wb_clk_i),
        .we(data_WE[0]),
        .re(data_EN),
        .waddr(data_A),
        .raddr(data_A),
        .wdi(data_Di),
        .rdo(data_Do)
    );

    bram11 tap_ram (
        .clk(wb_clk_i),
        .we(tap_WE[0]),
        .re(tap_EN),
        .waddr(tap_A),
        .raddr(tap_A),
        .wdi(tap_Di),
        .rdo(tap_Do)
    );
    
endmodule

module WBtoAXI (
    // WB
    input               wb_clk_i,
    input               wb_rst_i,
    input               wbs_stb_i,
    input               wbs_cyc_i,
    input               wbs_we_i,
    input [3:0]         wbs_sel_i,
    input [31:0]        wbs_dat_i,
    input [31:0]        wbs_adr_i,
    output reg          wbs_ack_o,
    output reg [31:0]   wbs_dat_o,

    // AXI LITE
    input               awready,
    input               wready,
    output reg          awvalid,
    output reg [11:0]   awaddr,
    output reg          wvalid,
    output reg [31:0]   wdata,

    input               arready,
    output reg          rready,
    output reg          arvalid,
    output reg [11:0]   araddr,
    input               rvalid,
    input [31:0]        rdata,

    // AXI stream
    output reg          ss_tvalid, 
    output reg [31:0]   ss_tdata, 
    output reg          ss_tlast, 
    input               ss_tready, 

    output reg          sm_tready, 
    input               sm_tvalid, 
    input [31:0]        sm_tdata, 
    input               sm_tlast
);

    wire valid;
    reg aw_handshaked, w_handshaked;
	reg ar_handshaked;
    assign valid = wbs_stb_i && wbs_cyc_i && wbs_adr_i[31:24] == 'h30;

    always  @(posedge wb_clk_i) begin
        if (wb_rst_i) begin
            aw_handshaked <= 0;
        end
        else begin
            if (awvalid && awready)  aw_handshaked <= 1;            
            else if (wbs_ack_o)      aw_handshaked <= 0;
        end
    end

    always  @(posedge wb_clk_i) begin
        if (wb_rst_i) begin
            w_handshaked <= 0;
        end
        else begin
            if (wvalid && wready)   w_handshaked <= 1;            
            else if (wbs_ack_o)     w_handshaked <= 0;
        end
    end

    always  @(posedge wb_clk_i) begin
        if (wb_rst_i) begin
            ar_handshaked <= 0;
        end
        else begin
            if (arvalid && arready) ar_handshaked <= 1;            
            else if (wbs_ack_o)     ar_handshaked <= 0;
        end
    end

    // axi-lite
    always @(*) begin
        if (valid && !wbs_adr_i[7]) begin            // wbs_adr_i >= 3000_0080
            awvalid = wbs_we_i && !aw_handshaked;
            awaddr = wbs_adr_i[11:0];

            wvalid = wbs_we_i && !w_handshaked;
            wdata = wbs_dat_i;

            arvalid = !wbs_we_i && !ar_handshaked;
            araddr = wbs_adr_i[11:0];

            rready = !wbs_we_i;
        end
        else begin
            awvalid = 0;
            awaddr = 0;

            wvalid = 0;
            wdata = 0;

            arvalid = 0;
            araddr = 0;

            rready = 0;
        end
    end

    // axi-stream
    always @(*) begin
        if (valid && wbs_adr_i[7] && wbs_adr_i[7:0] == 'h80) begin
            ss_tvalid = wbs_we_i;
            ss_tdata = wbs_dat_i;
            ss_tlast = 1;
        end 
        else begin
            ss_tvalid = 0;
            ss_tdata = 0;
            ss_tlast = 0;
        end
    end

    always @(*) begin
        if (valid && wbs_adr_i[7] && wbs_adr_i[7:0] == 'h84) begin
            sm_tready = 1;
        end 
        else begin
            sm_tready = 0;
        end
    end

    always @(*) begin
        if ((aw_handshaked && w_handshaked) | (rvalid && rready) || 
            (ss_tvalid && ss_tready) || (sm_tvalid && sm_tready)) begin
            wbs_ack_o = 1;
        end
        else begin
            wbs_ack_o = 0;
        end
    end

    always @(*) begin
        if (valid) begin
			wbs_dat_o = 0;
            if (!wbs_adr_i[7]) begin
                wbs_dat_o = rdata;
            end
            else begin
                if (wbs_adr_i[7:0] == 'h84) begin
                    wbs_dat_o = sm_tdata;
                end
            end           
        end
    end
    
endmodule

`default_nettype wire