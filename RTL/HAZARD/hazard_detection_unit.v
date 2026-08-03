`timescale 1ns / 1ps

module hazard_detection_unit(
  // Id_Ex
  input             id_ex_mem_read,
  input wire [4:0]  id_ex_rt,
  // If/Id
  input wire [4:0]  if_id_rs, if_id_rt,

  // control-flow / fault events
  input             ex_redirect,     // taken branch / jump / JR resolved in EX
  input             exception,      

  output            pc_write,        // 0 = hold PC
  output            if_id_write,     // 0 = hold IF/ID
  output            bubble,          // 1 = inject NOP into ID/EX
  output            stall,         

  // pipeline-register flush strobes
  output            flush_if_id,
  output            flush_id_ex,
  output            flush_ex_mem,
  output            flush_mem_wb
);

  wire load_active = id_ex_mem_read & (id_ex_rt != 5'b0);
  wire same_as_rs  = (id_ex_rt == if_id_rs);
  wire same_as_rt  = (id_ex_rt == if_id_rt);

  assign stall       = load_active & (same_as_rs | same_as_rt) & ~exception;

  assign pc_write    = ~stall;
  assign if_id_write = ~stall;
  assign bubble      = stall;

  // ---- flush matrix -------------------------------------------------------
  assign flush_if_id  = ex_redirect | exception;
  assign flush_id_ex  = ex_redirect | exception | bubble;
  assign flush_ex_mem = exception;
  assign flush_mem_wb = exception;

endmodule
