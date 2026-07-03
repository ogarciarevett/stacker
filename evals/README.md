# evals

Same idea as [agent-browser/evals](https://github.com/vercel-labs/agent-browser/tree/main/evals):
prove the skill does what it claims, don't vibe it.

| case | kind | what it proves |
|---|---|---|
| [context-footprint](cases/context-footprint.md) | deterministic | stashed sources stop loading; unrelated skills untouched |
| [skill-loading](cases/skill-loading.md) | deterministic | sources stay readable via `sources/` symlinks — nothing deleted |
| [update-propagation](cases/update-propagation.md) | deterministic | upstream edits visible through the link, no re-pull |
| [restore-roundtrip](cases/restore-roundtrip.md) | deterministic | `restore` puts every entry back exactly as it was |
| [agent-managed](cases/agent-managed.md) | deterministic | host-agent skills (Claude plugins, Gemini/Cursor extensions…) are never moved |
| [hardening](cases/hardening.md) | deterministic | dangling links, metachar names, dup dirs, traversal, blocked restores |
| [skill-selection](cases/skill-selection.md) | LLM, manual | a real task routes through the stacked skill alone |

Run the deterministic set (sandboxed `mktemp -d` fixture, no API keys, <1s):

```bash
bash evals/run.sh
```

## Real-world result — web-access (2026-07-03)

Applied on the author's machine: `web-access` (a router skill over
firecrawl + agent-browser + Browserbase) became the stacked skill, and its 9
overlapping sources (`firecrawl`, 7 `firecrawl-*` subskills, `agent-browser`)
were stashed out of `~/.claude/skills` (101 → 92 discovery entries). Result:
only `web-access` loads;
every source remains updatable in `~/.agents/skills/` and reachable through
`web-access/sources/`; the routing table lives in web-access's SKILL.md.
