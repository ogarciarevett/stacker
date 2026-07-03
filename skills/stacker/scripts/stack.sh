#!/usr/bin/env bash
# stacker stash/restore — unload overlapping source skills from the agent's
# discovery path WITHOUT deleting them, and re-link them under the stacked
# skill's sources/ dir. A symlinked source keeps receiving upstream updates
# (npx skills update, git pull in the canonical dir) — no re-pull, no vendoring.
#
# Requires: bash 3.2+, `readlink -f` (macOS 12.3+ or coreutils).
set -euo pipefail
set -f # never glob: skill names and manifest fields are always literal

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
  exit "${1:-1}"
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

valid_name() { # a skill name is one plain path segment, no metachars we can't carry
  case "$1" in '' | . | .. | */* | *"$TAB"*) return 1 ;; esac
}

cmd="${1:-}"; [ $# -gt 0 ] && shift || usage
stacked="" names=""
while [ $# -gt 0 ]; do
  case "$1" in
    --into|--from) stacked="${2:?missing dir}"; shift 2 ;;
    --all) shift ;;
    -h|--help) usage 0 ;;
    *)
      valid_name "$1" || { echo "ERROR: invalid skill name: '$1'" >&2; exit 1; }
      names="$names $1"; shift ;;
  esac
done
[ -n "$stacked" ] && [ -d "$stacked" ] || usage
src="$stacked/sources"
manifest="$src/.manifest.tsv"

want() { # literal match — no glob/regex from names or manifest
  [ -z "$names" ] && return 0
  local w
  for w in $names; do [ "$w" = "$1" ] && return 0; done
  return 1
}

stashed_already() { [ -f "$manifest" ] && cut -f1 "$manifest" | grep -qxF "$1"; }

mtime_of() { # BSD stat, then GNU stat; '?' when neither works
  local out
  if out="$(stat -f '%Sm' -t '%Y-%m-%d' "$1" 2>/dev/null)" && [ "${#out}" -eq 10 ]; then
    echo "$out"; return
  fi
  out="$(stat -c '%y' "$1" 2>/dev/null | cut -d' ' -f1)" || true
  echo "${out:-?}"
}

do_stash() {
  mkdir -p "$src"
  local n dir entry canonical found owner hit r
  for n in $names; do
    if stashed_already "$n"; then
      echo "skip     $n (already stashed)"; continue
    fi
    found=""
    for dir in "${AGENT_DIRS[@]}"; do
      [ -d "$dir" ] || continue   # empty/bogus entries (trailing colon) never build paths
      entry="$dir/$n"
      if [ -L "$entry" ]; then
        # ponytail: readlink->rm TOCTOU accepted — single-user local tool
        if ! canonical="$(readlink -f "$entry" 2>/dev/null)"; then
          echo "WARN: $n at $entry is a dangling symlink — skipped, fix or remove it manually" >&2
          found=yes; continue
        fi
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
        if [ -e "$src/$n" ] || [ -L "$src/$n" ]; then
          echo "WARN: sources/$n already exists — left $entry in place (same name in two discovery dirs?)" >&2
          found=yes; continue
        fi
        mv "$entry" "$src/$n"
        printf '%s\tmoved\t%s\t%s\n' "$n" "$entry" "$src/$n" >>"$manifest"
        echo "stashed  $n  (moved $entry -> sources/$n)"
        found=yes
      fi
    done
    if [ -z "$found" ]; then
      # not in any discovery dir — maybe it lives inside a host agent's install
      hit=""
      while IFS= read -r r; do
        [ -d "$r" ] || continue
        hit="$(find "$r" -maxdepth 4 -type d -name "$n" 2>/dev/null | head -1 || true)"
        [ -n "$hit" ] && break
      done <<<"$(protected_roots | tr ':' '\n')"
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
  local tmp n mode entry canonical blocked m restored=""
  tmp="$(mktemp "$manifest.XXXXXX")"
  while IFS="$TAB" read -r n mode entry canonical; do
    if ! want "$n"; then
      printf '%s\t%s\t%s\t%s\n' "$n" "$mode" "$entry" "$canonical" >>"$tmp"; continue
    fi
    # sanity: a manifest row must still describe the skill it names
    if [ "${entry##*/}" != "$n" ]; then
      echo "WARN: manifest row for $n has suspicious entry '$entry' — kept, not restored" >&2
      printf '%s\t%s\t%s\t%s\n' "$n" "$mode" "$entry" "$canonical" >>"$tmp"; continue
    fi
    blocked=""
    if [ "$mode" = moved ]; then
      { [ -e "$entry" ] || [ -L "$entry" ]; } && blocked=yes
    else
      [ -e "$entry" ] && [ ! -L "$entry" ] && blocked=yes
    fi
    if [ -n "$blocked" ]; then
      echo "WARN: $entry already exists (reinstalled while stashed?) — kept row, resolve manually" >&2
      printf '%s\t%s\t%s\t%s\n' "$n" "$mode" "$entry" "$canonical" >>"$tmp"; continue
    fi
    if [ "$mode" = linked ]; then
      rm -f "$src/$n"
      ln -sfn "$canonical" "$entry"
    else
      mv "$src/$n" "$entry"
    fi
    restored="$restored $n"
    echo "restored $n -> $entry"
  done <"$manifest"
  mv "$tmp" "$manifest"
  for m in $names; do
    case " $restored " in *" $m "*) ;; *) echo "WARN: $m not in the manifest — nothing restored for it" >&2 ;; esac
  done
}

do_status() {
  if [ -s "$manifest" ]; then
    if command -v column >/dev/null 2>&1; then
      column -t -s "$TAB" <"$manifest"
    else
      cat "$manifest"
    fi
  else
    echo "no skills stashed under $stacked"
  fi
}

do_doctor() {
  local agent root n mode entry canonical
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
      printf '  OK      %-20s %s (upstream SKILL.md: %s)\n' "$n" "$canonical" "$(mtime_of "$canonical/SKILL.md")"
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
