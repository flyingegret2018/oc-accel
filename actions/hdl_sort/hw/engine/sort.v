//lyhlu
//have a try
module sort #(
		parameter TOTAL_NUM = 1024
	)(
		input                           clk             ;
		input                           rst_n           ;
		input                           sort_start      ;
		output                          sort_done       ;
		input       [TOTAL_NUM*32-1:0]  input_data      ;
        output      [TOTAL_NUM*32-1:0]  output_result   ;
	);

    reg [10:0]              sort_cnt;
	reg [TOTAL_NUM*32+31:0] sort_vector;

assign sort_done = sort_cnt == TOTAL_NUM;
assign output_result = sort_vector[TOTAL_NUM*32-1:0];

always@(posedge clk or negedge rst_n)
	if(!rst_n)
	    sort_cnt <= 11'b0;
	else if(sort_start)
	    sort_cnt <= 11'b0;
	else if(sort_cnt != TOTAL_NUM)
	    sort_cnt <= sort_cnt + 1'b1;

always@(posedge clk or negedge rst_n)
	if(!rst_n)
	    sort_vector[31:0] <= 32'b0;
	else if(sort_start)
	    sort_vector[31:0] <= input_data[31:0];
	else if((sort_vector[63:32] > sort_vector[31:0]) & sort_cnt[0])
	    sort_vector[31:0] <= sort_vector[63:32];

always@(posedge clk or negedge rst_n)
	if(!rst_n)
        sort_vector[TOTAL_NUM*32-1:TOTAL_NUM*32-32] <= 32'b0;
	else if(sort_start)
        sort_vector[TOTAL_NUM*32-1:TOTAL_NUM*32-32] <= input_data[TOTAL_NUM*32-1:TOTAL_NUM*32-32];
	else if((sort_vector[TOTAL_NUM*32-1:TOTAL_NUM*32-32] > sort_vector[TOTAL_NUM*32-33:TOTAL_NUM*32-64]) & !sort_cnt[0])
	    sort_vector[TOTAL_NUM*32-1:TOTAL_NUM*32-32] <= sort_vector[TOTAL_NUM*32-33:TOTAL_NUM*32-64];
	else if(sort_cnt[0])
		sort_vector[TOTAL_NUM*32-1:TOTAL_NUM*32-32] <= sort_vector[TOTAL_NUM*32+31:TOTAL_NUM*32];

always@(posedge clk or negedge rst_n)
	if(!rst_n)
        sort_vector[TOTAL_NUM*32+31:TOTAL_NUM*32] <= 32'b0;
	else if(sort_start)
        sort_vector[TOTAL_NUM*32+31:TOTAL_NUM*32] <= 32'b0;
	else if((sort_vector[TOTAL_NUM*32-1:TOTAL_NUM*32-32] < sort_vector[TOTAL_NUM*32-33:TOTAL_NUM*32-64] & !sort_cnt[0])
		sort_vector[TOTAL_NUM*32+31:TOTAL_NUM*32] <= sort_vector[TOTAL_NUM*32-33:TOTAL_NUM*32-64];
	else if(!sort_cnt[0])
		sort_vector[TOTAL_NUM*32+31:TOTAL_NUM*32] <= sort_vector[TOTAL_NUM*32-1:TOTAL_NUM*32-32];

genvar i;
generate
for (i = 1; i < TOTAL_NUM/2; i = i + 1) begin:k_sort
always@(posedge clk or negedge rst_n)
	if(!rst_n)
        sort_vector[i*64+31:i*64] <= 32'b0;
	else if(sort_start)
        sort_vector[i*64+31:i*64] <= input_data[i*64+31:i*64];
	else if((sort_vector[i*64+63:i*64+32] > sort_vector[i*64+31:i*64]) & sort_cnt[0])
	    sort_vector[i*64+31:i*64] <= sort_vector[i*64+63:i*64+32];
	else if((sort_vector[i*64-1:i*64-32] < sort_vector[i*64-33:i*64-64] & !sort_cnt[0])
		sort_vector[i*64+31:i*64] <= sort_vector[i*64-33:i*64-64];
	else if(!sort_cnt[0])
		sort_vector[i*64+31:i*64] <= sort_vector[i*64-1:i*64-32];

always@(posedge clk or negedge rst_n)
	if(!rst_n)
        sort_vector[i*64-1:i*64-32] <= 32'b0;
	else if(sort_start)
        sort_vector[i*64-1:i*64-32] <= input_data[i*64-1:i*64-32];
	else if((sort_vector[i*64-1:i*64-32] > sort_vector[i*64-33:i*64-64]) & !sort_cnt[0])
	    sort_vector[i*64-1:i*64-32] <= sort_vector[i*64-33:i*64-64];
	else if((sort_vector[i*64+63:i*64+32] < sort_vector[i*64+31:i*64] & sort_cnt[0])
		sort_vector[i*64-1:i*64-32] <= sort_vector[i*64+63:i*64+32];
	else if(sort_cnt[0])
		sort_vector[i*64-1:i*64-32] <= sort_vector[i*64+31:i*64];
end
endgenerate

endmodule
