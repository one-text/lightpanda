#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
target=${1:-build}
if (( $# )); then shift; fi
case "$target" in
    build|build-dev|test) ;;
    *) die "Usage: scripts/build.sh [build|build-dev|test] [make arguments...]" ;;
esac

zig_path=$(command -v -- "${ZIG:-zig}") ||
    die "Zig is missing. Put it on PATH or set ZIG=/absolute/path/to/zig."
zig_path=$(cd -- "$(dirname -- "$zig_path")" && printf '%s/%s\n' "$PWD" "$(basename -- "$zig_path")")
for tool in make cargo rustc curl; do
    command -v "$tool" >/dev/null || die "Required build tool is missing: $tool"
done

# Synchronize .build/dev; working edits are allowed when its patch stack is current.
tree=$("$ROOT/scripts/prepare.sh")
required=$(awk -F '"' '/\.minimum_zig_version[[:space:]]*=/ { print $2; exit }' "$tree/build.zig.zon")
[[ -n "$required" ]] || die "Cannot read the pinned Zig version from build.zig.zon."
actual=$("$zig_path" version)
[[ "$actual" == "$required" ]] ||
    die "This stack requires Zig $required; found $actual. Set ZIG to the matching compiler."

# Upstream expands $(ZIG) unquoted: quote for its shell and escape Make dollars.
zig_command="'${zig_path//\'/\'\\\'\'}'"
zig_command=${zig_command//\$/\$\$}
make -C "$tree" download-v8
make -C "$tree" "$target" "$@" ZIG="$zig_command"
if [[ "$target" != test ]]; then
    printf '\nBinary: %s/zig-out/bin/lightpanda\n' "$tree"
fi
