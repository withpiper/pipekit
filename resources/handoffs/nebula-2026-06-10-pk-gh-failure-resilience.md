# Handoff: pk resilience on gh/GitHub API failures

**From:** Nebula, SiteLine POC-49 ship session, 2026-06-10
**Status:** proposal — not started

## Incident anchor

During the POC-49 ship (SiteLine, 2026-06-10), GitHub had a multi-hour "Partial System
Outage — API Requests: major_outage" (confirmed via githubstatus.com/api/v2/summary.json,
~16:59–17:37 UTC). Symptoms as seen from pk and gh:

- `pk ready POC-49` failed with a 401 "Requires authentication" on a **valid** keyring token.
- `gh pr edit` / `gh run rerun` 401'd intermittently while gh **reads** interleaved fine.
- A fresh CI push failed every job in ~2s with zero steps (`steps: []`) across all
  workflows, including previously-green ones.

Two wrong diagnoses were chased before the outage was found (pk token resolution, then
macOS keychain flakiness) — roughly an hour of misdirected debugging. GitHub's API returns
spurious 401s during outages, which pattern-matches perfectly to a local auth problem.

## The ask (small, two parts)

1. **Retry once.** pk subcommands that shell to `gh` (`cmd_ready`, `cmd_ship`, anything
   doing PR writes) should retry a failed gh call once (short backoff) before surfacing
   the error. The outage phase was intermittent; a single retry rode through most calls.
2. **Surface context on persistent failure.** When the retry also fails with an auth-shaped
   error (401/"Requires authentication"), print a diagnostic hint instead of the bare gh
   error:
   - `gh auth status` output (is the token actually healthy?)
   - a pointer to check `https://www.githubstatus.com/api/v2/summary.json` BEFORE
     debugging local auth — spurious 401s on healthy tokens and mass 2s/zero-step CI
     failures are the platform-outage tells.

Explicitly NOT asking for: an outage-detection daemon, automatic githubstatus polling, or
retry loops beyond one attempt. pk was not at fault here — `cmd_ready` just shells to gh
with no token path of its own — this is about making the failure mode self-explaining so
the next session doesn't burn an hour on a non-bug.

## Suggested home

`bin/pk` — a small `gh_with_retry()` wrapper around the existing gh invocations, plus the
hint block on persistent auth-shaped failure. Possibly a line in RUNBOOK.md's
troubleshooting section with the two platform-outage tells.
