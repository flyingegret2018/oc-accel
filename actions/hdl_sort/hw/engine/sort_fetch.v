`timescale 1ns/1ps
//Yanheng Lu
//IBM CSL OpenPower
//lyhlu@cn.ibm.com

module sort_fetch #(
    parameter ID_WIDTH = 1,
    parameter ARUSER_WIDTH = 9,
    parameter PASID_WIDTH = 9,
	parameter FETCH_WIDTH = 32768,
    parameter DATA_WIDTH = 1024,
    parameter ADDR_WIDTH = 64
)(
        input                           clk             ,
        input                           rst_n           ,
		input                           fetch_start     ,
		output                          fetch_done      ,
		input       [ADDR_WIDTH-1:0]    fetch_start_addr,
		input       [PASID_WIDTH-1:0]   fetch_pasid     ,
        output  reg [FETCH_WIDTH-1:0]   fetch_data      ,
		input       [5:0]               fetch_beat_num  ,

        //---- AXI bus ----
           // AXI read address channel
        output      [ID_WIDTH-1:0]      m_axi_arid    ,
        output  reg [ADDR_WIDTH-1:0]    m_axi_araddr  ,
        output      [007:0]             m_axi_arlen   ,
        output      [002:0]             m_axi_arsize  ,
        output      [001:0]             m_axi_arburst ,
        output      [ARUSER_WIDTH-1:0]  m_axi_aruser  ,
        output      [003:0]             m_axi_arcache ,
        output      [001:0]             m_axi_arlock  ,
        output      [002:0]             m_axi_arprot  ,
        output      [003:0]             m_axi_arqos   ,
        output      [003:0]             m_axi_arregion,
        output                          m_axi_arvalid ,
        input                           m_axi_arready ,
          // AXI read data channel
        output                          m_axi_rready  ,
        //input      [ARUSER_WIDTH - 1:0]   m_axi_ruser  ,
        input       [ID_WIDTH-1:0]      m_axi_rid     ,
        input       [DATA_WIDTH-1:0]    m_axi_rdata   ,
        input       [001:0]             m_axi_rresp   ,
        input                           m_axi_rlast   ,
        input                           m_axi_rvalid
);

    reg     [5:0]       beat_cnt;
	reg     [5:0]       read_cnt;

    assign m_axi_arid     = 0;
    assign m_axi_arsize   = 3'd7; // 8*2^7=1024
    assign m_axi_arburst  = 2'd1; // INCR mode for memory access
    assign m_axi_arcache  = 4'd3; // Normal Non-cacheable Bufferable
    assign m_axi_arprot   = 3'd0;
    assign m_axi_arqos    = 4'd0;
    assign m_axi_arregion = 4'd0; //?
    assign m_axi_arlock   = 2'b00; // normal access
    assign m_axi_rready   = 1'b1;
	assign m_axi_aruser   = fetch_pasid;
	assign m_axi_arlen    = 'd0;//fetch_beat_num-1;
	assign m_axi_arvalid  = beat_cnt < fetch_beat_num;
	assign fetch_done     = read_cnt == fetch_beat_num;

    always@(posedge clk or negedge rst_n)
        if(!rst_n)
	        read_cnt <= 'd0;
		else if(fetch_start)
	        read_cnt <= 'd0;
		else if(m_axi_rvalid & (m_axi_rresp == 2'b00))
		    read_cnt <= read_cnt + 1'b1;

    always@(posedge clk or negedge rst_n)
        if(!rst_n)
	        beat_cnt <= 'd0;
		else if(fetch_start)
	        beat_cnt <= 'd0;
        else if(m_axi_arvalid & m_axi_arready)
	        beat_cnt <= beat_cnt + 1'b1;

    always@(posedge clk or negedge rst_n)
        if(!rst_n)
            m_axi_araddr <= 'd0;
        else if(fetch_start)
            m_axi_araddr <= fetch_start_addr;
        else if(m_axi_arvalid & m_axi_arready)
            m_axi_araddr <= fetch_start_addr + 'd128;

	always@(posedge clk) if(fetch_start) fetch_data <= 'd0; else if(m_axi_rvalid & (m_axi_rresp == 'd0)) fetch_data <= {fetch_data[FETCH_WIDTH-1025:0], m_axi_rdata};

endmodule
