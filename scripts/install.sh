#!/usr/bin/env bash
# Source install for any Linux distro providing compatible Hyprland Lua APIs.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
prefix=${HOME:?}/.local
case ${1:-} in
  --prefix) [ $# = 2 ] || { echo 'usage: scripts/install.sh [--prefix /absolute/path]' >&2; exit 2; }; prefix=$2 ;;
  --help) echo 'usage: scripts/install.sh [--prefix /absolute/path]'; exit 0 ;;
  '') ;;
  *) echo 'usage: scripts/install.sh [--prefix /absolute/path]' >&2; exit 2 ;;
esac
case $prefix in /*) ;; *) echo 'prefix must be absolute' >&2; exit 2 ;; esac
[[ $prefix =~ ^/[a-zA-Z0-9_./-]+$ ]] || { echo 'prefix supports only letters, numbers, /, ., _ and -' >&2; exit 2; }
for c in cargo make pkg-config install; do command -v "$c" >/dev/null || { echo "missing tool: $c" >&2; exit 1; }; done
version=$(pkg-config --modversion hyprland)
case $version in
  0.56.2) tree=src/bars-0.56 ;;
  0.57.*) tree=src/bars ;;
  *) echo "unsupported Hyprland headers: $version (tested sources: 0.56.2 and 0.57.x)" >&2; exit 1 ;;
esac
pkg-config --exists hyprland gtk4 gtk4-layer-shell-0 cairo librsvg-2.0 pixman-1 libdrm libinput libudev wayland-server xkbcommon
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
export CARGO_TARGET_DIR=${CARGO_TARGET_DIR:-$root/target}
cargo build --release --locked --manifest-path "$root/Cargo.toml"
make -B -C "$root/$tree" TARGET="$work/zonari-bars.so"
[ "$(head -c4 "$work/zonari-bars.so")" = $'\177ELF' ] || { echo 'build produced no ELF plugin' >&2; exit 1; }
sh "$root/$tree/abi.sh" > "$work/zonari-bars.abi"
# Finish building before writing the installation; never change the running session.
install -Dm755 "$CARGO_TARGET_DIR/release/zonari-ui" "$prefix/bin/zonari-ui"
install -Dm755 "$work/zonari-bars.so" "$prefix/lib/zonari/zonari-bars.so"
install -Dm644 "$work/zonari-bars.abi" "$prefix/lib/zonari/zonari-bars.abi"
install -d "$prefix/share/zonari/core" "$prefix/share/zonari/recipes"
for module in "$root"/src/core/*.lua; do
  case ${module##*/} in test_*) continue ;; esac
  install -m644 "$module" "$prefix/share/zonari/core/"
done
install -m644 "$root"/examples/*.lua "$prefix/share/zonari/recipes/"
install -Dm644 "$root/LICENSE" "$prefix/share/licenses/zonari/LICENSE"
install -Dm644 "$root/COPYRIGHT.md" "$prefix/share/licenses/zonari/COPYRIGHT.md"
install -Dm644 "$root/$tree/NOTICE" "$prefix/share/licenses/zonari/NOTICE"
install -Dm644 "$root/$tree/LICENSE.hyprland-plugins" "$prefix/share/licenses/zonari/LICENSE.hyprland-plugins"
cat > "$work/zonari.lua" <<LUA
-- Generated example: copy to your Hyprland config directory and edit before loading.
package.path = "$prefix/share/zonari/core/?.lua;" .. package.path
hl.plugin.load("$prefix/lib/zonari/zonari-bars.so")
local zonari = require("zonari")
zonari.setup({ placement = "smart" })
local switcher = require("switcher")
-- Optional: unbind your desktop's Alt+Tab before enabling these two lines.
-- switcher.setup()
require("binds").install(zonari, { mod = "SUPER", menu = "ALT + F3" })
hl.on("hyprland.start", function() hl.exec_cmd("$prefix/bin/zonari-ui") end)
LUA
install -Dm644 "$work/zonari.lua" "$prefix/share/zonari/zonari.lua"
echo "Installed for Hyprland $version under $prefix. Config and session unchanged."
echo "Review $prefix/share/zonari/zonari.lua; see docs/installation.md before loading."
