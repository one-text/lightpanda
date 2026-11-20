#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
[[ $# == 0 ]] || die "Usage: scripts/prepare.sh"
load_stack

if [[ ! -e "$WORKTREE" && ! -L "$WORKTREE" ]]; then
    mkdir -p -- "$(dirname -- "$WORKTREE")"
    git -C "$UPSTREAM" worktree add --detach "$WORKTREE" "$BASE" >&2
fi

check_worktree "$WORKTREE"
check_applied_patches
if (( APPLIED_PATCHES < ${#PATCHES[@]} )); then
    [[ -z $(git -C "$WORKTREE" status --porcelain --untracked-files=all) ]] ||
        die ".build/dev is missing patches but has uncommitted changes. Commit/export or resolve those changes before preparing again."
    if ! git -C "$WORKTREE" am --no-3way -- "${PATCHES[@]:APPLIED_PATCHES}" >&2; then
        die "Patch application failed in .build/dev; resolve it there before continuing. No replacement worktree will be created."
    fi
    check_worktree "$WORKTREE"
    check_applied_patches
fi
(( APPLIED_PATCHES == ${#PATCHES[@]} )) || die "Not all patches were applied in .build/dev."
printf '%s\n' "$WORKTREE"
