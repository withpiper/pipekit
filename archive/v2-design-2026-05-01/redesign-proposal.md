# Pipekit Minimum Viable Loop — Redesign Proposal

## 1. Executive Summary

The current Pipekit loop is bloated because it was designed for a multi-user, multi-session, parallel-worktree future that the actual user (one solo dev) does not live in. State is duplicated across NEXT.md, session logs, a pending-next-md cache, Linear, git, and GitHub. Skills carry 200+ lines of prose for tasks (worktree creation, Linear status transitions, PR open) where the LLM adds zero value. Plan-review has a tiered verdict loop designed to defend against bad agents that, in practice, almost always returns "Pass" on the first try.

**Proposed system: 4 skills + 5 deterministic shell scripts + 2 hooks + Linear as the single source of truth for "what's next."** Total skill prose budget: ~600 lines (down from ~1900). NEXT.md is deleted. Session logs collapse to a single append-only file per branch, written by a hook. Plan/Quick/Standard/Heavy tiers collapse to one default flow with an opt-in `--deep` flag. Recovery becomes "rerun the same command" because every command is idempotent against Linear+git ground truth.

**Deletions: NEXT.md, pending-next-md.json cache, /start-session, /end-session as separate skills, Quick/Heavy tiers, /pipekit-help, the 3-round verdict stalemate detector, dev-branch batching (optional — see §8).**

---

## 2. State Model

### Three places, no fourth.

```
+----------------------------------------------------------+
|  LINEAR  (source of truth for "what's next" + status)    |
|  - Issue list, status (Todo / In Progress / In Review /  |
|    Done), assignee, spec body, comments                  |
|  - Queried live via Linear MCP. NEVER mirrored to disk.  |
+----------------------------------------------------------+
                            |
                            v
+----------------------------------------------------------+
|  GIT + GITHUB  (source of truth for "what's in flight")  |
|  - Branch existence == work in flight                    |
|  - Worktree existence == active session                  |
|  - PR existence + status == ship state                   |
|  - Branch name encodes Linear ID: eth/PIP-123-slug       |
+----------------------------------------------------------+
                            |
                            v
+----------------------------------------------------------+
|  .pipekit/journal/<branch>.md  (per-branch session log)  |
|  - Append-only. Written by a Stop hook + commit hook.    |
|  - Reflections, decisions, links to PR/Linear.           |
|  - Lives IN the branch (travels with the work).          |
|  - Deleted with the branch on shutdown (after PR merge   |
|    extracts useful bits to Linear comment).              |
+----------------------------------------------------------+
```

**Why three:** Linear answers "what should I work on?" Git/GitHub answers "what am I working on right now?" The journal answers "what did I think while doing it?" Anything else (NEXT.md, pending caches, PHASES.md as state) is a derived view and should be computed on demand, not stored.

**Killed state:** `NEXT.md` (derive from Linear), `~/.cache/pipekit/<repo>/pending-next-md.json` (no NEXT.md = no pending), `Logs/Sessions/*` as a separate tree (collapse into per-branch journal), Linear-map.json (use Linear API live).

---

## 3. The 10 Commands

| # | Step | Command | Type | LOC budget | Touches | Does NOT touch |
|---|------|---------|------|------------|---------|----------------|
| 1 | Start | `pk next` | **script** | 40 | Linear MCP read; git read; prints next issue + suggested command | nothing — read-only |
| 2 | Branch | `pk branch <issue-id>` | **script** | 80 | git worktree add; branch create; Linear status → "In Progress"; cd helper | spec content; agents; PR |
| 3 | Launch | `/work` (skill) | **skill** | 200 | reads spec from Linear; chooses planner agent; presents plan | git; PRs; Linear status |
| 4 | Plan | (part of `/work`) | **skill** | (in /work) | shows plan, asks human verdict (one prompt, no rounds) | nothing extra |
| 5 | Work | (part of `/work`) | **skill** | (in /work) | dispatches dev agent; commits via existing pre-commit hook | PR; merge |
| 6 | UAT | `/verify` (skill) | **skill** | 150 | runs tests; spawns QA review agent; produces verdict | git push; PR |
| 7 | Final paperwork | (Stop hook) | **hook** | 30 (script) | appends to `.pipekit/journal/<branch>.md` on Claude Stop event | NEXT.md (deleted), Linear status |
| 8 | Ship-Dev | `pk ship` | **script** | 100 | push; `gh pr create`; Linear status → "In Review"; auto-merge if green | spec; agents |
| 9 | Exit | (no command) | **nothing** | 0 | closing the Claude session is the exit | — |
| 10 | Shutdown branch | `pk done` | **script** | 60 | verifies PR merged; extracts journal highlights → Linear comment; deletes worktree + branch; Linear → "Done" | nothing else |

**Skills count: 2 (`/work`, `/verify`).** Plus retained orthogonal skills (`/brainstorm`, `/light-spec`, `/strategy-sync`, `/pr-fix`) that aren't part of the daily loop.

**Scripts count: 5** (`pk next`, `pk branch`, `pk ship`, `pk done`, plus `pk` dispatcher). All in `bin/pk` as a single bash file ~300 LOC total. No node, no python.

**Hooks count: 2** — Stop hook (journal append), post-commit hook (journal append commit summary).

### Why this split

- **Skills (LLM prose) only where the LLM is the actual worker:** planning code, reviewing code, writing tests. Worktree creation and PR opening are deterministic — using a skill there is paying Sonnet/Opus tokens to run `gh pr create`.
- **Scripts for state transitions:** they're idempotent, fast, debuggable with `bash -x`, and don't drift.
- **Hooks for paperwork:** the user shouldn't have to remember to log. The harness fires Stop, the journal updates.

---

## 4. Plan-Review Tier Collapse

**Verdict: delete Quick/Standard/Heavy. Replace with one flag.**

Reasoning: tiers exist to control cost and rigor. With one user, one judgment call, the user knows when they need rigor — they don't need a skill to ask them. Default `/work` runs: planner → human eyeballs plan (one screen, accept/reject/edit) → dev → tests. That's it.

For genuinely scary changes, `/work --deep` adds: spec-validator pre-check, plan-review subagent, post-implementation security-review subagent. Same skill, one branch.

**The 3-round verdict stalemate detector dies.** If a plan needs 3 rounds, the spec is bad — go back to `/light-spec-revise`. Detect that condition once, exit, tell the user. No loop.

---

## 5. Current Pipekit → Proposed Mapping

| Current skill | Verdict | Replacement |
|---|---|---|
| `/start-session` | **DELETE** | `pk next` script (40 LOC) |
| `/end-session` | **DELETE** | Stop hook writes journal; `pk ship` handles state transition |
| `/branch` | **REPLACE with script** | `pk branch <id>` (80 LOC bash) |
| `/launch` | **SHRINK to <200 lines** | becomes `/work`; tiers gone, auto/manual gone, just plan→verdict→dev |
| `/launch-native` | **DELETE** | merged into `/work` (the native variant wins; VBW dependency dropped from the daily loop) |
| `/review-plan` | **DELETE as standalone** | inline in `/work`; one-screen verdict |
| `/pipekit-help` | **DELETE** | `pk next` answers "what's next?" deterministically |
| `/spec-preflight` | **KEEP**, shrink to ~80 lines | called automatically by `/work --deep`; standalone for ad-hoc |
| `/light-spec` | **KEEP** (Stage 0, not daily loop) | unchanged |
| `/light-spec-revise` | **KEEP** | unchanged |
| `/spec-validator` | **KEEP**, used by `/work --deep` | unchanged |
| `/06-linear-todo-runner` | **KEEP** for batch mode | orthogonal — not in daily loop |
| `/00-roadmap-review` | **KEEP** (Stage 0) | unchanged |
| `/phase-plan` | **KEEP** (Stage 0) | unchanged |
| `/sync-linear` | **DELETE** | Linear is the source of truth; nothing to sync to |
| `/linear-status` | **REPLACE with script** | `pk status` (20 LOC, calls Linear MCP via gh-style CLI or `linear` CLI) |
| `/linear` | **DELETE** | absorbed into `pk branch` + `pk ship` |
| `/g-promote-dev` | **KEEP if dev branch survives**, else DELETE | see §8 |
| `/release-changelog` | **KEEP** | orthogonal, run on main merges |
| `/strategy-sync` | **KEEP** | orthogonal, post-ship |
| `/pr-fix` | **KEEP** | orthogonal, used during review |
| `/security-review` | **KEEP** | called by `/work --deep` |
| `/concept`, `/define`, `/strategy-create`, `/startup`, `/roadmap-create` | **KEEP** | Stage 0, run once per project |
| `/brainstorm`, `/brainstorm-review` | **KEEP** | orthogonal triage |
| `/pipekit-update` | **KEEP** | meta |
| `/skill-index`, `/task-processor` | **DELETE or audit** | unclear value in solo loop |

**Net daily-loop skill count: 2 (`/work`, `/verify`).** Down from ~10 active skills in the current loop.

---

## 6. The "Between Sessions" Problem — `pk next`

NEXT.md exists because the user wakes up, opens a terminal, and asks "what was I doing?" Three options were considered:

1. Keep NEXT.md, fix sync bugs.
2. Delete NEXT.md, derive answer live from Linear+git.
3. Hybrid: cache last answer, refresh on demand.

**Pick #2.** A 30–40 line bash script:

```bash
# pk next — pseudocode
current_branch=$(git branch --show-current)
if [[ "$current_branch" =~ ^[a-z]+/([A-Z]+-[0-9]+) ]]; then
  issue="${BASH_REMATCH[1]}"
  pr=$(gh pr view "$current_branch" --json state,url 2>/dev/null)
  if [[ -n "$pr" ]]; then
    echo "In flight: $issue — PR $url ($state). Run: pk ship  OR  pk done"
  else
    echo "In flight: $issue — no PR yet. Run: /work  OR  pk ship"
  fi
  exit 0
fi
# Not on a feature branch — find next Todo
next=$(linear-mcp list-issues --state Todo --assignee me --priority desc --limit 1)
echo "Next up: $next. Run: pk branch $(echo $next | jq .id)"
```

That's it. No mirror file, no cache, no drift. If Linear is down, the script says so. If git state is weird, the script says so.

**`pk next` is the answer to "what do I run now?"** It always works because it reads ground truth, never a mirror.

---

## 7. Failure Model — "Rerun the Same Command"

Every command is idempotent against Linear+git state. The user never reads a recovery procedure.

| Failure | Current pain | New behavior |
|---|---|---|
| `pk branch` fails mid-way (worktree created, Linear not updated) | Recovery procedure | Rerun `pk branch PIP-123`. Script checks: worktree exists? skip. Linear status correct? skip. Done. |
| `/work` crashes during plan | Manual cleanup | Rerun `/work`. Reads branch + Linear, picks up from state (no plan committed → re-plan; plan committed → skip to dev). |
| `pk ship` fails after PR open but before Linear update | Manual Linear update | Rerun `pk ship`. PR exists? skip create, just update Linear. |
| `pk done` fails | Stuck branch | Rerun. If PR merged, complete cleanup. If not, error: "PR not merged yet." |
| Hook fails to write journal | Silent loss | Hook is best-effort, errors logged to stderr, never blocks. |

**The discipline:** every script's first 5 lines are "read current state, decide what's left to do, do only that." No assumption that previous step succeeded. This is the same shape as `terraform apply` or `make`.

---

## 8. PR / Merge Strategy

**Recommendation: kill the dev branch for solo work. Feature → main with squash merge, branch protection via Ruleset, optional batch dev branch only when shipping multiple features that need integration testing together.**

Reasoning:
- Dev branch's value is integration testing across multiple in-flight features. Solo dev rarely has 3 in flight at once.
- Two-step merge (feature→dev, dev→main) doubles PR overhead.
- Squash to main keeps history clean and Ruleset-enforced.
- If you ever need to batch (e.g., a UI overhaul touching many files alongside backend work), spin up a temporary `integration/<topic>` branch ad hoc — don't make it permanent.

**Net change:** `pk ship` opens PR against `main`. `g-promote-dev` becomes optional / used rarely. Deletes the per-branch merge enforcement complexity from v1.8.0.6 in the daily path.

If the user disagrees and wants dev preserved (e.g., for staging deploys triggered off `dev`), `pk ship --to dev` keeps the option. But default is `main`.

---

## Open Questions

1. **Staging deploys.** Does the user have a `dev` branch deploy to a staging env that humans test against? If yes, killing dev branch breaks that pipeline — keep dev as default. If no (or staging is triggered by a separate flow), kill it.

2. **VBW dependency.** `/work` as designed drops VBW agents in favor of native Claude Code Agent tool. Is the user committed enough to VBW (`/vbw:lead`, `/vbw:dev`) that ripping it out of the daily loop is a regression? `/launch-native` exists as an A/B test — has it actually been validated as equivalent quality?

3. **Linear MCP rate limits / latency.** `pk next` calls Linear on every invocation. If MCP is slow (>2s), this becomes annoying. Cache for 60s in `/tmp`? Or accept the latency as honesty?

4. **Journal location.** Putting `.pipekit/journal/<branch>.md` *in the branch* means it travels with the work and dies with the branch. But it also means it shows up in PR diffs. Alternative: keep journal in `~/.local/share/pipekit/<repo>/<branch>.md` (out of repo). Cleaner for PRs, but less portable across machines. Lean toward in-repo with `.gitignore` exclusion of `.pipekit/journal/`, or just commit them — they're useful PR context.

5. **Stage 0 scope.** This proposal touches the daily Branch→Ship loop only. Stage 0 (concept→roadmap) is left intact because it runs once and the LLM prose actually adds value there (synthesis, not state transitions). Confirm that's the right scope.

6. **Existing in-flight branches.** Migration path: do we cut over cold (next branch uses new system) or convert existing worktrees? Cold cutover is simpler.

7. **`/verify` vs. just running tests.** Step 6 (UAT) — is there real value in a QA-review subagent, or is "run the test suite + manual smoke test" sufficient? If the latter, `/verify` collapses into a script `pk verify` that runs the test command from `method.config.md` and exits. Skill count drops to 1.

8. **ccmanager / claude-squad.** These are TUIs over worktrees. Does the user actually use them daily, or are they aspirational? If daily, `pk` scripts must not conflict with their state model (branch naming, worktree paths). If aspirational, ignore.

---

## Word count check
~2050 words. Opinionated. Backwards-compatibility ignored per instructions.
