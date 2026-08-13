# AI Agent modules

`aiagent` is split by lifecycle responsibility. Zsh's recursive loader sources these files in lexical order.

- `00-policy.zsh` — dangerous-command policy and parser primitives.
- `05-cli.zsh` — checkpoint/log inspection commands.
- `10-state.zsh` — checkpoint/slug/session state helpers and project/provider summaries.
- `20-presentation.zsh` — compact UI formatting and touched-file verification dispatch.
- `30-validation.zsh` — source verification and optional JS/TS project checks.
- `40-runtime.zsh` — public `aiagent` orchestrator: CLI, setup, context lifecycle, and phase coordination.
- `42-execution.zsh` — bounded ReAct execution loop, tool dispatch, retry/loop guards, checkpoint updates, and execution result state.
- `44-finalize.zsh` — checkpoint retirement and final COMPLETE/BLOCKED reporting plus optional review.

## Runtime contract

The orchestrator owns lifecycle. The execution phase owns model/tool iteration. The finalizer owns reporting. They communicate through an explicit 0700 state directory containing only: `step`, `done`, `block_reason`, `thought`, `commands_run`, `touched_files`, and `changed_files`.

This avoids relying on hidden dynamic locals across phase boundaries and makes the execution/finalization boundary independently testable.

The public command remains `aiagent`; its CLI flags are intentionally unchanged.
