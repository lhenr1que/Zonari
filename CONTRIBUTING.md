# Contributing

Zonari is an alpha window-management layer for Hyprland. Discuss larger changes in a GitHub issue and keep pull requests focused.

1. Read the [architecture](docs/architecture.md) and [development guide](docs/development.md).
2. Add regression coverage for bug fixes and update the relevant user documentation.
3. Run `bash scripts/check.sh` and include the result in your pull request. State separately whether any live desktop testing was done.

Use the existing Lua, Rust and C++ style. Keep policy in the core and presentation in the UI/plugin. Never evaluate configuration data as code; preserve atomic writes and plugin ABI checks.

Do not commit build outputs, raw test logs, machine-specific paths, prompts or agent transcripts. Developer notes belong outside the repository. Live desktop tests require backups and explicit approval from the person using the session.

Contributions are under GPL-3.0-only. Preserve upstream copyright and license notices, including the hyprbars BSD-3-Clause notices.
