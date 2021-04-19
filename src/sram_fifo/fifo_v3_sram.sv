// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Author: Florian Zaruba <zarubaf@iis.ee.ethz.ch>
module fifo_v3 #(
    parameter bit          FALL_THROUGH = 1'b0, // fifo is in fall-through mode
    parameter int unsigned DATA_WIDTH   = 32,   // default data width if the fifo is of type logic
    parameter int unsigned DEPTH        = 8,    // depth can be arbitrary from 0 to 2**32
    parameter type dtype                = logic [DATA_WIDTH-1:0],
    // DO NOT OVERWRITE THIS PARAMETER
    parameter int unsigned ADDR_DEPTH   = (DEPTH > 1) ? $clog2(DEPTH) : 1
)(
    input  logic  clk_i,            // Clock
    input  logic  rst_ni,           // Asynchronous reset active low
    input  logic  flush_i,          // flush the queue
    input  logic  testmode_i,       // test_mode to bypass clock gating
    // status flags
    output logic  full_o,           // queue is full
    output logic  empty_o,          // queue is empty
    output logic  [ADDR_DEPTH-1:0] usage_o,  // fill pointer
    // as long as the queue is not full we can push new data
    input  dtype  data_i,           // data to push into the queue
    input  logic  push_i,           // data is valid and can be pushed to the queue
    // as long as the queue is not empty we can pop new elements
    output dtype  data_o,           // output data
    input  logic  pop_i             // pop head from queue
);

    //not used
    logic [NUM_FIFOS-1:0] almost_empty_tmp;
    logic [NUM_FIFOS-1:0] almost_full_tmp;
    logic [NUM_FIFOS-1:0] rd_error_tmp;
    logic [NUM_FIFOS-1:0] wr_error_tmp;

    localparam int unsigned DATA_SPLIT = 32;
    localparam int unsigned NUM_FIFOS = (DATA_WIDTH%DATA_SPLIT) + 1 ;

    //cut the data into pieces of size DATA_SPLIT
    logic [NUM_FIFOS-1:0][DATA_SPLIT-1:0] data_i_tmp;
    logic [NUM_FIFOS-1:0][DATA_SPLIT-1:0] data_o_tmp;

    logic [NUM_FIFOS-1:0] empty_tmp;
    logic [NUM_FIFOS-1:0] full_tmp;

    logic [NUM_FIFOS-1:0][ADDR_DEPTH-1:0] rdcount_tmp;
    logic [NUM_FIFOS-1:0][ADDR_DEPTH-1:0] wrcount_tmp;
    
    logic flush_q;
    always_ff @( clk_i ) begin : flush_register
        flush_q <= flush_i;
    end

    for (genvar k=0; k < NUM_FIFOS; k++) begin
        assign data_i_tmp[k] = data_i[(k+1)*DATA_SPLIT-1:(k)*DATA_SPLIT];
    end

    //do I still need the logic for holding reset & enable ?
    
    for(genvar k=0; k < NUM_FIFOS; k++) begin : gen_fifos
        FIFO_SYNC_MACRO #(
            .DEVICE("7SERIES"), // Target Device: "7SERIES"
            .ALMOST_EMPTY_OFFSET(9'h080), // Sets the almost empty threshold
            .ALMOST_FULL_OFFSET(9'h080), // Sets almost full threshold
            .DATA_WIDTH(DATA_SPLIT), // Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
            .DO_REG(0), // Optional output register (0 or 1)
            .FIFO_SIZE ("18Kb") // Target BRAM: "18Kb" or "36Kb"
        ) FIFO_SYNC_MACRO_inst (
            .ALMOSTEMPTY(almost_empty_tmp[k]), // 1-bit output almost empty
            .ALMOSTFULL(almost_full_tmp[k]), // 1-bit output almost full
            .DO(data_o_tmp[k]), // Output data, width defined by DATA_WIDTH parameter
            .EMPTY(empty_tmp[k]), // 1-bit output empty
            .FULL(full_tmp[k]), // 1-bit output full
            .RDCOUNT(rdcount_tmp[k]), // Output read count, width determined by FIfor depth
            .RDERR(rd_error_tmp[k]), // 1-bit output read error
            .WRCOUNT(wrcount_tmp[k]), // Output write count, width determined by FIfor depth
            .WRERR(wr_error_tmp[k]), // 1-bit output write error
            .CLK(clk_i), // 1-bit input clock
            .DI(data_i_tmp[k]), // Input data, width defined by DATA_WIDTH parameter
            .RDEN(pop_i), // 1-bit input read enable
            .RST(rst_ni || flush_q), // 1-bit input reset
            .WREN(push_i) // 1-bit input write enable
    );
    end

    //workaround because there will not be more than 2 fifos
    always_comb begin : final
        if(NUM_FIFOS == 2)) begin
            usage_o = {rdcount_tmp[0],rdcount_tmp[1]} - {wrcount_tmp[0],wrcount_tmp[1]};
            full_o = full_tmp[0] && full_tmp[1];
            empty_o = empty_tmp[0] && empty_tmp[1];
            data_o = {data_o_tmp[0],data_o_tmp[1]};
        end else begin
            usage_o = rdcount_tmp[0] - wrcount_tmp[0];
            full_o = full_tmp[0];
            empty_o = empty_tmp[0];
            data_o = data_o_tmp[0];
        end     
    end

endmodule // fifo_v3
