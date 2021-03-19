module ariane_regfile_bram #(
  parameter int unsigned DATA_WIDTH     = 32,
  parameter int unsigned NUM_WORDS      = 32,
  parameter bit          ZERO_REG_ZERO  = 0
)(
  // clock and reset
  input  logic                              clk_i,
  input  logic                              rst_ni,
  // disable clock gates for testing
  input  logic                              test_en_i,
  // read port
  input  logic [1:0][$clog2(NUM_WORDS)-1:0]  raddr_i,
  output logic [1:0][DATA_WIDTH-1:0]        rdata_o,
  // write port
  input  logic [1:0][$clog2(NUM_WORDS)-1:0]  waddr_i,
  input  logic [1:0][DATA_WIDTH-1:0]         wdata_i,
  input  logic [1:0]                         we_i
);

    localparam int unsigned NR_RW_PORTS  = 2;
    localparam int unsigned ADDR_WIDTH = $clog2(NUM_WORDS);

    // vector pointing the location of the data (memery block 0 or 1)
    logic [NUM_WORDS-1:0] data_location ;
    logic mem_we [NR_RW_PORTS-1:0][1:0];
    logic [ADDR_WIDTH-1:0] mem_addr [NR_RW_PORTS-1:0][1:0] ;
    logic [DATA_WIDTH-1:0] mem_data_i [NR_RW_PORTS-1:0][1:0];
    logic [DATA_WIDTH-1:0] mem_data_o [NR_RW_PORTS-1:0][1:0];

    for(genvar i = 0; i < NR_RW_PORTS; i++) begin : inst_regfile_mem
        bram_tdp_rf #(
            .DATA_WIDTH(DATA_WIDTH),
            .NUM_WORDS(NUM_WORDS)
        ) bram_reg (
            .clkA_i(clk_i),
            .clkB_i(clk_i),
            .enA_i(1'b1),
            .enB_i(1'b1),
            .weA_i(mem_we[i][0]),
            .weB_i(mem_we[i][1]),
            .addrA_i(mem_addr[i][0]),
            .addrB_i(mem_addr[i][1]),
            .dataA_i(mem_data_i[i][0]),
            .dataB_i(mem_data_i[i][1]),
            .dataA_o(mem_data_o[i][0]),
            .dataB_o(mem_data_o[i][1])
        );
    end

    logic [NR_RW_PORTS-1:0] rd_data_loc, rd_data_loc_q, wr_data_loc;
    logic [NR_RW_PORTS-1:0] rd_data_port, wr_data_port;
    logic [NR_RW_PORTS-1:0] rd_data_port_q;
    logic [NR_RW_PORTS-1:0] rzero_q;

    for(genvar i = 0; i < NR_RW_PORTS; i++) begin : assign_data_loc
        assign rd_data_loc[i] = data_location[raddr_i[i]];
    end

    always_comb begin
        for(integer i = 0; i < NR_RW_PORTS; i++) begin 
            mem_we[rd_data_loc[i]][rd_data_port[i]]      = 1'b0;
            mem_addr[rd_data_loc[i]][rd_data_port[i]]    = raddr_i[i];

            rdata_o[i] =
                (ZERO_REG_ZERO && rzero_q[i] ) ? '0 : mem_data_o[rd_data_loc_q[i]][rd_data_port_q[i]];

            mem_we    [wr_data_loc[i]][wr_data_port[i]] = we_i[i];
            mem_addr  [wr_data_loc[i]][wr_data_port[i]] = waddr_i[i];
            mem_data_i[wr_data_loc[i]][wr_data_port[i]] = wdata_i[i];
        end
    end


    always_comb begin
        // both read addresses are mapped to the memory block 0
        if((rd_data_loc[0] == 1'b0 &&  rd_data_loc[1] == 1'b0)) begin
            rd_data_port = 2'b10;

            wr_data_loc  = 2'b11;
            wr_data_port = 2'b10;
        end else
        // both read addresses are mapped to the memory block 1
        if(rd_data_loc[0] == 1'b1 && rd_data_loc[1] == 1'b1) begin
            rd_data_port = 2'b10;

            wr_data_loc  = 2'b00;
            wr_data_port = 2'b10;
        end else
        // one read address is mapped to memory block 1 and the other to the mem block 0
        begin
            rd_data_port = 2'b00;

            wr_data_loc[0]  = 1'b0;
            wr_data_loc[1]  = 1'b1;
            wr_data_port = 2'b11;
        end
    end    

    always_ff @(posedge clk_i or negedge rst_ni)
    begin
        if(!rst_ni) begin
            data_location <= '0;
            rd_data_port_q <= '0;
            rd_data_loc_q  <= '0;
            rzero_q <= '0;
        end else begin
            rd_data_port_q <= rd_data_port;
            rd_data_loc_q  <= rd_data_loc;

            for(int i = 0; i < NR_RW_PORTS; i++) begin
                rzero_q[i] <= ~(|raddr_i[i]);

                if(we_i[i])
                    data_location[waddr_i[i]] <= wr_data_loc[i];
            end
        end
    end

endmodule