# =============================================================================
#  exc_overflow.asm -- Bonus Task 2, case 1 : ARITHMETIC OVERFLOW
#      0x7F + 1 = 0x80 -> signed overflow (V=1) on a trappable ADD
# =============================================================================
main:
        ADDI $t0, $zero, 0x7F    # 0: t0 = +127 (largest signed 8-bit)
        ADDI $t1, $zero, 1       # 1: t1 = 1
        ADD  $t2, $t0, $t1       # 2: <<< FAULT: +127 + 1 overflows
        SW   $t2, 0xBB($zero)    # 3: must never happen
        HLT                      # 4:

        .org 0x20
vector:
        MFCAUSE $s1              # 32
        MFEPC   $s2              # 33
        ADDI $s3, $zero, 1       # 34: CAUSE_OVERFLOW = 0x01
        BEQ  $s1, $s3, ovf       # 35
        ADDI $s4, $zero, 0xDD    # 36
        SW   $s4, 0xFE($zero)    # 37
        HLT                      # 38
ovf:
        ADDI $s5, $zero, 0xEE    # 39
        SW   $s5, 0xFF($zero)    # 40
        HLT                      # 41
