# Linear Issue Workflow

You guide the user through working on a Linear issue end-to-end, updating the issue status and posting comments at each milestone.

## Triggers

This skill is invoked when the user says:
- `/linear PROJ-123`
- `/linear https://linear.app/{workspace}/issue/{PREFIX}-123/...`

## Arguments

The argument is a Linear issue identifier (e.g., `PROJ-178`) or a full Linear URL. Extract the identifier from the URL if needed. Read `method.config.md` for the issue prefix and workspace slug.

## Linear State IDs

Read all state IDs from your project's `method.config.md` under "Workflow State IDs". The table maps state names (Building, UAT, In Dev, In Beta, Done, etc.) to Linear state UUIDs specific to your workspace.

## Workflow Phases

The workflow has 5 phases. At each phase transition, update the Linear issue status and post a comment. Always confirm with the user before moving to the next phase.

---

### Phase 1: Understand

1. **Fetch the issue** using `mcp__linear-server__get_issue` with the identifier.
2. **Present a summary** to the user:
   - Title, description, priority, labels, current state
   - Any existing comments
   - If the issue has a linked spec (`**Spec:**` or `**Linked spec:**` in description), read it
3. **Move to Building** using `mcp__linear-server__save_issue` with `stateId: {Building state ID from method.config.md}`.
4. **Post a comment**: "Started work on this issue."
5. **Ask the user** to confirm the scope and approach before proceeding.

---

### Phase 2: Implement

1. **Create a worktree** using `pk branch <ID>` (Linear-issue-based, recommended) or manually:
   - Branch from `dev` (default) or `main` (hotfixes only)
   - Worktree at `{worktree prefix from method.config.md}<description>/`
   - Use the appropriate prefix:
     - `hotfix/` for urgent production fixes (branch from `main`)
     - `fix/` for bug fixes (branch from `dev`)
     - `feature/` for new functionality (branch from `dev`)
     - `refactor/` for code restructuring (branch from `dev`)
   - Use kebab-case, keep it short and descriptive
   - Include the issue ID if natural (e.g., `feature/wit-178-markup-tooltip`)
2. **Do the work** — implement the changes as discussed.
3. **Commit** with conventional commit format: `{type}({scope}): {description}` and include `Closes PROJ-XXX` in the body.
4. **Push the branch** and verify the Vercel preview deployment succeeds.
5. **Post a comment** to the Linear issue summarizing what was done and the Vercel preview URL.

---

### Phase 3: Review

1. **Ask the user** to test on the Vercel preview URL (or the dev environment URL if merged to dev).
2. If the user requests changes, make them, commit, push, and update the Linear comment.
3. When the user approves:
   - **Create a PR** to `dev` (or `main` for hotfixes) using `gh pr create` with:
     - Short title (under 70 chars)
     - Body with Summary bullets + Test plan checklist
     - `Closes PROJ-XXX` in the body
   - **Move to UAT** using `mcp__linear-server__save_issue` with `stateId: {UAT state ID from method.config.md}`.
   - **Post a comment** with the PR link.

---

### Phase 4: Merge & Deploy

1. **Wait for PR checks** to pass (CI: type-check, lint, test).
2. When the user says to merge:
   - **Merge the PR** using `gh pr merge` (default merge commit, not squash).
   - For **normal flow** (merged to `dev`): the change deploys automatically to the dev environment via Vercel.
   - For **production** (merged to `main`): verify `vercel --prod` deployment succeeds.
   - For **hotfixes** (merged to `main`): immediately cherry-pick back to both `dev` and `beta`.
   - **Post a comment** confirming deployment target.
3. **Transition state per environment.** Under v2.5.0, state maps 1:1 to environment via env-named statuses:
   - **2-tier project** (`Ship environments: dev,main`): on `dev` merge → move to **In Dev** (set by `pk done`); on `main` merge → move to **Done** (set by `pk promote main`).
   - **3-tier project** (`Ship environments: dev,beta,main`): on `dev` merge → **In Dev** (`pk done`); on `beta` merge → **In Beta** (`pk promote beta`); on `main` merge → **Done** (`pk promote main`).
   - The recommended path is `pk done` (UAT → `In <FirstEnv>`) and `pk promote <env>` (one hop per call). This manual fallback only applies if you opened the promote PR by hand without `pk promote`.

---

### Phase 5: Cleanup

1. **Clean up the worktree** using `pk done <ID>` (Linear-issue-based, recommended) or manually:
   ```bash
   # From main repo directory
   git worktree remove {worktree prefix from method.config.md}<description>/
   git branch -d <branch-name>
   git push origin --delete <branch-name>
   ```
2. **Post a final comment** summarizing the full change and confirming deployment.
3. **Report to the user** that the issue is complete.

---

## Status Transition Summary

| Phase | Status | Comment |
|-------|--------|---------|
| Understand | Building | "Started work on this issue." |
| Implement | Building | Summary of changes + preview URL |
| Review (iterations) | Building | Updates on changes |
| Review (PR created) | UAT | PR link |
| Merge to first env | In `<FirstEnv>` (e.g. In Dev) | Set by `pk done` |
| Promote intermediate | In `<Env>` (e.g. In Beta) | Set by `pk promote <env>` |
| Final promote | Done | Deployment confirmed |

## Comment Style

Keep Linear comments concise and useful:
- **Bold the milestone** (e.g., "**Fix deployed to dev**")
- Use bullet points for changes
- Include commit hashes, branch names, PR links, preview URLs, and deploy targets
- Don't repeat the full issue description

## Important Notes

- Always confirm with the user before changing issue status
- If the user wants to skip phases (e.g., go straight to prod), accommodate but warn about risks
- If the issue already has a branch or PR, pick up from the appropriate phase
- If the user says "close" or "done" at any point, skip to Phase 4/5
- Keep the user informed of every status change you make
- **Branch strategy:** PRs target `dev` by default. Only hotfixes target `main`. See CLAUDE.md for the full release flow.
- **Worktrees:** All work happens in worktrees at `{worktree prefix from method.config.md}<description>/`, not branch switching in the main repo.

## Related

- Branch + worktree: `pk branch <ID>` — creates worktree + branch + Linear → In Progress (idempotent)
- v2 daily loop: `pk next` → `pk branch` → `/work` → `/verify` → `pk ship` → `pk done` → `/pk-exit` (recommended path; this skill is the manual hands-on alternative)
- Batch processing: `/linear-todo-runner` — rolling parallel queue for multiple issues
- Promotion: `pk ship` (feature → integration branch) + `pk promote` (walks the chain per `Ship environments` in `method.config.md`)
- Session log: `/pk-exit` — narrative session log to `Logs/Sessions/<date>_<HHMM>.md` (last command of every Claude Code session)
- Git workflow: See CLAUDE.md "Branch Strategy"
