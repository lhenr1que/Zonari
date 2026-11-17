#!/usr/bin/env bash
# Tests for scripts/check.sh: a fake repo, stand-in lua/cargo/make and a PATH that holds only what check.sh needs,
# so "missing tool" is really missing. Every failure must give a non-zero exit, and the run must stay in its temp dir.
set -u
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P) || exit 1
t=$(mktemp -d "${TMPDIR:-/tmp}/omniwm-test-check.XXXXXXXX") || exit 1
trap 'rm -rf -- "$t"' EXIT
repo=$t/repo log=$t/log out=$t/out
fails=0
ok() { echo "ok - $1"; }
bad() { echo "FALHOU - $1"; sed 's/^/    | /' "$out"; fails=$((fails + 1)); }

# Stand-ins log their arguments and fail when their name is in $FAKE_FAIL. Bash builtins only: PATH is restricted.
fake() {
  printf '#!%s\n%s\n' "$BASH" "printf '%s\n' \"$1 \$*\" >> \"\$LOG\"; [[ \" \$FAKE_FAIL \" == *\" $1 \"* ]] && exit 1; $2 exit 0" > "$t/fakes/$1"
  chmod +x "$t/fakes/$1"
}
mkdir -p "$t/fakes" "$t/outer" "$t/tmp"
# The fake lua runs a suite by its first word: ok, fail, or env (record what the suite saw and write into $HOME).
fake lua '[ "$1" = -v ] && { echo "Lua fake"; exit 0; }; read -r w < "$1"; [ "$w" = fail ] && exit 1;
  [ "$w" = env ] && { printf "HOME=%s\nCFG=%s\nRUN=%s\nSIG=%s\nWL=%s\nCARGO_HOME=%s\nPWD=%s\n" "$HOME" "$XDG_CONFIG_HOME" "$XDG_RUNTIME_DIR" "${HYPRLAND_INSTANCE_SIGNATURE-unset}" "${WAYLAND_DISPLAY-unset}" "$CARGO_HOME" "$PWD" > "$ENVLOG"; : > "$HOME/probe"; };'
fake cargo ''
fake make ''

# bin <tool to leave out>...: real coreutils check.sh uses plus every stand-in not named.
bin() {
  rm -rf "$t/bin" && mkdir "$t/bin"
  local c
  for c in bash mktemp rm mkdir dirname; do ln -s "$(command -v "$c")" "$t/bin/$c"; done
  for c in lua cargo make; do [[ " $* " == *" $c "* ]] || ln -s "$t/fakes/$c" "$t/bin/$c"; done
}

# repo <first word of each suite>...: a fresh fake checkout with one passing tools test.
mkrepo() {
  rm -rf "$repo" && mkdir -p "$repo/omniwm-core" "$repo/tests" "$repo/scripts" "$repo/omniwm-ui" "$repo/omniwm-bars"
  cp "$here/../scripts/check.sh" "$repo/scripts/check.sh"
  printf '%s\n' "exit \${TOOLS_RC:-0}" > "$repo/tests/test-dummy.sh"
  local i=0 w
  for w; do i=$((i + 1)); echo "$w" > "$repo/omniwm-core/test_$i.lua"; done
}

# expect <exit code> <description> [args]: run check.sh from an unrelated cwd with a session-like environment.
expect() {
  local want=$1 what=$2 rc; shift 2
  : > "$log"
  (cd "$t" && env -i PATH="$t/bin" HOME="$t/outer" TMPDIR="$t/tmp" LOG="$log" ENVLOG="$t/env" \
    FAKE_FAIL="${FAKE_FAIL-}" TOOLS_RC="${TOOLS_RC-0}" HYPRLAND_INSTANCE_SIGNATURE=sig WAYLAND_DISPLAY=wayland-1 \
    DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/nowhere "$BASH" "$repo/scripts/check.sh" "$@") > "$out" 2>&1
  rc=$?
  if [ "$rc" = "$want" ]; then ok "$what (código $rc)"; else bad "$what: código $rc, esperado $want"; fi
}
has() { grep -q -- "$1" "$log"; }
check_log() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

bin; mkrepo ok ok
expect 0 "tudo passa"
check_log "roda as duas suítes, tools, cargo test --locked e make" \
  'has "lua omniwm-core/test_1.lua" && has "lua omniwm-core/test_2.lua" && has "cargo test --locked --manifest-path omniwm-ui/Cargo.toml" && has "make -C omniwm-bars TARGET="'
check_log "plugin compilado no diretório temporário, nada em omniwm-bars/" \
  'grep -q "make -C omniwm-bars TARGET=$t/tmp/omniwm-check\.[^/]*/omniwm-bars\.so$" "$log" && [ -z "$(ls -A "$repo/omniwm-bars")" ]'
check_log "temporário apagado ao sair" '[ -z "$(ls -A "$t/tmp")" ]'

mkrepo fail ok
expect 1 "uma suíte Lua falha"
check_log "as suítes seguintes ainda rodam" 'has "lua omniwm-core/test_2.lua"'
check_log "a falha aparece no resumo" 'grep -q "omniwm-core/test_1.lua" "$out"'

mkrepo ok
TOOLS_RC=3 expect 1 "um teste de tests/ falha"
FAKE_FAIL=cargo expect 1 "cargo test falha"
FAKE_FAIL=make expect 1 "compilação do plugin falha"
FAKE_FAIL=lua expect 1 "lua -v falha"

for c in lua cargo make; do
  bin "$c"
  expect 1 "sem o comando $c"
  check_log "sem $c: não diz que passou" '! grep -q "tudo passou" "$out"'
done
bin

mkrepo
expect 1 "nenhuma suíte omniwm-core/test_*.lua"
rm "$repo/tests/test-dummy.sh"; echo ok > "$repo/omniwm-core/test_1.lua"
expect 1 "nenhum teste tests/test-*.sh"

mkrepo ok
expect 0 "--lua-only passa" --lua-only
check_log "--lua-only não roda tools, cargo nem make" '! has "cargo" && ! has "make" && grep -q "só Lua" "$out"'
mkrepo fail
expect 1 "--lua-only com suíte falhando" --lua-only
expect 2 "opção desconhecida" --nope
expect 2 "argumento a mais" --lua-only extra

mkrepo env
expect 0 "suíte que inspeciona o ambiente" --lua-only
check_log "HOME e XDG apontam para o temporário do check" \
  'grep -q "^HOME=$t/tmp/omniwm-check\.[^/]*/home$" "$t/env" && grep -q "^CFG=$t/tmp/omniwm-check\.[^/]*/config$" "$t/env" && grep -q "^RUN=$t/tmp/omniwm-check\.[^/]*/runtime$" "$t/env"'
check_log "sem sockets da sessão (Hyprland, Wayland)" 'grep -q "^SIG=unset$" "$t/env" && grep -q "^WL=unset$" "$t/env"'
check_log "CARGO_HOME fica no HOME de fora" 'grep -q "^CARGO_HOME=$t/outer/.cargo$" "$t/env"'
check_log "roda na raiz do repositório" 'grep -q "^PWD=$repo$" "$t/env"'
check_log "nada gravado no HOME de fora e temporário apagado" '[ -z "$(ls -A "$t/outer")" ] && [ -z "$(ls -A "$t/tmp")" ]'

[ "$fails" -eq 0 ] || { echo "test-check: $fails falha(s)"; exit 1; }
echo "test-check: tudo passou"
