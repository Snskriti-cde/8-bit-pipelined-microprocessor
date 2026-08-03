# =============================================================================
#  exc_illegal.asm -- Bonus Task 2, case 2 : ILLEGAL INSTRUCTION
#
#      uint8_t x = 10, y = 20;
#      __asm__(".byte 0xFF");      // FAULT: invalid opcode
#      uint8_t z = x + y;          // must NEVER execute
#      memory[0xBB] = z;           // must NEVER execute
#
#      // handler at the vector
#      if (CAUSE == ILLEGAL_INST) { memory[0xFF] = 0xEE; while(1); }
#
#  Why 0xF8000000 and not 0xFFFFFFFF: in this ISA the top 6 bits are the
#  opcode, and 0xFF... would decode as opcode 0x3F = HLT, i.e. a perfectly
#  legal instruction. 0xF8000000 is opcode 0x3E, which no instruction uses,
#  so control_unit's `default:` arm raises `illegal`.
# =============================================================================

main:
        ADDI $t0, $zero, 10      # 0: x = 10
        ADDI $t1, $zero, 20      # 1: y = 20

        .word 0xF8000000         # 2: <<< FAULT: undefined opcode 0x3E

        ADD  $t2, $t0, $t1       # 3: z = x + y      -- must never retire
        SW   $t2, 0xBB($zero)    # 4: memory[0xBB]=z -- must never happen
        ADDI $t3, $zero, 0x99    # 5: marker, must never execute
        HLT                      # 6:

# -----------------------------------------------------------------------------
#  Exception vector -- hardwired at address 0x20 in exception_unit.v
# -----------------------------------------------------------------------------
        .org 0x20

vector:
        MFCAUSE $s1              # 32: $s1 = CAUSE
        MFEPC   $s2              # 33: $s2 = EPC (address of the faulty instr)

        ADDI $s3, $zero, 2       # 34: CAUSE_ILLEGAL = 0x02
        BEQ  $s1, $s3, illegal   # 35: if (CAUSE == ILLEGAL_INST)

        ADDI $s4, $zero, 0xDD    # 36: unknown cause -> write 'DD' instead
        SW   $s4, 0xFE($zero)    # 37:
        HLT                      # 38:

illegal:
        ADDI $s5, $zero, 0xEE    # 39: 'EE' = error code
        SW   $s5, 0xFF($zero)    # 40: memory[0xFF] = 0xEE
        HLT                      # 41: while(1) -- safe stop
                                 #     (a self-branch `J .` behaves the same;
                                 #      HLT lets the testbench terminate)
