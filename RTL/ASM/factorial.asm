# recursive main block =======================================
main:
    ADDI $a0, $zero, 5;
    JAL fact;
    HLT;

# fact block =========================================
fact:
    ADDI $sp, $sp, -2;
    SW $ra, 0($sp);
    SW $a0, 1($sp);

# base case (n == 1, return 1) =============================
    ADDI $t0, $zero, 1;
    BEQ $a0, $t0, base_case;

# recursive case (else return n * fact(n-1)) ===============
    ADDI $a0, $a0, -1;
    JAL fact;
    LW $a0, 1($sp);          
    LW $ra, 0($sp);
    ADDI $sp, $sp, 2;
    MUL $v0, $a0, $v0;
    JR $ra;

# base case label (target for BEQ when n == 1) =================
base_case:
    ADDI $v0, $zero, 1;
    ADDI $sp, $sp, 2;
    JR $ra;