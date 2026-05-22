# Claude Code 지시 파일
# Transformer-like Accelerator Flow 프로젝트

---

## 프로젝트 목표

Argmax Attention Accelerator를 SystemVerilog RTL로 구현하고,
Verilator로 검증한 뒤, Ibex RISC-V CPU와 연동하여
AXI4-Lite 인터페이스를 갖춘 SoC-ready accelerator를 만든다.

최종 목표:
- Synthesizable RTL
- Ibex + Accelerator SoC 구성
- AXI4-Lite 외부 인터페이스
- CDC (Clock Domain Crossing) 처리 완료
- gem5 abstract model 연동

---

## 하드웨어 스펙 (고정 — 변경 금지)

```
입력:
  Q : 1 × D  (int8)
  K : N × D  (int8)
  V : N × D  (int8)

연산:
  score_i = dot(Q, K_i)      ← int32 accumulator
  idx     = argmax(score_i)
  out     = V[idx]            ← 1 × D int8

파라미터:
  N_MAX      = 16
  D_MAX      = 32
  DATA_WIDTH = 8   (입력)
  ACC_WIDTH  = 32  (accumulator)
```

---

## 아키텍처 확정 (고정 — 변경 금지)

### 전체 구조
```
[Ibex CPU]
    ↓ OBI bus (M1~M7)
    ↓ OBI + AXI4-Lite wrapper (M8~)
[Register Bank]
    ↓
[Accel Top]
    ├── [FSM Controller]
    ├── [MAC Unit]
    ├── [SRAM Model]
    └── [Counter Block]
    ↓
[Result Register] → CPU가 여기서 결과 읽음
```

### FSM (고정)
```
IDLE
 ↓ (start 신호)
LOAD_Q        ← Q 벡터 SRAM에서 로드
 ↓
LOAD_K_SCORE  ← K[i] 로드 + dot product 반복 (i=0..N-1)
 ↓
ARGMAX        ← score 최대값 idx 선택
 ↓
LOAD_V        ← V[idx] 로드
 ↓
DONE          ← result 레지스터에 out, idx 저장
 ↓
IDLE
```

### accel_top.sv 포트 (고정 — 변경 금지)
```systemverilog
module accel_top (
  input  logic        clk,
  input  logic        rst_n,

  // CPU interface (OBI)
  input  logic        obi_req,
  output logic        obi_gnt,
  input  logic [31:0] obi_addr,
  input  logic        obi_we,
  input  logic [31:0] obi_wdata,
  output logic [31:0] obi_rdata,
  output logic        obi_rvalid,

  // Status
  output logic        accel_done,
  output logic        accel_busy
);
```

### 버스 전략
```
M1~M7 : OBI (단순 handshake, Ibex 기본 지원)
M8    : AXI4-Lite wrapper 추가
         OBI → [AXI4-Lite Wrapper] → 외부 SoC 연결
M9+   : 필요시 AXI4 full (burst, DMA)
```

### 클럭 전략
```
M1~M7 : single clock (clk 하나, rst_n 하나)
M8    : CPU clk / Accel clk 분리
         제어 신호 → 2-flop synchronizer
         데이터    → Async FIFO (Gray code pointer)
M10   : CDC 전체 점검 + synthesis-ready cleanup
```

### 메모리 구조
```
SRAM (simulation model, sram_model.sv)
  Q  : 1  × 32 (int8) =   32 bytes
  K  : 16 × 32 (int8) =  512 bytes
  V  : 16 × 32 (int8) =  512 bytes
  총 ~1KB, 단일 SRAM bank
```

---

## Milestone 로드맵 (전체)

```
M1  Argmax attention 단독 accelerator
    - Python golden model
    - SystemVerilog RTL (accel_top, attention_core, mac_unit,
                         sram_model, reg_bank, counter_block)
    - Verilator C++ testbench
    - random 100회 + corner 5회 regression
    - cycle_count, sram_read_count, sram_write_count 출력
    - single clock

M2  Register bank + memory-mapped control
    - CPU가 OBI로 레지스터 read/write
    - start/done/busy 제어
    - register map 확정

M3  Pseudo CPU driver test
    - 실제 CPU 없이 bus transaction 시뮬레이션
    - C++ driver model 작성
    - end-to-end transaction 검증

M4  Top-k attention 또는 approximate softmax
    - architecture 승인 후 진행
    - golden model 업데이트

M5  Multi-head attention
    - head 수 파라미터화
    - SRAM 레이아웃 조정

M6  Quantized linear projection
    - int8 weight, int32 accumulator
    - projection matrix SRAM 추가

M7  Transformer block 일부
    - attention + FFN 연결
    - pipeline 구조 검토

M8  Ibex RISC-V 연동
    - Ibex RTL clone (GitHub: lowRISC/ibex)
    - OBI 연결
    - AXI4-Lite wrapper 추가
    - clk_cpu / clk_accel 분리
    - 2-flop synchronizer + Async FIFO

M9  gem5 abstract accelerator model
    - Python/C++ gem5 model 작성
    - timing 파라미터 Verilator 결과에서 추출
    - 서버 환경 권장

M10 Synthesis-ready cleanup
    - CDC 전체 점검
    - non-synthesizable 제거
    - timing constraint 초안
    - area/power estimation
```

---

## RTL 코딩 규칙 (반드시 준수)

```
- synthesizable SystemVerilog만 사용
- active-low reset: rst_n
- valid/ready handshake 사용
- 모든 counter에 명시적 width 지정
- implicit latch 금지
- unsized constant 금지 (8'd0 사용, 0 단독 금지)
- 모듈은 작고 독립적으로 테스트 가능하게
- sram_model.sv만 simulation용 허용 (파일 상단에 주석 명시)
- 포트 인터페이스는 명시적 요청 없이 변경 금지
```

---

## 검증 규칙 (반드시 준수)

```
- RTL 수정 후 반드시 Verilator 빌드 실행
- 모든 functional test는 model/golden_attention.py와 비교
- regression 결과는 results/csv/regression_summary.csv에 저장
- 로그 필수 항목: PASS/FAIL, cycle_count, sram_read_count, sram_write_count
```

---

## 프로젝트 폴더 구조 (고정)

```
transformer_accel_flow/
├── CLAUDE.md
├── AGENTS.md
├── SPEC.md
├── README.md
├── .claude/
│   └── agents/
│       ├── architect-agent.md
│       ├── rtl-agent.md
│       ├── verification-agent.md
│       └── review-agent.md
├── spec/
│   ├── algorithm.md
│   ├── register_map.md
│   ├── memory_map.md
│   └── verification_plan.md
├── rtl/
│   ├── accel_top.sv
│   ├── reg_bank.sv
│   ├── attention_core.sv
│   ├── mac_unit.sv
│   ├── sram_model.sv
│   └── counter_block.sv
├── tb/
│   ├── tb_accel_top.cpp
│   └── verilator_main.cpp
├── model/
│   └── golden_attention.py
├── scripts/
│   ├── gen_vectors.py
│   ├── run_verilator.sh
│   ├── run_regression.py
│   ├── parse_log.py
│   └── plot_results.py
├── tests/
│   ├── test_small.yaml
│   ├── test_random.yaml
│   └── test_corner.yaml
├── results/
│   ├── logs/
│   ├── csv/
│   └── figures/
└── docs/
    ├── architecture.md
    ├── experiment_notes.md
    └── roadmap.md
```

---

## Agent 역할 분담 (고정)

| Agent | 수정 가능 영역 | 역할 |
|-------|-------------|------|
| architect-agent | spec/ | SPEC, register map, FSM 정리 |
| rtl-agent | rtl/ | SystemVerilog RTL 작성 |
| verification-agent | tb/ model/ tests/ scripts/ | TB, golden model, regression |
| review-agent | 읽기 전용 | 버그 리스트 출력만 |

규칙: 각 agent는 자신의 영역 외 파일을 수정하지 않는다.

---

## Codex와의 역할 분리

```
Claude Code → 주 구현 (RTL, 파일 생성, agent 실행, 반복 수정)
Codex       → 보조 검토 (Verilator log 분석, 버그 추적, 작은 patch)

동일 파일 동시 수정 금지
```

Codex 투입 타이밍:
1. Verilator 빌드 실패 → error log를 Codex에 전달
2. RTL과 golden model 정합성 확인 필요 시
3. regression 실패 원인 분석 필요 시

---

## Claude Code 설정 방법

아래 두 가지만 하면 agent가 자동 인식된다.

```
1. 프로젝트 root에 CLAUDE.md 파일 생성
2. .claude/agents/ 폴더에 agent .md 파일 생성

→ Claude Code 시작 시 자동으로 읽힘
→ 별도 UI 설정 없음
```

---

## 첫 번째 실행 프롬프트 (Claude Code에 그대로 입력)

```
Read CLAUDE_CODE_INSTRUCTIONS.md and set up the full project.

Create transformer_accel_flow/ with all folders and files defined in the instructions.
Create .claude/agents/ with all four agent files.
Create CLAUDE.md at project root summarizing the architecture and rules.

Then start M1:
- Create model/golden_attention.py
- Create all RTL files under rtl/
- Create Verilator testbench under tb/
- Create all scripts under scripts/
- Attempt Verilator build
- If Verilator not installed, generate all files and show install command

M1 constraints:
- Single clock only
- No softmax
- No multi-head
- No Ibex, no gem5
- synthesizable RTL only (except sram_model.sv)
```

---

## Milestone 진행 방법

각 milestone은 아래 패턴으로 진행한다.

```
사용자: "M2 진행해"
Claude Code:
  1. 현재 milestone PASS 확인
  2. 다음 milestone 파일 생성/수정
  3. Verilator 빌드
  4. regression 실행
  5. PASS/FAIL 보고
  6. 실패 시 Codex에 log 전달 요청
```
