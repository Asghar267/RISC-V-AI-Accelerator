#include <stdint.h>

#define DOT4_BASE   0x80000000u
#define MMIO32(a)   (*(volatile uint32_t *)(a))
#define DOT4_CTRL   MMIO32(DOT4_BASE + 0x00u)
#define DOT4_STATUS MMIO32(DOT4_BASE + 0x04u)
#define DOT4_OPA    MMIO32(DOT4_BASE + 0x08u)
#define DOT4_OPB    MMIO32(DOT4_BASE + 0x0cu)
#define DOT4_RESULT MMIO32(DOT4_BASE + 0x10u)

static uint32_t pack4(int8_t x0, int8_t x1, int8_t x2, int8_t x3) {
    return ((uint32_t)(uint8_t)x0) | ((uint32_t)(uint8_t)x1 << 8) |
           ((uint32_t)(uint8_t)x2 << 16) | ((uint32_t)(uint8_t)x3 << 24);
}

static int32_t dot4_accel(uint32_t a, uint32_t b) {
    DOT4_OPA = a;
    DOT4_OPB = b;
    DOT4_CTRL = 1u;
    while ((DOT4_STATUS & 1u) == 0u) { }
    return (int32_t)DOT4_RESULT;
}

static int32_t dot4_sw(const int8_t *a, const int8_t *b) {
    return (int32_t)a[0]*b[0] + (int32_t)a[1]*b[1] +
           (int32_t)a[2]*b[2] + (int32_t)a[3]*b[3];
}

int main(void) {
    static const int8_t A[4][4] = {{1,2,3,4},{-1,2,-3,4},{5,-6,7,-8},{2,0,-2,1}};
    static const int8_t B[4][4] = {{1,0,2,-1},{2,1,0,3},{0,-2,1,2},{1,3,-1,0}};
    int32_t c_hw[4][4], c_sw[4][4];
    int failures = 0;
    if (dot4_accel(pack4(1,2,3,4), pack4(5,6,7,8)) != 70) failures++;
    for (int i=0; i<4; ++i) for (int j=0; j<4; ++j) {
        int8_t col[4] = {B[0][j],B[1][j],B[2][j],B[3][j]};
        c_hw[i][j] = dot4_accel(pack4(A[i][0],A[i][1],A[i][2],A[i][3]),
                                 pack4(col[0],col[1],col[2],col[3]));
        c_sw[i][j] = dot4_sw(A[i], col);
        if (c_hw[i][j] != c_sw[i][j]) failures++;
    }
    return failures;
}
