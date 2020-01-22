`timescale 1ns/1ps
//Yanheng Lu
//IBM CSL OpenPower
//lyhlu@cn.ibm.com

module sort_control #(
    parameter PASID_WIDTH = 9,
    parameter RETURN_WIDTH = 41,
    parameter DATA_WIDTH = 1024,
    parameter ADDR_WIDTH = 64
)(
        input                           clk             ,
        input                           rst_n           ,
        output                          fetch_start     ,
        input                           fetch_done      ,
        output      [ADDR_WIDTH-1:0]    fetch_start_addr,
        output      [PASID_WIDTH-1:0]   fetch_pasid     ,
        output      [5:0]               fetch_beat_num  ,
        output                          sort_start      ,
        input                           sort_done       ,
        output                          return_start        ,
        input                           return_done         ,
        output      [PASID_WIDTH-1:0]   return_pasid        ,
        output      [ADDR_WIDTH-1:0]    return_start_addr   ,
        output      [5:0]               return_beat_num     ,
        input                           engine_start    ,
        output                          engine_ready    ,
        input       [DATA_WIDTH-1:0]    engine_data     ,
        output                          complete_ready  ,
        input                           complete_accept ,
        output      [RETURN_WIDTH-1:0]  complete_data
);

    reg                     fetch_idle;
    reg                     sort_idle;
    reg                     return_idle;
    reg     [191:0]         fetch_config;
    reg     [127:0]         sort_config;
    reg     [127:0]         return_config;
    reg     [3:0]           cycle_cnt;
    reg                     fetch_used;
    reg                     sort_used;
    wire                    next_block;

always@(posedge clk or negedge rst_n)
    if(!rst_n)
        cycle_cnt <= 4'b0;
    else if(next_block)
        cycle_cnt <= 4'b0;
    else if(cycle_cnt[3])
        cycle_cnt <= cycle_cnt;
    else if(fetch_used != 1'b1)
        cycle_cnt <= cycle_cnt + 1'b1;

always@(posedge clk or negedge rst_n)
    if(!rst_n)
        fetch_used <= 1'b0;
    else if(engine_start)
        fetch_used <= 1'b1;
    else if(next_block)
        fetch_used <= 1'b0;

always@(posedge clk or negedge rst_n)
    if(!rst_n)
        fetch_idle <= 1'b1;
    else if(fetch_start)
        fetch_idle <= 1'b0;
    else if(fetch_done || cycle_cnt[3])
        fetch_idle <= 1'b1;

always@(posedge clk or negedge rst_n)
    if(!rst_n)
        sort_idle <= 1'b1;
    else if(sort_start)
        sort_idle <= 1'b0;
    else if(sort_done)
        sort_idle <= 1'b1;

always@(posedge clk or negedge rst_n)
    if(!rst_n)
        return_idle <= 1'b1;
    else if(return_start)
        return_idle <= 1'b0;
    else if(complete_accept)
        return_idle <= 1'b1;

always@(posedge clk or negedge rst_n)
    if(!rst_n)
        fetch_config <= 'd0;
    else if(engine_start)
        fetch_config <= engine_data[191:0];

always@(posedge clk) if(next_block) sort_config <= fetch_config[127:0];
always@(posedge clk) if(next_block) sort_used <= fetch_used;
always@(posedge clk) if(next_block) return_config <= sort_config[127:0];

assign next_block = fetch_idle & sort_idle & return_idle;
assign fetch_start = engine_start;
assign return_start = next_block & sort_used;
assign sort_start = next_block & fetch_used;
assign engine_ready = next_block & (cycle_cnt[3] == 1'b0);
assign complete_ready = return_done & !return_idle;
assign fetch_pasid = fetch_config[40:32];
assign fetch_beat_num = fetch_config[61:56];
assign fetch_start_addr = fetch_config[191:128];
assign return_start_addr = return_config[127:64];
assign return_beat_num = return_config[53:48];
assign return_pasid = return_config[40:32];
assign complete_data = return_config[40:0];

endmodule
