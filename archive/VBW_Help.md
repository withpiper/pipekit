VBW Help — v1.35.1

Lifecycle — The Main Loop
    /vbw:discuss [N]         Start/continue phase discussion before planning
    /vbw:init                Set up environment, scaffold .vbw-planning
    /vbw:vibe [intent/flags] The one command — routes to any lifecycle mode
                             (plan, execute, verify, discuss, archive, etc.)

Monitoring — Trust But Verify
    /vbw:status              Project progress dashboard

    Note: /vbw:qa and /vbw:verify were absorbed into /vbw:vibe --verify
    in v1.35.0. They still exist as hidden commands but are no longer
    part of the public help surface.

Supporting — The Safety Net
    /vbw:compress <file>     Caveman-compress natural language to save tokens
    /vbw:config              View/modify VBW configuration
    /vbw:debug <desc>        Investigate bugs with scientific method
                             (now self-contained — absorbs QA + UAT inline)
    /vbw:doctor              Health checks on installation
    /vbw:fix <desc>          Quick fix with commit discipline
    /vbw:help [cmd]          This help screen
    /vbw:list-todos          List pending backlog items with action hints
    /vbw:pause               Save session notes
    /vbw:profile [name]      Switch work profiles
    /vbw:report [desc]       Collect diagnostics, classify, auto-file GH issue
    /vbw:resume              Restore project context
    /vbw:skills              Browse/install community skills
    /vbw:teach               Manage project conventions
    /vbw:todo <desc>         Add to persistent backlog

Advanced
    /vbw:map                 Analyze codebase with Scout agents
    /vbw:research <topic>    Standalone research via Scout (with staleness tracking)
    /vbw:uninstall           Remove all VBW traces
    /vbw:update              Update to latest version
    /vbw:whats-new           View changelog

Getting Started: /vbw:init → /vbw:vibe → /vbw:vibe --archive

--

Resolved quirks (historical)

    .vbw-planning/.agent-pids leak into git status — FIXED in v1.35.1
        Was: planning-git.sh sync-ignore only wrote the nested
             .vbw-planning/.gitignore in commit mode, so manual-mode
             projects (the default) never got transient files filtered.
        Now: per upstream PR #517 (swt-labs/vibe-better-with-claude-code-vbw
             issue #506), ensure_transient_ignore fires across all three
             planning_tracking modes. Regression coverage in
             tests/planning-git.bats.
        Action for projects on v1.35.0 or earlier: bump to v1.35.1 via
             /vbw:update; nested .gitignore will materialize on next
             /vbw:config or /vbw:init invocation.

