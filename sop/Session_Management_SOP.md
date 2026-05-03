# Session Management SOP

> How to manage Claude Code sessions, context, and compaction during Pipekit work. Informed by Anthropic's guidance for Claude Code + Opus 4.7 and adapted for Pipekit's pipeline.

**Last updated:** 2026-04-17

---

## Why This Matters

Claude Code's context window is one million tokens, but **context rot** — degradation of model performance as context grows — kicks in well before that limit. Attention spreads thin across more tokens, and stale content distracts from current tasks. How you manage sessions shapes your results more than effort level or prompting.

Every time Claude finishes a turn, you have five choices for what to do next:

| Option | When | Why |
|--------|------|-----|
| **Continue** | Same task, context still load-bearing | Don't pay to rebuild what's already in the window |
| **Rewind** (double-Esc or `/rewind`) | Claude went down a wrong path | Drop the failed attempt, keep useful context, re-prompt with what you learned |
| **Compact** (`/compact <hint>`) | Mid-task, session bloated with stale exploration | Claude summarizes; you pass hints to steer focus |
| **Clear** (`/clear`) | Genuinely new task | Zero rot; you control exactly what carries forward |
| **Subagent** | Next step produces lots of output you'll only need a conclusion from | Intermediate noise stays in the child's context |

---

## Pipekit's Session Pattern

Pipekit's pipeline maps naturally onto session boundaries. Treat each pipeline step as a candidate for a fresh session:

| Pipeline step | Session boundary | Why |
|---------------|------------------|-----|
| `/concept` → `/define` | Same session | Both work from the same source documents |
| `/strategy-create` | Same session as define | Strategy docs build on the definition |
| `/startup` infrastructure setup | One session per major service (DB, deploy, auth) | Each service is bounded work with discrete outputs |
| `/roadmap-create` | Fresh session | Different context from infrastructure; reads strategy docs anew |
| `/phase-plan` | Fresh session | Distinct from roadmap creation |
| `/light-spec` per issue | Fresh session per issue | Each spec is a bounded AI-to-AI contract |
| `/work` (vbw backend) → vbw-dev execution | VBW manages its own context | Don't try to orchestrate from the main session — let `/work` dispatch and read state on completion |
| `/strategy-sync` post-ship | Fresh session | Compares codebase to strategy docs, needs clean context |

**Rule of thumb:** when you start a new pipeline step, start a new session. The tracker files (`{folder-name}-startup.md`, `method.config.md`, `.vbw-planning/ROADMAP.md`, `Strategy/`) carry state across sessions — you don't need Claude's memory to carry it.

---

## The Startup Tracker Is Pipekit's `/clear`

`{folder-name}-startup.md` is Pipekit's structured version of "write down what matters before starting a new session." When you:

1. Complete a `/startup` step and the next one is substantially different
2. Hit context bloat mid-setup
3. Come back the next day

...you can close the session, start fresh, and Claude reads the tracker to restore state. This is strictly better than `/compact` for multi-session work because the tracker is curated, not auto-summarized.

**Pattern:** don't `/compact` during `/startup`. Close and reopen, let the tracker restore context.

---

## When to Rewind

Rewind is often better than correction. Example scenario:

> Claude reads five files, tries an approach, and it doesn't work. Your instinct: type "that didn't work, try X instead." Better move: rewind to just after the file reads, re-prompt with what you learned. "Don't use approach A, the foo module doesn't expose that — go to B directly."

The messages after the rewind point drop from context. You keep the useful file reads; you lose the dead-end attempt.

Use `/rewind` or double-tap `Esc`. You can also use "summarize from here" to create a handoff message for the re-prompt.

---

## Compact vs. Clear

| | `/compact` | `/clear` |
|---|-----------|---------|
| **Effort** | Low — Claude summarizes | Higher — you write the brief |
| **Precision** | Lossy — model decides what mattered | Precise — you decide what carries forward |
| **Risk** | Can drop load-bearing context if the model mispredicts your next move | None — everything is explicit |
| **Best for** | Mid-task cleanup when you're staying on the same task | Task transitions or after dead ends |

**Steer compact with hints.** `/compact focus on the auth refactor, drop the test debugging` produces meaningfully better summaries than bare `/compact`.

**Compact failure mode:** if a long debugging session summarizes, then your next message is "now fix that other warning we saw in bar.ts" — the compact may have dropped the bar.ts reference because the session was focused on debugging. With 1M context, you can usually `/compact` proactively with a description of what's coming next, before hitting the auto-trigger.

---

## Subagents as Context Hygiene

Subagents aren't just for parallelism — they're for **keeping tool output noise out of the main session**. Pipekit skills that should spawn subagents:

| Skill | Why subagent |
|-------|-------------|
| `/01-light-spec` Phase 2 | Codebase exploration produces tons of grep/read output; only the conclusions matter for the spec |
| `/06-linear-todo-runner` | Parallel worktree agents per issue; each one's execution output stays isolated |
| `/concept --docs` | Ingesting user documents produces long reads; only the extracted context matters |
| `/strategy-sync` | Comparing codebase to strategy docs scans many files |

**Tell Claude explicitly when to use a subagent.** Opus 4.7 defaults to fewer subagents than earlier models. Examples:
- _"Spin up a subagent to verify the result of this work based on the following spec file."_
- _"Spin off a subagent to read through this other codebase and summarize how it implemented the auth flow, then implement it yourself in the same way."_
- _"Spin off a subagent to write the docs on this feature based on my git changes."_

**Mental test:** will I need the tool output again, or just the conclusion? If just the conclusion, spawn a subagent.

---

## Effort and Thinking Recommendations

For Opus 4.7 running Pipekit work:

| Task type | Effort level | Rationale |
|-----------|-------------|-----------|
| `/startup` orchestration | `xhigh` (default) | Complex multi-step with decisions and document synthesis |
| `/light-spec`, `/roadmap-create` | `xhigh` | Intelligence-sensitive AI-to-AI contracts |
| `pk status`, `pk next`, `/phase-plan --status` | `high` | Lookup/summary tasks |
| `/update-method` routine syncs | `medium` | Mechanical, low ambiguity |
| `/06-linear-todo-runner` worker agents | `xhigh` | Each worker executes a full spec — needs high capability |

Don't port over old effort settings from Opus 4.6 blindly. Experiment. `xhigh` is the new default and works well for most Pipekit skills.

---

## Decision Table

| Situation | Reach for | Why |
|-----------|-----------|-----|
| Same pipeline step, context load-bearing | Continue | Nothing to reclaim |
| Claude went down a wrong path with good file reads | Rewind (Esc Esc) | Keep the reads, drop the attempt |
| Mid-task, session bloated with stale exploration | `/compact <hint>` | Low effort, steerable |
| Starting a new pipeline step | `/clear` or close + reopen | Zero rot; you control what carries forward |
| Resuming `/startup` next day | Close, reopen, let tracker restore | Tracker is Pipekit's curated `/clear` brief |
| Next step generates lots of tool output you only need the conclusion from | Subagent | Intermediate output stays in the child |
| Context approaching limit mid-startup | Commit current state, close, reopen | Don't let auto-compact corrupt the tracker |

---

## Related

- `/startup` — creates `{folder-name}-startup.md` tracker
- `/pipekit-update` — syncs skills; run it then close/reopen
- [Anthropic blog: Claude Code session management](https://www.anthropic.com/news/claude-code-session-management) — source material
- [Best practices for Opus 4.7 with Claude Code](https://www.anthropic.com/news/best-practices-opus-47-claude-code) — source material
