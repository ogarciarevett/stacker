# skill-loading

**Deterministic — implemented in [`evals/run.sh`](../run.sh).**

Stashing must never delete a source. Every stashed skill stays reachable at
`<stacked>/sources/<name>/SKILL.md`, so a fan-out branch can load its full
instructions on demand — into the branch's context, never the main one.

Asserts: a symlink-installed source resolves through `sources/`; a real-dir
source was moved (content intact), not deleted.
