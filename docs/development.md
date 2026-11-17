# Development

## Build

The root Cargo workspace contains `crates/zonari-ui`. Lua modules live in `src/core`; native bars are split between `src/bars` (0.57) and `src/bars-0.56` (0.56.2).

```sh
cargo build --release --locked
make -C src/bars abi          # use src/bars-0.56 for Hyprland 0.56.2
```

Requires Rust, a C++23 compiler, make, Lua, GTK4, gtk4-layer-shell, librsvg and matching Hyprland headers. See [installation](installation.md) for pkg-config dependencies.

## Validation

```sh
bash scripts/check.sh
bash scripts/check.sh --lua-only
```

The full check runs Lua suites, shell regressions, Rust unit tests and a native plugin build. It isolates HOME/XDG state and removes desktop session variables; this is process isolation, not a security sandbox. CI runs it on Arch Linux. Tests stay next to Lua/C++ modules or under `tests/` for shell/integration coverage.

A build does not establish compositor compatibility at runtime. Report unit tests, source installation and live desktop tests separately. Do not commit raw logs; link CI output or summarize results in the pull request.

## Live testing

Obtain session-owner approval before changing desktop configuration or loading a native plugin. Save affected files with `scripts/live-backup.sh save <backup-directory> <absolute-path>...` and restore them with `scripts/live-backup.sh restore <backup-directory>`.

Use the documented installer or configuration example to load both the core and the matching plugin. Check `hyprctl configerrors` and `hyprctl plugin list`. Keep a way to restart the session. Validate snapping, dragging, Alt+Tab, minimum sizes, multi-monitor geometry and startup after login. Do not restart or log out a user's session automatically.

## Documentation

Keep user guides under `docs/`, configuration examples under `examples/` and package-manager integration under `packaging/`. Use GitHub issues and pull requests for proposals and review. Prompts, agent skills, transcripts, handoffs and raw historical evidence do not belong in the source tree; earlier records remain available through Git history.
