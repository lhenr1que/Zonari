#!/usr/bin/env bash
# Builds and runs zonari-bars/test_actions.cpp: arguments, guards and failure-log gating of the bar's host actions
# (zonari-bars/actionGate.hpp), no Hyprland needed.
set -u
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P) || exit 1
t=$(mktemp -d "${TMPDIR:-/tmp}/zonari-test-actions.XXXXXXXX") || exit 1
trap 'rm -rf -- "$t"' EXIT
cxx=${CXX:-g++}
command -v "$cxx" >/dev/null || { echo "FALHOU - falta o compilador $cxx"; exit 1; }
"$cxx" -std=c++2b -Wall -Wextra -Werror -I "$root/zonari-bars" "$root/zonari-bars/test_actions.cpp" -o "$t/test_actions" || { echo "FALHOU - compilar zonari-bars/test_actions.cpp"; exit 1; }
"$t/test_actions"
