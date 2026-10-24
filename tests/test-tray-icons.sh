#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT
input_dir="$repo_dir/tests/tray"
if [[ "${1:-}" == "--render" ]]; then
  input_dir="$repo_dir/tests/render"
  shift
fi

# Compile a test-only provider; nothing is built or installed by the plugin.
qt_tools="$(pkg-config --variable=libexecdir Qt6Core)"
"$qt_tools/moc" "$repo_dir/tests/render/runner.cpp" -o "$test_dir/runner.moc"
read -r -a qt_flags <<< "$(pkg-config --cflags --libs Qt6QuickTest Qt6Quick)"
g++ -std=c++17 -fPIC -Wall -Wextra -I "$test_dir" \
  "$repo_dir/tests/render/runner.cpp" "${qt_flags[@]}" -o "$test_dir/tray-tests"
TILELANE_ICON_FIXTURES="$repo_dir/tests/render/fixtures" \
  "$test_dir/tray-tests" -import "$repo_dir/tests/mocks" -input "$input_dir" "$@"
