// jtag_la: JTAG-readable RING-BUFFER capture with a hardware trigger and POST-trigger delay.
// On a rising edge of `arm` (JTAG/ISSP) it ARMS and records `sample` every clock into a ring
// buffer (wptr wraps). On `trig` it keeps recording POST more cycles, then FREEZES. The frozen
// buffer thus holds the last DEPTH cycles = (DEPTH-POST) BEFORE the trigger + POST after — so
// the pre-trigger context (what closed the SDRAM row before a bad HIT) is captured.
// Read out raw via rdaddr/rddata; reorder in software starting at the final wptr (= oldest).
module jtag_la #(
    parameter DW   = 48,
    parameter AW   = 9,
    parameter POST = 32          // cycles captured after the trigger before freezing
) (
    input              clk,
    input  [DW-1:0]    sample,
    input              trig,
    input              arm,
    input  [AW-1:0]    rdaddr,
    output reg [DW-1:0] rddata = 0,
    output reg          frozen = 0,
    output reg [AW-1:0] wptr_o = 0
);
    localparam DEPTH = (1 << AW);
    (* ramstyle = "M10K" *) reg [DW-1:0] mem [0:DEPTH-1];
    reg [AW-1:0] wptr      = 0;
    reg          armed     = 1'b0;
    reg          triggered = 1'b0;
    reg [AW-1:0] post      = 0;
    reg          arm_d     = 1'b0;
    reg          done      = 1'b0;

    always @(posedge clk) begin
        arm_d  <= arm;
        rddata <= mem[rdaddr];
        frozen <= done;
        wptr_o <= wptr;
        if (arm & ~arm_d) begin
            armed <= 1'b1; done <= 1'b0; triggered <= 1'b0; post <= 0; wptr <= 0;
        end else if (armed) begin
            mem[wptr] <= sample;
            wptr <= wptr + 1'b1;            // wraps modulo DEPTH
            if (trig & ~triggered) triggered <= 1'b1;
            if (triggered) begin
                if (post == POST-1) begin armed <= 1'b0; done <= 1'b1; end
                else post <= post + 1'b1;
            end
        end
    end
endmodule
