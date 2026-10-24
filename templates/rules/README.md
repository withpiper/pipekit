# Claude Code Rules

Every file here auto-loads into every session. Rules carry the rule only; the incident behind a rule goes in an SOP. Full guide: `sop/Rules_SOP.md` (`pipekit/sop/` in consuming projects).

- **Pipekit owns six files here:** `pipekit-discipline.md`, `pipekit-tooling.md`, `pipekit-security.md`, `pipekit-migrations.md`, `pipekit-cmux.md` and this README. `sync-method.sh` overwrites local edits to them on every run. To change a canonical rule for this project, write a companion file (e.g. `security.md` beside `pipekit-security.md`); it takes precedence per the Routing Pointers order in CLAUDE.md. To change it everywhere, change it in Pipekit.
- **A canonical rule that doesn't apply** is dropped with `Skip rules: <name>, …` in `method.config.md`, not by deleting the file.
- **Project-specific rules** are new files here with any other name (`patterns.md`, `naming.md`, `{library}-pitfalls.md`). Scope one to paths with `paths:` frontmatter when it only matters for some files.
