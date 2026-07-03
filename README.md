<div align="center">

<img src="assets/stacker.svg" width="180" alt="stacker — a stack of pancakes with a terminal-cursor pat of butter">

# stacker

**Stack your agent skills instead of picking one.**

[![Agent Skill](https://img.shields.io/badge/agent-skill-8A2BE2)](https://agentskills.io)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Evals](https://img.shields.io/badge/evals-18%2F18_passing-brightgreen)](evals/)
[![No re-pull](https://img.shields.io/badge/updates-symlinked,_no_re--pull-blue)](#persisting-a-stack--stacksh)

Works with **Claude Code** · **Codex** · **Gemini CLI** · **opencode** · **Cursor**

</div>

---

## The problem (we created it ourselves)

Skills are great, so we install lots of them. Soon several can do the same job:
web access via firecrawl *and* agent-browser *and* a cloud browser *and* the
agent's native fetch. Faced with overlap, agents fail in one of two ways:

- **Load ALL of them** into context "just in case" — bloat, conflicting
  instructions, improvisation.
- **Pick "the best" one** — except evals show there is no best one. Each tool
  is a little better at some things and a little worse at others. The deltas
  are real but axis-specific.

Choosing one skill throws away every axis the others were better at.

## The idea

Don't route. Don't hoard. **Stack.**

```text
                    one frozen task spec
                             │
           ┌─────────────────┼─────────────────┐
           ▼                 ▼                 ▼
      firecrawl        agent-browser      cloud browser    ← isolated branches,
      (branch A)        (branch B)         (branch C)        own context each
           └─────────────────┼─────────────────┘
                             ▼
              score: complete / correct / clean
                             ▼
      merge: best-of · union · patch · consensus · synthesis
                             ▼
              one output + provenance report
```

The unit you combine is the **output**, never the **context**. The stacked
result beats any single tool because their failures don't overlap. It's
ensembling, applied to agent skills.

|  | load all | pick one | **stack** |
|---|---|---|---|
| context cost | 💸 every session | low | low — one skill loads |
| output quality | 🤷 improvises | caps at the winner | **beats any single tool** |
| tool updates | ✅ | ✅ | ✅ symlinked, no re-pull |
| disagreements surfaced | ❌ | ❌ | ✅ provenance report |

## Install

With the [skills CLI](https://github.com/vercel-labs/skills):

```bash
npx skills add ogarciarevett/stacker
```

Or manually — copy the skill folder into your agent's skills directory:

```bash
# Claude Code
cp -r skills/stacker ~/.claude/skills/stacker

# Any agent using a shared skills dir
cp -r skills/stacker ~/.agents/skills/stacker
```

## Persisting a stack — `stack.sh`

A stack you build more than twice should become a skill of its own: one stacked
skill that owns the routing, with the overlapping sources **unloaded from the
agent's discovery path without deleting anything**:

```bash
bash skills/stacker/scripts/stack.sh stash --into ~/.agents/skills/web-access \
  firecrawl firecrawl-scrape firecrawl-search agent-browser

bash skills/stacker/scripts/stack.sh status  --from ~/.agents/skills/web-access
bash skills/stacker/scripts/stack.sh doctor  --from ~/.agents/skills/web-access
bash skills/stacker/scripts/stack.sh restore --from ~/.agents/skills/web-access  # exact undo
```

- **Symlink-installed sources** (the skills-CLI norm) are unlinked from
  discovery and re-linked under `<stacked>/sources/<name>` — the canonical copy
  keeps receiving upstream updates and the stack sees them through the link.
  **No re-pull, no vendoring.**
- **Real directories** are moved (never copied, never deleted) under `sources/`.
- **Agent-managed skills are never touched.** Claude Code plugin skills
  (`claude-in-chrome`), Gemini CLI extensions, Cursor extensions, opencode
  plugins, Codex installs — stacker detects the agents on your machine (binary
  or config root) and refuses to move anything they own, whichever CLI runs the
  stack. Those go in the stacked skill's Routing table instead.
- `sources/.manifest.tsv` records everything, so `restore` is exact and
  `doctor` can audit link health and upstream freshness.
- The stacked skill's SKILL.md must declare its **Routing** table and a
  **Sources** table (where every skill came from) — template in the skill.

## Where stacking pays

Web access is just the worked example — every skill collection grows the same
overlap families:

| overlap family | the typical pile-up | stack recipe |
|---|---|---|
| **Web access** | firecrawl + agent-browser + cloud browser + native fetch | **patch** — clean markdown base, JS-rendered gaps spliced in |
| **UI/UX review** | design-guidelines + frontend-ui-engineering + a11y + web-perf skills | **synthesis** — one critique, each lens credited |
| **Code review** (TypeScript, Rust, Python…) | language reviewer + generic code-quality + security reviewer | **union** of findings, **consensus** on severity |
| **Test generation** | TDD skill + e2e skill + regression-testing skill | **union** — dedupe cases, keep the strongest assertion |
| **Memory / context** | session memory + knowledge graph + learned-instincts store | **union** — query all, dedupe, newest wins conflicts |
| **Docs / research** | web search skills + deep-research + vendor-docs lookup | **consensus** for facts, **synthesis** for prose |

Same rule everywhere: the sources fan out in isolated branches, only outputs
come back, disagreements get reported instead of averaged away.

## Copy-paste prompts

Stack a one-off, output-critical task:

```text
Stack this task: extract the full pricing table from https://example.com/pricing.
Fan out every capable skill in parallel on the same frozen spec, score the
outputs (complete/correct/clean), merge them, and show me where the tools
disagreed.
```

Turn a recurring overlap into a persistent stack:

```text
My skills firecrawl, firecrawl-scrape, firecrawl-search and agent-browser all
overlap on web access. Use stacker to make web-access the stacked skill: stash
the sources with stack.sh so they stop loading but keep updating through
symlinks, and add the Routing + Sources tables to web-access's SKILL.md.
```

Stack a UI/UX review:

```text
Stack a design review of src/app/dashboard: run my UI/UX skills (design
guidelines, frontend-ui engineering, accessibility, web-perf) as separate
branches on the same pages, then synthesize one critique that credits which
lens found what. Flag anything two lenses disagree on.
```

Stack a code review (works the same for TypeScript, Rust, Python…):

```text
Stack a review of this PR: run the language reviewer (typescript), the generic
code-quality skill, and the security reviewer in parallel on the same diff.
Union the findings, dedupe, mark severity by consensus, and tell me which
findings only one reviewer caught.
```

Stack your memory systems before starting work:

```text
Before we start: stack a recall pass for "payments retry logic" across my
memory systems (session memory, knowledge graph, learned instincts). Union the
results, dedupe, prefer the newest fact when they conflict, and flag anything
single-sourced as unverified.
```

Audit or grow an existing stack:

```text
Run stacker's doctor on ~/.agents/skills/web-access, fix anything broken, and
stash any new overlapping web skill I've installed since.
```

Undo everything:

```text
Restore all the skills stashed under ~/.agents/skills/web-access to exactly
where they were.
```

## Evals

Prove it, don't vibe it — deterministic suite (sandboxed, no API keys) plus one
LLM-judged case. See [`evals/`](evals/):

```bash
bash evals/run.sh   # 18 assertions: footprint, loading, updates, restore, agent-managed, hardening
```

Real-world run (2026-07-03): stacking `web-access` over 9 sources (firecrawl +
7 subskills + agent-browser) took a Claude Code discovery path from **101 to 92
entries** — one skill loads, every source stays updatable and reachable.

## Repo structure

```
stacker/
├── README.md
├── LICENSE
├── assets/
│   └── stacker.svg         # the pancake logo (drawn by Codex, reviewed by Claude)
├── evals/
│   ├── README.md
│   ├── run.sh              # deterministic eval suite (sandboxed)
│   └── cases/              # one doc per eval case
└── skills/
    └── stacker/
        ├── SKILL.md        # the skill — this is what your agent reads
        └── scripts/
            └── stack.sh    # stash / restore / status / doctor
```

## License

[MIT](LICENSE)

---

<div align="center">

If stacker saved your context window, **⭐ star the repo** — that's how other
agents' humans find it.

</div>
