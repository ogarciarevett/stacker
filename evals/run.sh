#!/usr/bin/env bash
# Deterministic evals for stack.sh — runs in a throwaway sandbox, no API keys.
# Fixture: a canonical skill store, an agent discovery dir with 3 symlinked
# skills + 1 real dir, and an empty stacked skill. Mirrors the layout the
# skills CLI creates (~/.agents/skills + ~/.claude/skills symlinks).
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
stack="$here/../skills/stacker/scripts/stack.sh"
sb="$(mktemp -d)"; trap 'rm -rf "$sb"' EXIT

mkdir -p "$sb/canonical" "$sb/agent" "$sb/stacked"
for n in alpha beta gamma; do
  mkdir -p "$sb/canonical/$n"; echo "# $n v1" >"$sb/canonical/$n/SKILL.md"
  ln -s "$sb/canonical/$n" "$sb/agent/$n"
done
mkdir -p "$sb/agent/delta"; echo "# delta v1" >"$sb/agent/delta/SKILL.md"

# host-agent installs (like Claude Code plugins) — protected, never touched:
# epsilon is symlinked into discovery, claude-in-chrome isn't in discovery at all
mkdir -p "$sb/plugins/epsilon" "$sb/plugins/claude-in-chrome"
echo "# epsilon" >"$sb/plugins/epsilon/SKILL.md"
echo "# claude-in-chrome" >"$sb/plugins/claude-in-chrome/SKILL.md"
ln -s "$sb/plugins/epsilon" "$sb/agent/epsilon"

export STACKER_AGENT_DIRS="$sb/agent"
export STACKER_PROTECTED="$sb/plugins"
pass=0; fail=0
check() {
  if eval "$2"; then echo "PASS  $1"; pass=$((pass + 1))
  else echo "FAIL  $1"; fail=$((fail + 1)); fi
}

bash "$stack" stash --into "$sb/stacked" alpha beta delta epsilon claude-in-chrome >/dev/null

# case: agent-managed — host-agent skills are detected and never moved
check "agent-managed: epsilon (linked to plugin root) kept"  '[ -L "$sb/agent/epsilon" ] && [ -f "$sb/plugins/epsilon/SKILL.md" ]'
check "agent-managed: claude-in-chrome untouched"            '[ -f "$sb/plugins/claude-in-chrome/SKILL.md" ] && [ ! -e "$sb/stacked/sources/claude-in-chrome" ]'
check "agent-managed: neither entered the manifest"          '! grep -qE "epsilon|claude-in-chrome" "$sb/stacked/sources/.manifest.tsv"'

# case: context-footprint — stashed sources stop loading, others untouched
check "context-footprint: alpha unloaded from discovery" '[ ! -e "$sb/agent/alpha" ]'
check "context-footprint: delta (real dir) unloaded"     '[ ! -e "$sb/agent/delta" ]'
check "context-footprint: gamma still loads"             '[ -f "$sb/agent/gamma/SKILL.md" ]'

# case: skill-loading — sources reachable through the stacked skill, not deleted
check "skill-loading: alpha readable via sources/"       'grep -q alpha "$sb/stacked/sources/alpha/SKILL.md"'
check "skill-loading: delta moved, not deleted"          'grep -q delta "$sb/stacked/sources/delta/SKILL.md"'

# case: update-propagation — upstream edit visible through the symlink, no re-pull
echo "# alpha v2" >"$sb/canonical/alpha/SKILL.md"
check "update-propagation: canonical v2 visible in stack" 'grep -q v2 "$sb/stacked/sources/alpha/SKILL.md"'

# case: restore-roundtrip — exact undo
bash "$stack" restore --from "$sb/stacked" >/dev/null
check "restore: alpha symlink back in discovery"         '[ -L "$sb/agent/alpha" ] && grep -q v2 "$sb/agent/alpha/SKILL.md"'
check "restore: delta back as a real dir"                '[ -d "$sb/agent/delta" ] && [ ! -L "$sb/agent/delta" ]'
check "restore: manifest empty"                          '[ ! -s "$sb/stacked/sources/.manifest.tsv" ]'

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
