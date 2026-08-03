# =============================================================================
#  exc_trap.asm -- Bonus Task 2, case 3 : TRAP (software-raised exception)
# =============================================================================
main:
        ADDI $t0, $zero, 10      # 0
        ADDI $t1, $zero, 20      # 1
        TRAP                     # 2: <<< deliberate software fault
        SW   $t1, 0xBB($zero)    # 3: must never happen
        HLT                      # 4:

        .org 0x20
vector:
        MFCAUSE $s1              # 32
        MFEPC   $s2              # 33
        ADDI $s3, $zero, 3       # 34: CAUSE_TRAP = 0x03
        BEQ  $s1, $s3, trapped   # 35
        ADDI $s4, $zero, 0xDD    # 36
        SW   $s4, 0xFE($zero)    # 37
        HLT                      # 38
trapped:
        ADDI $s5, $zero, 0xEE    # 39
        SW   $s5, 0xFF($zero)    # 40
        HLT                      # 41
