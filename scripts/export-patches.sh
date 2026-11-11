#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
[[ $# == 0 ]] || die "Usage: scripts/export-patches.sh (always exports .build/dev)"
load_stack
check_worktree "$WORKTREE"
[[ -z $(git -C "$WORKTREE" status --porcelain --untracked-files=all) ]] ||
    die "Commit the changes in .build/dev before exporting patches."

mkdir -p -- "$ROOT/.build/patch-exports"
output=$(mktemp -d "$ROOT/.build/patch-exports/export.XXXXXX")
git -C "$WORKTREE" format-patch --no-numbered --zero-commit --no-signature --no-cover-letter --suffix=.patch --output-directory "$output" "$BASE..HEAD" >&2
printf '%s\n' "$output"
