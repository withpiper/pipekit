# External Survey — Buy vs Build for Pipekit (April 2026)

**Question:** Is there a 2026 tool (or 2-tool combo) that replaces Pipekit's 1900-line skill prose + 417-line runbook, OR is Pipekit's niche genuinely empty?

**Pipekit's 10-step loop:** Pick issue → branch+worktree → AI plans → AI executes → human verifies → PR → merge to dev → exit worktree → cleanup → batch dev→main promote.

---

## 1. Top 3 Candidates That Could Replace Some/All of Pipekit

### A. Charlie (Charlie Labs) — Linear-native autonomous engineer

- **What it covers:** Steps 1–6 (issue pick → PR) for TypeScript work. Charlie is now a fully integrated **Linear Agent** — you assign a Linear issue to it and it produces a PR. Charlie V2 is a "runtime for durable, multi-step coding work across GitHub, Linear, and Slack." Daemons handle ongoing maintenance work.
- **What it doesn't:** TypeScript-only (per Charlie Labs blog); no opinionated spec/plan/review gates; doesn't manage worktrees on your machine (it's cloud); no dev↔main promotion ritual.
- **Solo-dev fit:** Excellent — Linear free tier includes agents at no extra cost; Charlie itself has its own pricing.
- **Maintenance:** Linear partnership announced May 2025; "Agents create work, daemons maintain it" landing page is current. Not acquired by Linear; tight partnership.
- **Verdict:** **Supplement, not replace.** If your stack is TS, Charlie eats steps 3–6. You'd still keep Pipekit's spec gate + dev/main promote logic. Not a fit if multi-language.

### B. Cursor Background Agents + Linear trigger + Graphite

- **What it covers:** Steps 1–7. Linear trigger fires Cursor Background Agent → agent runs in cloud worktree → Graphite (Cursor acquired Dec 2025) handles stacked PRs and merge queue. Cursor added "new and improved worktrees in the Agents Window" in 2026; Automations let you fire on Linear events.
- **What it doesn't:** No opinionated planning/spec gate. No "Stage 0 foundation" notion. No dev→main promote cadence. Lock-in to Cursor.
- **Solo-dev fit:** Very good — single vendor, single bill (~$20–40/mo + Graphite). Cursor + Linear + Graphite is the closest commercial 2-tool combo to "Pipekit out of a box."
- **Maintenance:** Cursor changelog is weekly; Graphite Agent active; Linear Cursor integration shipped Aug 2025.
- **Verdict:** **Could replace ~70% of Pipekit's plumbing**, but not the methodology. If you stop caring about VBW-style planning rigor, this is the path.

### C. BMAD-METHOD (open source, MIT)

- **What it covers:** Stage 0 + spec/plan/exec/QA — almost identical conceptual frame to Pipekit. 21 specialized agents, 50+ guided workflows, four-phase cycle (Analysis → Planning → Solutioning → Implementation), docs-as-source-of-truth, human-in-the-loop gates. ~72k stars territory in the spec-driven space.
- **What it doesn't:** No Linear glue, no worktree manager, no dev/main promote. It is *prose + agent definitions*, exactly the layer Pipekit is. So switching to BMAD means **trading your prose for someone else's prose** — but theirs has a community and 21 vetted agents.
- **Solo-dev fit:** Free, MIT, runs on Claude Code/Cursor/etc. Heavier than needed if you're solo (designed for "an organized development team").
- **Maintenance:** Very active in 2026; ecosystem of derivative tools (Spec Kitty, etc.).
- **Verdict:** **Closest spiritual sibling to Pipekit.** If you're tired of authoring methodology, fork BMAD and prune it instead of maintaining 1900 lines yourself. Honest assessment: this is the *real* "stop reinventing the wheel" move.

---

## 2. Tools to Layer In (Don't Replace)

| Tool | Slot it fills |
|------|---------------|
| **ccmanager** (kbwo) | TUI session manager across worktrees; multi-agent (Claude/Codex/Gemini); session hooks. Replaces ad-hoc terminal juggling. Active 2026. |
| **claude-squad** (smtg-ai) | 6.8k stars, Go TUI, worktree-first, diff/checkout/commit-and-push from inside TUI. Overlaps ccmanager — pick one. |
| **Graphite (gt)** | Stacked PRs + merge queue + Graphite Agent for AI review. Cursor-owned now, deeper Cursor integration through 2026. Slot: replaces your dev→main promote scripts if you adopt stacks. |
| **GitHub Spec Kit** | MIT CLI, 72k+ stars, cross-agent (works with Claude Code/Cursor/etc.), four-phase SDD workflow. Slot: replaces `/light-spec` template + spec-validator skill. |
| **Linear MCP server** | First-party. Slot: lets Claude Code drive Linear directly without your custom `/linear` skill plumbing. You're already using `mcp__linear-server__*`. |
| **Conductor (Melty Labs)** | Multi-Claude-Code agents on your machine in parallel, isolated worktrees, dashboard. Slot: replaces your batch-runner skill if you want a GUI. |
| **jujutsu (jj) + jj-skill** | First-class conflicts, automatic snapshotting — saves agents from clobbering work. Slot: VCS layer under everything else. Big bet but solves a real agent failure mode. |
| **Codex CLI subagents + Automations** | OpenAI's worktree-aware agent runner with scheduled background tasks. Slot: cross-vendor parity if you ever leave Claude. |

---

## 3. Niches Where Nothing Quite Exists (= Pipekit's defensible territory)

After surveying ~25 tools, these gaps are real:

1. **Opinionated solo-dev SDLC that wraps a *planning agent framework* (VBW) AND Linear AND worktrees AND dev/main promote.** Every commercial tool either targets teams (Charlie, Devin, Cursor for teams) or ignores the issue-tracker side (claude-squad, Conductor, jj-navi). BMAD is the closest, but it's framework-only — no Linear glue.
2. **The Stage-0 "Foundation contract" abstraction** (greenfield/brownfield/inherited entry modes). No surveyed tool has this. Most assume greenfield.
3. **Sync-safe overrides for methodology files.** Pipekit's `sync-method.sh` + `.claude/overrides/` pattern is unusual. BMAD doesn't have it; Spec Kit doesn't have it.
4. **dev → main promote cadence as a first-class ritual.** Trunk-based-development tools (Trunk.io) and stacked-PR tools (Graphite) handle the mechanics, but none codify the *batch every 1–3 merges* cadence.
5. **VBW-aware wrapping** — Pipekit explicitly carves out what VBW owns vs Pipekit owns. No tool surveyed has heard of VBW.

That said: items 2, 3, 5 are bespoke abstractions Pipekit *invented*. They're a niche only because nobody else needs them. Items 1 and 4 are real shared pain.

---

## 4. Full Tool Table

| Tool | Problem solved | Loop coverage | Solo fit | AI-agent depth | Maintained (≤6mo) | Cost | Verdict for you |
|------|---------------|---------------|----------|----------------|-------------------|------|-----------------|
| **Charlie Labs** | Linear-native autonomous TS engineer | 1–6 | Good | Native Linear Agent | Yes (active partnership) | Tiered, undisclosed | Supplement (TS only) |
| **Devin 2.0** | Autonomous SWE | 3–6 | OK at $20/mo Core | Deep, opaque | Yes | $20+ACUs | Ignore — opaque, not Linear-native |
| **OpenHands** | OSS Devin alt | 3–6 | OK | Deep; Linear "on roadmap" | Yes (v1.6 Mar 2026) | Free OSS | Ignore until Linear ships |
| **Cursor Background Agents** | Async cloud agents | 1–7 (with Linear trigger + Graphite) | Excellent | Deep; Linear/Slack/GH triggers | Yes | $20–40/mo | **Strong replacement candidate** |
| **Codex CLI** | OpenAI agent + worktrees + automations | 3–7 | Good | Deep; subagents, auto-PR | Yes | API usage | Layer-in alternative to Claude Code |
| **Aider** | Pair-programming CLI | 3–4 | Good | Shallow (no orchestration) | Yes | Free | Ignore (Claude Code wins) |
| **Continue.dev** | IDE assistant | 3–4 | OK | IDE-only | Yes | Free/paid | Ignore for this loop |
| **Replit Agent / Bolt / Lovable / v0** | Greenfield app gen | N/A | Wrong shape | Zero pipeline integration | Yes | Paid SaaS | Ignore |
| **Charlie (in Linear)** | See Charlie Labs above | — | — | — | — | — | Supplement |
| **Anthropic Claude Agent SDK / Managed Agents** | Build your own agents | Building blocks | DIY | Native Claude | Yes | API | You're already on it |
| **Claude Code subagents/skills/plugins** | In-CLI orchestration | 3–5 | Excellent | Native | Yes | Pro/API | **You're already using this — the right layer** |
| **ccmanager (kbwo)** | TUI for multi-agent worktrees | 2, 8 | Excellent | Cross-agent (8+ CLIs) | Yes | Free OSS | Layer in (you decided this) |
| **claude-squad (smtg-ai)** | Worktree TUI, 6.8k stars | 2, 5, 7, 8 | Excellent | Multi-agent | Yes | Free OSS | Layer in (alternative to ccmanager) |
| **Conductor (Melty Labs)** | Parallel Claude Code agents w/ dashboard | 2–5 | Good | Claude-only | Yes | Free | Layer in if you want GUI |
| **git-spice / Spr / ghstack** | Stacked PRs (CLI) | 6–7 | Good | Git-only | Mixed | Free OSS | Skip — Graphite ate this category |
| **jj (jujutsu) + jj-navi/jj-skill** | Better VCS for agents | 2, 8, 9 | Good | Agent-aware skills exist | Yes | Free OSS | Speculative — high reward, high learning curve |
| **worktree.dev** | Worktree GUI | 2, 8 | OK | Generic | Unclear | Unclear | Skip — ccmanager covers this |
| **Graphite (gt)** | Stacked PRs + AI review + merge queue | 6–7, 10 | Good | Graphite Agent + Cursor (acquirer) | Yes | Free tier + paid | Layer in for promote logic |
| **Aviator / Mergify** | Merge queue automation | 7, 10 | OK | Rules-based | Yes | Paid SaaS | Skip — Graphite simpler |
| **Trunk.io** | Trunk-based dev tooling | 7, 10 | OK | Code health + merge | Yes | Free tier | Skip unless you want quality gates |
| **Linear (native)** | Issue tracker + native AI agents | 1, 5 | Excellent (free) | Agents free on all plans; first-party MCP | Yes | Free tier | **Already core to your stack — keep** |
| **BMAD-METHOD** | Spec-driven SDLC framework | 1–9 | Heavy but free | Cross-agent | Very active | Free MIT | **Strong methodology replacement candidate** |
| **GitHub Spec Kit** | SDD CLI, cross-agent | 3 (spec) | Good | Cross-agent slash commands | Yes (72k+ stars) | Free MIT | Layer in (replace `/light-spec`) |
| **AWS Kiro** | SDD IDE, EARS notation | 1–5 | Heavy, AWS lock-in | Deep, AWS-only | Yes | AWS-priced | Ignore (lock-in) |
| **Tessl / OpenSpec / Intent** | SDD variants | 3 (spec) | Mixed | Varies | Yes | Mixed | Skip — Spec Kit is enough |
| **Nimbalyst** | Visual workspace for Codex/Claude/etc., worktrees, **built-in task tracker** | 1–8 | Good | Multi-agent + MCP | Yes (active 2026) | Open source; pricing page exists | **Worth a closer look — you said it was lacking; I confirm it does NOT have native Linear integration**, only generic MCP |
| **CCPM (Claude Code Project Manager)** | Project mgmt inside Claude Code | 1, 5 | OK | Claude-only | Yes | Free | Skip — you have Linear |
| **wshobson/agents** | OSS Claude Code multi-agent kit | 3–5 | Excellent | Claude-only | Yes | Free | Layer in for agent definitions |
| **claude-pipeline (aaddrick)** | Portable Claude Code multi-agent pipeline w/ skills/hooks/quality gates | 1–9 | Excellent | Claude-only | Active | Free | **Spiritual sibling — review before next Pipekit refactor** |

**What I couldn't confirm:** Pricing for Charlie Labs (no public page); whether Nimbalyst has any native Linear integration beyond generic MCP (their own marketing implies *not*); exact release cadence for Conductor (Melty Labs).

---

## 5. Bottom-Line Recommendation: **Stay + ruthlessly simplify** (with one fork-decision to make)

**The honest read:** No single tool replaces Pipekit. The closest 2-tool combo is **Cursor Background Agents + Linear + Graphite**, which would cover ~70% of the mechanical loop (steps 1–7 + 10) but throws away your VBW planning layer and your dev/main promote opinions. That's a real product decision, not a tooling one.

**Three viable paths, ranked by my read on burnout risk:**

1. **Fork BMAD-METHOD, delete 80% of it, bolt on your Linear/VBW/dev-promote glue.** This is the "stop reinventing the wheel" move. You inherit 21 agent definitions, 50+ workflows, and an active community that maintains the prose for you. Your unique value moves from "I wrote the methodology" to "I integrated it with VBW + Linear + dev/main." That glue is ~300 lines, not 1900. **Highest leverage.**

2. **Keep Pipekit, but cut to the bone:** delete `/concept`, `/define`, `/strategy-create`, `/startup` (Stage 0 — you've used them once), shrink the 417-line runbook to ≤80 lines, replace `/light-spec` with Spec Kit, replace your worktree skills with `ccmanager` invocations, drop `launch-native` (the VBW A/B test). Target: <500 lines total. Pipekit becomes a thin Linear+VBW+dev-promote shim. **Lowest switching cost, addresses the burnout symptom.**

3. **Switch to Cursor + Linear + Graphite + Charlie** for TS-only work. Accept the loss of VBW planning rigor as a feature, not a bug. **Highest velocity, biggest philosophical change.**

**My honest pick if I had to bet your time on one:** Path 2 first (1-week sprint to delete cruft), then re-evaluate in a month whether Path 1 is worth the BMAD migration. Path 3 is a rewrite of your habits, not just your tools — only do it if you've decided VBW isn't pulling its weight.

The 1900 lines exist because you genuinely solved 5 niche problems nobody else solved. Three of them (Stage 0 contract, sync-safe overrides, VBW carve-out) are bespoke abstractions only *you* need. Two of them (solo-dev SDLC + dev/main cadence) are real gaps in the 2026 market — but they're 200-line gaps, not 1900-line gaps. The rest is methodology prose that BMAD or Spec Kit will write for you.

---

## Sources

- [Nimbalyst homepage](https://nimbalyst.com/) and [Nimbalyst vs Cursor comparison](https://nimbalyst.com/why-nimbalyst/)
- [Nimbalyst — best worktree tools 2026](https://nimbalyst.com/blog/best-git-worktree-tools-ai-coding-2026/)
- [Nimbalyst — best multi-agent tools 2026](https://nimbalyst.com/blog/best-multi-agent-coding-tools-2026/)
- [Charlie Labs — Charlie joins Linear Agents](https://www.charlielabs.ai/changelog?entry=2025-05-29-linear-agent)
- [Charlie Labs homepage](https://charlielabs.ai/)
- [Linear — Charlie integration](https://linear.app/integrations/charlie)
- [Linear AI Agents docs](https://linear.app/docs/agents-in-linear)
- [Linear adopts agentic AI — The Register](https://www.theregister.com/2026/03/26/linear_agent/)
- [ccmanager (kbwo) — GitHub](https://github.com/kbwo/ccmanager)
- [claude-squad (smtg-ai) — GitHub](https://github.com/smtg-ai/claude-squad)
- [Conductor × Portkey](https://portkey.ai/blog/conductor-x-portkey-is-now-live/)
- [Conductors to Orchestrators — O'Reilly](https://www.oreilly.com/radar/conductors-to-orchestrators-the-future-of-agentic-coding/)
- [BMAD-METHOD — GitHub](https://github.com/bmad-code-org/BMAD-METHOD) and [docs](https://docs.bmad-method.org/)
- [GitHub Spec Kit](https://github.com/github/spec-kit)
- [Martin Fowler — SDD tools comparison (Kiro/Spec Kit/Tessl)](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html)
- [Augment — 6 best SDD tools 2026](https://www.augmentcode.com/tools/best-spec-driven-development-tools)
- [Devin 2.0 pricing — VentureBeat](https://venturebeat.com/programming-development/devin-2-0-is-here-cognition-slashes-price-of-ai-software-engineer-to-20-per-month-from-500)
- [Devin pricing page](https://devin.ai/pricing/)
- [OpenHands homepage](https://openhands.dev/) and [GitHub](https://github.com/OpenHands/OpenHands)
- [Cursor changelog](https://cursor.com/changelog) and [product page](https://cursor.com/product)
- [Linear — Cursor background agents changelog](https://linear.app/changelog/2025-08-21-cursor-agent)
- [Cursor Automations — Tessl writeup](https://tessl.io/blog/cursor-launches-automations-for-always-on-coding-agents/)
- [Codex CLI docs](https://developers.openai.com/codex/cli) and [features](https://developers.openai.com/codex/cli/features)
- [Graphite stacked PRs](https://graphite.com/blog/stacked-prs)
- [GitHub ships stacked PRs — Agent Wars](https://www.agent-wars.com/news/2026-04-13-github-stacked-prs)
- [Graphite acquired by Cursor — Gitar analysis](https://cms.gitar.ai/automated-merge-queues-graphite-2026/)
- [Linear–MCP + OpenSpec SDD workflow](https://intent-driven.dev/blog/2026/01/11/linear-mcp-openspec-sdd-workflow/)
- [Linear pricing 2026 — Quackback](https://quackback.io/blog/linear-pricing)
- [jj for AI coding agents — Panozzaj blog](https://www.panozzaj.com/blog/2025/11/22/avoid-losing-work-with-jujutsu-jj-for-ai-coding-agents/)
- [jj-navi orchestrator](https://github.com/eersnington/jj-navi/tree/main/)
- [Claude Code subagents docs](https://code.claude.com/docs/en/sub-agents)
- [claude-pipeline (aaddrick)](https://github.com/aaddrick/claude-pipeline)
- [wshobson/agents](https://github.com/wshobson/agents)
- [Claude Code hooks/subagents/skills guide](https://ofox.ai/blog/claude-code-hooks-subagents-skills-complete-guide-2026/)
