#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -p "$test_dir/home/.nix-profile/share/applications" "$test_dir/user/applications" \
  "$test_dir/system-a/applications" "$test_dir/system-b/applications"

entry() {
  local path="$1"
  shift
  printf '[Desktop Entry]\nType=Application\nName=Fixture\nExec=true\n%s\n' "$@" > "$path"
}

scan() {
  env HOME="$test_dir/home" XDG_DATA_HOME="$test_dir/user" \
    XDG_DATA_DIRS="$test_dir/system-a:$test_dir/system-b" \
    bash "$repo_dir/scripts/hidden-desktop-entries" 'Hyprland:omarchy'
}

expect() {
  local expected="$1" actual
  # A visible final entry is a successful scan, not an error.
  if ! actual="$(scan)"; then
    printf 'Hidden-entry scan exited with an error. Partial output:\n%s\n' "$actual" >&2
    exit 1
  fi
  actual="$(printf '%s\n' "$actual" | sort)"
  if [[ "$actual" != "$expected" ]]; then
    printf 'Hidden entries differ. Expected:\n%s\nActual:\n%s\n' "$expected" "$actual" >&2
    exit 1
  fi
}

entry "$test_dir/user/applications/visible.desktop" ''
entry "$test_dir/system-a/applications/gnome-only.desktop" 'OnlyShowIn=GNOME;'
entry "$test_dir/system-a/applications/z-visible.desktop" ''
entry "$test_dir/system-b/applications/not-hyprland.desktop" 'NotShowIn=GNOME;Hyprland;'
entry "$test_dir/system-b/applications/allowed.desktop" 'OnlyShowIn=omarchy;'
entry "$test_dir/home/.nix-profile/share/applications/nix-hidden.desktop" 'NoDisplay=true'
expect $'gnome-only\nnix-hidden\nnot-hyprland'

# User entries override system entries in both directions.
entry "$test_dir/user/applications/gnome-only.desktop" ''
entry "$test_dir/user/applications/allowed.desktop" 'Hidden=true'
expect $'allowed\nnix-hidden\nnot-hyprland'

# Empty directories and a final visible file must also exit successfully.
rm "$test_dir/user/applications/"* "$test_dir/system-a/applications/"* \
  "$test_dir/system-b/applications/"* "$test_dir/home/.nix-profile/share/applications/"*
expect ''
entry "$test_dir/system-b/applications/visible.desktop" ''
expect ''
printf 'Hidden desktop entries: pass (all directories, visibility, overrides, empty and visible-only scans)\n'
