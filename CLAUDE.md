# Transformer-like Accelerator Flow

---

## 프로젝트 목표

Argmax Attention Accelerator를 SystemVerilog RTL로 구현하고
Verilator로 검증한 뒤, Ibex RISC-V CPU와 연동하여
AXI4-Lite 인터페이스를 갖춘 SoC-ready accelerator를 완성한다.

최종 목표:
- Synthesizable SystemVerilog RTL
- Ibex + Accelerator SoC 구성
- AXI4-Lite 외부 인터페이스
- CDC (Clock Domain Crossing) 완료
- gem5 abstract model 연동

---

## 하드웨어 스펙 (고정 — 절대 변경 금지)

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
  DATA_WIDTH = 8
  ACC_WIDTH  = 32
```

---

## 아키텍처 (고정 — 절대 변경 금지)

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
[Result Register]
```

### FSM (고정)
```
IDLE → LOAD_Q → LOAD_K_SCORE → ARGMAX → LOAD_V → DONE → IDLE
```

### accel_top.sv 포트 (고정 — 절대 변경 금지)
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
M8    : OBI + AXI4-Lite wrapper 추가
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

### 메모리 구조
```
SRAM (sram_model.sv)
  Q  :  1 × 32 int8 =   32 bytes
  K  : 16 × 32 int8 =  512 bytes
  V  : 16 × 32 int8 =  512 bytes
  총 ~1KB 단일 SRAM bank
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
- 모듈은 작고 독립적으로 테스트 가능하게 유지
- sram_model.sv만 simulation용 허용 (파일 상단 주석 필수)
- accel_top.sv 포트는 명시적 요청 없이 절대 변경 금지
```

---

## 검증 규칙 (반드시 준수)

```
- RTL 수정 후 반드시 Verilator 빌드 실행
- 모든 functional test는 model/golden_attention.py 결과와 비교
- regression 결과는 results/csv/regression_summary.csv에 저장
- 로그 필수 항목: PASS/FAIL, cycle_count, sram_read_count, sram_write_count
```

---

## Automode 안전 규칙 (반드시 준수)

### 파일 보호
```
- 아래 파일은 절대 삭제/덮어쓰기 금지
  CLAUDE.md
  SPEC.md
  spec/register_map.md
  rtl/accel_top.sv 포트 정의 부분
- 파일 삭제가 필요한 경우 반드시 git commit 먼저 실행 후 사람에게 보고
- 기존 파일 전체를 새로 교체하는 방식 금지
  반드시 필요한 부분만 수정 (Edit 사용)
```

### 빌드 실패 처리
```
- Verilator 빌드 3회 연속 실패 시 즉시 중단
- 중단 후 반드시 아래 형식으로 보고:
  [BUILD FAIL] 파일명 / 에러 메시지 / 시도한 수정 내역
- 보고 후 사람 승인 없이 재시도 금지
- Codex 투입이 필요하면 에러 로그 출력 후 대기
```

### 무한 루프 방지
```
- 동일한 수정을 3회 이상 반복 금지
- 같은 에러가 반복되면 다른 접근법 시도 전 사람에게 보고
- regression 실패율이 50% 초과 시 즉시 중단 후 보고
```

### agent 영역 보호
```
- 각 agent는 자신의 영역 외 파일 수정 즉시 중단
- 영역 침범 감지 시 보고 형식:
  [BOUNDARY VIOLATION] agent명 / 침범 시도 파일 / 이유
- review-agent는 어떤 경우에도 파일 수정 금지
```

### milestone 보호
```
- 사람 승인 없이 다음 milestone 자동 진행 금지
- milestone 완료 보고 형식:
  [M1 PASS] regression 100/100 | corner 5/5 | git commit: abc1234
- milestone 실패 보고 형식:
  [M1 FAIL] 실패 항목 / 에러 내용 / 권장 조치
```

### git 안전장치
```
- 매 milestone 완료 시 git commit 필수
  커밋 메시지 형식: "M1 PASS: regression 100/100"
- 작업 중 파일 대량 변경 전 자동 commit:
  커밋 메시지 형식: "WIP: M1 rtl-agent before major edit"
- git commit 실패 시 파일 수정 중단 후 보고
```

### 비용/토큰 보호
```
- 한 번에 전체 milestone 연속 자동 실행 금지
- milestone 하나 완료 후 반드시 보고 후 대기
- 불필요한 파일 전체 재생성 금지 (필요한 부분만 Edit)
- 로그 파일 무제한 생성 금지
  results/logs/ 안에 최대 50개 유지, 초과 시 오래된 것부터 삭제
```

### 네트워크/외부 접근
```
- git clone은 반드시 사람이 지정한 경로에만 실행
- M8 Ibex clone 위치: third_party/ibex 고정
  git clone https://github.com/lowRISC/ibex third_party/ibex
- 승인되지 않은 외부 저장소 clone 금지
- npm, pip 등 패키지 자동 설치 금지 (사람에게 먼저 보고)
```

---

## Agent 역할 분담 (고정)

| Agent | 수정 가능 영역 | 역할 |
|-------|-------------|------|
| architect-agent | spec/ | SPEC, register map, FSM 정리 |
| rtl-agent | rtl/ | SystemVerilog RTL 작성 |
| verification-agent | tb/ model/ tests/ scripts/ | TB, golden model, regression |
| review-agent | 읽기 전용 | 버그 리스트 출력만 |

규칙: 각 agent는 자신의 영역 외 파일을 절대 수정하지 않는다.

---

## Agent 파일 위치 및 내용

### .claude/agents/architect-agent.md
```
---
name: architect-agent
description: SPEC, register map, memory map, FSM 정리 담당
tools: Read, Write, Edit
---
수정 가능 영역: spec/ 만
SPEC.md와 register_map.md를 기준으로 작업한다.
알고리즘을 임의로 변경하지 않는다.
spec/ 외 파일 수정 시도 시 즉시 중단하고 보고한다.
작업 완료 후 변경 파일 목록을 보고한다.
```

### .claude/agents/rtl-agent.md
```
---
name: rtl-agent
description: SystemVerilog RTL 작성 담당
tools: Read, Write, Edit, Bash
---
수정 가능 영역: rtl/ 만
SPEC.md와 spec/register_map.md를 엄격히 따른다.
accel_top.sv 포트는 절대 변경하지 않는다.
파일 전체 재작성 금지, Edit으로 필요한 부분만 수정한다.
RTL 수정 후 반드시 실행:
  bash scripts/run_verilator.sh
빌드 3회 연속 실패 시 즉시 중단하고 에러 로그를 보고한다.
보고 형식: 변경 파일 / 빌드 결과 / 에러 로그 / 의심 위험 항목
```

### .claude/agents/verification-agent.md
```
---
name: verification-agent
description: Verilator testbench, golden model, regression 담당
tools: Read, Write, Edit, Bash
---
수정 가능 영역: tb/ model/ tests/ scripts/ 만
rtl/ 은 어떤 경우에도 수정하지 않는다.
모든 test는 model/golden_attention.py 결과와 비교한다.
regression 결과를 results/csv/regression_summary.csv에 저장한다.
로그에 PASS/FAIL, cycle_count, sram_read_count, sram_write_count 포함 필수.
실패율 50% 초과 시 즉시 중단 후 보고한다.
```

### .claude/agents/review-agent.md
```
---
name: review-agent
description: RTL 및 검증 결과 검토 담당
tools: Read, Bash
---
파일을 절대 수정하지 않는다. 읽기만 한다.
검토 항목:
- active-low rst_n 일관성
- FSM deadlock 가능성
- counter overflow
- signed/unsigned mismatch
- SRAM address overflow
- OBI handshake 오류
- non-synthesizable construct
- unsized constant
- implicit latch
- RTL과 golden model 간 arithmetic 불일치
보고 형식: file name / line number / issue / suggested fix
수정이 필요한 경우 rtl-agent에게 위임 요청만 한다.
```

---

## 폴더 구조 (고정)

```
~/project/chip/
├── CLAUDE.md
├── SPEC.md
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
├── third_party/
│   └── ibex/           ← M8 전에 수동 clone
└── docs/
    ├── architecture.md
    ├── experiment_notes.md
    └── roadmap.md
```

---

## Milestone 로드맵

```
M1  Argmax attention 단독 accelerator
    - Python golden model
    - RTL 전체 (accel_top, attention_core, mac_unit,
                 sram_model, reg_bank, counter_block)
    - Verilator C++ testbench
    - random 100회 + corner 5회 regression PASS
    - single clock, softmax 없음

M2  Register bank + memory-mapped control
    - OBI로 레지스터 read/write
    - start/done/busy 제어

M3  Pseudo CPU driver test
    - C++ driver model
    - end-to-end transaction 검증

M4  Top-k 또는 approximate softmax
    - 반드시 사람 승인 후 진행
    - 방향 미결정 시 중단 후 대기

M5  Multi-head attention

M6  Quantized linear projection

M7  Transformer block 일부

M8  Ibex RISC-V 연동
    - third_party/ibex 존재 여부 먼저 확인
    - 없으면 사람에게 clone 요청 후 대기
    - OBI 연결
    - AXI4-Lite wrapper
    - clk_cpu / clk_accel 분리
    - 2-flop synchronizer + Async FIFO

M9  gem5 abstract accelerator model
    - 서버 환경 권장
    - 로컬에서 진행 시 사람에게 확인 후 진행

M10 Synthesis-ready cleanup
    - CDC 전체 점검
    - non-synthesizable 제거
    - timing constraint 초안
```

---

## Milestone 진행 패턴

각 milestone은 반드시 이 순서로 진행한다.

```
1. architect-agent → spec/ 작성/확인
2. rtl-agent       → rtl/ 작성/수정
3. verification-agent → tb/ model/ scripts/ 작성
4. Verilator 빌드 + regression 실행
5. review-agent    → RTL 검토
6. PASS 시: git commit 후 보고 후 대기
   FAIL 시: 에러 로그 출력 후 즉시 중단, 사람 승인 대기
```

---

## Codex 투입 타이밍

Claude Code 단독으로 해결 안 될 때 사람에게 아래를 요청한다.

```
"Codex에게 아래 에러 로그를 전달해주세요"
[에러 로그 출력]
```

Codex가 fix를 주면 사람이 Claude Code에게 전달한다.
Codex fix를 받기 전까지 Claude Code는 대기한다.

---

## 시작 전 준비 확인

```
git init 완료 여부 확인
git add . && git commit -m "init" 실행 확인
uv 환경 확인: uv run python --version
Verilator 설치 확인: verilator --version
M8 전에 Ibex 미리 clone:
  git clone https://github.com/lowRISC/ibex third_party/ibex
```
