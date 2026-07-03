#!/usr/bin/env bash
# stacker stash/restore — unload overlapping source skills from the agent's
# discovery path WITHOUT deleting them, and re-link them under the stacked
# skill's sources/ dir. A symlinked source keeps receiving upstream updates
# (npx skills update, git pull in the canonical dir) — no re-pull, no vendoring.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  stack.sh stash   --into <stacked-skill-dir> <skill-name>...
  stack.sh restore --from <stacked-skill-dir> [<skill-name>...]   # no names = all
  stack.sh status  --from <stacked-skill-dir>
  stack.sh doctor  --from <stacked-skill-dir>

Discovery paths searched: $STACKER_AGENT_DIRS (colon-separated),
default ~/.claude/skills.

stash    removes each skill from the discovery path — a symlink entry is
         unlinked (canonical dir untouched, still updatable), a real dir is
         moved — and makes it reachable at <stacked>/sources/<name>.
         Every action is recorded in <stacked>/sources/.manifest.tsv.
         Skills owned by a host agent (Claude Code plugins, Gemini extensions,
         Cursor/opencode/Codex installs) are detected and NEVER touched —
         reference those in the stacked skill's Routing table instead.
         Extend the protected list with STACKER_PROTECTED=dir1:dir2.
restore  reverses stash exactly, using the manifest.
doctor   audits a stack: detected agents, broken links, upstream freshness.
         Sources update through their symlinks automatically — re-run stash
         (idempotent) to add new ones.
EOF
  exit 1
}

TAB="$(printf '\t')"
IFS=':' read -r -a AGENT_DIRS <<<"${STACKER_AGENT_DIRS:-$HOME/.claude/skills}"

# Host-agent skill roots: <agent-binary>:<root>. A root is protected when the
# binary is on PATH or the dir exists — those skills belong to the agent's own
# installation and are never stashed or moved.
AGENTS_TABLE="claude:$HOME/.claude/plugins
codex:$HOME/.codex
gemini:$HOME/.gemini/extensions
opencode:$HOME/.config/opencode
cursor:$HOME/.cursor/extensions"

protected_roots() {
  local agent root out="${STACKER_PROTECTED:-}"
  while IFS=: read -r agent root; do
    if command -v "$agent" >/dev/null 2>&1 || [ -d "$root" ]; then
      [ -d "$root" ] && out="$out:$root"
    fi
  done <<<"$AGENTS_TABLE"
  echo "${out#:}"
}

owner_of() { # $1 = absolute path; prints the owning protected root if any
  local p="$1" r
  local IFS=':'
  for r in $(protected_roots); do
    r="$(readlink -f "$r" 2>/dev/null)" || continue   # /var vs /private/var etc.
    case "$p" in "$r" | "$r"/*) echo "$r"; return 0 ;; esac
  done
  return 1
}

cmd="${1:-}"; [ $# -gt 0 ] && shift || usage
stacked="" names=""
while [ $# -gt 0 ]; do
  case "$1" in
    --into|--from) stacked="${2:?missing dir}"; shift 2 ;;
    --all) shift ;;
    -h|--help) usage ;;
    *) names="$names $1"; shift ;;
  esac
done
[ -n "$stacked" ] && [ -d "$stacked" ] || usage
src="$stacked/sources"
manifest="$src/.manifest.tsv"

want() { [ -z "$names" ] || case " $names " in *" $1 "*) ;; *) return 1 ;; esac; }

do_stash() {
  mkdir -p "$src"
  local n dir entry canonical found
  for n in $names; do
    if [ -f "$manifest" ] && grep -q "^$n$TAB" "$manifest"; then
      echo "skip     $n (already stashed)"; continue
    fi
    found=""
    for dir in "${AGENT_DIRS[@]}"; do
      entry="$dir/$n"
      if [ -L "$entry" ]; then
        canonical="$(readlink -f "$entry")"
        if [ "$canonical" = "$(readlink -f "$stacked")" ]; then
          echo "skip     $n (is the stacked skill itself)"; found=yes; continue
        fi
        if owner="$(owner_of "$canonical")"; then
          echo "skip     $n (agent-managed under $owner — never moved; add it as a Routing row)"
          found=yes; continue
        fi
        rm "$entry"
        ln -sfn "$canonical" "$src/$n"
        printf '%s\tlinked\t%s\t%s\n' "$n" "$entry" "$canonical" >>"$manifest"
        echo "stashed  $n  ($entry -> sources/$n -> $canonical)"
        found=yes
      elif [ -e "$entry" ]; then
        # ponytail: same real-dir name in >1 discovery path would collide here;
        # symlink installs (the skills-CLI norm) never hit this.
        mv "$entry" "$src/$n"
        printf '%s\tmoved\t%s\t%s\n' "$n" "$entry" "$src/$n" >>"$manifest"
        echo "stashed  $n  (moved $entry -> sources/$n)"
        found=yes
      fi
    done
    if [ -z "$found" ]; then
      # not in any discovery dir — maybe it lives inside a host agent's install
      hit=""
      for r in $(protected_roots | tr ':' ' '); do
        hit="$(find "$r" -maxdepth 4 -type d -name "$n" 2>/dev/null | head -1)"
        [ -n "$hit" ] && break
      done
      if [ -n "$hit" ]; then
        echo "skip     $n (agent-managed: $hit — owned by the host agent, never moved; add it as a Routing row)"
      else
        echo "WARN: $n not found in ${AGENT_DIRS[*]}" >&2
      fi
    fi
  done
  echo "done. Declare Routing + Sources in the stacked SKILL.md (see stacker SKILL.md)."
}

do_restore() {
  [ -f "$manifest" ] || { echo "nothing stashed ($manifest missing)" >&2; exit 1; }
  local tmp="$manifest.tmp" n mode entry canonical
  : >"$tmp"
  while IFS="$TAB" read -r n mode entry canonical; do
    if want "$n"; then
      if [ "$mode" = linked ]; then
        rm -f "$src/$n"
        ln -sfn "$canonical" "$entry"
      else
        mv "$src/$n" "$entry"
      fi
      echo "restored $n -> $entry"
    else
      printf '%s\t%s\t%s\t%s\n' "$n" "$mode" "$entry" "$canonical" >>"$tmp"
    fi
  done <"$manifest"
  mv "$tmp" "$manifest"
}

do_status() {
  if [ -s "$manifest" ]; then
    column -t -s "$TAB" <"$manifest"
  else
    echo "no skills stashed under $stacked"
  fi
}

do_doctor() {
  local agent root n mode entry canonical upd
  echo "agents detected (their skill roots are protected, never stashed):"
  while IFS=: read -r agent root; do
    if command -v "$agent" >/dev/null 2>&1 || [ -d "$root" ]; then
      printf '  %-9s %s\n' "$agent" "$root"
    fi
  done <<<"$AGENTS_TABLE"
  [ -n "${STACKER_PROTECTED:-}" ] && echo "  (extra)   $STACKER_PROTECTED"
  echo
  if [ ! -s "$manifest" ]; then echo "no skills stashed under $stacked"; return; fi
  echo "stack health:"
  while IFS="$TAB" read -r n mode entry canonical; do
    if [ -e "$src/$n" ]; then
      upd="$(stat -f '%Sm' -t '%Y-%m-%d' "$canonical/SKILL.md" 2>/dev/null ||
             stat -c '%y' "$canonical/SKILL.md" 2>/dev/null | cut -d' ' -f1 || echo '?')"
      printf '  OK      %-20s %s (upstream SKILL.md: %s)\n' "$n" "$canonical" "$upd"
    else
      printf '  BROKEN  %-20s canonical missing: %s — restore it or re-stash\n' "$n" "$canonical"
    fi
  done <"$manifest"
  echo
  echo "sources update through their symlinks automatically; re-run 'stash' (idempotent) to add new ones."
}

case "$cmd" in
  stash)   [ -n "$names" ] || usage; do_stash ;;
  restore) do_restore ;;
  status)  do_status ;;
  doctor)  do_doctor ;;
  *) usage ;;
esac
