# FROZEN SPEC — POC-57 — native-vs-VBW A/B

> **This file is the single frozen contract for all 6 experiment runs.** Verbatim copy of
> Linear POC-57 (Status: Approved, Readiness 9/10), pasted 2026-06-06. DO NOT EDIT between
> runs. Both backends, all 3 reps each, receive THIS exact text as the `/work` input.
> Target repo: SiteLine. Team key: POC.

---

# MVP: client Approve action on a published version (single sign-off)

## Light Spec

**Status:** Approved · **Complexity:** Medium (~6-10h) · **Derived tier:** tier:standard
**Linear Project:** i1-p2 Client Approval — Published Versions

### Problem

No durable, contract-level record of a client signing off on a budget. Today "client
approved" is free text in a snapshot's `description` (rendered "📷 Client approved (date)"
in `versions.js`) — unauditable, unattributable, unenforceable. Formal approval tables
(`approvals`/`approval_steps`) were scaffolded but never created; their notification
functions reference nonexistent tables and triggers are commented out as "Phase 3."

### Goal

A logged-in client contact with project access can click **Approve** on a published budget
version in the client view, producing a durable, attributable sign-off (who + when + which
snapshot) that the UI reflects and that notifies the internal publisher.

### Scope

**In scope:** persist approval (timestamp + approver contact id + optional note), one per
published version; Approve action in `project_detail.html`, gated; DB-level authz rejecting
non-access writes; "Approved (date)" stamp in internal version list + client view; internal
notification to publisher on approval.
**Out of scope:** multi-step/multi-approver engine (POC-58, parked); anonymous/link
approval; un-approve/revoke; dashboard "pending approvals" widget.

### Decisions (all DEFINED)

- Actor = authenticated contact only — from session `getCurrentContact()`, never a link token.
- Storage = approval fields directly on the `budget_snapshots` row; no approvals/approval_steps table in v1.
- One sign-off per published version: unapproved → approved-once; no re-approval.
- Surface = `project_detail.html` client view (`/project?recordId=…`), not a new page, not the producer editor.
- Notification recipient = version publisher (`snapshot_by`), fallback snapshot `created_by` if null.
- Write = plain RLS-guarded `UPDATE` on `budget_snapshots`, NO SECURITY DEFINER (avoids POC-87 footgun).
- Dashboard count = out of scope for v1.

### Requirements

- [ ] Authenticated contact with project access can record an approval on a published version from the client view.
- [ ] Approval persists who/when/optional-note, scoped to that published version.
- [ ] Approve action unavailable on working drafts and on already-approved versions.
- [ ] Write by a contact without project access is rejected at the DB layer.
- [ ] Recording an approval enqueues a notification to the version publisher.
- [ ] Approved versions show "Approved (date)" stamp in internal version list + client view, sourced from the approval field (not `description`).

### Acceptance Criteria

- [ ] Given an authenticated contact with project access viewing a published version (`is_snapshot = true`) not yet approved in `project_detail.html`, when they click **Approve**, then `approved_at` + `approved_by_contact_id` persist on that `budget_snapshots` row AND the view re-renders to the approved state without a full reload.
- [ ] Given an approved version, when the internal version list (`versions.js` `formatVersionLabel`) and the client view (`project_detail.html`) render it, then both show an "Approved (date)" stamp read from the persisted approval field.
- [ ] Given a contact **without** project access, when an approval `UPDATE` for that version is attempted, then RLS rejects it and no approval field is set.
- [ ] Given a working-draft (non-published) version, when an authenticated contact with access views it, then no Approve action is offered.
- [ ] Given an already-approved version, when any user views it, then the Approve action is not offered (no re-approval).
- [ ] Given an approval is recorded, when the notification queue is processed, then a notification targeting the publisher (`snapshot_by`, fallback `created_by`) is enqueued referencing that project + snapshot.

### Technical Context

- **Existing code:** `src/app/project_detail.html` (client view; inline script, version selector, `getClientSnapshots`, snapshot badge — Approve action lands here); `src/app/js/database/snapshots.js` (publish RPCs `snapshot_for_client`/`snapshot_and_continue`); `src/app/js/database/versions.js` `formatVersionLabel()` (~120-156; renders 📷 from `description`); `src/app/js/pages/budget-edit-main.js` (internal version list + LIVE tag ~7740/7943); `src/app/js/auth.js` `getCurrentContact()` (~936).
- **Database:** add nullable approval fields to `budget_snapshots` (`approved_at` timestamptz, `approved_by_contact_id` uuid FK→`contacts`, `approval_note` text). Notification: `notifications_queue` table + `enqueue_notification()` RPC (validates project access). Scaffolded `notify_on_approval_*` functions (migration `20260213142825`) reference never-created tables — **do not depend on them**.
- **Dependencies:** `process-notifications` edge function.
- **Patterns:** RLS via `user_has_project_access(project_id)`; existing `snapshots_select`/`snapshots_update` policies as exemplar; idempotent migrations + frozen-file invariant. New approval-write authz = an RLS UPDATE policy requiring project access + `is_snapshot = true` + not-yet-approved.
- **Authority:** the `budget_snapshots` row is the single source of truth for approval state; the version label and client view are *renderers* of that field and must read it (never `description`). Write authz authoritative at DB RLS layer; client JS gating is UX only.

### Notes

tier:standard. Contract-level sign-off — record must be unambiguous and auditable
(who + when + which snapshot). Touches financial sign-off but not totals math → not
financial-review-critical. Write path deliberately avoids SECURITY DEFINER per POC-87.

### Spec Review Agent verdict (v5)

Verdict: Pass · Spec: Pass · Readiness 9/10 · Blocking: None · Decomposition Readiness: Yes.
Non-blocking: (1) define behavior when `snapshot_by` AND `created_by` both null/non-notifiable;
(2) state whether the optional note is in the MVP click-UI or persisted-field-only;
(3) make the one-time invariant explicit at the write predicate (`approved_at is null` at UPDATE).
