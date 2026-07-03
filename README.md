# stacker

**Stack your agent skills instead of picking one.**

An [agent skill](https://agentskills.io) that teaches AI coding agents (Claude Code,
Codex, OpenCode, Gemini CLI, Cursor…) to combine the outputs of overlapping skills
instead of loading them all — or betting everything on a single "winner."

## The problem (we created it ourselves)

Skills are great, so we install lots of them. Soon several skills can do the same
job: web access via firecrawl *and* agent-browser *and* a cloud browser *and* the
agent's native fetch. Faced with overlap, agents fail in one of two ways:

- **Load ALL of them** into context "just in case" — bloat, conflicting
  instructions, improvisation.
- **Pick "the best" one** — except evals show there is no best one. Run a minimal
  eval over your own stack and you'll see it: each tool is a little better at some
  things and a little worse at others. The deltas are real but axis-specific.

Choosing one skill throws away every axis the others were better at.

## The idea

Don't route. Don't hoard. **Stack.**

For output-critical tasks, run the 2–4 capable skills in parallel on the same
frozen task spec — each in its own isolated context — then score the outputs and
merge them (best-of, union, patch, consensus, or synthesis). The unit you combine
is the **output**, never the **context**. The stacked result beats any single tool
because their failures don't overlap.

It's ensembling, applied to agent skills.

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

## Usage

The skill triggers when you ask your agent to **"stack"**, **"combine skills"**,
**"cross-check"**, **"use every tool"** — or automatically when a task is
output-critical and multiple installed skills overlap.

What the agent does:

1. Enumerates the 2–4 skills that can genuinely complete the task
2. Freezes one task spec and fans out — one isolated run per skill
3. Scores each output (complete / correct / clean)
4. Merges with the right strategy and reports provenance, including where the
   tools disagreed

Full workflow, merge-strategy table, and a worked example live in
[`skills/stacker/SKILL.md`](skills/stacker/SKILL.md).

## Repo structure

```
stacker/
├── README.md
├── LICENSE
└── skills/
    └── stacker/
        └── SKILL.md    # the skill — this is what your agent reads
```

## License

[MIT](LICENSE)
