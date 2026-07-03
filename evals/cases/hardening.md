# hardening

**Deterministic — implemented in [`evals/run.sh`](../run.sh).**

Regression cases from a stacked code review of `stack.sh` itself (3 parallel
lenses: quality, security, bash portability — merged per the stacker skill):

- a **dangling symlink** in the discovery path is warned and skipped; it must
  not abort the rest of the batch under `set -e` (BSD `readlink -f` exits 1)
- skill names are matched **literally** — regex/glob metachars (`a.b`) can't
  false-match other names in the manifest or in `restore` filters
- the **same name in two discovery dirs** doesn't nest the second copy inside
  the first's canonical tree; the duplicate is left in place with a warning
- **path-traversal names** (`..`, `a/b`, empty, embedded tab) are rejected at
  the argument boundary
- restoring an **unknown name** warns instead of silently exiting 0
- restoring onto a **recreated destination** (skill reinstalled while stashed)
  is blocked, keeps the manifest row, and never nests `name/name/`
