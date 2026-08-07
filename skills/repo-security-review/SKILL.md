---
name: repo-security-review
description: Periodic whole-repo security audit — parallel area agents, adversarial verification, evidence-classified findings, score report. Project audit areas live in a per-project areas file. Not /pr-security-review (PR-scoped) or /security-gate (feature-scoped).
---

# /repo-security-review

> **North star:** a periodic, whole-repo security pass whose findings you can trust — because every one of them cites code someone actually opened, and every one survived a deliberate attempt to refute it.

You are a senior security engineer conducting the project's periodic **whole-repo security review**: auditing the codebase area by area, verifying each candidate finding adversarially, and refreshing whatever security artifacts the project maintains.

This is the **portable framework**. The concrete, project-specific substance — which areas this repo has, which paths and primitives define each one, what "correct" looks like here — lives in a **project areas file** you read at runtime. Never hardcode a repo's endpoint layout, auth primitive, middleware names, or artifact paths in this skill.

## Three security surfaces, three jobs — don't conflate them

| Skill | Scope | Cadence | Shape |
|-------|-------|---------|-------|
| `/security-gate` | the **feature's diff**, category-triggered | once per feature, at Building → UAT | classify, then check only what matched |
| `/pr-security-review` | a **PR's diff**, antagonistic | on demand, for risky PRs | rubric-driven (migrations, RLS, SECURITY DEFINER, auth) |
| **`/repo-security-review`** (this) | the **whole repo** | periodic / pre-release | area sweep + adversarial verification + score report |

This one is the only whole-repo pass. It does not gate a ship, does not run per feature, and does not read a diff — it reads the codebase as it stands.

> **Note on the name.** Claude Code ships a built-in `/security-review` (diff-scoped review of pending branch changes). This skill is deliberately *not* that, and is named to avoid colliding with it in the skill list. Renamed from `/security-review` in v4.31.0.

## Triggers

- `/repo-security-review`
- "run the security review", "repo security audit", "audit the whole repo for security"
- Scoping a security pass before a release

## Running this review

Run at high reasoning effort — this is intelligence-sensitive work. For a deep full-codebase pass it is a strong fit for a **dynamic workflow** (or `ultracode`): fan the area agents (Step 2) out in parallel, then run the adversarial verification pass as a second stage.

Two rules below are load-bearing and exist to counter how capable models behave on this task: the **finding-stage coverage** rule (Step 2) — without it the model investigates deeply but under-reports — and **grounded reads** — open and cite the file (`file:line`); never infer a vulnerability *or* an all-clear from a filename or from memory. Pass both to every sub-agent.

Sub-agent roles follow `method.config.md § Model Policy`: area agents run the **Verification** role (default `sonnet`, effort `high`); the adversarial verification pass runs the **Plan review / adversarial** role (default `opus`, effort `xhigh`). All are read-only (`allowed-tools: Read, Bash, Grep, Glob`, plus `WebFetch` for the agent running live scans).

## Config (read from `method.config.md`)

| Key | Purpose | Default |
|-----|---------|---------|
| **Repo security areas** | Path to the project areas file (the substance) | `resources/repo-security-areas.md` |
| **Repo security report path** | Where to write the score report | `Reports/` |
| **Security architecture doc** | Internal architecture doc to read + refresh | (blank — step skipped) |
| **Public security page** | Public-facing security page to refresh | (blank — step skipped) |
| **Security scan host** | Hostname for live external scans | (blank — live scans skipped) |
| **Project display name** | Report header | (project name) |

**Every artifact key is optional.** A project with no public security page, no architecture doc, and no deployed host still gets the full audit and report — the corresponding steps are recorded as `n/a (not configured)`, never as done. Never invent an artifact path, and never write to one the project didn't configure.

## Step 0 — Load the areas file (gate)

Read the file at `Repo security areas` (default `resources/repo-security-areas.md`).

- **If it doesn't exist**, STOP and tell the user:
  > No repo-security areas file found at `<path>`. This skill is the framework; the project supplies the areas.

  Then scaffold one and stop for the user to fill it in:
  - If `pipekit/templates/repo-security-areas.template.md` exists (synced projects), copy it to `<path>`.
  - Otherwise create `<path>` directly with the template's sections — one block per audit area (**Authentication & authorization**, **API & input handling**, **Headers, transport & infrastructure**, **Data protection & storage**, plus any project-specific areas), each with the project's **path globs**, **primitives** (the actual function/middleware/policy names to grep for), and **checks**; plus **Not applicable**, **Live external scans**, and **Known gaps / accepted risks**.
  - Do not invent project specifics — leave clearly-marked placeholders.

The areas file is the substance; this skill is the discipline + report shape.

## Step 1 — Read current state

- If `Security architecture doc` is set and the file exists, read it — the claimed architecture is what the audit checks reality against.
- If `Public security page` is set and the file exists, read it — its claims are themselves auditable (Step 5).
- Find the previous report for trend comparison: `ls -t <Repo security report path>/Security_Review_*.md 2>/dev/null | head -1`. None → this is the first review; say so rather than inventing a baseline.
- Carry forward the areas file's **Known gaps / accepted risks** so they're tracked, not rediscovered as new findings each cycle.

## Step 2 — Audit the codebase (parallel area agents)

**Finding stage — maximize coverage; do not self-filter.** Report every issue you find, including ones you are uncertain about or judge low-severity. Do not drop findings for importance or confidence at this stage — tag each with a **confidence** level and a **severity**; the verification pass and scoring do the filtering. Surfacing a finding that later gets refuted is better than silently dropping a real one. Every finding *and every "no issue found" verdict* must come from a file you actually opened and can cite (`file:line`). Pass this same instruction to each sub-agent.

Spawn one read-only sub-agent **per area defined in the areas file**, in parallel. Each agent gets: its area's paths, primitives, and checks from the areas file; the coverage rule and grounded-reads rule above; and the report shape it must return (findings with `file:line`, severity, confidence — plus explicit cited "verified, no issue" verdicts where its checks come back clean).

Where the areas file leaves an area's checks thin, fall back to these generic baselines — and say so in the report (`generic-only — no project checks defined`) so an incomplete areas file is visible, never an invisible pass:

| Area | Generic baseline the agent verifies |
|------|-------------------------------------|
| **Authentication & authorization** | every user-reachable route/page enforces the project's auth primitive; authorization checked at the **query** (RLS / policies / ACLs), not only in app code; privileged or service-role clients never reachable from user input; session lifecycle (issuance, expiry, invalidation) sound |
| **API & input handling** | every endpoint runs the project's auth, CORS, and rate-limit middleware; parameterized queries throughout; no command / template / `eval` injection; validation at the boundary; error surfaces don't leak upstream internals |
| **Headers, transport & infrastructure** | security headers present and not permissive (CSP without unsafe sources, HSTS, frame/content-type options); SRI on third-party scripts; TLS enforced; no hardcoded secrets or credentials in source or config; dependency audit clean |
| **Data protection & storage** | object/bucket policies least-privilege and private-by-default; PII absent from logs, error reporting, and analytics; schema/migration changes reviewed for security implications; retention and deletion pathways exist |

**Account for every area — silence is not a pass.** Each area returns one of: **findings** (listed), **clean** (with the citations that establish it), or **N/A** (the areas file lists it under Not applicable, with the reason). An area that returns nothing at all is a could-not-run, and the report says so.

**Verification pass (adversarial) — run after all agents report.** Take each candidate finding and try to **refute** it: open the cited code and check whether the issue is actually reachable and exploitable given auth, RLS, and real call sites. Mark each **confirmed**, **refuted**, or **needs-more-info**. Keep refuted items in an appendix with the reason rather than deleting them; only confirmed and needs-info findings feed the score below. This raises precision without sacrificing the breadth from the finding stage.

## Step 3 — Live external scans (optional)

Only if `Security scan host` is set **and** the areas file's **Live external scans** section lists applicable scans. Otherwise record `Live scans: n/a (no host configured)` — never a pass.

Run whatever the areas file names, using whatever the session has bound. Common ones:

- **HTTP header grading** — `WebFetch` against a header-analysis service (e.g. MDN Observatory's analyze API) for `<Security scan host>`.
- **Lighthouse / best-practices audit** — via a bound Lighthouse MCP tool for `<Security scan host>`, if the project has one.

A scan that can't run (tool unbound, host unreachable) is recorded as `unavailable`, with the reason. Never report a scan result you didn't obtain.

## Step 4 — Generate the score report

Write `<Repo security report path>/Security_Review_{YYYY-MM-DD}.md`:

```markdown
# Security Review — {YYYY-MM-DD}  ·  {Project display name}

## Summary
- **Status:** PASS / WARNINGS / FAIL
- **Previous review:** {date, or "First review"}
- **Confirmed findings:** HIGH {n} · MEDIUM {n} · LOW {n}   (+ {n} needs-more-info)

## Score comparison
| Area | This review | Previous | Δ |
|------|-------------|----------|---|
| {area} | {score} | {score or "—"} | {±} |

## Area coverage
| Area | Verdict | Notes |
|------|---------|-------|
| {area} | findings / clean / N/A / could-not-run | {evidence or reason} |

## Findings (confirmed + needs-more-info)
### HIGH
{list with file:line, evidence type, and fix recommendation — or "None"}
### MEDIUM
{list, or "None"}
### LOW
{list, or "None"}

## Refuted (appendix)
{finding + why refuted, or "None"}

## Live external scans
{results per scan, or "n/a (no host configured)" / "unavailable — {reason}"}

## OWASP Top 10 assessment
{per-category status, cited}

## Known gaps / accepted risks
{carried from the areas file + anything new}

## Next review items
{specific, ordered}
```

Scoring is comparability, not precision: use the same rubric every cycle so the trend line means something. If the areas file defines a rubric, use it; otherwise score each area on confirmed findings by severity and say which rubric you used.

## Step 5 — Refresh the project's security artifacts (optional)

**If `Public security page` is set:** update it with the current posture, a document-version bump, and any language corrections the findings imply.

<important>
Do NOT overstate security posture. If something is "in progress", say so. If a DPA hasn't been signed, don't claim it's in place. A claim on a public page that the audit could not evidence is itself a HIGH finding — fix the page, not the finding.
</important>

**If `Security architecture doc` is set:** update it when findings affect the architecture (new endpoints, changed storage policies, a new trust boundary). Leave it alone otherwise — a no-op edit destroys the drift signal its own staleness carries.

If neither is set, skip this step and record it as `n/a (not configured)`.

## Step 6 — Summarize for the user

- Overall status and the change from the previous review.
- Top confirmed findings, prioritized, each with its fix recommendation.
- Which artifacts were updated (and which were skipped because they aren't configured).
- Recommended actions for next review.

## Evidence standards

Classify every finding by evidence type:

- `repo_evidence` — verified from code in the repository (`file:line`)
- `live_external_evidence` — verified from a live scan (header grading, Lighthouse, etc.)
- `unverified` — a claim that cannot be proven from the repo or a live scan

`unverified` is a legitimate outcome and must be reported as such — it is not a downgrade of a real finding, and it is not permission to assert one.

## Severity levels

- **HIGH** — directly exploitable (RCE, auth bypass, data breach)
- **MEDIUM** — requires conditions but significant impact
- **LOW** — defense-in-depth gaps or minor issues

## Key principles

1. **Honesty over optics** — never inflate the score or overstate protections.
2. **Evidence-based** — every finding needs a `file:line` reference or a scan result.
3. **Actionable** — each finding gets a clear fix recommendation.
4. **Consistent** — follow the same checklist every review so the trend is comparable.
5. **Coverage before filtering** — at the finding stage, surface everything with confidence + severity tags; never self-censor uncertain or low-severity findings. Filtering happens only in the verification pass and scoring.
6. **Framework here, areas in the project** — never hardcode a repo's endpoint layout, auth primitive, middleware names, or artifact paths; they live in the areas file and `method.config.md`.

## When NOT to use

- Reviewing a PR's diff → `/pr-security-review` (antagonistic, rubric-driven for migrations / RLS / SECURITY DEFINER / auth).
- Checking whether *this feature* was reviewed before it ships → `/security-gate` (feature-scoped, runs at the Building → UAT seam; hard-gates `pk ship` on projects with a categories file).
- Reviewing pending uncommitted changes → Claude Code's built-in `/security-review`.
- Production readiness (monitoring, backups, rate-limit coverage, secrets rotation) → `/prod-ready`.
- Money-math correctness → `/financial-review`.

## What this skill does NOT do

- No code modifications — the area agents are read-only; fixes are recommendations, and land through the normal `/work` loop.
- No Linear state transitions.
- No ship or merge blocking — `/security-gate` and `/prod-ready` own the hard gates.
- No writes to artifacts the project didn't configure.
- No session-log writes — `/pk-exit` owns the session log.
