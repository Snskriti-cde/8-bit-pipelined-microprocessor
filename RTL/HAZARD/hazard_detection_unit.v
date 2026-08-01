`timescale 1ns / 1ps
module hazard_detection_unit(
  // Id_Ex
  input id_ex_mem_read ,
  input wire[4:0] id_ex_rt,
  // If/Id
  input wire[4:0] if_id_rs, if_id_rt,
  
  output pc_write, //hold pc(0)
  output if_id_write,//hold IF/ID register(0) 
  output bubble,// for ID/EX(1)
  output stall //control
    );
    
  wire load_active = id_ex_mem_read & (id_ex_rt != 5'b0); // load instruction in excution_mem register
  wire same_as_rs = (id_ex_rt == if_id_rs);
  wire same_as_rt = (id_ex_rt == if_id_rt);
  
  assign  stall = load_active & (same_as_rs | same_as_rt);
  
  assign pc_write = ~stall;
  assign if_id_write = ~stall;
  assign bubble = stall;
  
endmodule
