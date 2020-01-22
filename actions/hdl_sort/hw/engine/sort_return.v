`timescale 1ns/1ps
//Yanheng Lu
//IBM CSL OpenPower
//lyhlu@cn.ibm.com

module sort_return #(
    parameter ID_WIDTH = 1,
    parameter AWUSER_WIDTH = 9,
    parameter PASID_WIDTH = 9,
    parameter RETURN_WIDTH = 32768,
    parameter DATA_WIDTH = 1024,
    parameter ADDR_WIDTH = 64
)(
    input                           clk                 ,
    input                           rst_n               ,
    input                           return_start        ,
    output                          return_done         ,
    input       [PASID_WIDTH-1:0]   return_pasid        ,
    input       [RETURN_WIDTH-1:0]  return_data         ,
    input       [ADDR_WIDTH-1:0]    return_start_addr   ,
    input       [5:0]               return_beat_num     ,
    output      [ID_WIDTH-1:0]      m_axi_awid          ,
    output      [ADDR_WIDTH-1:0]    m_axi_awaddr        ,
    output      [7:0]               m_axi_awlen         ,
    output      [2:0]               m_axi_awsize        ,
    output      [1:0]               m_axi_awburst       ,
    output      [3:0]               m_axi_awcache       ,
    output                          m_axi_awlock        ,
    output      [2:0]               m_axi_awprot        ,
    output      [3:0]               m_axi_awqos         ,
    output      [3:0]               m_axi_awregion,
    output      [AWUSER_WIDTH-1:0]  m_axi_awuser        ,
    output                          m_axi_awvalid       ,
    input                           m_axi_awready       ,
    //output      [ID_WIDTH-1:0]      m_axi_wid           ,
    output      [DATA_WIDTH-1:0]    m_axi_wdata         ,
    output      [DATA_WIDTH/8-1:0]  m_axi_wstrb         ,
    output                          m_axi_wlast         ,
    output                          m_axi_wvalid        ,
    input                           m_axi_wready        ,
    output                          m_axi_bready        ,
    input       [ID_WIDTH - 1:0]    m_axi_bid           ,
    input       [1:0]               m_axi_bresp         ,
    input                           m_axi_bvalid
);

    reg     [RETURN_WIDTH-1:0]      write_back_data;
    reg     [5:0]                   beat_cnt;
    reg     [5:0]                   write_cnt;
    reg     [5:0]                   bvalid_cnt;
    reg                             return_run;

    assign m_axi_bready     = 1'b1;
    //assign m_axi_wid        = 'd0;
    assign m_axi_wstrb      = 128'hffffffffffffffffffffffffffffffff;
    assign m_axi_awid       = 'd0;
    assign m_axi_awsize     = 3'd7; // 8*2^7=1024
    assign m_axi_awburst    = 2'd1; // INCR mode for memory access
    assign m_axi_awcache    = 4'd3; // Normal Non-cacheable Bufferable
    assign m_axi_awprot     = 3'd0;
    assign m_axi_awqos      = 4'd0;
    assign m_axi_awregion   = 4'd0; //?
    assign m_axi_awlock     = 2'b00; // normal access
    assign m_axi_awlen      = 8'd0;
    assign m_axi_awuser     = return_pasid;
    assign m_axi_wdata      = write_back_data[1023:0];
    assign m_axi_wlast      = m_axi_wvalid;
    assign m_axi_wvalid     = (write_cnt < return_beat_num) & return_run;
    assign m_axi_awvalid    = (beat_cnt < return_beat_num) & return_run;
    assign m_axi_awaddr     = return_start_addr + beat_cnt * 128;
    assign return_done      = bvalid_cnt == return_beat_num;

    always@(posedge clk or negedge rst_n)
        if(!rst_n)
            return_run <= 1'b0;
        else if(return_start)
            return_run <= 1'b1;
        else if(return_done)
            return_run <= 1'b1;

    always@(posedge clk or negedge rst_n)
        if(!rst_n)
            bvalid_cnt <= 'd0;
        else if(return_start)
            bvalid_cnt <= 'd0;
        else if(m_axi_bvalid & (m_axi_bresp == 2'b00))
            bvalid_cnt <= bvalid_cnt + 1'b1;

    always@(posedge clk or negedge rst_n)
        if(!rst_n)
            write_cnt <= 'd0;
        else if(return_start)
            write_cnt <= 'd0;
        else if(m_axi_wvalid & m_axi_wready)
            write_cnt <= write_cnt + 1'b1;

    always@(posedge clk or negedge rst_n)
        if(!rst_n)
            beat_cnt <= 'd0;
        else if(return_start)
            beat_cnt <= 'd0;
        else if(m_axi_awvalid & m_axi_awready)
            beat_cnt <= beat_cnt + 1'b1;

    always@(posedge clk) if(return_start) write_back_data <= return_data; else if(m_axi_wvalid & m_axi_wready) write_back_data <= write_back_data >> 1024;

endmodule
