# Piper Handoff — Pipekit v2.5.0.1 Update (durable record)

> **Slimmed 2026-05-31** to the durable-record shape per the handoff convention (`sop/Session_Management_SOP.md` § Handoff & Session-Log Content Discipline). The original Step 0–7 migration runbook was removed — the migration ran and completed on 2026-05-15. Replay it from this file's git history if ever needed. What remains is the decisions, caveats, and lessons worth keeping.

**From:** Nebula / pipekit repo (Ethan + Claude, 2026-05-15) · **To:** Piper (`~/Projects/piper`)
**Outcome:** Piper adopted Pipekit v2.5.0.1 (env-as-status). Methodology synced, the partial Linear migration finished, in-flight `UAT` issues reclassified, the new flow smoke-tested. Completed in the same session.

---

## What v2.5.0.1 delivered to Piper

| State (v2.5.0+) | Means |
|----------------|-------|
| `UAT` | PR open on preview branch (pre-merge) |
| `In Dev` | Merged to dev — first deploy env |
| `In Beta` | Promoted to beta (Piper 3-tier) |
| `Done` | Promoted to main — final |

- `pk done` regained the Linear `UAT → In Dev` transition (with `--merge` opt-in).
- `pk promote` writes `In <Env>` instead of the retired `Released`.
- `--confirmed` gate on `pk promote` refuses if any bundled issue is still `UAT`.
- v2.5.0.1 patched `sync-method.sh` to honor `$PWD` and refuse to sync Pipekit into itself.

---

## Caveats & lessons worth keeping

- **F2 — `pk promote` wrote terminal state at PR-open, not merge.** For ~5 min (until the promote PR merged) Linear showed the WIT ahead of reality; aborting the promote PR left Linear stale, requiring a manual state revert. Documented since v2.3.0. **Resolved in v2.6.0**, which split promote into two phases (Phase 1 opens the PR; Phase 2 `--finish` writes the terminal state only after merge). Kept here because the gotcha shaped that v2.6.0 design.
- **Linear team-name footgun.** Piper's Linear team is **`Withpiper`**, not `Piper` — `team: "Piper"` returns empty with *no error*. Always read the canonical name from `method.config.md` (`Team name:`) before any Linear MCP call; never guess from the project nickname. Cost real time on 2026-05-15.
- **F4 — branch-protected `dev`.** Sync commits route through a PR, not a direct push. (Piper and RS-Vault both hit this.)
- **F1 — `sync-method.sh` wrong-target bug.** Pre-v2.5.0.1 the script could target the wrong repo; v2.5.0.1 defaults `PROJECT_ROOT` to `$PWD` and refuses to sync into pipekit itself.
- **F5 — enumerate started-type Linear states before migrating.** Projects accumulate extra states (`In Review`, `QA`, …); list them all rather than assuming the canonical five.

---

## Gaps surfaced (status as of slimming)

- Extra started-type Linear states beyond the canonical set were left in place — retiring them was deferred as a separate decision.
- F2 promote-timing observation fed the v2.6.0 two-phase promote design (now shipped).

Full original migration runbook (Steps 0–7, rollback, success criteria): git history of this file prior to 2026-05-31.
