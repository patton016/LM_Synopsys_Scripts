//------------------------------------------------------------------------------
// www.fpga.pw
//
// nf6_mux2.v
//
// 功能：参数化位宽 2 选 1 多路选择器。
//   select == 2'b01 时输出 in_0，否则输出 in_1。
//
//------------------------------------------------------------------------------
`timescale 1ps / 1ps

module nf6_mux2 #(
    parameter MUX2_WIDTH = 8
) (
    input  [MUX2_WIDTH-1:0] in_0,
    input  [MUX2_WIDTH-1:0] in_1,
    output [MUX2_WIDTH-1:0] out,
    input  [1:0]            select
);

    assign out = (select == 2'b01) ? in_0 : in_1;

endmodule

