
module control_unit (
    input      [5:0] opcode,    
    input      [5:0] funct,     

    // ---- MUX #1 : Write-register address selector -----------------------------------
    output reg [1:0] reg_dst,      // REGDST_RT=00 | REGDST_RD=01 | REGDST_RA=10

    //----- MUX #2 : ALU B-port selector ------------------------------------------------
    output reg       alu_src,

    //----- MUX #3 : Write-back data selector-------------------------------------------
    output reg [1:0] mem_to_reg,   // WB_ALU=00 | WB_MEM=01 | WB_PC1=10

    //----- MUX #4 : Next-PC control signals (decoded in top-level) ---------------------
    output reg       branch,      
    output reg       jump,         
    output reg       jal,     
    output reg       jump_reg,   

    //  Register-file write enable ---------------------------------------------------- 
    output reg       reg_write,    

    // Data-memory port enables --------------------------------------------------- 
    output reg       mem_read,     // 1 = perform a data-memory READ  (LW only)
    output reg       mem_write,    // 1 = perform a data-memory WRITE (SW only)


    output reg [2:0] alu_op,
    output reg       halt       
);

   //====================================================================================
   // opcodes
   //===================================================================================
    localparam OPC_R=6'h00,                                              // R type
               ADDI=6'h08, SLTI=6'h0A, ANDI=6'h0C, ORI=6'h0D,XORI=6'h0E, //I type
               BEQ=6'h04, BNE=6'h05,                                     // B type
               LW=6'h23, SW=6'h2B,                                       // mem 
               J=6'h02, JAL=6'h03,                                       // J type                                   
               HLT=6'h3F;

    localparam F_JR=6'h08;   //  funct code for JR (only R-type funct decoded)

    // ===============================================================================
    // alu_op classes 
    // ==================================================================================

    localparam AOP_ADD=3'b000,
               AOP_SUB=3'b001,
               AOP_AND=3'b010,
               AOP_OR=3'b011,
               AOP_XOR=3'b100,
               AOP_SLT=3'b101,
               AOP_RTYPE=3'b111;
    
    // ===============================================================================
    // MUX select constants 
    // ==============================================================================

    //  MUX #1  reg_dst 
    localparam REGDST_RT = 2'b00,  // destination = rt = instr[20:16]  (I-type)
           REGDST_RD = 2'b01,      // destination = rd = instr[15:11]  (R-type)
           REGDST_RA = 2'b10;      // destination = ra = reg 31       (JAL link)

    //  MUX #2  alu_src 
    localparam ALUSRC_REG = 1'b0,    
    ALUSRC_IMM = 1'b1;     //imm [7:0] only

    //  MUX #3  mem_to_reg 
    localparam WB_ALU  = 2'b00,   
           WB_MEM  = 2'b01,       
           WB_PC1  = 2'b10;     


    // =================================================================================
    // decode 
    // =================================================================================

    always @(*) begin
        // ---------- safe defaults -------------
        reg_dst    = REGDST_RT;
        reg_write  = 1'b0;
        alu_src    = ALUSRC_REG;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = WB_ALU;
        branch     = 1'b0;
        jump       = 1'b0;
        jal        = 1'b0;
        jump_reg   = 1'b0;
        halt       = 1'b0;
        alu_op     = AOP_ADD;


        case (opcode)
 
           // R type ==========================================================
           OPC_R: begin
                if (funct == F_JR) begin
                    jump_reg  = 1'b1;          // PC <- rs; writes no register
                end else begin
                    reg_dst   = REGDST_RD;         // write rd
                    reg_write = 1'b1;
                    alu_op    = AOP_RTYPE;      // alu_control refines by funct
                end
            end
           // I type ==========================================================

            ADDI: begin reg_write = 1'b1; alu_src = ALUSRC_IMM; alu_op = AOP_ADD;  end
            SLTI: begin reg_write = 1'b1; alu_src = ALUSRC_IMM; alu_op = AOP_SLT;  end
            ANDI: begin reg_write = 1'b1; alu_src = ALUSRC_IMM; alu_op = AOP_AND;  end
            ORI : begin reg_write = 1'b1; alu_src = ALUSRC_IMM; alu_op = AOP_OR;   end
            XORI: begin reg_write = 1'b1; alu_src = ALUSRC_IMM; alu_op = AOP_XOR;  end


            LW  : begin 
                  reg_write = 1'b1; 
                  alu_src = ALUSRC_IMM; 
                  mem_read = 1'b1;
                  mem_to_reg = WB_MEM; 
                  alu_op = AOP_ADD;  
            end


            SW  : begin 
                  alu_src = ALUSRC_IMM; 
                  mem_write = 1'b1; 
                  alu_op = AOP_ADD; 
            end

          // B type ============================================================

            BEQ : begin branch=1'b1; alu_op=AOP_SUB;  end
            BNE : begin branch=1'b1; alu_op=AOP_SUB;  end

          // J type ============================================================

            J   : begin jump = 1'b1; end

            JAL : begin jump=1'b1;
                  jal = 1'b1;
                  reg_write = 1'b1;
                  reg_dst = REGDST_RA;
                  mem_to_reg = WB_PC1;
           end 

 
            HLT : begin
                  halt = 1'b1;
            end


            default: ;   // nothing to do

        endcase
    end

endmodule
