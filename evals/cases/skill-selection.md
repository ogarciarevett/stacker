# skill-selection

**LLM-judged — run manually** (needs an agent CLI; not part of `run.sh`).

With a stack applied (e.g. `web-access` over firecrawl + agent-browser), a
fresh agent session given a web task must route through the stacked skill
alone — none of the stashed skills' instructions may appear in the main
context.

```bash
claude -p "scrape https://news.ycombinator.com and give me the top 5 titles" --verbose
```

**Judge — PASS if:**

1. The transcript loads only the stacked skill (`web-access`), not any stashed
   source skill.
2. Any read of `sources/<name>/SKILL.md` happens inside a fan-out branch
   (subagent / separate invocation), not the main context.
3. The task completes correctly.
