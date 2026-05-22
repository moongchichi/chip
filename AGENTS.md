# Agent Roles

| Agent              | Files              | Role                                         |
|--------------------|--------------------|----------------------------------------------|
| architect-agent    | spec/              | SPEC, register map, FSM design decisions     |
| rtl-agent          | rtl/               | SystemVerilog RTL authoring and fixes        |
| verification-agent | tb/ model/ tests/ scripts/ | Testbench, golden model, regression |
| review-agent       | (read-only)        | Bug finding only — never modifies files      |

**Rule:** Each agent touches only its own area. Cross-area edits require user approval.

**Claude Code vs Codex split:**
- Claude Code → primary implementation (RTL, file gen, iteration)
- Codex → assist (Verilator log analysis, patch review, bug root-cause)
- Never edit the same file simultaneously
