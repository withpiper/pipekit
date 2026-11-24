---
name: dependabot-sweep
description: Clear the open Dependabot PRs end to end — triage every one, merge the green ones to the integration branch, repair the mechanical failures (lockfile drift, the empty Dependabot secret store, a stale base) and merge those, then ask once about the rest with a recommended action each. Use after the weekly Dependabot run or when Dependabot PRs pile up. `--dry-run` reports and touches nothing. Project specifics live in a per-project sweep file.
---

# Dependabot Sweep

Goal: run once, end with **zero open Dependabot PRs**, with as few questions as possible and no risk beyond what a reviewed PR to the integration branch already carries. Every action below is either a merge of a PR whose every check is green at a pinned head SHA, a lockfile-only repair that CI then re-gates, or an action the user approved in the one question at the end.

This is the **portable framework**. The project-specific substance — which groups or packages are never auto-merged and why, which lockfiles a repair may regenerate and with what command, the local smoke commands, the post-merge health check, the merge order, known CI noise — lives in a **project sweep file** read at runtime. Never hardcode it here.

Run from the parent project root, not from a `pk branch` worktree. The skill makes its own throwaway worktrees for repairs.

## Triggers

- `/dependabot-sweep [--dry-run] [--yes]`
- "sweep the Dependabot PRs", "clear Dependabot"

## Modes

- **default**: Step 0 and Phases 1 to 6.
- **`--dry-run`**: Step 0 and Phases 1 and 2 only. Print the triage table; make no merge, push, comment, Linear write or file (a missing sweep file is reported, not scaffolded).
- **`--yes`**: required on a project whose integration branch is production (Step 0); ignored elsewhere.

## Config

| Value | Source | Default |
|---|---|---|
| Base branch every merge targets | `method.config.md § Integration branch` (`pk config "Integration branch"`) | blank: `dev` if `origin/dev` exists, else the remote default branch (`git symbolic-ref refs/remotes/origin/HEAD`) — the same derivation `pk` uses |
| Merge strategy | `method.config.md § Merge method` (`pk config "Merge method" merge`) | `merge` |
| Environments, in order | `method.config.md § Ship environments` (`pk config "Ship environments"`) | blank: empty (single-tier) when the base is `main`, else `<base>,main` — as `pk` derives it |
| Script deploy | `method.config.md § Deploy command` (`pk config "Deploy command"`) | blank |
| Project sweep file | `method.config.md § Dependabot sweep config` | `resources/dependabot-sweep.md` |
| Repo | `gh repo view --json nameWithOwner --jq .nameWithOwner` | — |

Below, `<base>` is the integration branch, `<repo>` the `owner/name`, `<method>` the merge method.

## Step 0 — Load the sweep file and check the blast radius (gate)

1. Read the sweep file. **If it doesn't exist**, STOP:
   > No Dependabot sweep file at `<path>`. This skill is the framework; the project supplies the specifics.

   Under `--dry-run`, stop there. Otherwise copy the template to `<path>` — `pipekit/templates/dependabot-sweep.template.md` in a synced project, `templates/dependabot-sweep.template.md` in the method repo itself — or, with neither present, create `<path>` with the sections **Never auto-merged**, **Lockfiles**, **Stale-base triggers**, **Local smoke**, **Post-merge check**, **Merge order**, **Known noise**, each a clearly marked placeholder. Do not invent project specifics. Stop for the user to fill it in.
2. **Unfilled gate.** If the file still carries an `EXAMPLE` marker or `{PROJECT}`, STOP and name the sections that still need filling: an example row would otherwise run as a real regeneration command or hold a group the project doesn't have. An empty **Lockfiles** section is allowed, but then every Refresh is HOLD ("no lockfiles configured").
3. **Production guard.** If the `Ship environments` chain is empty or `<base>` is its **last** entry, every merge to `<base>` lands on production — unless `Deploy command` is set, in which case production is a manual `pk deploy` and a merge deploys nothing. In the production case, say so, and unless `--yes` was passed, run as `--dry-run`. Otherwise the sweep never reaches production: promotion stays a human `pk promote` (or `pk deploy`).

## Safety envelope (the "no risk" contract)

These hold in every phase. If a step would break one, the PR goes to HOLD instead.

1. **Base `<base>` only.** Never merge to a later environment branch, never run `pk promote`.
2. **Never bypass a check.** No `--admin`, no re-labelled checks, no `SKIP_*` variables.
3. **Merge exactly the head that was checked.** Every merge passes `--match-head-commit <sha>` with the head SHA whose checks were read, so a push in between fails the merge instead of landing an unchecked commit. The head pins the PR, not the base: see the stale-base rule in Phase 4.
4. **All checks green, not just required ones**, and every required context from the live read present. A non-required check that is red is still real; it blocks the merge here.
5. **Repairs change lockfiles only.** A repair may rebase the branch and regenerate the lockfiles listed under **Lockfiles** in the sweep file, and it stages only those files by name. Anything else aborts it (Phase 3, diff guard).
6. **Merge with `<method>`.** `gh pr merge --<method>`; never a strategy the repo or config does not use.
7. **One merge at a time**, re-reading the remaining PRs after each.
8. **No bumped code runs on this machine.** Every local install passes `--ignore-scripts` (or the package manager's equivalent); a developer shell carries tokens a postinstall script could read.

A Refresh push hands the bumped code the normal CI secret store, which Dependabot's own runs deliberately lack. That is the same exposure every human-authored dependency PR has, bounded by the `cooldown` in `.github/dependabot.yml` if the project sets one, and it is why GitHub Actions PRs are never refreshed.

### Never auto-merged (always HOLD, with a recommendation)

- Every group or package listed under **Never auto-merged** in the sweep file, each for the reason it gives there (a version pin a test enforces on purpose, a CDN/SRI-pinned copy, a two-halves contract that needs re-verification). HOLD **before** any Refresh, so `@dependabot ignore` still works on the untouched branch.
- **A semver-major bump.** Majors are planned work, not a sweep. If version updates are configured to `ignore` majors and one appears anyway, it is a security update or a config regression; say which.
- **A PR touching a migration directory** (`method.config.md § Migration dir`) or any path the sweep file names as off-limits. Dependabot should never produce one.
- **A GitHub Actions PR that fails the Actions check** (Phase 2).

## Phase 1 — Inventory

1. `git fetch origin <base>`. Confirm the active gh account can merge: `gh api repos/<repo> --jq .permissions.push` is `true`.
2. Required checks, read live (never hardcoded): `gh api repos/<repo>/branches/<base>/protection --jq '.required_status_checks.contexts'` (needs admin). On a 404, fall back to rulesets: `gh api repos/<repo>/rules/branches/<base> --jq '[.[]|select(.type=="required_status_checks")|.parameters.required_status_checks[].context]'`. Neither answers: stop, since MERGE cannot be judged.
3. Open PRs: `gh pr list --author app/dependabot --state open --limit 100 --json number,title,headRefName,headRefOid,baseRefName,mergeable,mergeStateStatus,labels,createdAt`.
4. Per PR: `gh pr view <n> --json files,commits,statusCheckRollup,body`. Record the ecosystem and group (from the head branch, e.g. `dependabot/npm_and_yarn/<dir>/<group>-…`), the files, the bump list (body), whether any commit author is not `dependabot[bot]` (a person already took the branch over), every check's state and conclusion, and the earliest `startedAt` of the latest check runs (the checks' base time, for the stale-base rule).

No open PRs: say so and stop.

## Phase 2 — Triage

`mergeable == UNKNOWN` (GitHub recomputes it for a while after every merge): re-query after 30 seconds, up to five times, before triaging that PR. Then put each PR in exactly one lane, in this order:

| Lane | Test |
|---|---|
| **HOLD** | Base is not `<base>`, or it matches "Never auto-merged" above. |
| **WAIT** | Any check is queued or in progress, or a required context has not reported yet. |
| **MERGE** | `mergeable == MERGEABLE`, every check is `SUCCESS`, `SKIPPED` or `NEUTRAL`, every required context is present, and the base is not stale (Phase 4). |
| **REPAIR** | Anything else. |

**Actions check** (github-actions PRs, before MERGE): the diff touches only `.github/workflows/` and `.github/actions/` (together, "the Actions paths") and every changed line is a `uses: owner/repo@<sha> # v<ver>` line; for each one, `gh api repos/<owner>/<repo>/git/ref/tags/v<ver> --jq .object.sha` (dereference an annotated tag with `gh api repos/<owner>/<repo>/git/tags/<sha> --jq .object.sha`) equals the pinned SHA. Any miss: HOLD. Never Refresh an Actions PR. A bump pinned by tag rather than SHA cannot be verified this way: HOLD, with "pin by SHA" as the recommendation.

Print the table (PR, group, bumps, lane, one-line reason). `--dry-run` stops here.

**WAIT** PRs: watch in the background, one command per PR, and come back when each exits; do not poll by hand. After any push or `@dependabot rebase`, first wait for `headRefOid` to change (`gh pr view <n> --json headRefOid`, every 30 s, up to 10 min), because `gh pr checks --watch` returns at once on the old, finished checks. Then `gh pr checks <n> --watch --interval 60` with `run_in_background`, unpiped (a pipe returns the last command's status, not the watch's). A watch still running at 1.5× the project's slowest CI job (the sweep file's **Known noise** may name it; default 75 minutes): stop it and treat the PR as REPAIR with reason "checks never finished". Then re-triage that PR.

## Phase 3 — Repair

One attempt per PR per run. Diagnose first, from the failed jobs: `gh run view <run> --job <job> --log-failed | grep -iE 'error|fail|secret source'`, and for a log that ends with no failure, `gh api repos/<repo>/check-runs/<job>/annotations`. Check the sweep file's **Known noise** before debugging anything as a bump failure.

| Failure class | Signature | Repair |
|---|---|---|
| **Lockfile drift** | The package manager refuses a frozen install: `npm ci` `EUSAGE` "… in sync"; `ERR_PNPM_OUTDATED_LOCKFILE`; yarn "lockfile needs to be updated"; deno "The lockfile is out of date"; `poetry.lock` / `uv.lock` / `Cargo.lock` out of date | Refresh |
| **Secret store** | Log says `Secret source: Dependabot` and the step fails on a missing token, auth or env value | Refresh |
| **Runner lost** | Annotation "The hosted runner lost communication with the server", or a job cancelled or timed out with no test failure in its log | No human commits on the branch: `@dependabot rebase`, then WAIT (keeps Dependabot in charge of the branch). Otherwise Refresh. `gh run rerun` only when the base is not stale: it keeps the old merge ref. |
| **Conflict** | `mergeable == CONFLICTING`, usually a lockfile after an earlier merge | No human commits on the branch: comment `@dependabot rebase`, then WAIT. Otherwise Refresh. |
| **Base red** | The same job also fails on the latest `<base>` run of that workflow (`gh run list --branch <base> --workflow <file> --limit 3`) | Not this bump. HOLD with reason "`<base>` is red on <job>"; do not touch the branch. |
| **Flaky test** | The failing test lives outside the directories the PR touches and passes on the latest `<base>` run, typically a timing assertion a few percent over its limit | Base not stale: `gh run rerun <run> --failed`, then WAIT. Base stale: as Runner lost. |
| **Real failure** | A test assertion, type error or lint error that does not reproduce on `<base>` | HOLD, naming the culprit package from the log. Do not Refresh: a person's commit stops Dependabot acting on `@dependabot ignore`, which is usually the recommended way out. |

### Refresh (the only repair that writes)

```bash
n=<pr>; br=<headRefName>; oid=<headRefOid as triaged>
root=$(git rev-parse --show-toplevel); wt="$(dirname "$root")/$(basename "$root")-deps-$n"
git fetch origin "$br" <base>
[ "$(git rev-parse "origin/$br")" = "$oid" ] || { echo "branch moved since triage"; exit 1; }   # re-triage instead
git worktree add -B "$br" "$wt" "$oid" && cd "$wt"
git rebase origin/<base>           # a conflict outside the listed lockfiles: git rebase --abort, HOLD
```

Shell state does not survive between tool calls: restate `root`, `wt`, `br` and `oid` in each later block. **Every exit — success or any HOLD below — ends with the cleanup** `cd "$root" && git worktree remove --force "$wt" && git branch -D "$br"`, so a held repair leaves no worktree or local branch behind.

Then run, for each lockfile under **Lockfiles** in the sweep file whose manifest the PR touches, the regeneration command the sweep file gives for it. Those commands must be lockfile-only and script-free (`pnpm install --lockfile-only --ignore-scripts`, `npm install --package-lock-only --ignore-scripts`, `uv lock`, `poetry lock --no-update`, `cargo update -p <pkg> --precise <ver>`). A command that rewrites far more of a lockfile than the bump accounts for is the wrong command: regenerate with the same tool and flags CI uses to check the lock, minus the frozen flag — a broader "install" variant once rewrote 2,731 lines of a lockfile against a one-line real change (a consumer project, 2026-11). A required tool absent on this machine: HOLD rather than push a half-regenerated lock.

**Stage by name, then guard.**

```bash
git add -- <every lockfile path from the sweep file>
git status --porcelain | grep -v '^M  ' && { echo "unexpected change"; exit 1; }    # anything unstaged or untracked: HOLD
git diff --cached --name-only origin/<base>    # every path: a file the Dependabot commits touched, or a listed lockfile
```

Then read `git diff --cached origin/<base>` for the lockfiles: every package whose resolved version changed must be in the PR's bump list or pulled in by one of them (`pnpm why <pkg>` / `npm explain <pkg>` / `yarn why <pkg>` / `uv tree --invert --package <pkg>` / `cargo tree -i <pkg>`). Anything else means the regeneration resolved more than the bump: HOLD.

**Local smoke** (cheap; CI is the real gate): run the sweep file's **Local smoke** commands — frozen installs with scripts off, plus any cheap check it names. Any failure: HOLD.

Commit and push:

```bash
git commit --allow-empty -m "fix(deps): regenerate lockfiles for dependabot #$n"   # plus the session's attribution trailer; empty still re-runs CI
git push --force-with-lease="$br:$oid" origin "$br"
cd "$root" && git worktree remove --force "$wt" && git branch -D "$br"
```

**Dropping a package from a group is Dependabot's job, not a Refresh.** Comment `@dependabot ignore <pkg>` on the PR (or add it to `ignore` in `dependabot.yml`). No reply within 15 minutes: `@dependabot recreate`. Dependabot may close the PR ("updatable in another way") and open a replacement, so re-run Phase 1 rather than waiting on the old number. Never rebuild a group's lockfile by hand to drop a package. Each way of doing it fails (a consumer project, 2026-11): copying the PR's whole manifest silently reverted a bump `<base>` had just merged; a lockfile regenerated from `<base>` resolved newer versions than the PR proposed; one edited from the PR's own lock kept orphaned entries the package manager would not prune. The recreate gave a clean PR in under 15 minutes.

**A `dependabot.yml` change applies to runs that start after it merges.** A group PR opened minutes after the merge can still carry the ignored package; the next run honours it.

Once a person has pushed, Dependabot stops rebasing that branch; any later conflict or stale base is this skill's to Refresh. The PR goes back to WAIT.

## Phase 4 — Merge

Order: the sweep file's **Merge order** if it gives one; otherwise GitHub Actions groups first (no lockfile), then single-package groups, then the large grouped updates.

**Stale-base rule.** When `<base>` does not require up-to-date branches, a PR's checks ran on a merge ref built from whatever `<base>` was then. Before merging, `git fetch origin <base>` (this run's own merges moved it) and list what `<base>` gained since the checks' base time: `git log --since=<base time> --name-only --format= origin/<base> | sort -u`. If that includes any file in the sweep file's **Stale-base triggers** (default: every lockfile and manifest in its **Lockfiles** table), or a commit this run merged that touched anything outside the Actions paths, the base is stale: `@dependabot rebase` (Dependabot-owned) or Refresh (person-owned), then WAIT. Otherwise the PR merges against a base that differs only in application code, the same standard every PR to `<base>` meets, and Phase 5 checks the result. (When the branch protection does require up-to-date branches, GitHub enforces this and `mergeStateStatus == BEHIND` routes the PR to REPAIR as Conflict.)

```bash
gh pr merge <n> --<method> --delete-branch --match-head-commit <headRefOid as triaged>
```

After each merge, re-triage the rest (Phase 2, including the UNKNOWN re-query). Loop Phases 2 to 4 until no PR is in WAIT, MERGE or REPAIR-with-an-attempt-left.

## Phase 5 — Post-merge check

For **every** merge commit this run made on `<base>`: `gh run list --branch <base> --commit <sha>` and confirm each run passed (a cancelled run counts as not passed; a deploy workflow that ran must have succeeded). Wait in the background as in Phase 2. Then run the sweep file's **Post-merge check** (a health endpoint, a smoke command), if it gives one.

A red `<base>` after a merge: stop the sweep, name the PR, and recommend a revert PR. Never revert or push to `<base>` directly.

## Phase 6 — Remaining PRs

If HOLD PRs remain, ask **one** `AskUserQuestion` (up to four questions; one per held PR, the rest batched in a follow-up call). Each question names the PR, the bumps and the evidence, and puts the recommended action first:

| Held because | Recommended | Alternatives |
|---|---|---|
| A **Never auto-merged** entry | The action the sweep file gives for it; otherwise leave open and file a Linear issue for the verification it names, with the PR linked | Close the PR (Dependabot reopens it next run) |
| Real failure, culprit known | Comment `@dependabot ignore <pkg> minor version` (Dependabot rebuilds the group without it, so the rest merges on the next sweep) and file a Linear issue to fix and `@dependabot unignore <pkg>` | Fix it on the branch as a Linear issue through `/work`; leave open |
| Base red | Leave open; `<base>` must go green first. File or link the issue for the red job | Re-run after the fix |
| Major or unexpected files | Close with a comment pointing to the issue that tracks planned majors (file one if none exists) | Leave open for a person |

Apply the answers. Linear issues go through the project's Linear route (`pk issue create` with every field the intake contract requires, per `sop/Linear_SOP.md § Filing a follow-up issue`), with the PR linked in the body.

## Report

End with a table: PR, group, outcome (merged / repaired then merged / ignored and tracked / left open), merge commit or Linear issue, and the count of Dependabot PRs still open with the reason for each. If the count is not zero, say why in one line per PR.

## Generic known noise (do not debug these as bump failures)

- Any job failing with `Secret source: Dependabot`: the Dependabot secret store is empty or partial. A Refresh clears it.
- A root-level grouped update can bump a nested package's manifest without touching that package's own lockfile, which fails every frozen install of the nested package. Lockfile drift; Refresh fixes it.
- Project-specific noise lives under **Known noise** in the sweep file; a deliberate tripwire test listed there is HOLD, not noise.
