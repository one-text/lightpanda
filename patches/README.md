# Downstream patches

Store Git mail patches here, generated with `git format-patch`. Helpers apply
`NNNN-description.patch` files in bytewise filename order (four-digit numbers).
Keep one logical change per patch. Explain its purpose, scope and references
in the commit message, not in a patch inventory in this README.

## Development and export

Keep the pinned `lightpanda` submodule clean. `.build/dev` is the sole
development worktree. Run `scripts/prepare.sh` to create it or apply missing
trailing patches, then make source changes there.

Commit each logical change in the development worktree, then run:

```bash
scripts/export-patches.sh
```

The helper exports the complete stack into a new directory under
`.build/patch-exports/` and prints its path. It keeps numbered filenames for
application order, but uses `--no-numbered` for plain `[PATCH]` subjects and
`--zero-commit` to omit unstable originating commit hashes. No series total
or commit hash should change an earlier patch when a new commit is appended.

Compare the exported files with `patches/` before replacing the tracked set.
For a normal addition, existing patches must remain byte-for-byte unchanged;
only new patch files should appear. Investigate unexpected differences rather
than including them as export noise. Copy the intended export into `patches/`
before preparing or building again.

## Stack maintenance

Patches are stable, not immutable. Consolidation, reordering, removal and
rebasing onto a new upstream release may intentionally change existing files.
Treat these as explicit maintenance operations, separate from adding a patch,
and remove obsolete patch files when replacing a revised stack.

## Validation

Build with `scripts/build.sh`. Run `.build/dev/zig-out/bin/lightpanda` against
the requested harness, following `AGENTS.md`. Keep temporary diagnostics and
reports in ignored `.build/` artifacts, not in this README.
