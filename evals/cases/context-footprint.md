# context-footprint

**Deterministic — implemented in [`evals/run.sh`](../run.sh).**

After `stack.sh stash`, the stashed skills must be gone from the agent's
discovery path (so they no longer load into every session's context), while
skills that were not stashed keep loading.

Asserts: stashed symlink entry removed, stashed real-dir entry removed, an
untouched skill's `SKILL.md` still present in the discovery path.
