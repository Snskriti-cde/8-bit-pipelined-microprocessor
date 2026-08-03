# =============================================================================
#  exc_clean.asm -- control experiment: NO fault. Proves the exception logic
#  is inert on a normal program (MEM[0xBB] IS written, CAUSE stays 0).
# =============================================================================
main:
        ADDI $t0, $zero, 10      # 0
        ADDI $t1, $zero, 20      # 1
        ADD  $t2, $t0, $t1       # 2: z = 30, no overflow
        SW   $t2, 0xBB($zero)    # 3: memory[0xBB] = 30
        HLT                      # 4
