# update-propagation

**Deterministic — implemented in [`evals/run.sh`](../run.sh).**

The reason stash uses symlinks instead of copies: when the canonical skill
updates (`npx skills update`, `git pull` in its repo), the stacked skill must
see the new version immediately — no re-pull, no re-vendor.

Asserts: editing the canonical `SKILL.md` after stashing is visible when read
through `<stacked>/sources/<name>/SKILL.md`.
