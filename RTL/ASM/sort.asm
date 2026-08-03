

        LI   $gp, 64            # array base address in data memory
        LI   $t0, 5
        SW   $t0, 0($gp)        # arr[0] = 5
        LI   $t0, 8
        SW   $t0, 1($gp)        # arr[1] = 8
        LI   $t0, 2
        SW   $t0, 2($gp)        # arr[2] = 2
        LI   $s2, 3             # n = 3
        LI   $s0, 0             # i = 0

OUTER:  SLT  $t0, $s0, $s2      # t0 = (i < n)
        BEQ  $t0, $zero, DONE   # if !(i<n) -> done
        ADD  $s1, $s0, $zero    # j = i

INNER:  SLT  $t0, $s1, $s2      # t0 = (j < n)
        BEQ  $t0, $zero, NEXTI  # if !(j<n) -> next i
        ADD  $t3, $gp, $s0      # &arr[i]
        LW   $t4, 0($t3)        # arr[i]
        ADD  $t6, $gp, $s1      # &arr[j]
        LW   $t5, 0($t6)        # arr[j]
        SLT  $t0, $t5, $t4      # t0 = (arr[j] < arr[i])  == (arr[i] > arr[j])
        BEQ  $t0, $zero, SKIP   # if not greater -> no swap
        SW   $t4, 0($t6)        # arr[j] = arr[i]
        SW   $t5, 0($t3)        # arr[i] = old arr[j]  (temp)

SKIP:   ADDI $s1, $s1, 1        # j++
        J    INNER
NEXTI:  ADDI $s0, $s0, 1        # i++
        J    OUTER
DONE:   HLT
