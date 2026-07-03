# agent-managed

**Deterministic — implemented in [`evals/run.sh`](../run.sh).**

Some overlapping skills belong to the **host agent's own installation**, not to
the user: Claude Code plugin skills (e.g. `claude-in-chrome`), Gemini CLI
extensions, Cursor extensions, opencode plugins, Codex installs. `stash`
detects the installed agents (by binary on PATH or their config root) and
refuses to move or unlink anything inside those roots — whichever agent is
running the stack. They belong in the stacked skill's **Routing table** as
rows, not in `sources/`.

Extend the protected list with `STACKER_PROTECTED=dir1:dir2`.

Asserts: a discovery symlink pointing into a protected root is kept; a skill
that lives only inside a protected root is found, reported, and left in place;
neither enters the manifest.
