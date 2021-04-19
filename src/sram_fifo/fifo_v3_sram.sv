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

    // 512 entries by 36 bits (18Kb FIFO)
    logic almost_empty;
    logic almost_full;
    logic read_error;
    logic write_error;

    // We need 9 bits for pointers, since the depth is 512
    logic [8:0] rd_count;
    logic [8:0] wr_count;

    logic wReset = 1'b1;
    logic wResetQ;

    SRL16E #(
        .INIT(16'hFF00)
    ) mReset(
        .CLK  (clk_i),
        .CE   (1'b1),
        .A0   (1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1),
        .D    (rst_ni),
        .Q    (wResetQ)
    );
    
    always_ff @(posedge clk_i) begin : hold_reset
          wReset <= wResetQ || flush_i;
    end

    logic wEnable = 0;
    logic wEnableQ;
    SRL16E #(
        .INIT(16'hFFF0)
    ) mEnable(
      .CLK ( clk_i ),
      .CE  ( 1'b1 ),
      .A0  ( 1'b1 ), .A1( 1'b1 ), .A2( 1'b1 ), .A3( 1'b1 ),
      .D   ( 1'b0 ),
      .Q   ( wEnableQ ) );
    always @( posedge clk_i ) begin : hold_enable
        wEnable    <= ~ wEnableQ;
    end

    FIFO_SYNC_MACRO #(
        .DEVICE("7SERIES"), // Target Device: "7SERIES"
        .ALMOST_EMPTY_OFFSET(9'h080), // Sets the almost empty threshold
        .ALMOST_FULL_OFFSET(9'h080), // Sets almost full threshold
        .DATA_WIDTH(36), // Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
        .DO_REG(0), // Optional output register (0 or 1)
        .FIFO_SIZE ("18Kb") // Target BRAM: "18Kb" or "36Kb"
    ) FIFO_SYNC_MACRO_inst (
        .ALMOSTEMPTY(almost_empty), // 1-bit output almost empty
        .ALMOSTFULL(almost_full), // 1-bit output almost full
        .DO(data_o), // Output data, width defined by DATA_WIDTH parameter
        .EMPTY(empty_o), // 1-bit output empty
        .FULL(full_o), // 1-bit output full
        .RDCOUNT(rd_count), // Output read count, width determined by FIfor depth
        .RDERR(read_error), // 1-bit output read error
        .WRCOUNT(wr_count), // Output write count, width determined by FIfor depth
        .WRERR(write_error), // 1-bit output write error
        .CLK(clk_i), // 1-bit input clock
        .DI(data_i), // Input data, width defined by DATA_WIDTH parameter
        .RDEN(pop_i&&wEnable), // 1-bit input read enable
        .RST(wReset), // 1-bit input reset
        .WREN(push_i&&wEnable) // 1-bit input write enable
    );

    assign usage_o = rd_count[8:0] - wr_count[8:0];

endmodule // fifo_v3
