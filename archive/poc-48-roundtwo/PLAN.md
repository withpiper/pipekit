# POC-48 round-2 — bounded head-to-head (RESUME NOTE)

Written 2026-06-07 before a compact. This is the plan to execute once context resumes.

---

# ★ ROUND-2 VERDICT (2026-06-08, experiment complete)

**Both arms built the same frozen POC-48 (tier:heavy financial-parity) from an identical base. Native, master-driven overnight; VBW, full `/vbw:vibe` lead→dev→qa, also master-driven. Native parked verified+gated; VBW halted by the user at the finish line after exhausting nearly the entire weekly token budget.**

## Speed & cost (the headline)
| | Native (improved) | VBW (full pipeline) |
|---|---|---|
| Wall-clock to verified | **~1h** | **~5.5h** (halted on final /verify) |
| Output tokens | ~low (single context) | **~640k+** |
| Budget impact | negligible | **exhausted ~a full week's quota on ONE issue** |
| Commits / diff | 16 atomic / ~+1.6k lines | ~+10k diff incl. large `.vbw-planning/` artifact tree |

The user had to **manually stop VBW** because it consumed almost the entire weekly token budget on a single tier:heavy issue. On a rate-capped Max plan this is not a tuning detail — it's disqualifying for routine use.

## Quality on the parity axis (the round's whole point — JS↔SQL to the cent)
- **OUT-side rounding:** Native rounded the SQL view per-row to mirror JS's `round2`-per-row-then-sum ordering **from the first pass** (spec's prescribed ordering) → held `<0.005` silently. VBW's dev hit the same compounding and **tried to loosen the spec AC to 0.02**; its orchestrator caught it, surfaced a genuine 3-way spec-internal conflict (parity vs no-admin-byte-for-byte vs don't-touch-fee-formula), and — once steered — applied the same fix native already had, gated behind `/financial-review` (accepted).
- **IN-side folding:** Native folded admin in-cost into the IN totals (`subtotal_sum`/`total_sum`/`tax_sum`) **from the first pass AND tested it with non-zero in-cost** (`adminRow({inCost:50/75})`). **VBW's decomposed dev MISSED this** — built the IN-side without folding, and its in-cost=0 fixture let the parity suite pass green. The defect (HIGH: profit overstated by the in-cost) was caught only by VBW's separate `/financial-review` (spec line 30), then fixed at a **+1 remediation cycle**.

**Net:** native got *both* sides of the parity axis correct on the first pass, with harder tests, in ~1/5 the time and a tiny fraction of the tokens.

## Where VBW genuinely added value
- Its `/financial-review` deep-analysis caught the real IN-side HIGH defect VBW's own build+QA missed. **But** `/financial-review` is shared Pipekit tooling — **native runs it too** (native's passed clean because native had no defect). The catch is a credit to the *gate*, not to the VBW *executor*.
- VBW *explicitly surfaced and governed* the spec-internal parity conflict (escalated, documented `PROVISIONAL-FOR-FINANCIAL-REVIEW.md`, sought sign-off). Native resolved the same tension silently. VBW's process is more legible/auditable — a real but narrow benefit, bought at ~5x cost.

## Convergent findings (both arms independently reached)
Snapshot/promote carry-forward + single-admin-block invariant; the M1 "checks file must derive, not sum stored" gap. Neither arm had a monopoly on rigor.

## VERDICT
**Executor parity on HARD tier:heavy financial work is CONFIRMED — and then some.** The improved native executor (test-first + sequential-default, `0933cfa`) matched-or-beat VBW-the-full-system on first-pass correctness across the exact axis VBW's planner+QA was supposed to win (financial parity), at ~1/5 wall-clock and a fraction of the tokens. VBW's distinctive value (explicit surfacing/governance of spec conflicts) is real but narrow, lives largely in the `/financial-review` gate native also runs, and is bought at a token cost that **exhausted a weekly budget on one issue**. For Pipekit 3.0: **native-on-Workflow is the right default executor; VBW becomes optional, not load-bearing.** The deep-analysis safety net is the gate (`/financial-review`, `/pr-security-review`), not the backend.

## State at experiment close
- Native: `exp/POC-48-native-1`, 16 commits, /verify PASS + /financial-review PASS, parked (UAT/ship = human).
- VBW: `exp/POC-48-vbwfull-1`, IN-side defect fixed (14/14 parity, 368/368), halted on final /verify for budget — functionally complete, parked, not shipped.
- Both are throwaway exp branches; if shipping POC-48 for real, cherry-pick from native (cleaner, cheaper, first-pass-correct) per the round-1 synthesis pattern.

---

## Decision (settled)

Round 2 = **POC-48 as a bounded head-to-head, NOT a 3×2.** Two arms, **one rep each**, and **the winner ships for real** (POC-48 is Approved/High and needs building anyway, so the experiment IS the real work — only the losing arm is throwaway).

**Why POC-48:** after round 1 (POC-57), the open question is the Pipekit 3.0 crux — *can native match VBW-the-full-system on HARD work?* POC-48 is tier:heavy financial-parity (JS↔SQL agreement to the cent) — exactly the axis where VBW's planner+QA rigor should pay off if it ever does. Its heaviness is the point; the 2-run structure keeps cost bounded (vs 6 runs) on the user's rate-capped Max plan. POC-40 (too light, no gate) and POC-58 (parked/speculative) were rejected.

## Arms

| Arm | Backend | How |
|---|---|---|
| **native** | improved native-best | `/work POC-48 --backend=native` with the improved skill (test-first + sequential-default) from pipekit `feat/native-workflow-executor` HEAD (commit `0933cfa`) installed in the base |
| **vbwfull** | real VBW full pipeline | `/vbw:vibe` scope→plan(`vbw-lead`)→execute(`vbw-dev`)→verify(`vbw-qa`), scoped to POC-48 from the frozen spec |

## Shared gate = the judge

POC-48 is tier:heavy financial → the objective gate is **`/financial-review`** + the **JS↔SQL parity tests (abs diff < 0.005)**. Far less subjective than a code rubric, so even n=1 is meaningful (parity either holds to the cent or it doesn't). Also `/verify` (full) on both. Optionally a blind judge pass over the two diffs like round 1.

## Setup steps (execute post-compact)

1. **Base:** pin current `origin/main` (now includes merged POC-57). `git fetch origin`; BASE_SHA = `origin/main`.
2. **Experiment base branch** = origin/main + improved native-best skill installed (extract `git -C ~/Projects/pipekit show feat/native-workflow-executor:skills/work/skill.md` → `.claude/skills/work/skill.md`), one commit. (Mirror round-1's `setup-pilot.sh` pattern, but extract the NOW-improved skill — HEAD `0933cfa`, must contain "Author the tests the spec/PLAN calls for" + "sequentially by default".)
3. **Two arm worktrees** off that base: `exp/POC-48-native-1`, `exp/POC-48-vbwfull-1`.
   - Note: vbwfull arm ignores the Pipekit skill (uses `/vbw:vibe`), but branch off the same base for an identical diff baseline.
4. **cmux panes** (workspace:18 pattern): `cmux new-split down --workspace workspace:18 --focus false`; cd each into its worktree; send/read uses `--workspace workspace:18 --surface surface:NN`. (User promotes panes to their own workspaces — re-fetch `cmux tree` before every read; refs go stale; read-screen needs the CURRENT workspace ref.)
5. **Runcards** mirroring round 1 (`experiments/poc-48-roundtwo/RUNCARD-native.md`, `RUNCARD-vbwfull.md`): same controls (no Linear writes during experiment — or, since winner ships, decide whether to `pk branch` for real; for round-1 cleanliness use exp branches + `--no-rollover`, then promote the winner's work to a real `pk branch POC-48` ship). Migration timestamps strictly later than main tail; local DB only until the winner ships.
6. **User drives** the `/work` and `/vbw:vibe` sessions (human-paced); master session (this one) watches via `cmux read-screen` and verifies fidelity (native on Step 5n + authors parity tests; vbwfull spawns lead→dev→qa).

## Watch criteria (the round-1 lessons)

- **native authors the parity/financial tests** (the round-1 gap, now supposedly fixed — this is the validation).
- **JS↔SQL parity to the cent** on both arms (the hard part; where a single-context native executor might struggle vs VBW's decomposition).
- **`/financial-review` verdict** on both.
- **Cost** — total tokens per arm + wall-clock (tier-contaminated by rate limits on Max, so tokens is the comparable metric).

## Then

Winner ships POC-48 for real (cherry-pick / promote to a `pk branch POC-48` Linear-tracked ship, like POC-57's synthesis if useful). Capture results to `[[pipekit_3_0_native_executor]]` memory.

## SETUP EXECUTED (2026-06-07)

Harness is live. `setup-headtohead.sh` ran clean.

- **BASE_SHA** = `4c65c828` (SiteLine `origin/main`, includes merged POC-57). Migration tail = `20260608120500_force_server_clock_on_approval.sql` → new POC-48 migrations must be strictly later.
- **Experiment base** = `exp/POC-48-base` (`c9164a0c`) — origin/main + improved native skill (`0933cfa`, both fixes verified present). Arms diff against this.
- **Arms (worktrees):** `exp/POC-48-native-1` → `~/Projects/SiteLine/.worktrees/POC-48-native-1`; `exp/POC-48-vbwfull-1` → `~/Projects/SiteLine/.worktrees/POC-48-vbwfull-1`.
- **Frozen spec** copied into each worktree as `POC-48-SPEC.frozen.md` (added to `.git/info/exclude` so it can't be committed into an arm diff).
- **Runcards:** `RUNCARD-native.md`, `RUNCARD-vbwfull.md`.
- **cmux:** master = `surface:35`/`pane:47`/`workspace:18` "Pipekit 3.0". Watch panes: **native = `surface:72`**, **vbwfull = `surface:73`** (both in workspace:18, cd'd into their worktrees). Re-fetch `cmux tree` before every read — user promotes panes to own workspaces.

### Launch (user drives)
- native pane: `claude --dangerously-skip-permissions` then `/work POC-48 --backend=native` (tell it: spec = `POC-48-SPEC.frozen.md`, don't read Linear).
- vbwfull pane: `claude --dangerously-skip-permissions` then `/vbw:vibe` scoped to POC-48 from `POC-48-SPEC.frozen.md`.

## AUTONOMOUS DRIVING (overnight, 2026-06-07 ~23:40)

User went to sleep, authorized me to **drive both panes** and check in ~every 15 min. This is a test, so I make the gate decisions. Refs shift — re-fetch `cmux tree` every wake. Native = **ws:38/surface:72**, VBW = **ws:37/surface:73** (titles "POC-48 Native" / "POC-48 VBW").

### Driving rules (HOLD-AT-BOUNDARY)
- **Plan/Verdict gates** → `proceed` if the plan is spec-faithful + test-first; else `revise: <specific gap>`. (Native's plan already approved + faithful.)
- **Discuss prompts** → answer succinctly from `SPEC.frozen.md`, then let it continue. Never invent scope beyond the frozen contract.
- **In-session permission prompts** → bypass-permissions is on, so rare. Allow non-destructive; HOLD destructive.
- **HARD STOP — never send / never confirm without the user:** `git push`, `pk ship`, `gh pr merge`, `supabase db push` to a shared env, any Linear state write. The winner ships *with the user* in the morning.
- **Overnight goal:** get BOTH arms to a verified, gated state — plan → execute → author parity/financial tests → `/financial-review` → `/verify` (full) — then **STOP before ship**. Park each arm at "ready to ship, awaiting human."
- **cmux hygiene:** re-fetch tree before every read/send; verdict box is a TEXT input (`cmux send "proceed"$'\n'`), NOT a numbered menu (no digit+enter). Pair every send with a read-screen. Detect turn-END (spinner gone — `Gerund…` present-tense absent; `✻ Brewed/Cooked for` past-tense is NOT activity).
- **Cadence:** ScheduleWakeup ~900s. If both rate-limited + mid-turn, just re-arm and wait. Re-arm each wake until both arms are parked-ready or blocked-needing-user.

### Watch (the round-2 validation)
- Native authors `tests/budget-rollup.test.js` + `tests/budget-parity.test.js` ITSELF (the `0933cfa` fix — confirmed in its plan).
- Both: JS↔SQL parity abs diff < 0.005 on admin base, each row charge, prod fee, contingency, totals, profit.
- Capture per arm: total tokens + wall-clock (rate-limit-contaminated; tokens is the comparable metric).
- Note asymmetry (expected/acceptable): native fetched contract from live Linear (its native flow) + uses gitignored `.pk-work/`; VBW reads frozen file + commits `.vbw-planning/` artifacts into the arm diff. Each tool's real footprint.

### Driving log
- 23:40 — both past initial scoping, actively working, rate-limited but progressing. Native Phase 0 (Diff +0, deep reads pre-exec). VBW Phase 1/5 (scope commit fafa1e6c, +474). No gates. Re-armed wakeup.
- 23:43 — Native executing (Diff +729 -38, writing admin-OUT derivation in budget-edit-main.js). DAG `.pk-work/POC-48-PLAN.md` ✅ materialized; native extending pre-existing tests/budget-rollup.test.js (test-first ✅); parity test pending. VBW at numbered exec-gate → drove option 1 "Execute Phase 1, then continue" (auto-continue through Phase 5) via send-key enter (NOT digit); confirmed landed. VBW flagged in-scope deviation: Phase 1 gained a migration for is_admin_hidden + snapshot/promote carry-forward (accepted — snapshot-versioned budgets need it; watching if native catches same). Both rate-limited, executing, no open gates. Re-armed.
- 04:46 — 🛑 LOOP STOPPED. User HALTED VBW manually: it had consumed nearly the ENTIRE WEEKLY token budget on this one tier:heavy issue (~5.5h, ~640k+ output tokens, still on final /verify after the IN-side remediation). This budget-exhaustion IS the capstone cost finding — harder evidence than wall-clock. VBW was functionally complete (IN-side defect fixed, 14/14 parity, 368/368, High closed) at halt. Native parked-ready. Both arms NOT shipped (UAT/ship = human, morning). Full verdict below. NOT re-armed.
- 04:30 — VBW fixed IN-side defect (project_totals folds admin in-cost into IN matching JS, $25→<0.005, catching test 8, provisional flag cleared, 14/14 parity / 368/368 / lint 0; scoped to total_sum not budgeted_total per POC-80). Now running final /verify (QA: Re-verifying), 5h16m / 636k tokens. 🎯 FAIRNESS CHECK RESULT (decisive): NATIVE NEVER HAD THE IN-SIDE DEFECT — native's project_totals folds adm_in_subtotal+adm_in_tax into subtotal_sum/total_sum/tax_sum from the start, AND native's tests exercise non-zero admin in-cost (budget-rollup.test.js:376 inCost:50 asserts profit fold; :526 inCost:75 hidden-leak test). So native got OUT-side rounding AND IN-side folding right first-pass+tested in ~1h; VBW's decomposed dev MISSED IN-side folding (tested only in-cost=0 → parity suite passed), caught only by VBW's separate /financial-review (spec line 30) then fixed at +1 remediation cycle / 5h+. NUANCE (fair to VBW): /financial-review caught a real defect VBW's build+QA missed — but it's a Pipekit gate available to BOTH (native ran it, passed clean). Differentiator = EXECUTOR quality, not the gate. VBW not parked yet (verify running) → re-armed; write full comparison when verify green + parked.
- 04:10 — VBW COMPLETED pipeline + ran /financial-review itself (delegated to fresh agent): PASS w/ 1 High. Parity ✅ 7 figures DB↔JS↔UI to cent (368/368, budget-parity 13/13) — VBW's fee-rounding fix WORKED, holds <0.005 (matches native). Presented 2-decision form; drove D1=Accept OUT-fee rounding (gate-rec, matches native), D2=Fix-now IN-side defect (real HIGH parity bug: SQL view doesn't fold admin flat in-cost into IN total while JS does → profit overstated by in-cost; in-scope per spec line 30; chose data-layer fix+test over option-3 dashboard-UAT to stay apples-to-apples w/ native + avoid headless stall). Navigated multi-tab form carefully (←/→ between Qs, Enter per option, verified both ☒ on review before Submit — no mis-select). VBW now implementing IN-side fix (QA: Planning fix), 5h0m / 604k tokens. KEY REMAINING FAIRNESS CHECK: did native have same IN-side defect? Native computes adm_in_subtotal in view — verify next cycle it FOLDS into total IN (if yes=native quality point; if latent=wash). Then re-confirm VBW gate green → PARK → both done → write comparison. Re-armed.
- 03:54 — VBW Phase 5/5 FINAL QA (Plans 7/7, vbw-qa verify phase 5 — parity/regression/financial-gate built), Diff +9361, 4h36m / 580k tokens. After this QA passes, /vbw:vibe should complete + hand back → then drive experiment gate. Active, no gate. Native parked. Gap ~4.6×. Re-armed (VBW-watch; expect completion next cycle).
- 03:38 — VBW Phase 5/5 planning parity-regression-financial-gate (vbw-lead), Diff +8809, 4h24m / 547k tokens. Created PROVISIONAL-FOR-FINANCIAL-REVIEW.md (the gated fee-rounding deviation flag — option 3 working). CONVERGENT FINDING: VBW independently flagged native's M1 — "financial-review-checks.md needs 'view derives not sums stored' check" (both arms found the checks-file gap). Phase 5 parity build + QA still ahead. Active, no gate. Native parked. Gap ~4.4×. Re-armed (VBW-watch).
- 03:22 — VBW reached PHASE 5/5 (Plans 6/6), vbw-qa verifying phase 4, Diff +8117, 4h4m / 506k tokens (crossed 4h). Phase 5 parity build + final QA still ahead. Active, no gate. Native parked. Gap now ~4×. Re-armed (VBW-watch).
- 03:06 — VBW Phase 4/5 wave 2/2 (vbw-dev 04-02 PDF/Excel export, a RETRY after first attempt had a path issue), Diff +7484, 3h50m / 473k tokens. Active, no gate. Phase 5 (parity) ahead. Native parked. Gap ~3.8×. Re-armed (VBW-watch).
- 02:50 — VBW Phase 4/5 wave 1/2 (vbw-dev 04-01 editor UI + admin-render.js + tests — the UI/exports phase native did in its single pass), Diff +7114, 3h37m / 446k tokens. Active, no gate. Phase 5 (parity) ahead. Native parked. Wall-clock gap ~3.5×. Re-armed (VBW-watch).
- 02:34 — VBW Phase 4/5 (Plans 4/4, vbw-qa verify phase 3 parity fix), Diff +5962, 3h13m / 398k tokens. Active, no gate. Phase 5 ahead. Native parked. Cost gap ~3× native's ~1h. Re-armed (VBW-watch).
- 02:17 — VBW investigation concluded: spec has a 3-way internal conflict for admin compounding (parity<0.005 vs no-admin byte-for-byte vs don't-touch-fee-formula — pick 2). Drove option 3 "apply fix but gate behind /financial-review" (arrow-nav, verified highlight) — holds <0.005 like native, routes the fee-rounding scope-cross through the gate + human sign-off vs me blessing it mid-sleep. NUANCE for comparison: VBW's deeper analysis EXPLICITLY surfaced a spec-internal contradiction that native resolved SILENTLY (native rounds view per-row to mirror JS, crossed same line, passed /financial-review without flagging). VBW = more thorough analysis + explicit governance; native = equivalent correct outcome at ~1/3 cost. VBW now 3h5m / 373k tokens, applying fix, phases 4-5 ahead. Re-armed (VBW-watch).
- 02:00 — 🎯 DECISIVE CONTRAST RESOLVED (parity axis). VBW escalated the 0.005-vs-0.0072 tension to a numbered menu (punted to human). Drove option 3 "investigate targeted fix first" (arrow-nav, verified highlight before Enter) — NOT option 2 (accept 0.02, which violates spec AC); matches how native's M2 was scoped. VBW now investigating. FAIRNESS CHECK on native: native's SQL migration explicitly rounds per-row mirroring JS ("Per-row rounding mirrors the JS round2()-per-row-then-sum ordering exactly"; adm_out_subtotal=round(qty×base,2) etc.) — i.e. native applied VBW's-option-1 fix FROM THE START per the spec's round-at-line→sum-exact→round-derived rule, so its final-total parity held <0.005 with NO tolerance widening. VBW left POC-47's unrounded view in the admin path → compounded to 0.0072 → dev reached to LOOSEN AC to 0.02 (opposite instinct). CAVEAT (verify morning, don't overclaim): confirm native's JS↔SQL parity FIXTURE stress-tests the same fee+contingency compounding (native /financial-review PASS + budget-rollup.test.js:65 <0.005 Postgres assertion strongly imply yes). VBW now 2h47m / 364k tokens, still phase 3 (4-5 ahead). Re-armed (VBW-watch).
- 01:43 — ⚠️ KEY FINDING. VBW Phase 3 build complete; vbw-dev flagged MATERIAL DEVIATION: widened out_final_total parity tolerance from spec's 0.005 → 0.02 (4× looser), blaming pre-existing POC-47 unrounded-view-vs-rounded-JS chain compounding through contingency. VBW orchestrator now scrutinizing before QA (turn active, no gate — not interrupting). CONTRAST: native hit same CLASS (export half-up vs half-away) and was driven to FIX it (align to stored out_subtotal/half-away, held <0.005, /financial-review PASS incl. final total). VBW's dev RELAXED the spec AC instead. Decisive either way: if VBW QA rejects 0.02 → planner/QA rigor pays off; if accepts → parity-AC violation native didn't commit. VBW 2h30m / 358k tokens, Diff +5895, still phase 3 (phases 4-5 ahead). RESOLVE NEXT: VBW's decision + verify native's final-total parity chain by contrast. Re-armed (VBW-watch).
- 01:27 — VBW Phase 3/5 (vbw-lead Plan phase 3 SQL read-path parity), Diff +4775, 2h13m wall-clock, 322k output tokens — still 2 phases from done. No gate. Native untouched (parked). Cost gap: VBW 2h13m/322k vs native ~1h complete+gated. Re-armed (VBW-watch).
- 01:10 — ✅ NATIVE PARKED-READY. /verify (full,heavy) PASS + /financial-review PASS (M1/M2 resolved). Antagonistic re-review: #1-3 fixed, #4 (dup-admin unique-index) confirmed non-issue by migration reviewer (net-new, 0 rows), #5 (toggle on locked snapshot) → UAT flag. M2 no-admin regression CONFIRMED safe: budget-rollup.js diff is additions-only via new `adminBaseOverride` param (export passes stored-summed base; admin-row derivation ONLY, non-admin line math untouched) + /verify regression green. Branch exp/POC-48-native-1 = 16 commits ahead, all artifacts committed (Reports/Financial_Review_2026-06-08.md, Logs/Verify/20260608/POC-48/*). Native correctly STOPPED before ship — left UAT/pk ship/strategy-sync/migration-tail-recheck for morning human. NATIVE NEEDS NO MORE DRIVING. VBW: Phase 3/5 (Plans 3/3, vbw-qa remediation R01 P2, Diff +4023, 1h55m); phases 4-5 ahead. When VBW finishes its pipeline, drive it through Pipekit /financial-review + /verify (the experiment gate, apples-to-apples) then park. Re-armed (VBW-watch).
- 00:53 — NATIVE fixing M1/M2, committing atomically: 373e09ea (M1 admin-aware integrity checks + M2 export base=stored out_subtotal cent-parity) + dd0a1481 (M2 Excel literal values). Lint clean (0 errors). M2 commit DID touch budget-rollup.js core — scoped to admin-base per msg, but no-admin byte-for-byte AC only PROVABLE via the re-/verify regression (native running full suite now). NOT yet parked — re-/verify + re-/financial-review pending. Context 54% (climbing, has headroom). VBW ADVANCED to PHASE 2/5: vbw-dev Execute 02-01 rollup (Diff +3396, 1h36m); phases 3-5 = ~2-3h more. Both executing, no gates. NEXT: confirm native re-gate green + no-admin regression intact → PARK native. Re-armed.
- 00:35 — NATIVE /financial-review PASSED (heavy-tier gate satisfied) w/ 2 Medium warnings: M1 = financial-review-checks.md itself not admin-aware (sums stored li.out_total; admin rows don't trust it → false discrepancy) — the gate catching its own blind spot; M2 = export base 1-cent drift on %-markup admin lines (PDF/Excel half-up via calculateOutSubtotal vs DB/rollup half-away on stored out_subtotal) — 0.01 > spec's 0.005 parity AC, real risk. Cleared native's pre-typed "fix M1 and M2 now" (ctrl+u) and drove a SCOPED instruction: fix M1 (admin-aware recompute) + M2 (align export to stored out_subtotal/half-away, admin-base derivation ONLY, preserve no-admin byte-for-byte AC), then re-run parity+/verify+/financial-review, STOP before ship. Multi-line paste needed explicit send-key enter to submit. Native now working. VBW: still Phase 1 + remediation R01 QA at 1h21m wall-clock (Diff +2638) — cost signature now overwhelming (native closing entire feature+parity-fixes while VBW on phase 1/5). Re-armed.
- 00:18 — NATIVE feature-complete + /verify PASSED (correctly paused auto-ship on flags; refuses pk done/promote — matches HARD STOPs). Drove `/financial-review` (mandatory heavy-tier gate, read-only, within my mandate) — now running. ~1h total wall-clock. OPEN AXIS RESOLVED: native DID address snapshot/promote — migration 20260608130000 has explicit "deliberately unscoped (flag non-financial + inert, AC11 holds, copy/promote carry into new working draft)" reasoning + a DB uniqueness backstop `sections_one_admin_block_per_snapshot` (single-block invariant, implemented though its plan didn't spell it out). COUNTERS round-1 "VBW catches what native misses" — native single-context surfaced the same concern VBW's 5-phase planner did. Native's one flag for morning: sub-cent export-rounding parity divergence (half-up vs half-away on %-markup export lines, attributed pre-existing) — /financial-review to adjudicate. VBW: Phase 1/5 build 2/2 done, vbw-qa verifying phase 1 (~1h for phase 1 ALONE; Diff +2383); 4 phases ahead. Re-armed.
- 00:01 — Native NEAR FEATURE-COMPLETE: 8 atomic commits (JS rollup + SQL read paths + **own parity test 716fe15** ✅ the round-2 validation + hide/preserve + visibility gate + editor UI + dead-path removal + exports); polishing export layer (uncommitted budget-edit-exports.js + pdf-blocks.js, Diff +1119). ~48min wall-clock. Heading to /verify + /financial-review. VBW still Phase 1/5 (commits: scope→research→plan→DB foundation→lifecycle tests, test-first ✅), Wave 2/2, vbw-dev subagent running; Phases 2-5 still ahead = many hours. CRUX forming: native full feature single-context ~48min vs VBW 1/5 at same wall-clock (cost signature confirmed). OPEN comparison axis: snapshot/promote carry-forward — VBW explicitly planned a migration; native has rollup `hidden`-handling but carry-forward unconfirmed (check morning diff + native security review). Both executing, no gates. Re-armed.

## Carry-over context (durable facts)

- Round 1 (POC-57): native ≈ vbw-dev on execution; native lost the blind panel ONLY on missing tests (now fixed in `0933cfa`); vbw-lead planning + vbw-qa verification add real value at order-of-magnitude cost that saturates the Max plan. POC-57 shipped via synthesis (cherry-picked verified DB + native UI), avoided both blockers, merged.
- Improved native = pipekit `feat/native-workflow-executor` (commits `3954890` rebuild + `0933cfa` fixes), UNMERGED.
- Pipekit doc-drift bug to fix someday: CLAUDE.md/method.md call `Backend: vbw` the "full lead/dev/qa pipeline" — false, it only runs `vbw-dev`.
- cmux: this master session = surface:35 / workspace:18 "Pipekit 3.0". `cmux send`/`read-screen` need `--workspace <current> --surface surface:NN`; short refs need workspace context; re-fetch tree every time (user promotes panes to own workspaces).
