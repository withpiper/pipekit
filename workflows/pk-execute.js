export const meta = {
  name: 'pk-execute',
  description: 'Execute a /work task DAG: one agent per task, verify before commit, integrate in order',
  whenToUse: 'Invoked by /work Step 5 with the parsed .pk-work/<ID>-PLAN.md as args. Not for ad-hoc use.',
  phases: [
    { title: 'Execute', detail: 'tasks in dependency order; disjoint-file siblings in parallel when isolation is on' },
    { title: 'Integrate', detail: 'cherry-pick a parallel wave onto the feature branch, re-run each verify' },
  ],
}

// pk-execute — the executor half of /work (Pipekit).
//
// The session parses .pk-work/<ID>-PLAN.md and hands the DAG in as `args`;
// this script holds the loop so the session's context holds only the result.
// Scripts have no filesystem or git access, so every read, edit, test and
// commit happens inside an agent; the script decides order, parallelism and
// when to stop, and threads the expected HEAD sha from task to task so an
// agent that finds a different HEAD refuses to edit ("wrong-base") instead of
// building on a tree the plan never saw.
//
// args = {
//   issue, title, goal,            // goal: one line — why this issue exists, who it serves
//   integration,                   // integration branch name (for context only)
//   baseSha,                       // feature-branch HEAD when the run starts
//   worktreePath,                  // the issue's worktree (where sequential tasks commit)
//   testCommand,                   // the AC-named test command, else the pre-deploy gate
//   parallel,                      // true only when the session verified worktree.baseRef=head
//   maxParallel,                   // wave width cap (default 3)
//   model, effort,                 // execution tier per § Model Policy; null/absent → inherit
//   tasks: [{ id, title, deps, files, change, verify, done, spec }],
// }
//
// Returns { status: 'complete' | 'stopped', headSha, results: [...] } — the
// session writes .pk-work/<ID>-SUMMARY.md from `results`.

const TASK_RESULT = {
  type: 'object',
  required: ['status', 'summary'],
  properties: {
    status: { type: 'string', enum: ['done', 'verify-failed', 'blocked', 'wrong-base'] },
    commitSha: { type: 'string', description: 'full sha of the commit this task made (status done only)' },
    headSha: { type: 'string', description: 'git rev-parse HEAD after the commit (status done only)' },
    branch: { type: 'string', description: 'git branch --show-current where the commit landed' },
    filesTouched: { type: 'array', items: { type: 'string' } },
    testsAuthored: { type: 'array', items: { type: 'string' }, description: 'test files created or extended' },
    verifyCommand: { type: 'string' },
    verifyPassed: { type: 'boolean' },
    verifyTail: { type: 'string', description: 'last ~20 lines of the verify output' },
    summary: { type: 'string', description: 'one or two sentences: what changed, grounded in tool results' },
    notes: { type: 'string', description: 'adjacent problems noticed but NOT fixed; deviations from the task' },
  },
}

const INTEGRATE_RESULT = {
  type: 'object',
  required: ['status', 'summary'],
  properties: {
    status: { type: 'string', enum: ['done', 'integrate-failed'] },
    headSha: { type: 'string' },
    picked: { type: 'array', items: { type: 'string' } },
    verifyTail: { type: 'string' },
    summary: { type: 'string' },
  },
}

const a = args || {}
const tasks = Array.isArray(a.tasks) ? a.tasks : []
if (!tasks.length) throw new Error('pk-execute: args.tasks is empty — parse the PLAN before invoking')
if (!a.baseSha) throw new Error('pk-execute: args.baseSha is required (git rev-parse HEAD in the worktree)')
const maxParallel = Math.max(1, a.maxParallel || 3)
const agentOpts = (extra) => {
  const o = { phase: 'Execute', ...extra }
  if (a.model) o.model = a.model
  if (a.effort) o.effort = a.effort
  return o
}

// ---- dependency levels (Kahn), then waves of pairwise-disjoint file sets ----
const byId = new Map(tasks.map((t) => [t.id, t]))
for (const t of tasks) {
  for (const d of t.deps || []) {
    if (!byId.has(d)) throw new Error(`pk-execute: ${t.id} depends on unknown task ${d}`)
  }
}
const levels = []
const placed = new Set()
while (placed.size < tasks.length) {
  const ready = tasks.filter((t) => !placed.has(t.id) && (t.deps || []).every((d) => placed.has(d)))
  if (!ready.length) throw new Error('pk-execute: dependency cycle in the PLAN')
  levels.push(ready)
  ready.forEach((t) => placed.add(t.id))
}

const disjoint = (t, wave) => wave.every((w) => !(w.files || []).some((f) => (t.files || []).includes(f)))
const waves = []
for (const level of levels) {
  if (!a.parallel) {
    level.forEach((t) => waves.push([t]))
    continue
  }
  const open = []
  for (const t of level) {
    const w = open.find((wave) => wave.length < maxParallel && disjoint(t, wave))
    if (w) w.push(t)
    else open.push([t])
  }
  waves.push(...open)
}

// ---- prompts ----------------------------------------------------------------
const taskPrompt = (t, expectedHead, isolated) => `You are executing one task of a planned change for Linear issue ${a.issue} — ${a.title}.
Why this issue exists: ${a.goal || '(not stated)'}
Integration branch: ${a.integration || '(unknown)'}

${isolated
  ? `You are in an isolated worktree branched from the feature branch. Work and commit here; the orchestrator integrates your commit afterwards.`
  : `You are in the issue's worktree at ${a.worktreePath || 'the current directory'}. Commit directly on the feature branch.`}
First command: \`git rev-parse HEAD\`. It must print ${expectedHead}. If it does not, change nothing and return status "wrong-base" with what you saw.

Task ${t.id} — ${t.title}
Files you may write: ${(t.files || []).join(', ') || '(none listed)'}
  Stay inside this set. A change that needs a file outside it is reported in notes, not made.
Change: ${t.change}
Verify: ${t.verify}
Done when: ${t.done}
${t.spec ? `Spec slice:\n${t.spec}\n` : ''}
How to work:
- Author the tests this task calls for, before or with the code, then run the verify command exactly as written${a.testCommand ? ` (project test command: \`${a.testCommand}\` — use it verbatim before improvising)` : ''}.
- Commit only if verify passes: one commit, \`git add\` scoped to the files above (never \`git add -A\`), subject in the form {type}({scope}): {desc} saying why.
- If verify fails, do not loop and do not paper over it: leave the tree as is, do not commit, return status "verify-failed" with the output tail.
- If you are blocked (a permission denial, a hook you cannot satisfy, a type error that contradicts the plan), return status "blocked" and say what you saw.
- Keep to this task. A pre-existing bug, a cleanup, or an abstraction the task does not need goes in notes as a follow-up, not in the commit.
- Before returning, audit each claim in your summary against a tool result from this session; report only what you can point to.
Your final output is the structured result, not a message to a person.`

const integratePrompt = (wave, results, expectedHead) => `You are integrating a parallel wave of task commits for Linear issue ${a.issue} onto the feature branch.
You are in the issue's worktree at ${a.worktreePath || 'the current directory'}.
First command: \`git rev-parse HEAD\`. It must print ${expectedHead}. If it does not, change nothing and return status "integrate-failed".

Cherry-pick these commits in this order, one at a time:
${wave.map((t, i) => `- ${t.id} ${t.title}: ${results[i].commitSha}`).join('\n')}

Each task declared a disjoint file set, so no conflict is expected. If a cherry-pick conflicts, run \`git cherry-pick --abort\`, do not resolve by hand, and return status "integrate-failed" naming the conflicting files.
After all picks, re-run every task's verify on the integrated tree:
${wave.map((t) => `- ${t.id}: ${t.verify}`).join('\n')}
If any verify fails on the integrated tree, return status "integrate-failed" with the output tail (leave the picks in place; the orchestrator decides).
On success return status "done", the new HEAD sha, and the picked shas. Your final output is the structured result, not a message to a person.`

// ---- run ---------------------------------------------------------------------
let head = a.baseSha
const results = []
let stopped = null

for (const wave of waves) {
  if (stopped) break
  if (wave.length === 1) {
    const t = wave[0]
    log(`${t.id} ${t.title}`)
    const r = await agent(taskPrompt(t, head, false), agentOpts({ label: t.id, schema: TASK_RESULT }))
    const rec = { task: t.id, title: t.title, mode: 'sequential', ...(r || { status: 'blocked', summary: 'agent returned no result' }) }
    results.push(rec)
    if (rec.status !== 'done') { stopped = rec; break }
    if (!rec.headSha) { rec.status = 'blocked'; rec.summary += ' (no headSha returned)'; stopped = rec; break }
    head = rec.headSha
    continue
  }

  log(`parallel wave: ${wave.map((t) => t.id).join(', ')}`)
  const rs = await parallel(wave.map((t) => () =>
    agent(taskPrompt(t, head, true), agentOpts({ label: t.id, schema: TASK_RESULT, isolation: 'worktree' }))))
  const recs = wave.map((t, i) => ({ task: t.id, title: t.title, mode: 'parallel', ...(rs[i] || { status: 'blocked', summary: 'agent returned no result' }) }))
  results.push(...recs)
  const bad = recs.find((r) => r.status !== 'done' || !r.commitSha)
  if (bad) { stopped = bad; break }

  log(`integrate: ${wave.map((t) => t.id).join(', ')}`)
  const ir = await agent(integratePrompt(wave, recs, head), agentOpts({ label: `integrate ${wave.map((t) => t.id).join('+')}`, phase: 'Integrate', schema: INTEGRATE_RESULT, effort: 'low' }))
  const irec = { task: `integrate:${wave.map((t) => t.id).join('+')}`, mode: 'integrate', ...(ir || { status: 'integrate-failed', summary: 'integrator returned no result' }) }
  results.push(irec)
  if (irec.status !== 'done' || !irec.headSha) { stopped = irec; break }
  head = irec.headSha
}

if (stopped) log(`stopped at ${stopped.task}: ${stopped.status}`)
return { status: stopped ? 'stopped' : 'complete', headSha: head, waves: waves.map((w) => w.map((t) => t.id)), results }
