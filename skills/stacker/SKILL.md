---
name: stacker
description: Stack overlapping skills instead of picking one. When two or more installed skills or tools can do the same job (web scraping, search, code review, test generation, data extraction), run the best candidates in parallel on the same task, score their outputs, and merge them into one result that beats any single tool. Use when the user says "stack", "combine skills", "use every tool", "ensemble", "cross-check", "double-check with another tool", when a task is output-critical and multiple capable skills are installed, or when evals show no single tool wins on every axis. Also use when the user wants to stop overlapping skills from loading into context ("stash", "unload", "stop loading these skills") — scripts/stack.sh unloads them behind one stacked skill without deleting them. Do NOT use for routine tasks where one tool is clearly sufficient — route to that tool instead.
---

# stacker

Skills overlap. Run a minimal eval over your installed skills and you find the
uncomfortable truth: **no tool wins on every axis.** One scraper is faster, another
renders JavaScript, a third survives bot walls. One reviewer catches security holes,
another catches naming. The deltas are small and axis-specific.

Agents handle this badly in two symmetric ways:

- **Load everything.** Every overlapping skill goes into context "just in case."
  Context bloats, instructions conflict, the agent improvises.
- **Pick "the best."** A router chooses one winner and throws away every axis
  the losers were better at.

Stacker is the third option: **run the top candidates on the same frozen task,
score their outputs, merge them.** Ensembling, applied to agent skills. The unit
you combine is the *output*, never the *context*.

## When to stack (and when not to)

Stacking costs tokens, time, and sometimes money. It is the paid upgrade, not the
default. Stack only when ALL of these hold:

1. **Output-critical** — correctness or completeness matters more than latency and cost.
2. **Real overlap** — 2+ installed skills can each do the task end to end.
3. **Complementary failures** — evals or experience show they fail on *different* inputs.

| Signal | Action |
|---|---|
| Routine task, one obvious tool | Route (single tool, escalate on failure) |
| One tool strictly dominates every axis | Route |
| Output feeds a decision, a publish, or money | **Stack** |
| Tools fail differently (JS vs static, bot walls, rate limits) | **Stack** |
| User says "double-check", "make sure", "cross-check" | **Stack** |

If you only need a fallback ladder ("try cheap, escalate on failure"), that is
routing, not stacking — keep the router skill you already have.

## The stack workflow

1. **Enumerate candidates.** List the installed skills/tools that can genuinely
   complete this task end to end. Cap at 2–4. If you can't name what each one is
   *better at*, drop it.

2. **Freeze the task spec.** One paragraph: input, expected output shape, success
   criteria. Every candidate gets the identical spec — otherwise you're comparing
   answers to different questions.

3. **Fan out in parallel.** One isolated run per candidate (subagent, background
   job, or separate CLI invocation). Each branch loads ONLY its own skill's
   instructions. Nothing but the branch's *output* returns to the main context.

4. **Score each output** against the success criteria from step 2. Simple 3-axis
   rubric, 0–2 each:
   - **Complete** — covers everything the spec asked for?
   - **Correct** — spot-check 2–3 verifiable facts/behaviors?
   - **Clean** — usable as-is (format, noise, truncation)?

5. **Merge** with the strategy that fits the output type (table below).

6. **Report with provenance.** Deliver the stacked result, then one line per
   candidate: what it contributed, where it disagreed, its score. Disagreements
   between tools are signal — surface them, never average them away.

## Merge strategies

| Strategy | When | How |
|---|---|---|
| **best-of** | Outputs are interchangeable, one clearly scored highest | Take the winner, discard the rest |
| **union** | Outputs are lists/collections (search results, findings, extracted items) | Combine, dedupe by identity, keep the best-sourced duplicate |
| **patch** | One output is the best base but has gaps others fill | Take the winner, splice in the specific sections losers did better |
| **consensus** | Outputs assert facts that must be right | Keep facts 2+ tools agree on; flag single-source facts as unverified |
| **synthesis** | Outputs are prose/analysis with different strengths | Rewrite into one artifact, crediting which tool sourced which part |

Default: **union** for collections, **patch** for documents, **consensus** for facts.

## Common overlap families

Use these to enumerate candidates fast (step 1) — most skill collections grow
the same overlaps:

| family | typical candidates | default merge |
|---|---|---|
| Web access | scraper CLI, local browser, cloud browser, native fetch | patch |
| UI/UX review | design guidelines, frontend-ui engineering, a11y, web-perf | synthesis |
| Code review (TS/Rust/Python…) | language reviewer, generic code-quality, security reviewer | union + consensus severity |
| Test generation | TDD, e2e, regression-testing skills | union |
| Memory / context recall | session memory, knowledge graph, learned instincts | union, newest wins conflicts |
| Docs / research | web search, deep-research, vendor-docs lookup | consensus facts, synthesis prose |

## Worked example — web scraping

Task: extract full product data from a JS-heavy page, feeding a pricing decision
(output-critical → stack).

```text
Candidates:  firecrawl scrape (fast, clean markdown, fails on some SPAs)
             agent-browser   (renders JS reliably, noisier output)

Fan out:     firecrawl scrape <url>            → branch A
             agent-browser open <url> &&
             agent-browser get text body       → branch B

Score:       A: complete 1 (missing lazy-loaded specs), correct 2, clean 2
             B: complete 2, correct 2, clean 1 (nav noise)

Merge:       patch — A's clean markdown as base, B's rendered spec table
             spliced in.

Report:      stacked result + "specs table came from agent-browser only;
             prices identical in both (consensus ✓)"
```

Either tool alone ships a defect: A misses data, B ships noise. The stack ships neither.

## Context discipline (the whole point)

The problem stacker exists to solve is agents loading every overlapping skill into
one context. So:

- **Never** load candidate skills' full instructions into the main context.
  Each fan-out branch loads its own skill; the main context sees only outputs.
- The main context holds: the task spec, the candidate list, the scores, the
  merged result. That's it.
- 2–4 candidates max. A 6-tool stack is context bloat wearing a costume.

## Persisting a stack — `scripts/stack.sh`

A stack you build more than twice deserves to become a skill of its own: ONE
stacked skill that owns the routing, with the source skills unloaded from the
agent's discovery path so they stop costing context every session.
`scripts/stack.sh` does the mechanical half:

```bash
# unload sources from the discovery path, re-link them under the stacked skill
bash scripts/stack.sh stash --into ~/.agents/skills/web-access \
  firecrawl firecrawl-scrape firecrawl-search agent-browser

bash scripts/stack.sh status  --from ~/.agents/skills/web-access
bash scripts/stack.sh restore --from ~/.agents/skills/web-access firecrawl  # or no names = all
```

**Nothing is deleted:**

- A discovery entry that is a **symlink** (the skills-CLI norm) is unlinked; the
  canonical dir (e.g. `~/.agents/skills/<name>`) stays put and keeps receiving
  upstream updates. The stacked skill reaches it via a new symlink at
  `sources/<name>` — updates flow through the link, no re-pull, no vendoring.
- A **real directory** is moved (not copied) to `sources/<name>`.
- `sources/.manifest.tsv` records every action, so `restore` is an exact undo.

**Agent-managed skills are NEVER touched.** Skills that ship with the host
agent — Claude Code plugin skills (`claude-in-chrome`), Gemini CLI extensions,
Cursor extensions, opencode plugins, Codex installs — belong to that agent's
own installation. `stash` detects which agents are present (binary on PATH or
config root on disk) and refuses to move anything inside their roots, whatever
CLI is running the stack. Those still belong in the stacked skill's **Routing
table** as rows — they cost no discovery entry, so there is nothing to stash.
Extend the protected list with `STACKER_PROTECTED=dir1:dir2`.

**Updating a stack** needs no command: sources update through their symlinks
the moment upstream does (`npx skills update`, `git pull`). To audit or grow a
stack:

```bash
bash scripts/stack.sh doctor --from <stacked-dir>   # detected agents, broken links, upstream freshness
bash scripts/stack.sh stash  --into <stacked-dir> <new-source>   # idempotent — re-run to add sources
```

Discovery paths default to `~/.claude/skills`; override with
`STACKER_AGENT_DIRS=dir1:dir2`.

## What a generated stacked skill MUST declare

After stashing, the stacked skill is the only one the agent loads — so it must
carry what the stashed skills used to announce:

1. **Routing** — a decision table mapping task → source tool, plus the
   escalation path. This is what replaces "load them all".
2. **Sources** — where every candidate came from and how it stays fresh:

```md
## Sources (stacked by stacker)

Unloaded from the discovery path; reachable via `sources/` symlinks.
Upstream updates flow through the links — no re-pull.

| source | reachable at | canonical |
|---|---|---|
| firecrawl     | sources/firecrawl     | ~/.agents/skills/firecrawl |
| agent-browser | sources/agent-browser | ~/.agents/skills/agent-browser |

Restore any source: `stack.sh restore --from <this dir> <name>`
```

A fan-out branch that needs a source's full instructions reads
`sources/<name>/SKILL.md` — into ITS context, never the main one.

## Anti-patterns

- **Stacking cheap tasks.** A weather lookup does not need an ensemble.
- **Stacking dominated tools.** If tool A beats tool B on every axis you care
  about, B adds cost and zero coverage.
- **Merging by vibes.** No frozen spec, no scores → you're just picking the
  longest output.
- **Hiding disagreement.** If two tools return different prices, that's a
  finding, not a rounding problem.
