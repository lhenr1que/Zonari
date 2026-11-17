# Contributing with coding agents

Read README.md, CONTRIBUTING.md and docs/development.md before editing. Keep changes scoped to the user's request and preserve unrelated work.

- Lua policy lives in src/core, GTK UI in crates/zonari-ui, Hyprland native code in src/bars and src/bars-0.56, Omarchy integration in omarchy.
- Add a failing regression test before fixing a bug. Validate with `bash scripts/check.sh`. Distinguish unit tests, builds and live desktop tests.
- Never execute user data as Lua. Write settings atomically; keep native plugins tied to the matching compositor ABI.
- Do not load plugins, modify user configuration, use sudo or change the live desktop without authorization. Back up files before authorized live tests.
- Preserve GPLv3 licensing and upstream BSD notices. Do not publish, merge or rename remotes unless requested.
- Keep public documentation concise and current. Do not commit prompts, transcripts, handoffs, raw test logs or agent-specific skills/settings. Put temporary work records outside the repository.
