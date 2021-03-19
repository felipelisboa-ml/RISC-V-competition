// True Dual Port (TDP) in read first (RF) mode

module bram_tdp_rf #(
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned NUM_WORDS  = 32
) (
    input  logic clkA_i,
    input  logic clkB_i,
    input  logic enA_i,
    input  logic enB_i,
    input  logic weA_i,
    input  logic weB_i,
    input  logic [$clog2(DATA_WIDTH)-1:0] addrA_i,
    input  logic [$clog2(DATA_WIDTH)-1:0] addrB_i,
    input  logic [DATA_WIDTH-1:0] dataA_i,
    input  logic [DATA_WIDTH-1:0] dataB_i,
    output logic [DATA_WIDTH-1:0] dataA_o,
    output logic [DATA_WIDTH-1:0] dataB_o
);

    logic [DATA_WIDTH-1:0] ram [NUM_WORDS-1:0];

    always_ff @(posedge clkA_i) begin
        if(enA_i) begin
            if(weA_i)
                ram[addrA_i] <= dataA_i;
            dataA_o <= ram[addrA_i];
        end
    end

    always_ff @(posedge clkB_i) begin
        if(enB_i) begin
            if(weB_i)
                ram[addrB_i] <= dataB_i;
            dataB_o <= ram[addrB_i];
        end
    end

`ifndef SYNTHESIS
    // Initialize ram to remove warnings on simulation
    initial
    begin
        for(int i = 0; i < DATA_WIDTH; i++) begin
            for(int j = 0; j < NUM_WORDS; j++) begin
                ram[i][j] = $random();
            end
        end
    end
`endif

endmodule