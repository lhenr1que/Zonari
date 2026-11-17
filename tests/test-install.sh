#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
mkdir -p "$t/bin" "$t/home"
cat > "$t/bin/pkg-config" <<'SH'
#!/bin/sh
case "$*" in '--modversion hyprland') echo "${TEST_VERSION:-0.56.2}";; esac
SH
cat > "$t/bin/cargo" <<'SH'
#!/bin/sh
mkdir -p "$CARGO_TARGET_DIR/release"
printf '#!/bin/sh\n' > "$CARGO_TARGET_DIR/release/zonari-ui"
SH
cat > "$t/bin/make" <<'SH'
#!/bin/sh
printf '%s\n' "$*" > "$TEST_MAKE_LOG"
for arg; do case $arg in TARGET=*) printf '\177ELFtest' > "${arg#TARGET=}";; esac; done
SH
chmod +x "$t/bin/"*
export PATH="$t/bin:$PATH" HOME="$t/home" TEST_MAKE_LOG="$t/make.log" CARGO_TARGET_DIR="$t/target"
bash "$root/scripts/install.sh" --prefix "$t/prefix"
test -x "$t/prefix/bin/zonari-ui"
test -f "$t/prefix/lib/zonari/zonari-bars.so"
test -f "$t/prefix/share/zonari/core/zonari.lua"
grep -q "$t/prefix/lib/zonari/zonari-bars.so" "$t/prefix/share/zonari/zonari.lua"
grep -q zonari-bars-0.56 "$t/make.log"
test ! -e "$HOME/.config"
TEST_VERSION=0.57.2 bash "$root/scripts/install.sh" --prefix "$t/other"
grep -q 'zonari-bars TARGET=' "$t/make.log"
if TEST_VERSION=0.58.0 bash "$root/scripts/install.sh" --prefix "$t/unsupported"; then echo 'unsupported headers accepted'; exit 1; fi
test ! -e "$t/unsupported"
echo 'portable install: passed (0.56.2, 0.57.2, unsupported version, no config writes)'
