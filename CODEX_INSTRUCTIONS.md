# Codex 지시 파일
# Transformer-like Accelerator Flow 프로젝트

---

## Codex 역할 (고정)

Codex는 이 프로젝트에서 독립 검토자 + 보조 수정자다.
Claude Code가 주 구현을 담당하고, Codex는 결과를 검토하고 작은 fix만 제공한다.

```
Claude Code → 주 구현 (RTL, 파일 생성, agent 실행)
Codex       → 보조 검토 (log 분석, 버그 추적, 작은 patch)
```

절대 하지 말아야 할 것:
- Claude Code 작업 중인 파일 동시 수정 금지
- 모듈 전체 재설계 금지
- SPEC.md, register_map.md 임의 변경 금지
- 포트 인터페이스 임의 변경 금지
- 현재 milestone 범위 밖의 기능 추가 금지

---

## 프로젝트 개요

Argmax Attention Accelerator를 SystemVerilog RTL로 구현하고
Verilator로 검증한 뒤, Ibex RISC-V + AXI4-Lite SoC-ready
accelerator로 확장하는 프로젝트.

---

## 하드웨어 스펙 (고정)

```
Q : 1 × D  (int8)
K : N × D  (int8)
V : N × D  (int8)

score_i = dot(Q, K_i)   ← int32 accumulator
idx     = argmax(score_i)
out     = V[idx]

N_MAX      = 16
D_MAX      = 32
DATA_WIDTH = 8
ACC_WIDTH  = 32
```

---

## 아키텍처 확정 (고정)

### 전체 구조
```
[Ibex CPU]
    ↓ OBI bus (M1~M7) → AXI4-Lite wrapper 추가 (M8~)
[Register Bank]
    ↓
[Accel Top]
    ├── [FSM Controller]
    ├── [MAC Unit]
    ├── [SRAM Model]
    └── [Counter Block]
    ↓
[Result Register]
```

### accel_top.sv 포트 (고정)
```systemverilog
module accel_top (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        obi_req,
  output logic        obi_gnt,
  input  logic [31:0] obi_addr,
  input  logic        obi_we,
  input  logic [31:0] obi_wdata,
  output logic [31:0] obi_rdata,
  output logic        obi_rvalid,
  output logic        accel_done,
  output logic        accel_busy
);
```

### 버스 전략
```
M1~M7 : OBI
M8    : OBI + AXI4-Lite wrapper
M9+   : 필요시 AXI4 full
```

### 클럭 전략
```
M1~M7 : single clock (clk / rst_n)
M8    : clk_cpu / clk_accel 분리
         제어 신호 → 2-flop synchronizer
         데이터    → Async FIFO (Gray code pointer)
M10   : CDC 전체 점검
```

---

## Milestone 로드맵

```
M1  Argmax attention + Verilator 검증       ← 현재
M2  Register bank + memory-mapped control
M3  Pseudo CPU driver test
M4  Top-k / approximate softmax
M5  Multi-head attention
M6  Quantized linear projection
M7  Transformer block 일부
M8  Ibex 연동 + AXI4-Lite + CDC
M9  gem5 abstract model
M10 Synthesis-ready cleanup
```

---

## Codex 투입 타이밍 및 프롬프트 템플릿

### 타이밍 1: Verilator 빌드 실패

```
Read this Verilator error log.
Find the minimal fix only.
Do not redesign the module.
Only fix syntax errors, width mismatches, and build issues.
Report format: file name / line number / issue / suggested fix.

[ERROR LOG 붙여넣기]
```

### 타이밍 2: RTL과 Golden model 정합성 확인

```
Review rtl/attention_core.sv and model/golden_attention.py.
Check consistency of:
- signed arithmetic handling
- accumulator width (int32)
- argmax tie-breaking behavior
Do not edit files.
Return: list of inconsistencies with file name and line number.
```

### 타이밍 3: Regression 실패 분석

```
Read results/logs/ and results/csv/regression_summary.csv.
Identify which test cases failed.
Categorize failures: width mismatch / sign error / argmax tie / other.
Do not edit RTL.
Return a concise failure analysis report.
```

### 타이밍 4: Python script 개선

```
Review scripts/run_regression.py.
Check edge cases in:
- vector generation range
- PASS/FAIL comparison
- CSV output format
Suggest minimal improvements only.
Do not change overall structure.
```

### 타이밍 5: CDC 검토 (M8 이후)

```
Review rtl/ for CDC issues.
Check:
- signals crossing clk_cpu → clk_accel without synchronizer
- signals crossing clk_accel → clk_cpu without synchronizer
- Async FIFO Gray code pointer correctness
- 2-flop synchronizer placement
Do not edit files.
Return: list of CDC violations with file name and line number.
```

### 타이밍 6: AXI4-Lite wrapper 검토 (M8 이후)

```
Review rtl/axi4lite_wrapper.sv.
Check:
- AW/W/B/AR/R channel handshake correctness
- AWVALID/AWREADY, WVALID/WREADY, BVALID/BREADY timing
- ARVALID/ARREADY, RVALID/RREADY timing
- address decoding correctness
- no deadlock condition
Do not edit files.
Return issues with file name and line number.
```

---

## RTL 검토 체크리스트

Codex에게 RTL review 요청 시 아래 항목 기준으로 검토한다.

```
- active-low rst_n 일관성
- FSM deadlock 가능성
- counter overflow
- signed/unsigned mismatch
- SRAM address overflow
- OBI handshake 오류
- AXI handshake 오류 (M8~)
- CDC 미처리 신호 (M8~)
- non-synthesizable construct 혼입
- unsized constant 사용
- implicit latch
- RTL과 Python golden model 간 arithmetic 불일치
```

---

## Milestone별 완료 기준

### M1 완료 기준
```
✓ Verilator 빌드 성공
✓ random 100회 전부 PASS
✓ corner 5회 전부 PASS
✓ results/csv/regression_summary.csv 생성
✓ cycle_count, sram_read_count, sram_write_count 기록
✓ softmax 없음
✓ non-synthesizable RTL 없음 (sram_model.sv 제외)
✓ single clock
```

### M8 완료 기준 (추가)
```
✓ Ibex RTL 연결 성공
✓ OBI transaction 검증
✓ AXI4-Lite wrapper 동작 확인
✓ clk_cpu / clk_accel 분리
✓ 2-flop synchronizer 적용
✓ Async FIFO 동작 확인
✓ CDC 위반 없음
```

### M10 완료 기준 (추가)
```
✓ 모든 non-synthesizable construct 제거
✓ CDC 전체 점검 완료
✓ timing constraint 초안 작성
✓ area/power estimation 완료
```

---

## Codex 사용 원칙

| 원칙 | 내용 |
|------|------|
| 최소 수정 | 전체 재설계 금지, 최소 patch만 |
| 읽기 우선 | 수정 전 반드시 현재 파일 읽기 |
| 영역 존중 | Claude Code 작업 중 파일 동시 수정 금지 |
| 보고 형식 | file name + line number + issue + suggested fix |
| SPEC 보존 | SPEC.md, register_map.md, 포트 인터페이스 수정 금지 |
| 범위 준수 | 현재 milestone 외 기능 추가 금지 |
