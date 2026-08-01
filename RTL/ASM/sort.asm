
; --- 1. INITIALIZATION ---
ADDI s0, zero, 0       ; s0 = Base address of array (Memory Address 0)
ADDI s1, zero, 5       ; s1 = Array length (n = 5)
ADDI t2, s1, -1        ; t2 = Outer loop limit (n - 1)
ADDI t0, zero, 0       ; t0 = Outer loop counter (i = 0)

; --- 2. OUTER LOOP ---
OUTER_LOOP:
BEQ t0, t2, END        ; If i == (n - 1), the array is fully sorted!
ADDI t1, zero, 0       ; t1 = Inner loop counter (j = 0)

; Calculate inner loop limit: (n - 1) - i
SUB t3, t2, t0         ; t3 = Inner limit

; --- 3. INNER LOOP ---
INNER_LOOP:
BEQ t1, t3, NEXT_I     ; If j == inner limit, exit inner loop

; Calculate exact memory address for arr[j]
ADD t4, s0, t1         ; t4 = base_address + j

; Fetch the two adjacent array elements
LW t5, 0(t4)           ; Load arr[j] into t5
LW t6, 1(t4)           ; Load arr[j+1] into t6 (offset by 1 byte)

; --- 4. COMPARE & SWAP ---
; We want to swap if arr[j] > arr[j+1]
; Since we only have SLT (Set Less Than), we flip it:
; Is arr[j+1] < arr[j]? 
SLT t7, t6, t5         ; t7 = 1 if (arr[j+1] < arr[j]), else 0
BEQ t7, zero, NEXT_J   ; If t7 is 0, they are in order. Skip the swap.

; Execute the Swap using the same memory pointer
SW t6, 0(t4)           ; Store the smaller value at arr[j]
SW t5, 1(t4)           ; Store the larger value at arr[j+1]

; --- 5. ITERATE INNER LOOP ---
NEXT_J:
ADDI t1, t1, 1         ; j = j + 1
J INNER_LOOP           ; Jump back to top of Inner Loop

; --- 6. ITERATE OUTER LOOP ---
NEXT_I:
ADDI t0, t0, 1         ; i = i + 1
J OUTER_LOOP           ; Jump back to top of Outer Loop

; --- 7. FINISH ---
END:
HLT                    ; Halt the processor