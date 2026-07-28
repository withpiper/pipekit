---
name: security-review
description: Periodic repo security audit (not PR-scoped — see /pr-security-review for that). Use when auditing the whole repo for auth, secrets, RLS, OWASP baselines. Use when scoping a security pass before a release.
---

# Security Review Skill

You are a senior security engineer conducting the weekly security review for the project. Read `method.config.md` for project context.

## Running this review

Run at high reasoning effort — this is intelligence-sensitive work. For a deep full-codebase pass it is a strong fit for a **dynamic workflow** (or `ultracode`): fan the audit agents (§2) out in parallel, then run the adversarial verification pass as a second stage.

Two rules below are load-bearing and exist to counter how capable models behave on this task: the **finding-stage coverage** rule (§2) — without it the model investigates deeply but under-reports — and **grounded reads** — open and cite the file (`file:line`); never infer a vulnerability *or* an all-clear from a filename or from memory. Pass both to every sub-agent.

## Triggers

This skill is invoked when the user says:
- `/security-review`
- "run security review"
- "security audit"

## Purpose

Perform a comprehensive security review of the codebase, update the internal security score report, and refresh the public security page to reflect current findings.

## Execution Steps

### 1. Read Current State

Read these files to understand the current security posture:
- `Security/SECURITY_ARCHITECTURE.md` — internal architecture doc
- `src/marketing/security.html` — public-facing security page
- The most recent `Security/Security_Score_*.md` report

### 2. Audit the Codebase

**Finding stage — maximize coverage; do not self-filter.** Report every issue you find, including ones you are uncertain about or judge low-severity. Do not drop findings for importance or confidence at this stage — tag each with a **confidence** level and a **severity**; the verification pass and scoring do the filtering. Surfacing a finding that later gets refuted is better than silently dropping a real one. Every finding *and every "no issue found" verdict* must come from a file you actually opened and can cite (`file:line`). Pass this same instruction to each sub-agent.

Run parallel sub-agents to audit these areas:

**Agent 1 — Authentication & Authorization:**
- Check all HTML pages call `requireAuth()` or equivalent
- Verify RLS policies exist for all tables
- Check service-role usage has ownership guards
- Review auth.js for session handling issues

**Agent 2 — API Security:**
- Verify ALL PHP endpoints in `src/app/api/` use:
  - `require_once api-auth.php` + `validateApiAuth()`
  - `require_once cors.php` + `handleCors()`
  - `require_once rate-limiter.php` + `rateLimit()` (for cost-sensitive endpoints)
- Check for SQL injection, command injection, or unsafe input handling

**Agent 3 — Security Headers & Infrastructure:**
- Review `.htaccess` files for security headers
- Check CSP directives for unsafe sources
- Verify SRI on third-party scripts
- Check for hardcoded secrets or credentials

**Agent 4 — Data Protection & Storage:**
- Review Supabase storage bucket policies
- Check for PII in logs or error reporting
- Verify Sentry context doesn't leak personal data
- Check migration files for security implications

**Verification pass (adversarial) — run after all agents report.** Take each candidate finding and try to **refute** it: open the cited code and check whether the issue is actually reachable and exploitable given auth, RLS, and real call sites. Mark each **confirmed**, **refuted**, or **needs-more-info**. Keep refuted items in an appendix with the reason rather than deleting them; only confirmed and needs-info findings feed the score below. This raises precision without sacrificing the breadth from the finding stage.

### 3. Run Security Scans (if possible)

Use available tools to check security posture:
- **Lighthouse:** `mcp__lighthouse__get_security_audit` for `{production URL from method.config.md}` (performance, best practices)
- **MDN Observatory:** Use `WebFetch` to query `https://http-observatory.security.mozilla.org/api/v2/analyze?host={production URL from method.config.md}` for HTTP security header grading

### 4. Generate Security Score Report

Create a new report at `Security/Security_Score_{YYYY-MM-DD}.md` following the format of previous reports. Include:

- Executive summary
- Score comparison table (vs previous report)
- Detailed findings with evidence (file:line references)
- OWASP Top 10 assessment
- GDPR compliance status
- Review cycle status
- Next review items

### 5. Update the Public Security Page

Update `src/marketing/security.html` with:
- Current security score in the posture badge
- Document version bump
- Any language corrections based on findings (e.g., if claims don't match evidence)

**Do NOT overstate security posture.** If something is "in progress", say so. If a DPA hasn't been signed, don't claim it's in place.

### 6. Update Security Architecture Doc

If any findings affect the architecture (new endpoints, changed storage policies, etc.), update `Security/SECURITY_ARCHITECTURE.md`.

### 7. Summary

Present the user with:
- Overall score and change from previous
- Top findings (prioritized)
- What was updated on the public page
- Recommended actions for next review

## Evidence Standards

Classify all findings by evidence type:
- `repo_evidence` — verified from code in the repository
- `live_external_evidence` — verified from live scanning (MDN Observatory, Lighthouse)
- `unverified` — claims that cannot be proven from repo or live scans

## Severity Levels

- **HIGH**: Directly exploitable (RCE, auth bypass, data breach)
- **MEDIUM**: Requires conditions but significant impact
- **LOW**: Defense-in-depth gaps or minor issues

## Key Principles

1. **Honesty over optics** — Never inflate the score or overstate protections
2. **Evidence-based** — Every finding needs a file:line reference or scan result
3. **Actionable** — Each finding should have a clear fix recommendation
4. **Consistent** — Follow the same checklist every review for comparability
5. **Coverage before filtering** — At the finding stage, surface everything with confidence + severity tags; never self-censor uncertain or low-severity findings. Filtering happens only in the verification pass and scoring
