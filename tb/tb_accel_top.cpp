#pragma once
#include "Vaccel_top.h"
#include "verilated.h"
#include <cstdint>
#include <cstdio>

// OBI register map addresses
static constexpr uint32_t ADDR_CTRL       = 0x000;
static constexpr uint32_t ADDR_STATUS     = 0x004;
static constexpr uint32_t ADDR_IDX_OUT    = 0x008;
static constexpr uint32_t ADDR_N_CFG      = 0x010;
static constexpr uint32_t ADDR_D_CFG      = 0x014;
static constexpr uint32_t ADDR_CYCLE_CNT  = 0x018;
static constexpr uint32_t ADDR_SRAM_RD    = 0x01C;
static constexpr uint32_t ADDR_SRAM_WR    = 0x020;
static constexpr uint32_t ADDR_RESULT_BASE = 0x030;
static constexpr uint32_t ADDR_Q_BASE     = 0x100;
static constexpr uint32_t ADDR_K_BASE     = 0x200;
static constexpr uint32_t ADDR_V_BASE     = 0xA00;

class AccelDriver {
public:
    Vaccel_top* dut;
    uint64_t    sim_time;

    explicit AccelDriver(Vaccel_top* d) : dut(d), sim_time(0) {}

    void tick() {
        dut->clk = 0;
        dut->eval();
        sim_time++;
        dut->clk = 1;
        dut->eval();
        sim_time++;
    }

    void reset(int cycles = 10) {
        dut->rst_n   = 0;
        dut->obi_req = 0;
        dut->obi_we  = 0;
        dut->obi_addr  = 0;
        dut->obi_wdata = 0;
        for (int i = 0; i < cycles; i++) tick();
        dut->rst_n = 1;
        tick();
    }

    void obi_write(uint32_t addr, uint32_t data) {
        dut->obi_req   = 1;
        dut->obi_we    = 1;
        dut->obi_addr  = addr;
        dut->obi_wdata = data;
        // Wait for gnt (should be immediate)
        do { tick(); } while (!dut->obi_gnt);
        dut->obi_req = 0;
        dut->obi_we  = 0;
        tick();  // rvalid cycle
    }

    uint32_t obi_read(uint32_t addr) {
        dut->obi_req   = 1;
        dut->obi_we    = 0;
        dut->obi_addr  = addr;
        dut->obi_wdata = 0;
        do { tick(); } while (!dut->obi_gnt);
        dut->obi_req = 0;
        tick();  // rvalid cycle — data is valid now
        return dut->obi_rdata;
    }

    void load_Q(const int8_t* q, int D) {
        for (int i = 0; i < D; i++)
            obi_write(ADDR_Q_BASE + (uint32_t)i * 4,
                      (uint32_t)(uint8_t)q[i]);
    }

    void load_K(const int8_t* k, int N, int D) {
        for (int i = 0; i < N * D; i++)
            obi_write(ADDR_K_BASE + (uint32_t)i * 4,
                      (uint32_t)(uint8_t)k[i]);
    }

    void load_V(const int8_t* v, int N, int D) {
        for (int i = 0; i < N * D; i++)
            obi_write(ADDR_V_BASE + (uint32_t)i * 4,
                      (uint32_t)(uint8_t)v[i]);
    }

    // Returns false if timeout
    bool run_accel(int N, int D, int timeout_cycles = 100000) {
        obi_write(ADDR_N_CFG, (uint32_t)N);
        obi_write(ADDR_D_CFG, (uint32_t)D);
        obi_write(ADDR_CTRL,  1);  // start pulse

        for (int c = 0; c < timeout_cycles; c++) {
            tick();
            uint32_t status = obi_read(ADDR_STATUS);
            if (status & 0x1) return true;  // done
        }
        return false;
    }

    void read_result(int D, int8_t* out, int* idx) {
        *idx = (int)(obi_read(ADDR_IDX_OUT) & 0xF);
        for (int i = 0; i < D; i++) {
            uint32_t raw = obi_read(ADDR_RESULT_BASE + (uint32_t)i * 4);
            out[i] = (int8_t)(raw & 0xFF);
        }
    }

    uint32_t read_cycle_count()     { return obi_read(ADDR_CYCLE_CNT); }
    uint32_t read_sram_read_count() { return obi_read(ADDR_SRAM_RD);   }
    uint32_t read_sram_write_count(){ return obi_read(ADDR_SRAM_WR);   }
};
