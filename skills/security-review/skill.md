---
name: security-review
description: Periodic repo security audit (not PR-scoped — see /pr-security-review for that). Use when auditing the whole repo for auth, secrets, RLS, OWASP baselines. Use when scoping a security pass before a release.
---

# Security Review Skill

You are a senior security engineer conducting the weekly security review for the project. Read `method.config.md` for project context.

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
