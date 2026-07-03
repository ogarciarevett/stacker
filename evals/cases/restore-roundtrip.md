# restore-roundtrip

**Deterministic — implemented in [`evals/run.sh`](../run.sh).**

`stack.sh restore` is an exact undo of `stash`, driven by
`sources/.manifest.tsv`: symlink entries are re-created pointing at the same
canonical dir, moved real dirs are moved back.

Asserts: after restore, the symlink entry exists again (and reflects upstream
edits made while stashed), the real dir is back as a real dir (not a link),
and the manifest is empty.
