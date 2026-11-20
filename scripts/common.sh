#!/usr/bin/env bash
# Shared by the patch-stack helpers.
set -euo pipefail
export LC_ALL=C

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
UPSTREAM="$ROOT/lightpanda"
WORKTREE="$ROOT/.build/dev"

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

load_stack() {
    local entry patch path primary=true
    entry=$(git -C "$ROOT" ls-files --stage -- lightpanda)
    [[ "$entry" =~ ^160000\ ([0-9a-f]{40})\ 0$'\t'lightpanda$ ]] ||
        die "Stage a single upstream submodule pointer with git add lightpanda."
    BASE=${BASH_REMATCH[1]}
    [[ $(git -C "$UPSTREAM" rev-parse --show-toplevel) == "$UPSTREAM" ]] ||
        die "Initialize the submodule: git submodule update --init --recursive."
    [[ $(git -C "$UPSTREAM" rev-parse HEAD) == "$BASE" ]] ||
        die "Submodule checkout differs from the staged pin; initialize it or stage the intended upstream update."
    [[ -z $(git -C "$UPSTREAM" status --porcelain --untracked-files=all) ]] ||
        die "The upstream submodule has local changes; preserve them before preparing the stack."

    while IFS= read -r entry; do
        [[ "$entry" == worktree\ * ]] || continue
        if [[ "$primary" == true ]]; then
            primary=false
            continue
        fi
        path=${entry#worktree }
        [[ "$path" == "$WORKTREE" ]] ||
            die "Only .build/dev is allowed as a linked worktree. Remove the extra worktree explicitly: $path"
    done < <(git -C "$UPSTREAM" worktree list --porcelain)

    [[ -d "$ROOT/patches" ]] || die "Missing patches directory; restore it before preparing the stack."
    shopt -s nullglob
    PATCHES=("$ROOT"/patches/*.patch)
    for patch in "${PATCHES[@]}"; do
        [[ ${patch##*/} =~ ^[0-9]{4}-.+\.patch$ ]] ||
            die "Patch filenames must use four digits: ${patch##*/}"
    done
}

check_worktree() {
    local tree=$1 state
    [[ -d "$tree" ]] || die "Missing .build/dev; initialize it with scripts/prepare.sh."
    [[ $(git -C "$tree" rev-parse --show-toplevel) == "$tree" ]] ||
        die "Not a worktree root: $tree"
    [[ $(git -C "$tree" rev-parse --path-format=absolute --git-common-dir) == \
       $(git -C "$UPSTREAM" rev-parse --path-format=absolute --git-common-dir) ]] ||
        die "The worktree must belong to the Lightpanda submodule."
    for state in rebase-apply rebase-merge MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD sequencer; do
        [[ ! -e $(git -C "$tree" rev-parse --git-path "$state") ]] ||
            die "A Git operation is unfinished in .build/dev ($state); resolve it there first."
    done
    git -C "$tree" merge-base --is-ancestor "$BASE" HEAD ||
        die "Rebase .build/dev onto the staged upstream pin before continuing."
    [[ -z $(git -C "$tree" rev-list --merges "$BASE..HEAD") ]] ||
        die "Keep a linear patch stack in .build/dev, without merge commits."
}

check_applied_patches() {
    local ids
    local -a commits=()
    ids=$(git -C "$WORKTREE" rev-list --reverse "$BASE..HEAD")
    if [[ -n "$ids" ]]; then
        mapfile -t commits <<< "$ids"
    fi
    APPLIED_PATCHES=${#commits[@]}
    (( APPLIED_PATCHES <= ${#PATCHES[@]} )) ||
        die ".build/dev has unexported or extra commits. Run scripts/export-patches.sh and reconcile patches/ before preparing again."
    (
        local temporary previous actual expected patch i
        temporary=$(mktemp -d)
        trap 'rm -f -- "$temporary/index" "$temporary/index.lock"; rmdir -- "$temporary"' EXIT
        export GIT_INDEX_FILE="$temporary/index"
        git -C "$WORKTREE" read-tree "$BASE"
        previous=$(git -C "$WORKTREE" rev-parse "$BASE^{tree}")
        for i in "${!PATCHES[@]}"; do
            patch=${PATCHES[i]}
            expected=$(git patch-id --verbatim < "$patch")
            [[ -n "$expected" && "$expected" != *$'\n'* ]] ||
                die "Expected one non-empty patch in ${patch##*/}."
            if (( i < APPLIED_PATCHES )); then
                actual=$(git -C "$WORKTREE" rev-parse "${commits[i]}^{tree}")
                [[ "$actual" != "$previous" ]] ||
                    die ".build/dev contains an empty commit; it is not the stored patch stack."
                # Compare resulting trees, not patch IDs, which ignore hunk locations.
                git -C "$WORKTREE" apply --cached --whitespace=nowarn -- "$patch" ||
                    die "Cannot validate ${patch##*/} against the pinned patch stack."
                [[ $(git -C "$WORKTREE" write-tree) == "$actual" ]] ||
                    die ".build/dev does not match ${patch##*/}. Reconcile its commits or export intentional stack changes; no worktree was reset."
                previous=$actual
            fi
        done
    )
}
