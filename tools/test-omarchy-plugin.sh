#!/usr/bin/env bash
# The Omarchy plugin wrapper (OpenSpec add-omarchy-plugin), no root, nothing installed on the system, no compile:
#  1. manifest.json passes the checks `omarchy plugin validate` makes (mirrored here, so CI needs no Omarchy), and the
#     real validator too when it is installed;
#  2. no symlink is tracked (the validator refuses a plugin folder with one);
#  3. omarchy/hypervi status/setup/alt-tab/remove, against fake hyprctl, pkg-config, cargo and make in a temporary HOME:
#     refuses a Hyprland older than 0.56.2 or headers that differ from the running compositor, writes the Lua include by
#     temporary + rename, builds plugin-0.56/ on 0.56.x and plugin/ on 0.57+, adds one require line to hyprland.lua with a backup, and remove puts hyprland.lua back as it was;
#  4. both PKGBUILDs depend on hyprland>=0.57.
# KWINISH_ROOT=<dir> checks another copy of the repository.
set -u
root=${KWINISH_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}
t=$(mktemp -d "${TMPDIR:-/tmp}/kwinish-test-omarchy.XXXXXXXX") || exit 1
trap 'rm -rf -- "$t"' EXIT
fails=0
ok() { echo "ok - $1"; }
bad() { echo "FALHOU - $1"; fails=$((fails + 1)); }
need() { command -v "$1" >/dev/null || { bad "falta o comando $1"; exit 1; }; }
need jq; need git; need lua

# 1. manifest
m=$root/manifest.json
if [ -f "$m" ] && jq -e . "$m" >/dev/null 2>&1; then
  ok "manifest.json exists and is JSON"
  jq -e '.schemaVersion == 1' "$m" >/dev/null && ok "manifest: schemaVersion 1" || bad "manifest: schemaVersion must be the number 1"
  for f in id name version kinds entryPoints; do jq -e --arg f "$f" 'has($f)' "$m" >/dev/null || bad "manifest: missing $f"; done
  id=$(jq -r '.id' "$m")
  [[ $id =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ && $id != omarchy.* ]] && ok "manifest: id '$id' is valid" || bad "manifest: invalid id '$id'"
  jq -e '(.kinds|index("bar-widget")) != null and (.entryPoints|has("barWidget"))' "$m" >/dev/null \
    && ok "manifest: bar-widget kind with its entry point" || bad "manifest: bar-widget kind needs entryPoints.barWidget"
  while IFS= read -r ep; do
    if [[ -z $ep || $ep == /* || $ep == *..* || ! -f $root/$ep ]]; then bad "manifest: bad entry point '$ep'"; else ok "manifest: entry point $ep exists"; fi
  done < <(jq -r '.entryPoints[]' "$m")
  jq -e '.barWidget.defaultSection | IN("left","centerBegin","center","centerEnd","tray","right")' "$m" >/dev/null \
    && ok "manifest: barWidget.defaultSection is valid" || bad "manifest: barWidget.defaultSection invalid"
else
  bad "manifest.json missing or not JSON"
fi

# 2. no tracked symlink
links=$(git -C "$root" ls-files -s | awk '$1 == "120000" { print $4 }')
[ -z "$links" ] && ok "no symlink tracked" || bad "symlinks tracked (omarchy plugin validate refuses them): $links"

# 1b. the real validator, on a clean export (tracked and new files, nothing ignored)
if command -v omarchy-plugin-validate >/dev/null; then
  mkdir -p "$t/export"
  git -C "$root" ls-files -z -co --exclude-standard | (cd "$root" && xargs -0 cp -P --parents -t "$t/export" 2>/dev/null) || true
  omarchy-plugin-validate "$t/export" >"$t/validate.log" 2>&1 && ok "omarchy-plugin-validate accepts the repository" \
    || { bad "omarchy-plugin-validate refuses the repository:"; sed 's/^/    /' "$t/validate.log"; }
else
  ok "omarchy-plugin-validate not installed (skipped; mirrored checks above)"
fi

# 3. the CLI
cli=$root/omarchy/hypervi
[ -x "$cli" ] && ok "omarchy/hypervi is executable" || { bad "omarchy/hypervi missing or not executable"; echo "test-omarchy-plugin: $fails falha(s)"; exit 1; }

fake=$t/bin; mkdir -p "$fake"
real_pkgconfig=$(command -v pkg-config || true)
cat >"$fake/hyprctl" <<'EOF'
#!/bin/sh
case "$*" in
  "version -j") printf '{"version":"%s","tag":"v%s","commit":"%s"}\n' "$FAKE_RUN" "$FAKE_RUN" "$FAKE_COMMIT" ;;
  "plugin list"*) echo "no plugins loaded" ;;
  *) echo "fake hyprctl: $*" >>"$FAKE_LOG" ;;
esac
EOF
cat >"$fake/pkg-config" <<EOF
#!/bin/sh
case "\$*" in
  "--modversion hyprland") echo "\$FAKE_HDR" ;;
  "--variable=prefix hyprland") echo "\$FAKE_PREFIX" ;;
  *) [ -n "$real_pkgconfig" ] && exec "$real_pkgconfig" "\$@"; exit 1 ;;
esac
EOF
cat >"$fake/cargo" <<'EOF'
#!/bin/sh
echo "cargo $*" >>"$FAKE_LOG"
mkdir -p "$CARGO_TARGET_DIR/release" && printf '#!/bin/sh\n' >"$CARGO_TARGET_DIR/release/kwinish-ui" && chmod +x "$CARGO_TARGET_DIR/release/kwinish-ui"
EOF
cat >"$fake/make" <<'EOF'
#!/bin/sh
echo "make $*" >>"$FAKE_LOG"
# like make: an existing TARGET counts as up to date (no -B) and is left as it is; otherwise "build" an ELF
force=; for a in "$@"; do [ "$a" = -B ] && force=1; done
for a in "$@"; do case "$a" in TARGET=*) f=${a#TARGET=}; { [ -e "$f" ] && [ -z "$force" ]; } || printf '\177ELF fake plugin\n' >"$f" ;; esac; done
EOF
chmod +x "$fake"/*
mkdir -p "$t/prefix/include/hyprland/src"
printf '#define GIT_COMMIT_HASH "abc123"\n#define AQUAMARINE_VERSION "0.16.0"\n#define HYPRUTILS_VERSION "0.14.3"\n#define HYPRGRAPHICS_VERSION "0.6.0"\n#define HYPRCURSOR_VERSION "0.1.13"\n#define HYPRLANG_VERSION "0.6.8"\n' \
  >"$t/prefix/include/hyprland/src/version.h"

# run <name> <running> <headers> <args...>: the CLI in a fresh-or-kept HOME ($t/home-<name>)
run() {
  local name=$1 run_v=$2 hdr_v=$3; shift 3
  local h=$t/home-$name
  mkdir -p "$h/.config/hypr"
  env -i PATH="$fake:/usr/bin:/bin" HOME="$h" XDG_CONFIG_HOME="$h/.config" XDG_DATA_HOME="$h/.local/share" \
    FAKE_RUN="$run_v" FAKE_HDR="$hdr_v" FAKE_COMMIT=abc123 FAKE_PREFIX="$t/prefix" FAKE_LOG="$t/log-$name" \
    HYPRLAND_INSTANCE_SIGNATURE=fake "$cli" "$@" >"$t/out-$name" 2>&1
}
orig='-- user config
require("hypr.monitors")'
seed() { mkdir -p "$t/home-$1/.config/hypr"; printf '%s\n' "$orig" >"$t/home-$1/.config/hypr/hyprland.lua"; }

# 0.55: too old, refused without writing anything
seed old
run old 0.55.0 0.55.0 status --json; rc=$?
if [ "$rc" = 0 ] && jq -e '.compatible == false and .hyprland == "0.55.0"' "$t/out-old" >/dev/null 2>&1; then ok "status --json: 0.55.0 is not compatible"
else bad "status --json on 0.55.0 (exit $rc): $(cat "$t/out-old")"; fi
run old 0.55.0 0.55.0 setup; rc=$?
if [ "$rc" != 0 ] && grep -q '0\.56\.2' "$t/out-old" && [ ! -e "$t/home-old/.local/share/hypervi" ] && [ ! -e "$t/home-old/.config/hypr/hypervi.lua" ] \
  && [ "$(cat "$t/home-old/.config/hypr/hyprland.lua")" = "$orig" ]; then ok "setup refuses Hyprland 0.55.0 and writes nothing"
else bad "setup on 0.55.0 (exit $rc) must fail naming 0.56.2 and write nothing: $(cat "$t/out-old")"; fi

# 0.56.2 (Omarchy 4.5): the core and UI are shared, the plugin comes from plugin-0.56/
seed o56
run o56 0.56.2 0.56.2 setup; rc=$?
[ "$rc" = 0 ] && ok "setup on 0.56.2 succeeds" || bad "setup on 0.56.2 (exit $rc): $(cat "$t/out-o56")"
[ "$(head -c4 "$t/home-o56/.local/share/hypervi/kwinish-bars.so" 2>/dev/null)" = $'\177ELF' ] && ok "setup on 0.56.2: plugin really built" || bad "setup on 0.56.2: plugin file empty or missing"
# status must not call an empty file a built plugin
: >"$t/home-o56/.local/share/hypervi/kwinish-bars.so"
run o56 0.56.2 0.56.2 status --json
jq -e '.plugin_built == false' "$t/out-o56" >/dev/null 2>&1 && ok "status: an empty kwinish-bars.so is not built" || bad "status: empty kwinish-bars.so reported as built"
run o56 0.56.2 0.56.2 rebuild; rc=$?
[ "$rc" = 0 ] && [ "$(head -c4 "$t/home-o56/.local/share/hypervi/kwinish-bars.so")" = $'\177ELF' ] && ok "rebuild replaces an empty plugin" || bad "rebuild (exit $rc) left the plugin empty"
grep -qF -- "-C $root/plugin-0.56 " "$t/log-o56" 2>/dev/null && ok "setup on 0.56.2 builds plugin-0.56/" || bad "setup on 0.56.2 did not build plugin-0.56/: $(cat "$t/log-o56" 2>/dev/null)"
run o56 0.56.2 0.56.2 status --json
jq -e '.compatible == true and .plugin_line == "0.56" and .abi_ok == true' "$t/out-o56" >/dev/null 2>&1 && ok "status on 0.56.2: compatible, plugin line 0.56" \
  || bad "status on 0.56.2: $(cat "$t/out-o56")"
[ -f "$root/plugin-0.56/Makefile" ] && [ -f "$root/plugin-0.56/main.cpp" ] && ok "plugin-0.56/ has the sources" || bad "plugin-0.56/ missing"
for f in $(sed -n 's/^SRC *= *//p' "$root/plugin-0.56/Makefile" 2>/dev/null); do [ -f "$root/plugin-0.56/$f" ] || bad "plugin-0.56/: Makefile source $f missing"; done
for fn in $(grep -ho 'addLuaFunction(PHANDLE, "kwinish", "[a-z_]*"' "$root"/plugin/*.cpp | cut -d'"' -f4 | sort -u); do
  grep -q "addLuaFunction(PHANDLE, \"kwinish\", \"$fn\"" "$root"/plugin-0.56/*.cpp 2>/dev/null || bad "plugin-0.56/ lacks hl.plugin.kwinish.$fn (the core calls the same API on both lines)"
done
ok "plugin-0.56/ registers the same hl.plugin.kwinish functions"

seed skew
run skew 0.57.2 0.57.1 setup; rc=$?
if [ "$rc" != 0 ] && [ ! -e "$t/home-skew/.local/share/hypervi" ]; then ok "setup refuses headers that differ from the running Hyprland"
else bad "setup with running 0.57.2 and headers 0.57.1 (exit $rc) must fail: $(cat "$t/out-skew")"; fi

seed new
run new 0.57.2 0.57.2 setup; rc=$?
h=$t/home-new
inc=$h/.config/hypr/hypervi.lua
if [ "$rc" = 0 ]; then ok "setup on 0.57.2 succeeds"; else bad "setup on 0.57.2 (exit $rc): $(cat "$t/out-new")"; fi
[ "$(head -c4 "$h/.local/share/hypervi/kwinish-bars.so" 2>/dev/null)" = $'\177ELF' ] && ok "setup: plugin built into ~/.local/share/hypervi (an ELF, not an empty file)" \
  || bad "setup: ~/.local/share/hypervi/kwinish-bars.so missing or not built (make saw an up-to-date target?)"
[ "$(cat "$h/.local/share/hypervi/kwinish-bars.abi" 2>/dev/null)" = "abc123_aq_0.16_hu_0.14_hg_0.6_hc_0.1_hlg_0.6" ] \
  && ok "setup: ABI receipt written" || bad "setup: ABI receipt wrong: $(cat "$h/.local/share/hypervi/kwinish-bars.abi" 2>&1)"
[ -x "$h/.local/bin/kwinish-ui" ] && ok "setup: kwinish-ui installed on ~/.local/bin" || bad "setup: no ~/.local/bin/kwinish-ui"
[ ! -L "$h/.local/bin/kwinish-ui" ] && ok "setup: kwinish-ui is a copy, not a link" || bad "setup: kwinish-ui is a link"
grep -q -- '--locked' "$t/log-new" && ok "setup: cargo build --locked" || bad "setup: cargo not called with --locked"
if [ -f "$inc" ] && HV_F="$inc" lua -e 'assert(loadfile(os.getenv("HV_F")))' 2>"$t/luac"; then ok "setup: hypervi.lua written and compiles"
else bad "setup: hypervi.lua missing or invalid Lua: $(cat "$t/luac" 2>/dev/null)"; fi
grep -qF "$root/core/?.lua" "$inc" 2>/dev/null && ok "hypervi.lua: core from the plugin checkout" || bad "hypervi.lua: core path is not $root/core"
grep -qF "hl.plugin.load" "$inc" 2>/dev/null && grep -qF "$h/.local/share/hypervi/kwinish-bars.so" "$inc" && ok "hypervi.lua: loads the built plugin" \
  || bad "hypervi.lua: does not load $h/.local/share/hypervi/kwinish-bars.so"
grep -qF 'mod = "SUPER + CTRL + SHIFT"' "$inc" 2>/dev/null && ok "hypervi.lua: binds on SUPER + CTRL + SHIFT (no Omarchy default uses it)" \
  || bad "hypervi.lua: default mod must be SUPER + CTRL + SHIFT"
grep -qE '^local alt_tab = false' "$inc" 2>/dev/null && ok "hypervi.lua: Alt+Tab off by default (Omarchy binds ALT + Tab)" || bad "hypervi.lua: Alt+Tab must default to off"
# Alt+Tab: off by default; --alt-tab, or `alt-tab on|off` later, hands ALT + TAB to the HyperVi switcher
grep -qE '^local alt_tab = false' "$inc" 2>/dev/null && ok "default: alt_tab = false" || bad "default must be alt_tab = false"
seed alt
run alt 0.57.2 0.57.2 setup --alt-tab; rc=$?
ia=$t/home-alt/.config/hypr/hypervi.lua
[ "$rc" = 0 ] && grep -qE '^local alt_tab = true' "$ia" && ok "setup --alt-tab: alt_tab = true" || bad "setup --alt-tab (exit $rc): $(cat "$t/out-alt")"
grep -qF 'hl.unbind("ALT + TAB")' "$ia" && grep -qF 'hl.unbind("ALT + SHIFT + TAB")' "$ia" && ok "hypervi.lua: unbinds Omarchy's ALT + TAB pair when alt_tab is on" \
  || bad "hypervi.lua: must unbind ALT + TAB and ALT + SHIFT + TAB"
run alt 0.57.2 0.57.2 alt-tab off; rc=$?
[ "$rc" = 0 ] && grep -qE '^local alt_tab = false' "$ia" && ok "alt-tab off" || bad "alt-tab off (exit $rc): $(cat "$t/out-alt")"
ls "$t/home-alt/.config/hypr"/.hypervi.lua.* >/dev/null 2>&1 && bad "alt-tab: left a temporary file" || ok "alt-tab: written by temporary + rename"
run alt 0.57.2 0.57.2 alt-tab on; rc=$?
[ "$rc" = 0 ] && grep -qE '^local alt_tab = true' "$ia" && HV_F="$ia" lua -e 'assert(loadfile(os.getenv("HV_F")))' 2>/dev/null && ok "alt-tab on (still valid Lua)" || bad "alt-tab on (exit $rc)"
run alt 0.57.2 0.57.2 alt-tab off; run alt 0.57.2 0.57.2 setup --alt-tab; rc=$?
[ "$rc" = 0 ] && grep -qE '^local alt_tab = true' "$ia" && ok "setup --alt-tab on an existing hypervi.lua turns it on" || bad "setup --alt-tab kept alt_tab off in an existing hypervi.lua"
run alt 0.57.2 0.57.2 alt-tab maybe; rc=$?
[ "$rc" != 0 ] && ok "alt-tab rejects anything but on/off" || bad "alt-tab maybe must fail"

ls "$h/.config/hypr"/.hypervi.lua.* >/dev/null 2>&1 && bad "setup: left a temporary file" || ok "setup: no temporary file left"
n=$(grep -c '^require("hypr.hypervi")' "$h/.config/hypr/hyprland.lua")
[ "$n" = 1 ] && ok "setup: one require line in hyprland.lua" || bad "setup: $n require lines in hyprland.lua"
[ "$(cat "$h/.config/hypr/hyprland.lua.hypervi-bak" 2>/dev/null)" = "$orig" ] && ok "setup: backup of hyprland.lua" || bad "setup: no backup of the original hyprland.lua"

run new 0.57.2 0.57.2 setup; rc=$?
n=$(grep -c '^require("hypr.hypervi")' "$h/.config/hypr/hyprland.lua")
[ "$rc" = 0 ] && [ "$n" = 1 ] && [ "$(cat "$h/.config/hypr/hyprland.lua.hypervi-bak")" = "$orig" ] \
  && ok "setup twice: still one require line, backup kept" || bad "setup twice (exit $rc): $n require lines or backup changed"

run new 0.57.2 0.57.2 status --json
jq -e '.compatible == true and .configured == true and .plugin_built == true and .abi_ok == true and .ui_installed == true' "$t/out-new" >/dev/null 2>&1 \
  && ok "status --json after setup" || bad "status --json after setup: $(cat "$t/out-new")"

FAKE_SAVE=$(cat "$t/prefix/include/hyprland/src/version.h")
sed -i 's/abc123/def456/' "$t/prefix/include/hyprland/src/version.h"
run new 0.57.2 0.57.2 status --json
jq -e '.abi_ok == false' "$t/out-new" >/dev/null 2>&1 && ok "status: ABI mismatch after a Hyprland update" || bad "status: ABI change not seen: $(cat "$t/out-new")"
printf '%s\n' "$FAKE_SAVE" >"$t/prefix/include/hyprland/src/version.h"

cp "$inc" "$inc.keep" 2>/dev/null
run new 0.57.2 0.57.2 remove; rc=$?
if [ "$rc" = 0 ] && [ "$(cat "$h/.config/hypr/hyprland.lua")" = "$orig" ] && [ ! -e "$inc" ] && [ ! -e "$h/.local/bin/kwinish-ui" ] \
  && [ ! -e "$h/.local/share/hypervi" ]; then ok "remove: hyprland.lua back as it was, files gone"
else bad "remove (exit $rc): $(cat "$t/out-new")"; fi

# remove keeps a kwinish-ui it did not install
seed foreign; mkdir -p "$t/home-foreign/.local/bin"; echo mine >"$t/home-foreign/.local/bin/kwinish-ui"
run foreign 0.57.2 0.57.2 remove
[ "$(cat "$t/home-foreign/.local/bin/kwinish-ui" 2>/dev/null)" = mine ] && ok "remove: keeps a kwinish-ui it did not install" || bad "remove: deleted a foreign kwinish-ui"

# setup without hyprland.lua (not a Lua config): refuse
mkdir -p "$t/home-nolua/.config/hypr"
run nolua 0.57.2 0.57.2 setup; rc=$?
[ "$rc" != 0 ] && [ ! -e "$t/home-nolua/.local/share/hypervi" ] && ok "setup refuses without ~/.config/hypr/hyprland.lua" || bad "setup without hyprland.lua (exit $rc)"

# 3b. the bar widget asks the CLI
w=$root/$(jq -r '.entryPoints.barWidget // "missing"' "$m" 2>/dev/null)
grep -q 'status' "$w" 2>/dev/null && grep -q -- '--json' "$w" && ok "bar widget reads hypervi status --json" || bad "bar widget does not read the status"
# a file named like a qs.Ui type shadows it in its own directory: BarWidget.qml using BarWidget instantiates itself
case $(basename "$w" .qml) in BarWidget | BarIconButton | WidgetButton) bad "bar widget file shadows the qs.Ui type $(basename "$w" .qml)" ;; *) ok "bar widget file does not shadow a qs.Ui type" ;; esac
grep -qE '^\s*property var state\b' "$w" && bad "bar widget redefines Item.state" || ok "bar widget does not redefine Item.state"

# 3c. coexisting with Omarchy's titlebars (omarchy-hyprland-titlebars: a hyprbars fork named "Hyprbar", attached to every
# window and drawn only on floating-workspace windows): the HyperVi bar must not skip a window for a Hyprbar, and
# hypervi.lua turns Omarchy's bar off so a window never gets two
for tree in plugin plugin-0.56; do
  body=$(sed -n '/^static void onNewWindow/,/^}/p' "$root/$tree/main.cpp")
  grep -q '"KwinishBar"' <<<"$body" && ok "$tree: onNewWindow skips a window that already has a KwinishBar" || bad "$tree: onNewWindow must skip its own KwinishBar"
  grep -q '"Hyprbar"' <<<"$body" && bad "$tree: onNewWindow skips windows with a Hyprbar (Omarchy attaches one to every window)" || ok "$tree: onNewWindow does not give way to a Hyprbar"
done
grep -qF 'if hl.plugin and hl.plugin.hyprbars then' "$inc.keep" 2>/dev/null && grep -qF 'hyprbars = { enabled = false }' "$inc.keep" \
  && ok "hypervi.lua: turns Omarchy's titlebars off when they are loaded" || bad "hypervi.lua: must set plugin.hyprbars.enabled = false when hl.plugin.hyprbars exists"

# 4. PKGBUILDs
for p in packaging/PKGBUILD packaging/plugin/PKGBUILD; do
  grep -qE "depends=\(.*'hyprland>=0\.57'" "$root/$p" && ok "$p: depends on hyprland>=0.57" || bad "$p: must depend on hyprland>=0.57"
done

[ "$fails" = 0 ] && echo "test-omarchy-plugin: tudo passou" || { echo "test-omarchy-plugin: $fails falha(s)"; exit 1; }
