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
# the CARVE-OUTS — the sites the rule names, and no other
#
# each lands on a box whose `rhx` resolves NO repo skill, so the path form is
# the only surface that exists there.
#
# ⚠️ this read *"a skill may, a human never"* until 2026-09-08. that was the
#    wrong discriminator: carve-outs 1 and 2 are both skills, so the TYPIST
#    looked like the rule. it is the FAR SIDE's reach, and the rule's carve-out
#    3 is a human at a keyboard against a box that resolves no skill.
######################################################################
CARVED=(
  ".agent/repo=.this/role=any/skills/git.grove.provision.boot.sh"
  ".agent/repo=.this/role=any/skills/git.grove.auth.github.set.sh"

  # ── the RULE ITSELF. a rule must be able to spell what it forbids.
  #
  # 🛑 .this file was RED at HEAD and no reader acted on it — measured 2026-09-08.
  #    two of its three hits predate any edit: its `.the rule` banner (`NEVER
  #    bash src/…`) and its note that the parent rule once modeled the same
  #    violation. both spell the banned form ON PURPOSE, in the file whose whole
  #    job is to ban it.
  #
  # ⚠️ the play's own header already records this shape as m.10 — *a correction
  #    that quotes the dead form re-creates it* — and its fix was the ELLIPSIS
  #    escape. that escape serves prose, and it CANNOT serve carve-out 3, whose
  #    worked example must stay pasteable to be worth its place.
  #
  # ⇒ so the file is carved whole, as `rule.require.one-command-provision.md`
  #   already is. the cost is real and named: a genuine violation added to this
  #   file will not redden here. it is the reader of the rule who catches that.
  ".agent/repo=.this/role=any/briefs/grove/provision/rule.forbid.the-driver-by-path.md"

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

  # ── ONE line, and the tightest trigger of the set: the fix-text under this
  #    skill's `rhx does not run` rung. the rung AHEAD of it ran
  #    `rhx keyrack list` on the grove and it failed, so `rhx grove.provision`
  #    is the very surface the fix-text calls broken. the send re-applies
  #    `5.1.node`, which is what puts `rhx` on that box at all
  #
  # ⚠️ every other fix-text in the file names `rhx`, so the one line is not a
  #    habit — it is the false branch of a probe (`rule.forbid.exemption-as-habit`)
  ".agent/repo=.this/role=any/skills/git.grove.auth.keys.set.sh"
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
######################################################################
# 🛑 .carve-out 3 is a FORM, so it is read as one — never listed per file
#
# the rule carves out *"a ONE-BUNDLE apply on a grove, sent over a duct"*. that
# is a shape, and CARVED above is a list of PATHS, so the two cannot express one
# claim: every new prose page that documents the routine send reddens, and the
# only repair a path list offers is one more row.
#
# ⚠️ measured 2026-09-29: two such rows were red at HEAD —
#    `howto.opt-into-openhours.md:32` and
#    `.dream/v2026_09_13.fix.cross-repo-hook-blocks-the-grove-carve-out.md:28`.
#    both transcribe the rule's own `.the routine form` block verbatim, so the
#    clamp condemned the rule's sanctioned example. that is
#    `gotcha.a-check-that-cries-wolf-gets-silenced` m.7 — one pattern, two
#    claims, and the correct value is OPPOSITE in each.
#
# ⇒ a path list would have grown a row per page, forever, which is
#   `rule.forbid.exemption-as-habit`'s own tell: an exemption whose
#   justification never varies names a permanent condition.
#
# .the discriminator is the rule's own: WHICH BOX does this land on?
#   - `git.grove.send` names a FAR SIDE by construction, and a grove's `rhx`
#     resolves no repo skill — so a path form inside a send's `--what` payload
#     IS carve-out 3, read rather than claimed
#   - a path form with no send near it lands on THIS box, where `rhx` resolves
#     the skill, and that is the blocker
#
# ⚠️ the window is 3 lines, because the routine form wraps on a `\` — the send
#    and the payload sit on different lines in every extant instance
######################################################################
SENDER='git\.grove\.send'
SEND_WINDOW=3

PAT='(bash|sh|source)[[:space:]]+[^[:space:]"'"'"']*grove\.provision\._\.sh'
ELLIPSIS='(bash|sh|source)[[:space:]]+[^[:space:]"'"'"']*…'

# ⚠️ ONE reader for ONE set. the prior form counted `n_all` and `n_prose` with
#    two greps and subtracted — two readers of one set, free to disagree on the
#    input the check exists to catch (`…cries-wolf`, m.9). awk classifies each
#    hit once and emits only the rows that are neither prose nor a send.
_real_hits() {
  awk -v pat="$PAT" -v ell="$ELLIPSIS" -v snd="$SENDER" -v win="$SEND_WINDOW" '
    { for (i = win; i > 0; i--) hist[i + 1] = hist[i]; hist[1] = $0 }
    $0 ~ pat && $0 !~ ell {
      for (i = 1; i <= win + 1; i++) if (hist[i] ~ snd) next
      printf "%d:%s\n", NR, $0
    }
  ' "$1"
}

hits=0
carved_seen=()
while IFS= read -r f; do
  [[ -f "$_root/$f" ]] || continue
  grep -Eq "$PAT" "$_root/$f" 2>/dev/null || continue
  if _is_carved "$f"; then
    carved_seen+=("$f")
    continue
  fi
  real="$(_real_hits "$_root/$f")"
  [[ -z "$real" ]] && continue
  hits=$(( hits + 1 ))
  if [[ "$hits" -le 20 ]]; then
    echo "   ✋ P  $f" >&2
    printf '%s\n' "$real" | head -3 | while IFS= read -r line; do
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
