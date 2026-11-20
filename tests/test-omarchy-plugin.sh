#!/usr/bin/env bash
# The Omarchy plugin wrapper (OpenSpec add-omarchy-plugin), no root, nothing installed on the system, no compile:
#  1. manifest.json passes the checks `omarchy plugin validate` makes (mirrored here, so CI needs no Omarchy), and the
#     real validator too when it is installed;
#  2. no symlink is tracked (the validator refuses a plugin folder with one);
#  3. omarchy/zonari status/setup/alt-tab/remove, against fake hyprctl, pkg-config, cargo and make in a temporary HOME:
#     refuses a Hyprland older than 0.56.2 or headers that differ from the running compositor, writes the Lua include by
#     temporary + rename, builds src/bars-0.56/ on 0.56.x and src/bars/ on 0.57+, adds one require line to hyprland.lua with a backup, and remove puts hyprland.lua back as it was;
#  4. both PKGBUILDs depend on hyprland>=0.57.
# ZONARI_ROOT=<dir> checks another copy of the repository.
set -u
root=${ZONARI_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}
t=$(mktemp -d "${TMPDIR:-/tmp}/zonari-test-omarchy.XXXXXXXX") || exit 1
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
cli=$root/omarchy/zonari
[ -x "$cli" ] && ok "omarchy/zonari is executable" || { bad "omarchy/zonari missing or not executable"; echo "test-omarchy-plugin: $fails falha(s)"; exit 1; }

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
mkdir -p "$CARGO_TARGET_DIR/release" && printf '#!/bin/sh\n' >"$CARGO_TARGET_DIR/release/zonari-ui" && chmod +x "$CARGO_TARGET_DIR/release/zonari-ui"
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
if [ "$rc" != 0 ] && grep -q '0\.56\.2' "$t/out-old" && [ ! -e "$t/home-old/.local/share/zonari" ] && [ ! -e "$t/home-old/.config/hypr/zonari.lua" ] \
  && [ "$(cat "$t/home-old/.config/hypr/hyprland.lua")" = "$orig" ]; then ok "setup refuses Hyprland 0.55.0 and writes nothing"
else bad "setup on 0.55.0 (exit $rc) must fail naming 0.56.2 and write nothing: $(cat "$t/out-old")"; fi

# 0.56.2 (Omarchy 4.5): the core and UI are shared, the plugin comes from src/bars-0.56/
seed o56
run o56 0.56.2 0.56.2 setup; rc=$?
[ "$rc" = 0 ] && ok "setup on 0.56.2 succeeds" || bad "setup on 0.56.2 (exit $rc): $(cat "$t/out-o56")"
[ "$(head -c4 "$t/home-o56/.local/share/zonari/zonari-bars.so" 2>/dev/null)" = $'\177ELF' ] && ok "setup on 0.56.2: plugin really built" || bad "setup on 0.56.2: plugin file empty or missing"
# status must not call an empty file a built plugin
: >"$t/home-o56/.local/share/zonari/zonari-bars.so"
run o56 0.56.2 0.56.2 status --json
jq -e '.plugin_built == false' "$t/out-o56" >/dev/null 2>&1 && ok "status: an empty zonari-bars.so is not built" || bad "status: empty zonari-bars.so reported as built"
run o56 0.56.2 0.56.2 rebuild; rc=$?
[ "$rc" = 0 ] && [ "$(head -c4 "$t/home-o56/.local/share/zonari/zonari-bars.so")" = $'\177ELF' ] && ok "rebuild replaces an empty plugin" || bad "rebuild (exit $rc) left the plugin empty"
grep -qF -- "-C $root/src/bars-0.56 " "$t/log-o56" 2>/dev/null && ok "setup on 0.56.2 builds src/bars-0.56/" || bad "setup on 0.56.2 did not build src/bars-0.56/: $(cat "$t/log-o56" 2>/dev/null)"
run o56 0.56.2 0.56.2 status --json
jq -e '.compatible == true and .plugin_line == "0.56" and .abi_ok == true' "$t/out-o56" >/dev/null 2>&1 && ok "status on 0.56.2: compatible, plugin line 0.56" \
  || bad "status on 0.56.2: $(cat "$t/out-o56")"
[ -f "$root/src/bars-0.56/Makefile" ] && [ -f "$root/src/bars-0.56/main.cpp" ] && ok "src/bars-0.56/ has the sources" || bad "src/bars-0.56/ missing"
for f in $(sed -n 's/^SRC *= *//p' "$root/src/bars-0.56/Makefile" 2>/dev/null); do [ -f "$root/src/bars-0.56/$f" ] || bad "src/bars-0.56/: Makefile source $f missing"; done
fns=$(grep -ho 'addLuaFunction(PHANDLE, "zonari", "[a-z_]*"' "$root"/src/bars/*.cpp | cut -d'"' -f4 | sort -u)
[ -n "$fns" ] || bad "no hl.plugin.zonari function found in src/bars/ (sources moved?)"
for fn in $fns; do
  grep -q "addLuaFunction(PHANDLE, \"zonari\", \"$fn\"" "$root"/src/bars-0.56/*.cpp 2>/dev/null || bad "src/bars-0.56/ lacks hl.plugin.zonari.$fn (the core calls the same API on both lines)"
done
ok "src/bars-0.56/ registers the same hl.plugin.zonari functions"

seed skew
run skew 0.57.2 0.57.1 setup; rc=$?
if [ "$rc" != 0 ] && [ ! -e "$t/home-skew/.local/share/zonari" ]; then ok "setup refuses headers that differ from the running Hyprland"
else bad "setup with running 0.57.2 and headers 0.57.1 (exit $rc) must fail: $(cat "$t/out-skew")"; fi

seed new
run new 0.57.2 0.57.2 setup; rc=$?
h=$t/home-new
inc=$h/.config/hypr/zonari.lua
if [ "$rc" = 0 ]; then ok "setup on 0.57.2 succeeds"; else bad "setup on 0.57.2 (exit $rc): $(cat "$t/out-new")"; fi
[ "$(head -c4 "$h/.local/share/zonari/zonari-bars.so" 2>/dev/null)" = $'\177ELF' ] && ok "setup: plugin built into ~/.local/share/zonari (an ELF, not an empty file)" \
  || bad "setup: ~/.local/share/zonari/zonari-bars.so missing or not built (make saw an up-to-date target?)"
[ "$(cat "$h/.local/share/zonari/zonari-bars.abi" 2>/dev/null)" = "abc123_aq_0.16_hu_0.14_hg_0.6_hc_0.1_hlg_0.6" ] \
  && ok "setup: ABI receipt written" || bad "setup: ABI receipt wrong: $(cat "$h/.local/share/zonari/zonari-bars.abi" 2>&1)"
[ -x "$h/.local/bin/zonari-ui" ] && ok "setup: zonari-ui installed on ~/.local/bin" || bad "setup: no ~/.local/bin/zonari-ui"
[ ! -L "$h/.local/bin/zonari-ui" ] && ok "setup: zonari-ui is a copy, not a link" || bad "setup: zonari-ui is a link"
grep -q -- '--locked' "$t/log-new" && ok "setup: cargo build --locked" || bad "setup: cargo not called with --locked"
if [ -f "$inc" ] && HV_F="$inc" lua -e 'assert(loadfile(os.getenv("HV_F")))' 2>"$t/luac"; then ok "setup: zonari.lua written and compiles"
else bad "setup: zonari.lua missing or invalid Lua: $(cat "$t/luac" 2>/dev/null)"; fi
grep -qF "$root/src/core/?.lua" "$inc" 2>/dev/null && ok "zonari.lua: core from the plugin checkout" || bad "zonari.lua: core path is not $root/src/core"
grep -qF "hl.plugin.load" "$inc" 2>/dev/null && grep -qF "$h/.local/share/zonari/zonari-bars.so" "$inc" && ok "zonari.lua: loads the built plugin" \
  || bad "zonari.lua: does not load $h/.local/share/zonari/zonari-bars.so"
lua "$root/tests/testdata/omarchy-binds.lua" "$inc" "$root/src/core" >"$t/binds" 2>"$t/binds.err" || bad "zonari.lua binds could not be read: $(cat "$t/binds.err")"
dups=$(cut -d= -f2 "$t/binds" | sort | uniq -d)
[ -s "$t/binds" ] && [ -z "$dups" ] && ok "zonari.lua: $(wc -l <"$t/binds") binds, no two on the same keys" || bad "zonari.lua: binds on the same keys: $dups"
for want in tile:left=ALT+CTRL+SUPER+LEFT tile:right=ALT+CTRL+SUPER+RIGHT tile:top=ALT+CTRL+SUPER+UP tile:bottom=ALT+CTRL+SUPER+DOWN \
  tile:topleft=ALT+CTRL+SUPER+U tile:topright=ALT+CTRL+SUPER+I tile:bottomleft=ALT+CTRL+SUPER+J tile:bottomright=ALT+CTRL+SUPER+K \
  tile:max=ALT+CTRL+SUPER+RETURN pack:left=ALT+CTRL+SHIFT+SUPER+LEFT show_desktop:=ALT+CTRL+SUPER+M layouts:=ALT+CTRL+SUPER+L; do
  grep -qxF "$want" "$t/binds" && ok "bind $want" || bad "bind $want missing (got: $(grep "^${want%%=*}=" "$t/binds"))"
done
# reserve: Omarchy's dock (floating workspaces) has no exclusive zone; zonari.lua keeps its band free from shell.json
dock() { # dock <json for the dock key or empty> -> the reserve lines zonari.lua passes to kw.setup
  local hh=$t/dock-home; rm -rf "$hh"; mkdir -p "$hh/.config/omarchy"
  [ -n "$1" ] && printf '{"dock":%s}' "$1" >"$hh/.config/omarchy/shell.json"
  HOME=$hh lua "$root/tests/testdata/omarchy-binds.lua" "$inc" "$root/src/core" 2>&1 | grep '^reserve:' | sort | tr '\n' ' '
}
[ "$(dock '')" = "reserve:bottom=51 " ] && ok "reserve: no shell.json -> dock at the bottom, 51 px" || bad "reserve without shell.json: '$(dock '')'"
[ "$(dock '{"position":"left"}')" = "reserve:left=51 " ] && ok "reserve: dock on the left" || bad "reserve dock left: '$(dock '{"position":"left"}')'"
[ "$(dock '{"position":"bottom","autohide":true}')" = "" ] && ok "reserve: none when the dock hides itself" || bad "reserve autohide: '$(dock '{"autohide":true}')'"
printf 'not json' >"$t/bad.json"
[ "$(dock '"x"')" = "reserve:bottom=51 " ] && ok "reserve: an odd dock value falls back to the bottom" || bad "reserve with dock = string: '$(dock '"x"')'"

# Omarchy 4.5 uses these (hyprctl binds, 16/11/2026): none of ours may land on them
for used in CTRL+SHIFT+SUPER+LEFT CTRL+SHIFT+SUPER+A CTRL+SHIFT+SUPER+D CTRL+SHIFT+SUPER+T ALT+CTRL+SUPER+W ALT+CTRL+SUPER+D ALT+CTRL+SUPER+T ALT+CTRL+SUPER+E ALT+SUPER+LEFT SUPER+T; do
  grep -q "=$used\$" "$t/binds" && bad "a Zonari bind lands on Omarchy's $used"
done
ok "no Zonari bind on the Omarchy combos checked"
# Alt+Tab: one switch, "alt_tab" in ~/.config/zonari/settings.json (also the settings window's); zonari.lua's line is the
# fallback when the key is missing. On: Zonari's switcher and Omarchy's ALT + TAB pair unbound; off: nothing touched.
eff() { HOME=$t/home-$1 XDG_CONFIG_HOME=$t/home-$1/.config lua "$root/tests/testdata/omarchy-binds.lua" "$t/home-$1/.config/hypr/zonari.lua" "$root/src/core" 2>&1 | grep '^alt_tab='; }
sj() { cat "$t/home-$1/.config/zonari/settings.json" 2>/dev/null; }
jq -e '.workspace_modes == false' <<<"$(sj new)" >/dev/null 2>&1 && ok "setup: workspace modes left to Omarchy's switcher (workspace_modes=false)" || bad "setup must write workspace_modes=false: $(sj new)"
[ "$(eff new)" = "alt_tab=false unbind=" ] && jq -e '.alt_tab == false' <<<"$(sj new)" >/dev/null 2>&1 && ok "setup: Alt+Tab left to Omarchy, alt_tab=false in settings.json" \
  || bad "setup default: $(eff new) / $(sj new)"
seed alt; mkdir -p "$t/home-alt/.config/zonari"; echo '{"bar_height": 30}' >"$t/home-alt/.config/zonari/settings.json"
run alt 0.57.2 0.57.2 setup --alt-tab; rc=$?
ia=$t/home-alt/.config/hypr/zonari.lua
[ "$rc" = 0 ] && [ "$(eff alt)" = "alt_tab=true unbind=ALT + TAB,ALT + SHIFT + TAB" ] && ok "setup --alt-tab: Zonari switcher, Omarchy's pair unbound" \
  || bad "setup --alt-tab (exit $rc): $(eff alt) $(cat "$t/out-alt")"
jq -e '.alt_tab == true and .bar_height == 30' <<<"$(sj alt)" >/dev/null 2>&1 && ok "setup --alt-tab: settings.json keeps the other keys" || bad "settings.json after setup --alt-tab: $(sj alt)"
run alt 0.57.2 0.57.2 alt-tab off; rc=$?
[ "$rc" = 0 ] && [ "$(eff alt)" = "alt_tab=false unbind=" ] && jq -e '.alt_tab == false and .bar_height == 30' <<<"$(sj alt)" >/dev/null 2>&1 && ok "alt-tab off" || bad "alt-tab off (exit $rc): $(eff alt) $(sj alt)"
ls "$t/home-alt/.config/zonari"/.settings.json.* >/dev/null 2>&1 && bad "alt-tab: left a temporary file" || ok "alt-tab: settings.json written by temporary + rename"
run alt 0.57.2 0.57.2 alt-tab on; rc=$?
[ "$rc" = 0 ] && [ "$(eff alt)" = "alt_tab=true unbind=ALT + TAB,ALT + SHIFT + TAB" ] && ok "alt-tab on" || bad "alt-tab on (exit $rc): $(eff alt)"
run alt 0.57.2 0.57.2 alt-tab off; run alt 0.57.2 0.57.2 setup --alt-tab; rc=$?
[ "$rc" = 0 ] && [ "$(eff alt)" = "alt_tab=true unbind=ALT + TAB,ALT + SHIFT + TAB" ] && ok "setup --alt-tab on an existing install turns it on" || bad "setup --alt-tab on existing: $(eff alt)"
rm "$t/home-alt/.config/zonari/settings.json"
[ "$(eff alt)" = "alt_tab=true unbind=ALT + TAB,ALT + SHIFT + TAB" ] && ok "no settings.json: zonari.lua's fallback (written true by setup --alt-tab)" || bad "fallback without settings.json: $(eff alt)"
echo 'not json' >"$t/home-alt/.config/zonari/settings.json"
run alt 0.57.2 0.57.2 alt-tab on; rc=$?
[ "$rc" != 0 ] && [ "$(cat "$t/home-alt/.config/zonari/settings.json")" = "not json" ] && ok "alt-tab refuses to overwrite a settings.json it cannot read" || bad "alt-tab on a broken settings.json (exit $rc)"
[ "$(eff alt)" = "alt_tab=true unbind=ALT + TAB,ALT + SHIFT + TAB" ] && ok "broken settings.json: zonari.lua's fallback" || bad "broken settings.json: $(eff alt)"
rm "$t/home-alt/.config/zonari/settings.json"; run alt 0.57.2 0.57.2 alt-tab on
# refresh: rewrites an unedited zonari.lua with the current generator, keeping alt_tab; refuses an edited one
printf -- '-- old generator\nlocal alt_tab = true\n' >"$ia"; sha256sum "$ia" | cut -d' ' -f1 >"$t/home-alt/.local/share/zonari/zonari.lua.sha256"
run alt 0.57.2 0.57.2 refresh; rc=$?
[ "$rc" = 0 ] && grep -qF 'local M = "SUPER + CTRL + ALT"' "$ia" && grep -qE '^local alt_tab = true' "$ia" && ok "refresh: rewrites an unedited zonari.lua, keeps alt_tab" \
  || bad "refresh (exit $rc): $(cat "$t/out-alt")"
echo '-- my edit' >>"$ia"; cp "$ia" "$t/edited"
run alt 0.57.2 0.57.2 refresh; rc=$?
[ "$rc" != 0 ] && cmp -s "$ia" "$t/edited" && ok "refresh: refuses an edited zonari.lua and leaves it alone" || bad "refresh on an edited file (exit $rc)"
run alt 0.57.2 0.57.2 alt-tab maybe; rc=$?
[ "$rc" != 0 ] && ok "alt-tab rejects anything but on/off" || bad "alt-tab maybe must fail"

ls "$h/.config/hypr"/.zonari.lua.* >/dev/null 2>&1 && bad "setup: left a temporary file" || ok "setup: no temporary file left"
n=$(grep -c '^require("hypr.zonari")' "$h/.config/hypr/hyprland.lua")
[ "$n" = 1 ] && ok "setup: one require line in hyprland.lua" || bad "setup: $n require lines in hyprland.lua"
[ "$(cat "$h/.config/hypr/hyprland.lua.zonari-bak" 2>/dev/null)" = "$orig" ] && ok "setup: backup of hyprland.lua" || bad "setup: no backup of the original hyprland.lua"

run new 0.57.2 0.57.2 setup; rc=$?
n=$(grep -c '^require("hypr.zonari")' "$h/.config/hypr/hyprland.lua")
[ "$rc" = 0 ] && [ "$n" = 1 ] && [ "$(cat "$h/.config/hypr/hyprland.lua.zonari-bak")" = "$orig" ] \
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
if [ "$rc" = 0 ] && [ "$(cat "$h/.config/hypr/hyprland.lua")" = "$orig" ] && [ ! -e "$inc" ] && [ ! -e "$h/.local/bin/zonari-ui" ] \
  && [ ! -e "$h/.local/share/zonari" ]; then ok "remove: hyprland.lua back as it was, files gone"
else bad "remove (exit $rc): $(cat "$t/out-new")"; fi

# remove keeps a zonari-ui it did not install
seed foreign; mkdir -p "$t/home-foreign/.local/bin"; echo mine >"$t/home-foreign/.local/bin/zonari-ui"
run foreign 0.57.2 0.57.2 remove
[ "$(cat "$t/home-foreign/.local/bin/zonari-ui" 2>/dev/null)" = mine ] && ok "remove: keeps a zonari-ui it did not install" || bad "remove: deleted a foreign zonari-ui"

# remove keeps a build cache it did not create; a data directory that already existed does not make setup's own cache foreign
seed pretarget
mkdir -p "$t/home-pretarget/.local/share/zonari/target"
echo keep >"$t/home-pretarget/.local/share/zonari/target/keep"
echo notes >"$t/home-pretarget/.local/share/zonari/notes.txt"
run pretarget 0.57.2 0.57.2 setup; rc=$?
[ "$rc" = 0 ] && [ "$(cat "$t/home-pretarget/.local/share/zonari/target/keep" 2>/dev/null)" = keep ] \
  && ok "setup: builds with a pre-existing target directory" || bad "setup with a pre-existing target (exit $rc): $(cat "$t/out-pretarget")"
run pretarget 0.57.2 0.57.2 remove; rc=$?
if [ "$rc" = 0 ] && [ "$(cat "$t/home-pretarget/.local/share/zonari/target/keep" 2>/dev/null)" = keep ] \
  && [ "$(cat "$t/home-pretarget/.local/share/zonari/notes.txt" 2>/dev/null)" = notes ] \
  && [ ! -e "$t/home-pretarget/.local/share/zonari/zonari-bars.so" ] && [ ! -e "$t/home-pretarget/.local/share/zonari/bin" ]; then
  ok "remove: keeps a target directory setup did not create"
else bad "remove with a pre-existing target (exit $rc): $(cat "$t/out-pretarget")"; fi

seed predata
mkdir -p "$t/home-predata/.local/share/zonari"
echo notes >"$t/home-predata/.local/share/zonari/notes.txt"
run predata 0.57.2 0.57.2 setup
run predata 0.57.2 0.57.2 remove; rc=$?
if [ "$rc" = 0 ] && [ "$(cat "$t/home-predata/.local/share/zonari/notes.txt" 2>/dev/null)" = notes ] \
  && [ ! -e "$t/home-predata/.local/share/zonari/target" ] && [ ! -e "$t/home-predata/.local/share/zonari/zonari-bars.so" ]; then
  ok "remove: deletes the target directory setup created, keeps other data"
else bad "remove with a pre-existing data directory (exit $rc): $(cat "$t/out-predata")"; fi

seed swapped
run swapped 0.57.2 0.57.2 setup
rm -rf "$t/home-swapped/.local/share/zonari/target"
mkdir -p "$t/home-swapped/.local/share/zonari/target"; echo keep >"$t/home-swapped/.local/share/zonari/target/keep"
run swapped 0.57.2 0.57.2 remove; rc=$?
[ "$rc" = 0 ] && [ "$(cat "$t/home-swapped/.local/share/zonari/target/keep" 2>/dev/null)" = keep ] \
  && ok "remove: keeps a target directory that replaced the one setup created" || bad "remove after target replacement (exit $rc): $(cat "$t/out-swapped")"

# migration: data from before the rename (~/.config/kwinish) is copied to ~/.config/zonari once; the old folder stays
seed mig; mkdir -p "$t/home-mig/.config/kwinish"; echo '{"bar_height": 30}' >"$t/home-mig/.config/kwinish/settings.json"; echo grid >"$t/home-mig/.config/kwinish/layout"
run mig 0.57.2 0.57.2 setup; rc=$?
[ "$rc" = 0 ] && [ "$(cat "$t/home-mig/.config/zonari/layout" 2>/dev/null)" = grid ] && jq -e '.bar_height == 30 and .workspace_modes == false' "$t/home-mig/.config/zonari/settings.json" >/dev/null 2>&1 \
  && [ -f "$t/home-mig/.config/kwinish/settings.json" ] && ok "setup: ~/.config/kwinish copied to ~/.config/zonari (old kept)" || bad "migration (exit $rc): $(ls -A "$t/home-mig/.config/zonari" 2>&1)"
echo '{"bar_height": 40}' >"$t/home-mig/.config/kwinish/settings.json"
run mig 0.57.2 0.57.2 setup
jq -e '.bar_height == 30' "$t/home-mig/.config/zonari/settings.json" >/dev/null 2>&1 && ok "migration runs once: an existing ~/.config/zonari wins" || bad "migration overwrote ~/.config/zonari"

# OmniWM is the latest source when both old names exist.
seed migom
mkdir -p "$t/home-migom/.config/omniwm" "$t/home-migom/.config/kwinish"
echo current >"$t/home-migom/.config/omniwm/layout"
echo stale >"$t/home-migom/.config/kwinish/layout"
run migom 0.57.2 0.57.2 setup
[ "$(cat "$t/home-migom/.config/zonari/layout" 2>/dev/null)" = current ] && ok "migration prefers OmniWM over Kwinish" || bad "migration lost current OmniWM settings"

# setup without hyprland.lua (not a Lua config): refuse
mkdir -p "$t/home-nolua/.config/hypr"
run nolua 0.57.2 0.57.2 setup; rc=$?
[ "$rc" != 0 ] && [ ! -e "$t/home-nolua/.local/share/zonari" ] && ok "setup refuses without ~/.config/hypr/hyprland.lua" || bad "setup without hyprland.lua (exit $rc)"

# 3b. the bar widget asks the CLI
w=$root/$(jq -r '.entryPoints.barWidget // "missing"' "$m" 2>/dev/null)
grep -q 'status' "$w" 2>/dev/null && grep -q -- '--json' "$w" && ok "bar widget reads zonari status --json" || bad "bar widget does not read the status"
# a file named like a qs.Ui type shadows it in its own directory: BarWidget.qml using BarWidget instantiates itself
case $(basename "$w" .qml) in BarWidget | BarIconButton | WidgetButton) bad "bar widget file shadows the qs.Ui type $(basename "$w" .qml)" ;; *) ok "bar widget file does not shadow a qs.Ui type" ;; esac
grep -qE '^\s*property var state\b' "$w" && bad "bar widget redefines Item.state" || ok "bar widget does not redefine Item.state"

# 3c. coexisting with Omarchy's titlebars (omarchy-hyprland-titlebars: a hyprbars fork named "Hyprbar", attached to every
# window and drawn only on floating-workspace windows): the Zonari bar must not skip a window for a Hyprbar, and
# zonari.lua turns Omarchy's bar off so a window never gets two
for tree in src/bars src/bars-0.56; do
  body=$(sed -n '/^static void onNewWindow/,/^}/p' "$root/$tree/main.cpp")
  grep -q '"ZonariBar"' <<<"$body" && ok "$tree: onNewWindow skips a window that already has a ZonariBar" || bad "$tree: onNewWindow must skip its own ZonariBar"
  grep -q '"Hyprbar"' <<<"$body" && bad "$tree: onNewWindow skips windows with a Hyprbar (Omarchy attaches one to every window)" || ok "$tree: onNewWindow does not give way to a Hyprbar"
done
grep -qF 'if hl.plugin and hl.plugin.hyprbars then' "$inc.keep" 2>/dev/null && grep -qF 'hyprbars = { enabled = false }' "$inc.keep" \
  && ok "zonari.lua: turns Omarchy's titlebars off when they are loaded" || bad "zonari.lua: must set plugin.hyprbars.enabled = false when hl.plugin.hyprbars exists"

# 4. PKGBUILDs
for p in packaging/PKGBUILD packaging/bars/PKGBUILD; do
  grep -qE "depends=\(.*'hyprland>=0\.57'" "$root/$p" && ok "$p: depends on hyprland>=0.57" || bad "$p: must depend on hyprland>=0.57"
done

[ "$fails" = 0 ] && echo "test-omarchy-plugin: tudo passou" || { echo "test-omarchy-plugin: $fails falha(s)"; exit 1; }
