## ADDED Requirements

### Requirement: Independent source installation
The installer SHALL build and install the core, UI, title-bar plugin and an example configuration under an absolute prefix without requiring Omarchy or editing user configuration. It SHALL choose the 0.56 source for 0.56.2 and the main source for 0.57.x, refusing unsupported headers before installing.

#### Scenario: Install outside Omarchy
- WHEN dependencies exist and install.sh is run with a writable prefix
- THEN UI, core, plugin, ABI receipt, licenses and a prefix-specific Lua example are installed
- AND no compositor is loaded or reloaded and no user config is changed.

#### Scenario: Unsupported version
- WHEN headers report 0.58.0
- THEN installation fails before writing the destination.

### Requirement: Workspace packaging
Arch recipes SHALL build from the root Cargo workspace and zonari-bars directory, using the root target output for the UI.

#### Scenario: Build after directory migration
- WHEN each recipe's build function executes
- THEN its Cargo manifest or plugin Makefile exists at the selected directory.
