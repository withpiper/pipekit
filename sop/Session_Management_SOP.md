# Session Management SOP

> How to manage Claude Code sessions, context, and compaction during Pipekit work. Informed by Anthropic's guidance for Claude Code + Opus 4.8 and adapted for Pipekit's pipeline.

**v2.7.0** — Last updated: 2026-06-05  *(session boundaries reframed as cognitive-load not token scarcity; handoff & session-log content discipline section; effort table + `ultracode` row; 4.7→4.8 refresh)*

---

## Why This Matters

Claude Code's context window is one million tokens, but **context rot** — degradation of model performance as context grows — kicks in well before that limit. Attention spreads thin across more tokens, and stale content distracts from current tasks. How you manage sessions shapes your results more than effort level or prompting.

**Session boundaries exist for cognitive load, not token scarcity.** The 1M window and harness-persistent memory mean you rarely run *out of room* — so a boundary is never "make space," it's "drop the rot." This also means the boundaries here are distinct from the **stage-isolation** gates in `method.md` § Fresh-Chat Discipline: those are about *judgment independence* (an agent can't review work it helped produce) and are mandatory regardless of window size; the boundaries below are *hygiene* — optional, judgment calls about when stale context is hurting more than it helps.

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
| **End of any session** | **`/pk-exit`** | **Narrative session log to `Logs/Sessions/<date>_<HHMM>.md`. Run manually as the final command of every Claude Code session regardless of where the current issue stands. Per-session, not per-issue — never auto-chained from `/work` or `/verify`.** |

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

**Tell Claude explicitly when to use a subagent.** Recent Claude models default to fewer subagents than you might expect — spell it out. Examples:
- _"Spin up a subagent to verify the result of this work based on the following spec file."_
- _"Spin off a subagent to read through this other codebase and summarize how it implemented the auth flow, then implement it yourself in the same way."_
- _"Spin off a subagent to write the docs on this feature based on my git changes."_

**Mental test:** will I need the tool output again, or just the conclusion? If just the conclusion, spawn a subagent.

---

## Effort and Thinking Recommendations

These levels were calibrated on Opus 4.7. Treat the table as a **starting point, not a spec** — re-validate on your current model rather than assuming the mapping ports unchanged. The relative ordering (orchestration and AI-to-AI contracts want more effort than lookups and mechanical syncs) is the durable part; the specific level names may drift between releases.

| Task type | Effort level | Rationale |
|-----------|-------------|-----------|
| `/startup` orchestration | `xhigh` (default) | Complex multi-step with decisions and document synthesis |
| `/light-spec`, `/roadmap-create` | `xhigh` | Intelligence-sensitive AI-to-AI contracts |
| `pk status`, `pk next`, `/phase-plan --status` | `high` | Lookup/summary tasks |
| `/update-method` routine syncs | `medium` | Mechanical, low ambiguity |
| `/06-linear-todo-runner` worker agents | `xhigh` | Each worker executes a full spec — needs high capability |
| Codebase-wide audits, large migrations, multi-issue batches | `ultracode` | Claude Code's `/effort` menu option: pins `xhigh` **and** lets Claude auto-decide when to spawn a dynamic workflow (parallel subagents, verify-before-integrate). Token-heavy — reserve for work that genuinely spans many files or issues. Overlaps `/06-linear-todo-runner`'s hand-rolled parallel queue. |

Don't port effort settings between model releases blindly — experiment when you upgrade. As of the 4.7 calibration, `xhigh` worked well as the default for most Pipekit skills; confirm that still holds on your model before relying on it.

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

## Handoff & Session-Log Content Discipline

Handoff docs (`resources/`) and session logs (`Logs/Sessions/`) mix two kinds of content with very different shelf lives. The 1M window + harness memory carry *state* across sessions automatically — so the value of a written handoff is no longer "re-prime the next session," it's "preserve what the next session can't reconstruct on its own."

Split every handoff and log on this line:

| Keep (durable) | Let Linear + harness memory carry (ephemeral) |
|---|---|
| Decisions and the rationale behind them | Step-by-step "what to run next" |
| Gotchas / caveats (an API that writes state early; a team-name footgun) | Current status / what's deferred |
| Lessons learned the hard way | Command sequences the harness can regenerate |
| Gaps and open questions worth tracking | Pre-flight checklists for a one-time task |

**The test:** *would re-reading this in three months teach me something, or just recite what state things were in?* Keep the former; the latter is what Linear and harness memory already hold.

This does not delete handoffs — they stay committed cross-machine artifacts. It *slims* them: a 400-line migration runbook becomes a one-page durable record once the migration has run, and the procedural body lives in git history if anyone needs to replay it. See `resources/nebula-piper-pipekit-v2.5.0.1-handoff.md` for a handoff retrofitted to this shape.

---

## Related

- `/startup` — creates `{folder-name}-startup.md` tracker
- `/pipekit-update` — syncs skills; run it then close/reopen
- [Anthropic blog: Claude Code session management](https://www.anthropic.com/news/claude-code-session-management) — source material
- [Best practices for Opus 4.7 with Claude Code](https://www.anthropic.com/news/best-practices-opus-47-claude-code) — source material
