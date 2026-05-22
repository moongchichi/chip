#include "Vaccel_top.h"
#include "verilated.h"
#include "tb_accel_top.cpp"

#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cstdio>
#include <ctime>

static constexpr int N_MAX = 16;
static constexpr int D_MAX = 32;

// Simple LCG for reproducible random vectors
static uint64_t rng_state;
static void rng_seed(uint64_t s) { rng_state = s; }
static int8_t rng_int8() {
    rng_state = rng_state * 6364136223846793005ULL + 1442695040888963407ULL;
    return (int8_t)((rng_state >> 33) & 0xFF);
}

// Inline golden reference
static int golden_argmax_attention(
    const int8_t* Q, const int8_t* K, const int8_t* V,
    int N, int D, int8_t* out_ref)
{
    int32_t scores[N_MAX] = {};
    for (int i = 0; i < N; i++)
        for (int j = 0; j < D; j++)
            scores[i] += (int32_t)Q[j] * (int32_t)K[i * D + j];
    int best = 0;
    for (int i = 1; i < N; i++)
        if (scores[i] > scores[best]) best = i;
    memcpy(out_ref, &V[best * D], (size_t)D);
    return best;
}

int main(int argc, char** argv) {
    // Parse args
    int  N    = N_MAX;
    int  D    = D_MAX;
    long seed = 42;

    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--N")    && i+1 < argc) N    = atoi(argv[++i]);
        if (!strcmp(argv[i], "--D")    && i+1 < argc) D    = atoi(argv[++i]);
        if (!strcmp(argv[i], "--seed") && i+1 < argc) seed = atol(argv[++i]);
    }
    if (N < 1 || N > N_MAX) { fprintf(stderr, "N out of range\n"); return 1; }
    if (D < 1 || D > D_MAX) { fprintf(stderr, "D out of range\n"); return 1; }

    // Generate random vectors
    rng_seed((uint64_t)seed);
    int8_t Q[D_MAX];
    int8_t K[N_MAX * D_MAX];
    int8_t V[N_MAX * D_MAX];
    for (int i = 0; i < D;     i++) Q[i] = rng_int8();
    for (int i = 0; i < N * D; i++) K[i] = rng_int8();
    for (int i = 0; i < N * D; i++) V[i] = rng_int8();

    // Golden reference
    int8_t ref_out[D_MAX] = {};
    int    ref_idx = golden_argmax_attention(Q, K, V, N, D, ref_out);

    // Verilator simulation
    Verilated::commandArgs(argc, argv);
    Vaccel_top* dut = new Vaccel_top;
    AccelDriver drv(dut);

    drv.reset(10);
    drv.load_Q(Q, D);
    drv.load_K(K, N, D);
    drv.load_V(V, N, D);

    bool ok = drv.run_accel(N, D);
    if (!ok) {
        printf("FAIL timeout\n");
        delete dut;
        return 1;
    }

    int8_t  rtl_out[D_MAX] = {};
    int     rtl_idx;
    drv.read_result(D, rtl_out, &rtl_idx);

    uint32_t cycles  = drv.read_cycle_count();
    uint32_t sram_rd = drv.read_sram_read_count();
    uint32_t sram_wr = drv.read_sram_write_count();

    // Compare
    bool pass = (rtl_idx == ref_idx);
    if (pass)
        for (int i = 0; i < D; i++)
            if (rtl_out[i] != ref_out[i]) { pass = false; break; }

    if (pass) {
        printf("PASS idx=%d cycles=%u sram_rd=%u sram_wr=%u\n",
               rtl_idx, cycles, sram_rd, sram_wr);
    } else {
        printf("FAIL idx=%d expected=%d cycles=%u sram_rd=%u sram_wr=%u\n",
               rtl_idx, ref_idx, cycles, sram_rd, sram_wr);
        printf("  ref_out:"); for(int i=0;i<D;i++) printf(" %d", (int)ref_out[i]); printf("\n");
        printf("  rtl_out:"); for(int i=0;i<D;i++) printf(" %d", (int)rtl_out[i]); printf("\n");
    }

    delete dut;
    return pass ? 0 : 1;
}
