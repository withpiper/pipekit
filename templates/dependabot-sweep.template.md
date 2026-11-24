# Dependabot Sweep — {PROJECT}

Project-specific values consumed by the portable `/dependabot-sweep` skill. Copy this file to
your project (default path `resources/dependabot-sweep.md`, or set `Dependabot sweep config`
in `method.config.md`) and fill in every section. The skill refuses to run while any
`EXAMPLE` marker or `{PROJECT}` remains — delete each example once replaced. The skill
supplies the triage lanes, the safety envelope and the repair procedure; this file supplies
what only your repo knows. Keep it committed — it's project-owned, never overwritten by sync.

> Examples below assume a pnpm monorepo with one nested npm package and a Deno functions
> directory. Replace them with your own; delete what doesn't apply.

---

## Never auto-merged

Groups or packages the sweep always HOLDs, each with the reason and the recommended action
for the Phase 6 question. Typical entries: a package a test pins to a CDN/SRI copy, two
packages that form one contract and must move together, anything whose bump needs a manual
re-verification first.

| Group or package | Why | Recommended action |
|---|---|---|
| EXAMPLE `supabase` group | `@supabase/ssr` and `supabase-js` share one storage contract; `src/lib/version-pin.test.ts` fails on purpose until it is re-verified | Leave open; file a Linear issue "re-verify <contract> for <pkg> <ver>" |
| EXAMPLE `dompurify` | Browser loads it from a CDN URL with an SRI hash; `tests/dompurify-pin.test.js` holds npm to that pin | Leave open; file a Linear issue to move the CDN pin and the npm version together |

Off-limits paths (any PR touching these is HOLD, beyond `Migration dir`):

```
# EXAMPLE — replace:
apps/legacy/supabase/functions/
```

## Lockfiles

Every lockfile a Refresh may regenerate, the manifest that drives it, and the **lockfile-only,
script-free** command that regenerates it. Use the tool and flags CI uses to check the lock,
minus the frozen flag — a broader install variant can rewrite thousands of unrelated lines.

| Lockfile | Manifest | Regenerate (run from repo root) |
|---|---|---|
| EXAMPLE `pnpm-lock.yaml` | `package.json`, `pnpm-workspace.yaml` | `pnpm install --lockfile-only --ignore-scripts` |
| EXAMPLE `apps/legacy/package-lock.json` | `apps/legacy/package.json` | `(cd apps/legacy && npm install --package-lock-only --ignore-scripts)` |
| EXAMPLE `apps/legacy/deno.lock` | `apps/legacy/deno.json`, imports in `supabase/functions` | `(cd apps/legacy && find supabase/functions -name '*.ts' \| xargs deno check --frozen=false --node-modules-dir=none)` |

## Stale-base triggers

Files whose change on the integration branch since a PR's checks ran makes that PR's green
result stale (Phase 4). Leave blank to use every lockfile and manifest in the table above.

```
# EXAMPLE — replace:
pnpm-workspace.yaml
```

## Local smoke

Cheap checks after a Refresh, before the push. Frozen installs, scripts off.

```bash
# EXAMPLE — replace:
pnpm install --frozen-lockfile --ignore-scripts
(cd apps/legacy && npm ci --ignore-scripts)
(cd apps/legacy && npm run check:functions)    # needs deno
```

## Post-merge check

Run after every merge's CI on the integration branch passes. Leave blank to rely on CI alone.

```bash
# EXAMPLE — replace:
curl -s https://dev.example.com/api/health    # expect {"status":"ok"}
```

## Merge order

Leave blank for the default (GitHub Actions groups, then single-package groups, then the large
grouped updates).

## Known noise

CI failures that are not bump failures, and the slowest CI job (the WAIT timeout is 1.5× it).

- EXAMPLE — slowest job: `unit-tests`, up to 50 minutes.
- EXAMPLE — `sync` and `check-generated-types` fail with `Secret source: Dependabot`: the Dependabot secret store is empty. A Refresh clears them.
- EXAMPLE — `src/lib/version-pin.test.ts` failing on a supabase bump is the deliberate tripwire above (HOLD), not noise.
