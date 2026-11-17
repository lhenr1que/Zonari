#!/usr/bin/env bash
# Packaging and plugin build checks (etapa E of the 27/10 audit), no root, nothing installed on the system, no compile:
#  1. zonari-bars/Makefile rebuilds the plugin when any plugin header changes (make -q on a temp copy);
#  2. resources/packaging/bars/PKGBUILD ships every source the rebuild hook needs: package() runs into a temp pkgdir, and every
#     #include "..." of the shipped sources must be shipped too;
#  3. resources/packaging/bars/zonari-bars-rebuild reports a failure, not success, when installing the rebuilt plugin fails.
# ZONARI_ROOT=<dir> checks another copy of the repository.
set -u
root=${ZONARI_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}
t=$(mktemp -d "${TMPDIR:-/tmp}/zonari-test-packaging.XXXXXXXX") || exit 1
trap 'rm -rf -- "$t"' EXIT
fails=0
ok() { echo "ok - $1"; }
bad() { echo "FALHOU - $1"; fails=$((fails + 1)); }

# 1. Makefile: a header newer than the plugin makes it out of date
cp -r "$root/zonari-bars" "$t/mk"
touch -d '2000-01-01' "$t"/mk/*
touch "$t/mk/zonari-bars.so"
if make -q -C "$t/mk" zonari-bars.so >/dev/null 2>&1; then ok "Makefile: plugin up to date when nothing changed"; else bad "Makefile: plugin out of date with nothing changed"; fi
stale=()
for h in "$t"/mk/*.hpp; do
  case ${h##*/} in test_*) continue ;; esac
  touch -d '2000-01-01' "$t/mk/zonari-bars.so"; touch -d '2001-01-01' "$h"
  make -q -C "$t/mk" zonari-bars.so >/dev/null 2>&1; rc=$? # 1: out of date, as it must be; 0: not rebuilt; 2: make error
  [ "$rc" = 1 ] || stale+=("${h##*/}(make -q exit $rc)")
  touch -d '2000-01-01' "$h"; touch "$t/mk/zonari-bars.so"
done
[ ${#stale[@]} = 0 ] && ok "Makefile: a changed header rebuilds the plugin" || bad "Makefile: changing these headers does not rebuild: ${stale[*]}"

# 2. PKGBUILD package(): the shipped plugin sources are complete
mkdir -p "$t/src" "$t/pkg"
git -C "$root" ls-files -z | (cd "$root" && xargs -0 cp --parents -t "$t/src" 2>/dev/null) || true
mkdir -p "$t/src/zonari"; (cd "$t/src" && find . -mindepth 1 -maxdepth 1 ! -name zonari -exec mv -t zonari {} +)
: > "$t/src/zonari/zonari-bars/zonari-bars.so"; : > "$t/src/zonari/zonari-bars/zonari-bars.abi"
if (cd "$t/src" && srcdir=$PWD pkgdir=$t/pkg bash -euc 'source "$1"; package' _ "$root/resources/packaging/bars/PKGBUILD") >"$t/pkg.log" 2>&1; then
  ok "PKGBUILD: package() runs"
  ps=$t/pkg/usr/share/zonari/plugin-src
  missing=()
  for f in "$ps"/*.cpp "$ps"/*.hpp; do
    [ -f "$f" ] || continue
    for inc in $(sed -n 's/^#include "\([^"]*\)".*/\1/p' "$f"); do [ -f "$ps/$inc" ] || missing+=("${f##*/}->$inc"); done
  done
  for s in $(sed -n 's/^SRC *= *//p' "$root/zonari-bars/Makefile"); do [ -f "$ps/$s" ] || missing+=("Makefile->$s"); done
  [ ${#missing[@]} = 0 ] && ok "PKGBUILD: the rebuild sources include everything they need" || bad "PKGBUILD: shipped sources miss: ${missing[*]}"
  ls "$ps" | grep -q '^test_' && bad "PKGBUILD: ships test sources" || ok "PKGBUILD: no test sources shipped"
else
  bad "PKGBUILD: package() failed:"; sed 's/^/    /' "$t/pkg.log"
fi

# 2b. resources/packaging/PKGBUILD package(): every core module (not the tests) is shipped
mkdir -p "$t/pkgcore" "$t/src/zonari/zonari-ui/target/release"; : > "$t/src/zonari/zonari-ui/target/release/zonari-ui"
if (cd "$t/src" && srcdir=$PWD pkgdir=$t/pkgcore bash -euc 'source "$1"; package' _ "$root/resources/packaging/PKGBUILD") >"$t/pkgcore.log" 2>&1; then
  missing=()
  for m in "$root"/zonari-core/*.lua; do
    case ${m##*/} in test_*) continue ;; esac
    [ -f "$t/pkgcore/usr/share/zonari/core/${m##*/}" ] || missing+=("${m##*/}")
  done
  [ ${#missing[@]} = 0 ] && ok "PKGBUILD (core): every core module is shipped" || bad "PKGBUILD (core): not shipped: ${missing[*]}"
else
  bad "PKGBUILD (core): package() failed:"; sed 's/^/    /' "$t/pkgcore.log"
fi

# 3. zonari-bars-rebuild: an install that fails is reported as a failure
mkdir -p "$t/fake" "$t/bin"
printf 'abi:\n\t@: > zonari-bars.so; : > zonari-bars.abi\n' > "$t/fake/Makefile"
printf '#!/bin/sh\n[ "$1" = --modversion ] && echo 0.57.0; exit 0\n' > "$t/bin/pkg-config"; chmod +x "$t/bin/pkg-config"
: > "$t/notadir" # dest under a regular file: install cannot create it
out=$(PATH="$t/bin:$PATH" ZONARI_PLUGIN_SRC="$t/fake" ZONARI_PLUGIN_DEST="$t/notadir/plugins" sh "$root/resources/packaging/bars/zonari-bars-rebuild" 2>&1); rc=$?
if ! grep -q 'rebuilt for' <<<"$out" && grep -q 'installing it into .* failed' <<<"$out"; then ok "rebuild: a failed install of the plugin is reported as a failure"; else bad "rebuild: plugin install failed but no failure reported: $out"; fi
[ "$rc" = 0 ] && ok "rebuild: never fails the pacman transaction" || bad "rebuild: exit $rc (must be 0)"
# the second install (the ABI file) fails: a read-only directory where the file should go
mkdir -p "$t/dest2/zonari-bars.abi"; chmod 555 "$t/dest2/zonari-bars.abi"
out=$(PATH="$t/bin:$PATH" ZONARI_PLUGIN_SRC="$t/fake" ZONARI_PLUGIN_DEST="$t/dest2" sh "$root/resources/packaging/bars/zonari-bars-rebuild" 2>&1)
chmod 755 "$t/dest2/zonari-bars.abi"
if ! grep -q 'rebuilt for' <<<"$out" && grep -q 'installing it into .* failed' <<<"$out"; then ok "rebuild: a failed install of the ABI file is reported as a failure"; else bad "rebuild: ABI install failed but no failure reported: $out"; fi
out=$(PATH="$t/bin:$PATH" ZONARI_PLUGIN_SRC="$t/fake" ZONARI_PLUGIN_DEST="$t/dest" sh "$root/resources/packaging/bars/zonari-bars-rebuild" 2>&1)
[ -f "$t/dest/zonari-bars.so" ] && grep -q 'rebuilt for' <<<"$out" && ok "rebuild: success when install works" || bad "rebuild: did not install or report: $out"

[ "$fails" = 0 ] && echo "packaging: tudo passou" || { echo "packaging: $fails falha(s)"; exit 1; }
