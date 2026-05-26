# Supabase Branch-DB Seed Strategy Runbook

**Purpose:** Make per-PR Supabase branch DBs testable on arrival — known test user, representative fixtures, working login — via `supabase/seed.sql`. Read `sop/Git_and_Deployment.md` § Solo-dev exception first; this runbook implements **Path A** of that decision tree.

**Audience:** A Pipekit consuming project on the Vercel-Supabase branching integration where per-PR branch DBs currently come up empty. Written generically; replace `<project>` and `<test-user-uuid>` with your project's values throughout.

**Estimated time:** ~30 min for Step 0 pre-flight + 1-2 hours for initial seed design + ongoing maintenance (~1h/quarter as schemas evolve).

**Reversibility:** Trivial. `git rm supabase/seed.sql` returns you to empty-branch state. No workflow surgery required.

---

## Step 0 — Verify `seed.sql` auto-runs on a branch DB (load-bearing pre-flight)

**Do not invest in seed design until you confirm the hook exists on your stack.** Vercel-Supabase integration versions / Supabase plans differ in whether they auto-execute `supabase/seed.sql` on branch DB initialization. Find out cheaply, before writing real seed.

1. Add a single sentinel insert to `supabase/seed.sql` (create the file if it doesn't exist):
   ```sql
   -- Sentinel: Step 0 pre-flight for branch-DB seed runbook. Remove after validation.
   CREATE TABLE IF NOT EXISTS public._seed_health_check (
     id serial PRIMARY KEY,
     stamp timestamptz NOT NULL DEFAULT now(),
     note text
   );
   INSERT INTO public._seed_health_check (note)
   VALUES ('seed.sql ran during branch DB provisioning')
   ON CONFLICT DO NOTHING;
   ```
2. Commit the sentinel on a throwaway branch (`git checkout -b throwaway/seed-preflight`) and open a PR.
3. After the Supabase branch DB provisions, connect to it (Vercel will print the connection details in the deploy log, OR use the Supabase dashboard → Branches view) and run:
   ```sql
   SELECT * FROM public._seed_health_check;
   ```
4. **If you see a row:** `seed.sql` runs automatically. You have the hook you need — continue to Step 1.
5. **If the table doesn't exist or is empty:** the integration is not running `seed.sql` on branch creation. Three options:
   - Check Supabase project settings → Database → Settings for a "run seed.sql on branch initialization" toggle (some plans have this; older or lower-tier plans may not)
   - Add a GHA workflow that runs `supabase db push --linked` + executes `seed.sql` via `psql` after the branch DB is detected as ready (more work but generic)
   - Fall back to Path B (decommission per `resources/supabase-branch-db-decommission.md`)

6. After validating, remove the sentinel table from `seed.sql` and drop it from any branch DBs that received it. Close the throwaway PR.

**Why this is Step 0:** the whole runbook is predicated on the seed hook firing. If it doesn't fire on your stack, every subsequent step is wasted work. 15 minutes here saves potentially hours of "why isn't my test user showing up in the branch DB."

---

## Step 1 — Verify `auth.users` insert pattern against installed Supabase CLI

Per `pipekit-tooling.md` § Source Authority Hierarchy + § Enumerate the Surface Before Claiming Behavior: `auth.users` columns + required triggers have shifted across Supabase CLI versions. Don't guess.

1. `supabase --version` — record the version.
2. Read the canonical schema source:
   ```bash
   # Local: spin up supabase, look at the auth schema directly
   supabase start
   psql "$(supabase status -o env --override-name api.db.url DATABASE_URL | grep DATABASE_URL | cut -d= -f2-)" \
     -c "\\d auth.users"
   ```
3. Note the required columns. As of mid-2026 Supabase CLI v2+, the minimum-viable insert for a password-grant user is roughly:
   - `id` (uuid, PK)
   - `instance_id` (uuid, typically `'00000000-0000-0000-0000-000000000000'` for the default instance)
   - `aud` (text, typically `'authenticated'`)
   - `role` (text, typically `'authenticated'`)
   - `email` (text)
   - `encrypted_password` (text, bcrypt via `crypt(password, gen_salt('bf'))`)
   - `email_confirmed_at` (timestamptz — MUST be set or login flows fail)
   - `raw_app_meta_data` (jsonb, typically `'{"provider":"email","providers":["email"]}'`)
   - `raw_user_meta_data` (jsonb, typically `'{}'`)
   - `created_at` (timestamptz)
   - `updated_at` (timestamptz)
4. **Plus a companion `auth.identities` row** for the password-grant flow:
   - `id` (uuid)
   - `user_id` (uuid, FK → auth.users.id)
   - `provider_id` (text, the email value duplicated)
   - `provider` (text, `'email'`)
   - `identity_data` (jsonb, e.g., `'{"sub": "<user-uuid>", "email": "test@piper.dev"}'`)
   - `last_sign_in_at` (timestamptz)
   - `created_at` / `updated_at`

5. **Verify your specific version's requirements** by reading `node_modules/@supabase/supabase-js/dist/...` types if available, OR by inspecting the columns directly via `\d auth.users` and `\d auth.identities`. If you can't reach a Tier 1-4 source per the source-authority hierarchy, emit the seed pattern with `UNVERIFIED:` flags and validate against the real schema before committing.

If you'd rather skip the raw-SQL `auth.users` insert entirely, an alternative is a **Node-side post-provisioning script** that calls `supabase.auth.admin.createUser({ email, password, email_confirm: true })` — this hides the schema details behind the SDK. Trade-off: requires a Node runtime in your seeding context (GHA step, not `seed.sql`), so you lose the "single seeding pattern, two contexts" property.

---

## Step 2 — Design the seed (minimum viable, then incremental)

Don't try to seed everything on day one. Start with the smallest set that makes the app loadable, then grow as needed.

**Minimum viable seed (day 1):**

1. **One test user** with known password
2. **One organization** the test user belongs to
3. **One entity** under the org (per ADR-004's 1:1 org=entity topology, if applicable)
4. **Membership** linking the user to the org with the highest-privilege role (typically `org_admin` or `finance_admin`)

That's it. With this much seed, the app loads, the user can log in, and the UI renders empty states cleanly.

**Incremental additions (add as you hit them):**

5. **A second org** to test cross-org RLS isolation (skip if you don't have cross-org views)
6. **Sample projects** so project-list views aren't empty
7. **Sample budget snapshots + line items** for budget-editor surfaces
8. **A few representative custom tax codes / rates** in the seeded org (system tax codes are migration-seeded — see WIT-419 for the pattern)
9. **A non-admin user** in the seeded org for permission-gating tests

Discipline: every fixture added is fixture you must maintain. Add only what unblocks a real testing surface.

---

## Step 3 — Write `supabase/seed.sql` with idempotency + sentinel UUIDs

Two patterns make seed maintenance manageable:

**Sentinel UUIDs for seed data.** Use `00000000-0000-0000-0000-000000000XXX` for every seeded ID. This makes seed data trivially identifiable (`WHERE id LIKE '00000000%'`) and prevents collisions with production-shaped data. Reserve a range — e.g., `001-009` for users, `010-019` for orgs, `020-029` for entities, `030-099` for fixtures.

**`ON CONFLICT DO NOTHING` on every INSERT.** Supabase may re-run `seed.sql` on branch DB re-provisioning, or you may want to re-run `supabase db reset` locally without dropping the existing test data. Idempotent INSERTs make both safe.

Example structure (verify column names against your Supabase CLI version per Step 1):

```sql
-- ============================================================================
-- supabase/seed.sql
-- Test fixtures for local dev + Vercel-Supabase branch DBs.
-- Sentinel UUIDs: 00000000-0000-0000-0000-000000000XXX
--   001-009  →  users
--   010-019  →  orgs
--   020-029  →  entities
--   030-099  →  fixtures
-- ============================================================================

-- 1. Test user with bcrypt'd password (testpass123)
-- VERIFY auth.users columns against installed Supabase CLI before running.
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated',
  'test@<project>.dev',
  crypt('testpass123', gen_salt('bf')),
  now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb,
  now(), now()
)
ON CONFLICT (id) DO NOTHING;

-- 2. Identity row for password-grant flow
INSERT INTO auth.identities (
  id, user_id, provider_id, provider, identity_data,
  last_sign_in_at, created_at, updated_at
)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  'test@<project>.dev', 'email',
  jsonb_build_object('sub', '00000000-0000-0000-0000-000000000001', 'email', 'test@<project>.dev'),
  now(), now(), now()
)
ON CONFLICT (id) DO NOTHING;

-- 3. Test organization (prefer calling your canonical create-org RPC if you have one)
INSERT INTO public.organizations (id, name, ...)
VALUES ('00000000-0000-0000-0000-000000000010', 'Test Org', ...)
ON CONFLICT (id) DO NOTHING;

-- 4. Membership linking test user as org_admin / finance_admin
INSERT INTO public.organization_members (organization_id, user_id, role)
VALUES (
  '00000000-0000-0000-0000-000000000010',
  '00000000-0000-0000-0000-000000000001',
  'finance_admin'
)
ON CONFLICT (organization_id, user_id) DO NOTHING;

-- 5. Test entity under the org (if your topology requires entities)
INSERT INTO public.entities (id, organization_id, name, ...)
VALUES (
  '00000000-0000-0000-0000-000000000020',
  '00000000-0000-0000-0000-000000000010',
  'Test Entity', ...
)
ON CONFLICT (id) DO NOTHING;

-- Add incremental fixtures (projects, budgets, line items) below as needed.
-- Document each block with a comment naming the surface it unblocks.
```

**Prefer canonical RPCs over raw INSERTs where you have them.** If your app creates orgs via `SELECT create_organization('Test Org', '00000000-0000-0000-0000-000000000010')`, the seed should too — that way RLS predicates, audit-log writes, and trigger side-effects all fire correctly and the seed exercises the same code path as production.

---

## Step 4 — Local validation

1. `supabase db reset` — applies migrations + runs `seed.sql`
2. Confirm the test user exists: `psql ... -c "SELECT id, email FROM auth.users WHERE id LIKE '00000000%';"`
3. Boot the app locally: `pnpm dev` (or equivalent)
4. Navigate to login → sign in as `test@<project>.dev` / `testpass123`
5. Confirm the seeded org + entity show up in the appropriate UI surfaces
6. Confirm RLS doesn't leak: log out, try direct API requests as the anon user, verify they're rejected appropriately

If anything fails: fix the seed locally first. Don't push a broken seed.

---

## Step 5 — Cloud validation on a real branch DB

1. Commit the seed: `git add supabase/seed.sql && git commit -m "feat(seed): test user + org + entity fixtures for branch DBs"`
2. Push to a feature branch and open a PR
3. Wait for the Supabase branch DB to provision (Vercel deploy log shows the link)
4. Connect to the branch DB (via Supabase dashboard → Branches OR the connection string in Vercel envs) and confirm:
   - `SELECT email FROM auth.users WHERE id LIKE '00000000%';` returns the test user
   - The org / entity rows exist
5. Open the preview deploy URL → log in as the test user → confirm full app flow works
6. Close the PR (or leave open if it has real changes)

If step 4 fails (data missing on the cloud branch DB): the seed isn't running in the cloud context despite Step 0's confirmation. Common cause: an `seed.sql` syntax error that the cloud branch silently swallows but local doesn't. Check Supabase branch DB logs.

---

## Step 6 — Enable Vercel Preview password protection

Critical security gate. Preview URLs are publicly accessible by default. Your test user has `finance_admin` privileges on the seeded org — anyone with the URL can log in and exercise mutation surfaces.

In Vercel project settings → Deployment Protection → Preview Deployments:

- Toggle on "Vercel Authentication" (requires Vercel login to access) OR "Password Protection" (shared password)
- Save changes
- Test: open a preview URL in an incognito window, confirm you're gated

If your project requires preview deploys to be accessible to external collaborators (e.g., design review, client previews), use Vercel's "Comments" feature or generate per-collaborator access tokens rather than removing the gate.

---

## Step 7 — Maintenance discipline

Seed will drift from schema if you let it. Two anti-drift practices:

1. **Schema-change PR template addition:** add a checklist item to your PR template — "If this PR modifies tables / columns / RLS that `supabase/seed.sql` touches, update the seed in the same PR."
2. **Local CI gate:** add a vitest / pgtap assertion that confirms login works against the seed-applied DB. If `supabase db reset` succeeds but the test user can't log in, the seed has drifted. CI catches it on every PR.

Quarterly: run `supabase db reset` from main, log in as the test user, click through every major UI surface. If anything is broken, the seed drifted. ~30 minutes; catches drift before it accumulates.

---

## File checklist

After Path A is live:

- [ ] `supabase/seed.sql` — minimum viable seed (test user + org + entity + membership)
- [ ] `.github/PULL_REQUEST_TEMPLATE.md` — checklist item for seed update on schema changes
- [ ] One vitest / pgtap assertion that login-as-test-user succeeds on a freshly-reset DB
- [ ] Vercel project settings → Deployment Protection → Preview enabled
- [ ] `CLAUDE.md` or onboarding doc — documents `test@<project>.dev` / `testpass123` as the dev login
- [ ] One-cycle proof: a real PR has gone through branch-DB → seeded → tested via preview → merged successfully
- [ ] Pre-flight sentinel removed from `seed.sql`

---

## What this runbook does NOT cover

- **Auth provider flows beyond email/password** (magic link, OAuth, SSO) — seed only covers password-grant. If your prod flow is OAuth-only, the test user via `seed.sql` is for local + branch-DB only; production user creation goes through the OAuth provider.
- **Realistic data volume for performance testing** — seed is for testability, not load. For load testing, use a separate fixture-generation script targeting the integration DB.
- **Multi-tenant test fixtures** at scale — once you have ≥ 3 orgs in the seed, consider extracting fixture data into JSON files and loading via a small Node loader script invoked from `seed.sql` via `\set` + `\copy`.
- **Production data sanitization for testing against real-shape data** — separate concern, much heavier; consider Supabase's seed-from-snapshot features or third-party tools like Snaplet.
