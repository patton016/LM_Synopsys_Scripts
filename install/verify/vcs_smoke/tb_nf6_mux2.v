//------------------------------------------------------------------------------
// www.fpga.pw
// 2026-10-01
// Simple testbench for nf6_mux2.
// Dumps an FSDB file for waveform viewing in Verdi.
//------------------------------------------------------------------------------
`timescale 1ps / 1ps

module tb_nf6_mux2;
  parameter MUX2_WIDTH = 8;

  reg  [MUX2_WIDTH-1:0] in0;
  reg  [MUX2_WIDTH-1:0] in1;
  reg  [1:0]            sel;
  wire [MUX2_WIDTH-1:0] out;

  nf6_mux2 #(.MUX2_WIDTH(MUX2_WIDTH)) uut (
    .in_0  (in0),
    .in_1  (in1),
    .out   (out),
    .select(sel)
  );

  initial begin
    $fsdbDumpfile("nf6_mux2.fsdb");
    $fsdbDumpvars(0, tb_nf6_mux2);

    $display("[TB] Starting nf6_mux2 simple testbench");

    in0 = 8'hAA; in1 = 8'h55; sel = 2'b00; #10;
    sel = 2'b01; #10;
    sel = 2'b10; #10;
    sel = 2'b11; #10;
    in0 = 8'hFF; in1 = 8'h00; sel = 2'b01; #10;
    in0 = 8'h0F; in1 = 8'hF0; sel = 2'b10; #10;

    $display("[TB] Simulation finished");
    $finish;
  end
endmodule
