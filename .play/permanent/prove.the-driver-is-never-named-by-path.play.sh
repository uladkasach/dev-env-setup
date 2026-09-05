#!/usr/bin/env bash
######################################################################
# prove: no tracked file names the provision driver by PATH
#
# .what = one invariant, read out of the checkout's git index:
#
#           `bash|sh|source <…/grove.provision._.sh>` appears NOWHERE,
#           except at the two sites `rule.forbid.the-driver-by-path`
#           carves out by name.
#
# 🛑 .why a clamp and not a rule alone
#
#    the banned form was in ~140 tracked files on 2026-09-03, INCLUDING the
#    `.the rule` table of `rule.require.grove-provision-as-the-only-entrypoint`.
#    so the rule that declares the one door named the wrong handle, and every
#    reader who copied a worked example inherited it.
#
#    ⇒ that is the failure a rule cannot fix by itself: a reader meets the
#      EXAMPLE first. one bad example outranks a paragraph, and the repo had
#      one hundred and forty of them.
#
# ⚠️ .the two carve-outs are read from a LIST, and that is a second declaration
#
#    the rule declares them in prose; this play declares them in `CARVED`. they
#    are free to drift, which is `gotcha.a-check-that-cries-wolf-gets-silenced`
#    m.9 — one fact, two holders.
#
#    ⇒ it is clamped the only way a two-list pair can be: the row prints the
#      carve-outs it honored, so a reader sees the list this run used rather
#      than the list the rule says. a third site added to the code and not to
#      the rule reddens here; a fourth added to the rule and not here reddens
#      here too. neither drifts silently.
#
# ⚠️ .why the index and not the disk
#    an untracked scratch file is nobody's example — it reaches no other reader
#    and no other box. the corpus this rule governs is the corpus git carries.
#    ⇒ `git ls-files` is the set, and it is named in the output so a reader
#      knows which store was consulted (`gotcha.a-check-that-cries-wolf…`, q13)
#
# .the rows
#   P   a tracked file that invokes the driver by path, outside the carve-outs
#   C   a carve-out named by the list that no longer holds the form
#
# guarantee:
#   - READ-ONLY. it reads the index; it touches no box state
#   - STATIC. no network, no privilege, same answer on every box
#
# usage:
#   rhx play.run --play prove.the-driver-is-never-named-by-path
######################################################################
set -uo pipefail

FAILED=0
_fail() { FAILED=1; }

# ⚠️ the root leads with THIS FILE's location, never a hardcoded
#    `$HOME/git/more/dev-env-setup` — that names MAIN on every box, so a run
#    from a worktree would measure a tree under nobody's hand
_self="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)" || _self=""
if   [[ -n "$_self" && -f "$_self/src/grove.provision._.sh" ]]; then _root="$_self"
elif [[ -f "$PWD/src/grove.provision._.sh" ]];                 then _root="$PWD"
else                                                                _root="$HOME/git/more/dev-env-setup"
fi

######################################################################
# the CARVE-OUTS — the two sites the rule names, and no third
#
# each is a skill that OWNS the drive and sends to a box where `rhx` cannot be
# found. the discriminator is who types it: a skill may, a human never.
######################################################################
CARVED=(
  ".agent/repo=.this/role=any/skills/git.grove.provision.boot.sh"
  ".agent/repo=.this/role=any/skills/git.grove.auth.github.set.sh"

  # ── the BARE-BOX class: prose that documents the FIRST apply on a new grove.
  #
  # ⚠️ a first apply runs on a box with the repo pushed and NO node, no pnpm,
  #    and therefore no `rhx` at all — `5.1.node` is what puts it there, and it
  #    has not run yet. so the driver by path is the only surface that exists at
  #    that moment, and these four files transcribe the send `boot` makes.
  #
  # ⇒ their SECOND apply onward could use `rhx`, and that is exactly why they
  #   must stay verbatim: they describe one specific run, the one where it
  #   cannot
  ".agent/repo=.this/role=any/briefs/grove/reach/howto.bootstrap-a-grove-from-scratch.md"
  ".agent/repo=.this/role=any/briefs/grove/reach/howto.add-a-new-grove.md"
  ".agent/repo=.this/role=any/briefs/grove/provision/rule.require.one-command-provision.md"

  # ⚠️ ONE line of this file, and the rest of its fix-texts name `rhx`: the
  #    `--bare` send at the `no tmux yet` rung. a bare send is a
  #    non-interactive ssh, which reads no `.zshrc`, so `rhx` is unreachable on
  #    the far side — the same trigger as carve-out 2
  ".agent/repo=.this/role=any/skills/git.grove.ready.verify.sh"
)

# the driver ITSELF is not a caller of itself — its own path appears in it as a
# usage string, never as an invocation. it is excluded because a self-reference
# cannot be a second surface
CARVED+=("src/grove.provision._.sh")

_is_carved() {
  local f="$1" c
  for c in "${CARVED[@]}"; do [[ "$f" == "$c" ]] && return 0; done
  return 1
}

echo "🔭 prove.the-driver-is-never-named-by-path"
echo "   ├─ root:  $_root"
echo "   ├─ store: git ls-files (the INDEX, not the disk)"
echo "   └─ carve-outs honored by THIS run:"
for c in "${CARVED[@]}"; do echo "      · $c"; done
echo ""

######################################################################
# P. the sweep
#
# the pattern demands an INVOKER — `bash`, `sh`, or `source` — ahead of the
# path. a bare mention of `grove.provision._.sh` is a reference to the file and
# is legitimate everywhere; this rule bans the CALL, never the name.
######################################################################
######################################################################
# ⚠️ .the pattern was WRONG TWICE on its first roll, and both are recorded
#    because each is a `gotcha.a-check-that-cries-wolf-gets-silenced` shape:
#
#    1. it carried `\.` in the alternation, for the posix `. <file>` source
#       form. that matched a PROSE PERIOD before a backticked filename —
#       "…enumeration. `grove.provision._.sh` is the driver" — so it condemned
#       two briefs for a sentence (q7: one pattern, two claims). `source`
#       covers the case; the bare dot is dropped.
#
#    2. it matched the ELLIPSIS form, `bash …/grove.provision._.sh`. that is
#       prose shorthand and cannot be pasted — it is how a brief NAMES the
#       banned shape in order to ban it. so the rule's own ban text, and this
#       play's own header, reddened themselves (m.10: a correction that quotes
#       the dead form re-creates it).
#
#    ⇒ a path that carries `…` is prose. a path a reader could paste is a call.
######################################################################
PAT='(bash|sh|source)[[:space:]]+[^[:space:]"'"'"']*grove\.provision\._\.sh'
ELLIPSIS='(bash|sh|source)[[:space:]]+[^[:space:]"'"'"']*…'

hits=0
carved_seen=()
while IFS= read -r f; do
  [[ -f "$_root/$f" ]] || continue
  grep -Eq "$PAT" "$_root/$f" 2>/dev/null || continue
  if _is_carved "$f"; then
    carved_seen+=("$f")
    continue
  fi
  # a file whose ONLY matches are the prose ellipsis form has named the shape,
  # never invoked it. read the two sets and demand a difference
  n_all="$(grep -cE "$PAT" "$_root/$f")"
  n_prose="$(grep -E "$PAT" "$_root/$f" | grep -cE "$ELLIPSIS")"
  [[ "$n_all" -eq "$n_prose" ]] && continue
  hits=$(( hits + 1 ))
  if [[ "$hits" -le 20 ]]; then
    echo "   ✋ P  $f" >&2
    grep -nE "$PAT" "$_root/$f" | grep -vE "$ELLIPSIS" | head -3 | while IFS= read -r line; do
      echo "         $line" >&2
    done
  fi
done < <(git -C "$_root" ls-files 2>/dev/null)

if [[ "$hits" -gt 0 ]]; then
  [[ "$hits" -gt 20 ]] && echo "   ✋ P  … and $(( hits - 20 )) more" >&2
  echo "" >&2
  echo "   ⇒ $hits tracked file(s) invoke the driver by PATH" >&2
  echo "   ⇒ the surface is \`rhx\`, always:" >&2
  echo "        rhx grove.provision --what <slug> --mode apply     # this box" >&2
  echo "        rhx git.grove.provision boot <name> --mode apply   # a grove" >&2
  echo "   ⇒ a worked example teaches louder than the rule beside it, which is" >&2
  echo "     why this is a clamp and not a paragraph" >&2
  echo "   read: rule.forbid.the-driver-by-path" >&2
  _fail
else
  echo "   • P  no tracked file invokes the driver by path ✔"
fi

######################################################################
# C. a carve-out that no longer holds the form
#
# ⚠️ this is the half that keeps the two lists honest. a carve-out listed here
#    and absent from the code is a stale exemption, and a stale exemption reads
#    exactly like a live one until somebody deletes the wrong site
#    (`rule.forbid.exemption-as-habit`)
######################################################################
stale=0
for c in "${CARVED[@]}"; do
  [[ "$c" == "src/grove.provision._.sh" ]] && continue   # the driver, not a caller
  seen=0
  for s in ${carved_seen[@]+"${carved_seen[@]}"}; do [[ "$s" == "$c" ]] && seen=1; done
  [[ "$seen" -eq 1 ]] && continue
  echo "   ✋ C  carve-out no longer holds the form: $c" >&2
  echo "         ⇒ either the site was repaired — then DELETE it from CARVED here" >&2
  echo "           and from rule.forbid.the-driver-by-path — or the file moved" >&2
  stale=$(( stale + 1 ))
done
[[ "$stale" -eq 0 ]] && echo "   • C  every carve-out still holds the form it was granted for ✔"
[[ "$stale" -eq 0 ]] || _fail

echo ""
if [[ "$FAILED" -eq 0 ]]; then
  echo "🌲 the driver is reached through rhx, everywhere ✔"
  exit 0
fi
echo "✋ the driver is named by path somewhere it must not be" >&2
exit 1
