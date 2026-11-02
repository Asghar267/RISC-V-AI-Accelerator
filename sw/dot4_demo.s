# RISC-V Assembly Program: Dual-Mode (INT8 + INT16) Verification + UART Terminal Output
# Continuous Loop execution with UART Baud Rate timing delay

.equ DOT4_BASE,   0x80000000
.equ DOT4_CTRL,   0x80000000
.equ DOT4_STATUS, 0x80000004
.equ DOT4_OPA,    0x80000008
.equ DOT4_OPB,    0x8000000c
.equ DOT4_RESULT, 0x80000010
.equ HOST_OUT,    0x90000000

.text
main:
    # Initialize MMIO Base Register & Data Pointers
    lui  s0, 0x80000         # Base Address 0x80000000
    addi s1, x0, matA_data   # Pointer to Matrix A
    addi s2, x0, matB_data   # Pointer to Matrix B
    addi s3, x0, expectedC_data # Pointer to Expected C
    addi t3, x0, 1           # CTRL Trigger INT8 Mode (Mode=0, Start=1 -> CTRL=1)

    # ====================================================
    # PART 1: INT8 MODE (4x4 Matrix Multiplication)
    # ====================================================
    
    # --- ROW 0 ---
    lw   t1, 0(s1)           # Load A[0]
    sw   t1, 8(s0)           # OPA = A[0]

    lw   t2, 0(s2)           # B[0]
    sw   t2, 12(s0)          # OPB = B[0]
    sw   t3, 0(s0)           # Trigger DOT4 (INT8)
    lw   t5, 16(s0)          # Read RESULT
    lw   t6, 0(s3)           # Expected C[0][0]
    bne  t5, t6, test_fail

    lw   t2, 4(s2)           # B[1]
    sw   t2, 12(s0)
    sw   t3, 0(s0)
    lw   t5, 16(s0)
    lw   t6, 4(s3)
    bne  t5, t6, test_fail

    lw   t2, 8(s2)           # B[2]
    sw   t2, 12(s0)
    sw   t3, 0(s0)
    lw   t5, 16(s0)
    lw   t6, 8(s3)
    bne  t5, t6, test_fail

    lw   t2, 12(s2)          # B[3]
    sw   t2, 12(s0)
    sw   t3, 0(s0)
    lw   t5, 16(s0)
    lw   t6, 12(s3)
    bne  t5, t6, test_fail

    # --- ROW 1 ---
    lw   t1, 4(s1)           # Load A[1]
    sw   t1, 8(s0)

    lw   t2, 0(s2)
    sw   t2, 12(s0)
    sw   t3, 0(s0)
    lw   t5, 16(s0)
    lw   t6, 16(s3)
    bne  t5, t6, test_fail

    lw   t2, 4(s2)
    sw   t2, 12(s0)
    sw   t3, 0(s0)
    lw   t5, 16(s0)
    lw   t6, 20(s3)
    bne  t5, t6, test_fail

    lw   t2, 8(s2)
    sw   t2, 12(s0)
    sw   t3, 0(s0)
    lw   t5, 16(s0)
    lw   t6, 24(s3)
    bne  t5, t6, test_fail

    lw   t2, 12(s2)
    sw   t2, 12(s0)
    sw   t3, 0(s0)
    lw   t5, 16(s0)
    lw   t6, 28(s3)
    bne  t5, t6, test_fail

    # --- ROW 2 ---
    lw   t1, 8(s1)           # Load A[2]
    sw   t1, 8(s0)

    lw   t2, 0(s2)
    sw   t2, 12(s0)
    sw   t3, 0(s0)
    lw   t5, 16(s0)
    lw   t6, 32(s3)
    bne  t5, t6, test_fail

    lw   t2, 4(s2)
    sw   t2, 12(s0)
    sw   t3, 0(s0)
    lw   t5, 16(s0)
    lw   t6, 36(s3)
    bne  t5, t6, test_fail

    lw   t2, 8(s2)
    sw   t2, 12(s0)
    sw   t3, 0(s0)
    lw   t5, 16(s0)
    lw   t6, 40(s3)
    bne  t5, t6, test_fail

    lw   t2, 12(s2)
    sw   t2, 12(s0)
    sw   t3, 0(s0)
    lw   t5, 16(s0)
    lw   t6, 44(s3)
    bne  t5, t6, test_fail

    # --- ROW 3 ---
    lw   t1, 12(s1)          # Load A[3]
    sw   t1, 8(s0)

    lw   t2, 0(s2)
    sw   t2, 12(s0)
    sw   t3, 0(s0)
    lw   t5, 16(s0)
    lw   t6, 48(s3)
    bne  t5, t6, test_fail

    lw   t2, 4(s2)
    sw   t2, 12(s0)
    sw   t3, 0(s0)
    lw   t5, 16(s0)
    lw   t6, 52(s3)
    bne  t5, t6, test_fail

    lw   t2, 8(s2)
    sw   t2, 12(s0)
    sw   t3, 0(s0)
    lw   t5, 16(s0)
    lw   t6, 56(s3)
    bne  t5, t6, test_fail

    lw   t2, 12(s2)
    sw   t2, 12(s0)
    sw   t3, 0(s0)
    lw   t5, 16(s0)
    lw   t6, 60(s3)
    bne  t5, t6, test_fail

    # ====================================================
    # PART 2: INT16 MODE VERIFICATION (2x INT16 Vector Dot)
    # ====================================================
    addi t4, x0, 3           # CTRL Trigger INT16 Mode (Mode=1, Start=1 -> CTRL=3)
    addi s6, x0, int16_opa1  # Pointer to INT16 Data Section

    lw   t1, 0(s6)           # [1000, -200]
    sw   t1, 8(s0)
    lw   t2, 4(s6)           # [50, 4]
    sw   t2, 12(s0)
    sw   t4, 0(s0)           # Trigger INT16 Mode (CTRL=3)
    lw   t5, 16(s0)          # Read Result
    lw   t6, 8(s6)           # Expected = 49200
    bne  t5, t6, test_fail

    lw   t1, 12(s6)          # [300, 400]
    sw   t1, 8(s0)
    lw   t2, 16(s6)          # [200, 100]
    sw   t2, 12(s0)
    sw   t4, 0(s0)           # Trigger INT16 Mode (CTRL=3)
    lw   t5, 16(s0)          # Read Result
    lw   t6, 20(s6)          # Expected = 100000
    bne  t5, t6, test_fail

    # ====================================================
    # PART 3: SUCCESS SIGNAL TO HOST & FPGA LEDS
    # ====================================================
    lui  a0, 0x90000
    addi a1, x0, 10          # Status Code 10 (0x0A => LEDs 1 & 3 ON)
    sw   a1, 0(a0)           # Write to HOST_OUT register

pass_loop:
    j    pass_loop           # Finish Workload Execution

test_fail:
    lui  a0, 0x90000
    addi a1, x0, 255         # Error Status Code 255 (0xFF => All LEDs ON)
    sw   a1, 0(a0)
fail_loop:
    j    fail_loop

# ----------------------------------------------------
# DATA SECTION: INT8 Matrices & INT16 Test Vectors
# ----------------------------------------------------
matA_data:
    .word 0x04030201         # Row 0: [1, 2, 3, 4]
    .word 0x01000102         # Row 1: [2, 1, 0, 1]
    .word 0x03020100         # Row 2: [0, 1, 2, 3]
    .word 0x01010101         # Row 3: [1, 1, 1, 1]

matB_data:
    .word 0x02010001         # Col 0: [1, 0, 1, 2]
    .word 0x01020100         # Col 1: [0, 1, 2, 1]
    .word 0x01000102         # Col 2: [2, 1, 0, 1]
    .word 0x04030201         # Col 3: [1, 2, 3, 4]

expectedC_data:
    .word 12                 # C[0][0]
    .word 12                 # C[0][1]
    .word 8                  # C[0][2]
    .word 30                 # C[0][3]
    .word 4                  # C[1][0]
    .word 2                  # C[1][1]
    .word 6                  # C[1][2]
    .word 8                  # C[1][3]
    .word 8                  # C[2][0]
    .word 8                  # C[2][1]
    .word 4                  # C[2][2]
    .word 20                 # C[2][3]
    .word 4                  # C[3][0]
    .word 4                  # C[3][1]
    .word 4                  # C[3][2]
    .word 10                 # C[3][3]

# INT16 Test Data Section
int16_opa1: .word 0xFF3803E8  # Vector [1000, -200]
int16_opb1: .word 0x00040032  # Vector [50, 4]
int16_exp1: .word 49200       # Expected: 1000*50 + (-200)*4 = 49200

int16_opa2: .word 0x0190012C  # Vector [300, 400]
int16_opb2: .word 0x006400C8  # Vector [200, 100]
int16_exp2: .word 100000      # Expected: 300*200 + 400*100 = 100000