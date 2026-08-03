
module control_unit (
    input      [5:0] opcode,   
    input      [5:0] funct,    

    // ---- MUX #1 : Write-register address selector ---------------------------
    output reg [1:0] reg_dst,      // REGDST_RT=00 | REGDST_RD=01 | REGDST_RA=10

    //----- MUX #2 : ALU B-port selector ---------------------------------------
    output reg       alu_src,     

    //----- MUX #3 : Write-back data selector ----------------------------------
    output reg [1:0] mem_to_reg,   // WB_ALU=00 | WB_MEM=01 | WB_PC1=10

    //----- MUX #4 : Next-PC control signals -----------------------------------
    output reg       branch,
    output reg       jump,
    output reg       jal,
    output reg       jump_reg,

    //  Register-file write enable ---------------------------------------------
    output reg       reg_write,

    // Data-memory port enables ------------------------------------------------
    output reg       mem_read,
    output reg       mem_write,

    output reg [2:0] alu_op,
    output reg       halt,

    // ---- exception-related decode (Bonus Task 2) ----------------------------
    output reg       illegal,      // 1 = undefined opcode / funct
    output reg       trap,         // 1 = TRAP instruction
    output reg       ov_en,        // 1 = trap on signed overflow
    output reg       cp0_read,     // 1 = write a CP0 register into rd
    output reg       cp0_sel       // 0 = CAUSE, 1 = EPC
);

   //====================================================================================
   // opcodes
   //===================================================================================
    localparam OPC_R=6'h00,
               ADDI=6'h08, SLTI=6'h0A, ANDI=6'h0C, ORI=6'h0D, XORI=6'h0E,
               BEQ=6'h04, BNE=6'h05,
               LW=6'h23, SW=6'h2B,
               J=6'h02, JAL=6'h03,
               TRAP=6'h1A,                                   // NEW: software trap
               HLT=6'h3F;

    // ---- R-type funct codes (the complete legal set) ------------------------
    localparam F_ADD=6'h20, F_SUB=6'h22, F_AND=6'h24, F_OR=6'h25, F_XOR=6'h26,
               F_NOR=6'h27, F_SLT=6'h2A, F_SLL=6'h00, F_SRL=6'h02, F_SRA=6'h03,
               F_ROL=6'h10, F_ROR=6'h11, F_JR=6'h08,  F_NOT=6'h21, F_PASA=6'h23,
               F_INC=6'h12, F_DEC=6'h13, F_MUL=6'h18, F_DIV=6'h1A,
               F_MFCAUSE=6'h1E, F_MFEPC=6'h1F;               // NEW: CP0 reads

    // ===============================================================================
    // alu_op classes
    // ==============================================================================
    localparam AOP_ADD=3'b000, AOP_SUB=3'b001, AOP_AND=3'b010, AOP_OR=3'b011,
               AOP_XOR=3'b100, AOP_SLT=3'b101, AOP_RTYPE=3'b111;

    // MUX select constants
    localparam REGDST_RT = 2'b00, REGDST_RD = 2'b01, REGDST_RA = 2'b10;
    localparam ALUSRC_REG = 1'b0, ALUSRC_IMM = 1'b1;
    localparam WB_ALU = 2'b00, WB_MEM = 2'b01, WB_PC1 = 2'b10;

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
        illegal    = 1'b0;
        trap       = 1'b0;
        ov_en      = 1'b0;
        cp0_read   = 1'b0;
        cp0_sel    = 1'b0;

        case (opcode)

           // R type ==========================================================
           OPC_R: begin
                case (funct)
                    F_JR: jump_reg = 1'b1;                  // PC <- rs, no writeback

                    F_MFCAUSE, F_MFEPC: begin               // rd <- CP0[sel]
                        reg_dst   = REGDST_RD;
                        reg_write = 1'b1;
                        cp0_read  = 1'b1;
                        cp0_sel   = (funct == F_MFEPC);
                    end

                    F_ADD, F_SUB, F_INC, F_DEC: begin       // signed -> trappable
                        reg_dst   = REGDST_RD;
                        reg_write = 1'b1;
                        alu_op    = AOP_RTYPE;
                        ov_en     = 1'b1;
                    end

                    F_AND, F_OR, F_XOR, F_NOR, F_SLT, F_SLL, F_SRL, F_SRA,
                    F_ROL, F_ROR, F_NOT, F_PASA, F_MUL, F_DIV: begin
                        reg_dst   = REGDST_RD;
                        reg_write = 1'b1;
                        alu_op    = AOP_RTYPE;
                    end

                    default: illegal = 1'b1;                // undefined funct
                endcase
            end

           // I type ==========================================================
            ADDI: begin reg_write=1'b1; alu_src=ALUSRC_IMM; alu_op=AOP_ADD; ov_en=1'b1; end
            SLTI: begin reg_write=1'b1; alu_src=ALUSRC_IMM; alu_op=AOP_SLT;  end
            ANDI: begin reg_write=1'b1; alu_src=ALUSRC_IMM; alu_op=AOP_AND;  end
            ORI : begin reg_write=1'b1; alu_src=ALUSRC_IMM; alu_op=AOP_OR;   end
            XORI: begin reg_write=1'b1; alu_src=ALUSRC_IMM; alu_op=AOP_XOR;  end

            LW  : begin
                  reg_write  = 1'b1;
                  alu_src    = ALUSRC_IMM;
                  mem_read   = 1'b1;
                  mem_to_reg = WB_MEM;
                  alu_op     = AOP_ADD;
            end

            SW  : begin
                  alu_src   = ALUSRC_IMM;
                  mem_write = 1'b1;
                  alu_op    = AOP_ADD;
            end

          // B type ============================================================
            BEQ : begin branch=1'b1; alu_op=AOP_SUB;  end
            BNE : begin branch=1'b1; alu_op=AOP_SUB;  end

          // J type ============================================================
            J   : begin jump = 1'b1; end

            JAL : begin jump      = 1'b1;
                  jal        = 1'b1;
                  reg_write  = 1'b1;
                  reg_dst    = REGDST_RA;
                  mem_to_reg = WB_PC1;
           end

          // exceptions / system ===============================================
            TRAP: begin trap = 1'b1; end                    // no architectural effect

            HLT : begin halt = 1'b1; end

            default: illegal = 1'b1;                        // undefined opcode
        endcase
    end

endmodule
