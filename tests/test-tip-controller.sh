#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
runner="/usr/lib/qt6/bin/qmltestrunner"
QT_QPA_PLATFORM=offscreen QSG_RHI_BACKEND=software \
  "$runner" -import "$repo_dir/tests/mocks" -input "$repo_dir/tests/tip" "$@"
