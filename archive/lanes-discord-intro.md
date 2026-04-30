**Pipekit** — a structured AI-assisted software delivery system. Wraps VBW in a visibility + project management layer, with explicit quality gates from idea to production.

🔗 https://github.com/withpiper/pipekit

**Core principle:** no stage may introduce guesswork into the next stage. Specs, plans, and execution each pass independent gates before handoff.

**What's in the box:**
- 12-step pipeline (concept → ship) with Pass/Revise gates per stage
- Linear-native (issues, status, dependencies as first-class state)
- Three scale tiers (Quick / Standard / Heavy) with always-confirm routing
- Sync-safe overrides (customize without forking)
- Foundation Contract — Stage 0 as a set of artifacts, not a script
- /spec-preflight, /launch, /review-plan, /strategy-sync, and ~25 other portable skills

**Battle-tested.** Five releases in two days, ten closed issues, all methodology-driven. Every fix came from real friction during real shipping work.

**Pin to a version:** `./scripts/sync-method.sh v1.5.0`

Open to feedback — what gates do you wish your AI-coding stack enforced?
