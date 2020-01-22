/*
 * Copyright 2019 International Business Machines
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

`timescale 1ns/1ps

module sc_core # (
           parameter RETURN_WIDTH                   = 41,
           parameter PASID_WIDTH                    = 9,
           parameter TOTAL_NUM                      = 1024,
           // Parameters of Axi Slave Bus Interface AXI_CTRL_REG
           parameter C_S_AXI_CTRL_REG_DATA_WIDTH    = 32,
           parameter C_S_AXI_CTRL_REG_ADDR_WIDTH    = 32,

           // Parameters of Axi Master Bus Interface AXI_HOST_MEM ; to Host memory
           parameter C_M_AXI_HOST_MEM_ID_WIDTH      = 2,
           parameter C_M_AXI_HOST_MEM_ADDR_WIDTH    = 64,
           parameter C_M_AXI_HOST_MEM_DATA_WIDTH    = 1024,
           parameter C_M_AXI_HOST_MEM_AWUSER_WIDTH  = 8,
           parameter C_M_AXI_HOST_MEM_ARUSER_WIDTH  = 8,
           parameter C_M_AXI_HOST_MEM_WUSER_WIDTH   = 1,
           parameter C_M_AXI_HOST_MEM_RUSER_WIDTH   = 1,
           parameter C_M_AXI_HOST_MEM_BUSER_WIDTH   = 1
)
(
//////////////////////////////////////////////////////////////////////
//                  Clock and Reset
//////////////////////////////////////////////////////////////////////
input                                           clk                 ,
input                                           rst_n               ,

//////////////////////////////////////////////////////////////////////
//                  AXI MM Master
//////////////////////////////////////////////////////////////////////

  // AXI write address channel
output    [C_M_AXI_HOST_MEM_ID_WIDTH - 1:0]     m_axi_snap_awid     ,
output    [C_M_AXI_HOST_MEM_ADDR_WIDTH - 1:0]   m_axi_snap_awaddr   ,
output    [0007:0]                              m_axi_snap_awlen    ,
output    [0002:0]                              m_axi_snap_awsize   ,
output    [0001:0]                              m_axi_snap_awburst  ,
output    [0003:0]                              m_axi_snap_awcache  ,
output    [0001:0]                              m_axi_snap_awlock   ,
output    [0002:0]                              m_axi_snap_awprot   ,
output    [0003:0]                              m_axi_snap_awqos    ,
output    [0003:0]                              m_axi_snap_awregion ,
output    [C_M_AXI_HOST_MEM_AWUSER_WIDTH - 1:0] m_axi_snap_awuser   ,
output                                          m_axi_snap_awvalid  ,
input                                           m_axi_snap_awready  ,
  // AXI write data channel
output    [C_M_AXI_HOST_MEM_DATA_WIDTH - 1:0]   m_axi_snap_wdata    ,
output    [(C_M_AXI_HOST_MEM_DATA_WIDTH/8) -1:0]m_axi_snap_wstrb    ,
output                                          m_axi_snap_wlast    ,
output                                          m_axi_snap_wvalid   ,
input                                           m_axi_snap_wready   ,
  // AXI write response channel
output                                          m_axi_snap_bready   ,
input     [C_M_AXI_HOST_MEM_ID_WIDTH - 1:0]     m_axi_snap_bid      ,
input     [0001:0]                              m_axi_snap_bresp    ,
input                                           m_axi_snap_bvalid   ,
  // AXI read address channel
output    [C_M_AXI_HOST_MEM_ID_WIDTH - 1:0]     m_axi_snap_arid     ,
output    [C_M_AXI_HOST_MEM_ADDR_WIDTH - 1:0]   m_axi_snap_araddr   ,
output    [0007:0]                              m_axi_snap_arlen    ,
output    [0002:0]                              m_axi_snap_arsize   ,
output    [0001:0]                              m_axi_snap_arburst  ,
output    [C_M_AXI_HOST_MEM_ARUSER_WIDTH - 1:0] m_axi_snap_aruser   ,
output    [0003:0]                              m_axi_snap_arcache  ,
output    [0001:0]                              m_axi_snap_arlock   ,
output    [0002:0]                              m_axi_snap_arprot   ,
output    [0003:0]                              m_axi_snap_arqos    ,
output    [0003:0]                              m_axi_snap_arregion ,
output                                          m_axi_snap_arvalid  ,
input                                           m_axi_snap_arready  ,
  // AXI  ead data channel
output                                          m_axi_snap_rready   ,
input     [C_M_AXI_HOST_MEM_ID_WIDTH - 1:0]     m_axi_snap_rid      ,
input     [C_M_AXI_HOST_MEM_DATA_WIDTH - 1:0]   m_axi_snap_rdata    ,
input     [0001:0]                              m_axi_snap_rresp    ,
input                                           m_axi_snap_rlast    ,
input                                           m_axi_snap_rvalid   ,


//////////////////////////////////////////////////////////////////////
//                   Handshaking signals
//////////////////////////////////////////////////////////////////////
input                                           engine_start,
output                                          engine_ready,
input       [C_M_AXI_HOST_MEM_DATA_WIDTH - 1:0] engine_data,
output                                          complete_ready,
input                                           complete_accept,
output      [RETURN_WIDTH - 1:0]                complete_data

);

parameter PROCESS_DWIDTH = TOTAL_NUM*32;


    wire                                        fetch_start         ;
    wire                                        fetch_done          ;
    wire    [PASID_WIDTH-1:0]                   fetch_pasid         ;
    wire    [5:0]                               fetch_beat_num      ;
    wire    [C_M_AXI_HOST_MEM_ADDR_WIDTH-1:0]   fetch_start_addr    ;
    wire                                        sort_start          ;
    wire                                        sort_done           ;
    wire    [PROCESS_DWIDTH-1:0]                sort_input          ;
    wire    [PROCESS_DWIDTH-1:0]                sort_result         ;
    wire                                        return_start        ;
    wire                                        return_done         ;
    wire    [PASID_WIDTH-1:0]                   return_pasid        ;
    wire    [5:0]                               return_beat_num     ;
    wire    [C_M_AXI_HOST_MEM_ADDR_WIDTH-1:0]   return_start_addr   ;

sort_control#(
                .DATA_WIDTH     ( C_M_AXI_HOST_MEM_DATA_WIDTH   ),
                .ADDR_WIDTH     ( C_M_AXI_HOST_MEM_ADDR_WIDTH   ),
                .RETURN_WIDTH   ( RETURN_WIDTH                  ),
                .PASID_WIDTH    ( PASID_WIDTH                   )
                ) sort_control0(
        .clk                ( clk                   ),
        .rst_n              ( rst_n                 ),
        .sort_start         ( sort_start            ),
        .sort_done          ( sort_done             ),
        .fetch_start        ( fetch_start           ),
        .fetch_done         ( fetch_done            ),
        .fetch_pasid        ( fetch_pasid           ),
        .fetch_beat_num     ( fetch_beat_num        ),
        .fetch_start_addr   ( fetch_start_addr      ),
        .return_start       ( return_start          ),
        .return_done        ( return_done           ),
        .return_pasid       ( return_pasid          ),
        .return_beat_num    ( return_beat_num       ),
        .return_start_addr  ( return_start_addr     ),
        .engine_start       ( engine_start          ),
        .engine_ready       ( engine_ready          ),
        .engine_data        ( engine_data           ),
        .complete_ready     ( complete_ready        ),
        .complete_accept    ( complete_accept       ),
        .complete_data      ( complete_data         )
    );

sort_return#(
                .ID_WIDTH       ( C_M_AXI_HOST_MEM_ID_WIDTH     ),
                .ADDR_WIDTH     ( C_M_AXI_HOST_MEM_ADDR_WIDTH   ),
                .PASID_WIDTH    ( PASID_WIDTH                   ),
                .RETURN_WIDTH   ( PROCESS_DWIDTH                ),
                .DATA_WIDTH     ( C_M_AXI_HOST_MEM_DATA_WIDTH   ),
                .AWUSER_WIDTH   ( C_M_AXI_HOST_MEM_AWUSER_WIDTH )
                ) sort_return0(
        .clk                ( clk                   ),
        .rst_n              ( rst_n                 ),
        .return_start       ( return_start          ),
        .return_done        ( return_done           ),
        .return_pasid       ( return_pasid          ),
        .return_data        ( sort_result           ),
        .return_start_addr  ( return_start_addr     ),
        .return_beat_num    ( return_beat_num       ),
        .m_axi_awid         ( m_axi_snap_awid       ),
        .m_axi_awaddr       ( m_axi_snap_awaddr     ),
        .m_axi_awlen        ( m_axi_snap_awlen      ),
        .m_axi_awsize       ( m_axi_snap_awsize     ),
        .m_axi_awburst      ( m_axi_snap_awburst    ),
        .m_axi_awcache      ( m_axi_snap_awcache    ),
        .m_axi_awlock       ( m_axi_snap_awlock     ),
        .m_axi_awprot       ( m_axi_snap_awprot     ),
        .m_axi_awqos        ( m_axi_snap_awqos      ),
        .m_axi_awregion     ( m_axi_snap_awregion   ),
        .m_axi_awuser       ( m_axi_snap_awuser     ),
        .m_axi_awvalid      ( m_axi_snap_awvalid    ),
        .m_axi_awready      ( m_axi_snap_awready    ),
        .m_axi_wdata        ( m_axi_snap_wdata      ),
        .m_axi_wstrb        ( m_axi_snap_wstrb      ),
        .m_axi_wlast        ( m_axi_snap_wlast      ),
        .m_axi_wvalid       ( m_axi_snap_wvalid     ),
        .m_axi_wready       ( m_axi_snap_wready     ),
        .m_axi_bready       ( m_axi_snap_bready     ),
        .m_axi_bid          ( m_axi_snap_bid        ),
        .m_axi_bresp        ( m_axi_snap_bresp      ),
        .m_axi_bvalid       ( m_axi_snap_bvalid     )
    );

sort_fetch#(
                .ID_WIDTH       ( C_M_AXI_HOST_MEM_ID_WIDTH     ),
                .ADDR_WIDTH     ( C_M_AXI_HOST_MEM_ADDR_WIDTH   ),
                .DATA_WIDTH     ( C_M_AXI_HOST_MEM_DATA_WIDTH   ),
                .PASID_WIDTH    ( PASID_WIDTH                   ),
                .FETCH_WIDTH    ( PROCESS_DWIDTH                ),
                .ARUSER_WIDTH   ( C_M_AXI_HOST_MEM_ARUSER_WIDTH )
                ) sort_fetch0(
        .clk                ( clk                   ),
        .rst_n              ( rst_n                 ),
        .fetch_start        ( fetch_start           ),
        .fetch_done         ( fetch_done            ),
        .fetch_pasid        ( fetch_pasid           ),
        .fetch_data         ( sort_input            ),
        .fetch_start_addr   ( fetch_start_addr      ),
        .fetch_beat_num     ( fetch_beat_num        ),
        .m_axi_arid         ( m_axi_snap_arid       ),
        .m_axi_araddr       ( m_axi_snap_araddr     ),
        .m_axi_arlen        ( m_axi_snap_arlen      ),
        .m_axi_arsize       ( m_axi_snap_arsize     ),
        .m_axi_arburst      ( m_axi_snap_arburst    ),
        .m_axi_aruser       ( m_axi_snap_aruser     ),
        .m_axi_arcache      ( m_axi_snap_arcache    ),
        .m_axi_arlock       ( m_axi_snap_arlock     ),
        .m_axi_arprot       ( m_axi_snap_arprot     ),
        .m_axi_arqos        ( m_axi_snap_arqos      ),
        .m_axi_arregion     ( m_axi_snap_arregion   ),
        .m_axi_arvalid      ( m_axi_snap_arvalid    ),
        .m_axi_arready      ( m_axi_snap_arready    ),
        .m_axi_rready       ( m_axi_snap_rready     ),
        .m_axi_rid          ( m_axi_snap_rid        ),
        .m_axi_rdata        ( m_axi_snap_rdata      ),
        .m_axi_rresp        ( m_axi_snap_rresp      ),
        .m_axi_rlast        ( m_axi_snap_rlast      ),
        .m_axi_rvalid       ( m_axi_snap_rvalid     )
     );

sort #(
        .TOTAL_NUM          ( TOTAL_NUM         )
        ) sort0(
        .clk                ( clk               ),
        .rst_n              ( rst_n             ),
        .sort_start         ( sort_start        ),
        .sort_done          ( sort_done         ),
        .input_data         ( sort_input        ),
        .output_result      ( sort_result       )
    );

endmodule
