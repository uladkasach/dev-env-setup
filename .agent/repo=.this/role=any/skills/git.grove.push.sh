#!/usr/bin/env bash
######################################################################
# .what = push content from here to a grove
#
# .why  = a grove needs content that main does not carry — a worktree's
#         src/, a config, an installer. push it directly instead of a
#         merge-then-clone round trip, so a change is validated on the
#         grove BEFORE it merges.
#
# usage:
#   rhx git.grove.push <grove> --from <local-path> --into <remote-path>
#   rhx git.grove.push grove-box --from src --into git/more/dev-env-setup.wip/src
#
# ⚠️ `--into` NAMES THE DESTINATION DIRECTORY, and it is HOME-RELATIVE
#
#      two ways to get it wrong, both measured, both silent:
#
#      1. a LEADING `~/` or `/`. the path is already resolved against the
#         grove's `$HOME`, so `~/git/…` becomes `$HOME/~/git/…` — a literal
#         `~` directory. the push reports success and the content is nowhere
#         the caller will look.
#
#      2. an --into that names the PARENT rather than the destination. on
#         2026-07-30 `--from src --into git/more/dev-env-setup.wip` emptied
#         all of `src/` onto the checkout ROOT — `grove.provision/`,
#         `bash_aliases.sh`, and the rest, each a level too high — and the
#         same run with `--from .agent` overwrote the repo's own `readme.md`
#         with `.agent/readme.md`. again: exit 0, "cowabunga", no complaint.
#
#      worse, four playbooks DOCUMENTED form 2 in their own usage lines, so
#      a caller inherits the mistake. the docs are the cause to fix.
#
#      the rule that avoids both: --into ends with the name you want --from's
#      contents to live under, and starts with no slash —
#
#        --from src    --into git/more/dev-env-setup.wip/src      ✔
#        --from .agent --into git/more/dev-env-setup.wip/.agent   ✔
#        --from src    --into git/more/dev-env-setup.wip          ✋ scatters
#        --from src    --into ~/git/more/dev-env-setup.wip/src    ✋ literal ~
#
# ⚠️ A FILE --from TAKES THE OPPOSITE FORM, and that inversion is the footgun
#
#      a DIRECTORY's --into names where its CONTENTS go, so the dir's own name
#      must appear in --into. a FILE has no contents, so --into names the
#      PARENT the file lands in, and the file's name must NOT appear —
#
#        --from src/foo.sh --into git/more/wip/src            ✔ → src/foo.sh
#        --from src/foo.sh --into git/more/wip/src/foo.sh     ✋ → src/foo.sh/foo.sh
#
#      the two kinds want opposite --into shapes for one flag, so the rule a
#      caller carries from a dir push is exactly wrong on a file push. both
#      transports LAND a file correctly; the prose misled, since it said
#      "contents of <file>" on the way out. so the preview and sign-off blocks
#      below split by kind.
#
# guarantee:
#   - rides the grove's ssh alias (set by `git grove set`)
#   - creates the remote parent dir
#   - a DIR  --from: `--into X` means ITS CONTENTS END UP AT X
#   - a FILE --from: `--into X` means THE FILE ENDS UP AT X/<its name>
#     both hold on BOTH transports, with or without a trailing slash on --from
#   - plan mode by default (safe preview)
#
######################################################################
# .why TWO transports, and why that is NOT the duplicate-list defect
#
#   settled 2026-07-29 (the human) — recorded against relitigation.
#
#   | transport | needs                | why we want it                        |
#   |-----------|----------------------|---------------------------------------|
#   | rsync     | rsync on BOTH ends   | THE MAIN CASE. delta transfer — a     |
#   |           |                      | repeat push of src/ carries only the  |
#   |           |                      | bytes that changed. that is the whole |
#   |           |                      | iterate-on-a-grove loop, run dozens   |
#   |           |                      | of times an hour                      |
#   | tar       | tar on the remote    | THE FALLBACK. every unix ships tar,   |
#   |           |                      | so this cannot be unavailable. a      |
#   |           |                      | fresh grove mid-bootstrap may not     |
#   |           |                      | have rsync yet, and that is exactly   |
#   |           |                      | when a push must still work           |
#
#   the pair splits by need: rsync for SPEED on the common path, tar for REACH
#   on the bare path. neither subsumes the other — rsync is faster but strictly
#   less available, tar is universal but re-sends the whole tree every time.
#
#   rsync is the DEFAULT; tar is an explicit OPT-IN (`--via tar`). no automatic
#   fallback — see "no silent fallback" below for why that matters.
#
#   this is NOT the "two lists drift" defect that retired install_env.grove.sh
#   and three others. those were two DECLARATIONS of what to do. these are two
#   CARRIERS of one declaration. the test that separates them:
#
#     > does each copy hold its own knowledge, or do they carry the same content
#     > by different means?
#
#   two lists of steps = two sets of knowledge = drift. two transports for one
#   payload = one set of knowledge = fine, PROVIDED they agree on the result.
#
# .the defect it carried — found 2026-07-29, and it was the AGREEMENT
#
#   the two branches disagreed on LAYOUT, so one command had two outcomes, split
#   by which tool the box happened to hold:
#
#     rsync  `rsync -az "$FROM" "$GROVE:$INTO"`
#            rsync's rule: NO trailing slash on the source means "copy the
#            DIRECTORY into the target". so `--from src --into …/src` produced
#            `…/src/src/`
#     tar    `tar … --strip-components=1 -C "$INTO"`
#            strips the leading component, so it copied CONTENTS to `…/src/` —
#            the layout a human expects
#
#   the header documented rsync's rule as the contract, which made the tar
#   fallback silently non-conformant. rsync sits on both ends here, so the rsync
#   branch always won.
#
#   the cost: `--from src --into ~/…/dev-env-setup/src` wrote a SHADOW COPY at
#   `src/src/` and reported `cowabunga! pushed`. the driver read the stale
#   `src/`, so one fix was pushed three times, credited each time, and never
#   once ran. a whole diagnosis then rested on a false premise.
#
#   > **a transport whose layout depends on the tool that carried it has no
#   > contract.** the fix is not to delete a carrier — make every carrier owe
#   > the same result, and state that result as the guarantee.
#
#   `--into` names a destination for the CONTENT, the only reading a human
#   gives it. both branches honor exactly that, and `verify.grove.push.layout`
#   holds them to it.
######################################################################
set -o pipefail

# 🛑 the sink comes along — a push READS BACK, and what it reads is grove-chosen
#
# .why  a push looks like a one-way write, and it is not. `rsync -avn --delete`
#       reports the files that exist AT THE DESTINATION and not in the source,
#       so those bytes are FILENAMES THE GROVE WROTE, relayed here by rsync's
#       own protocol. a linux filename may hold any byte but `/` and NUL, so an
#       OSC 52 fits in one — and `src/tmux.conf` sets `set-clipboard on`, so it
#       writes this human's clipboard.
#
#       ⚠️ and the stale-file block runs ABOVE the mode gate, so it fires on
#         `--mode plan` — the default, and the command a human runs FIRST. its
#         own fix-text then tells them to copy an `rm -rf` line off that same
#         screen. the clipboard is rewritten at the exact moment they reach for it.
#
# .why  this file, and via the shared operations file
#       `git.grove.operations.sh` already owns the guard that loads the sink
#       from THIS CHECKOUT. to re-spell it here would be a third holder of one
#       rule (`rule.forbid.two-writers-on-one-artifact`) — and it is a rule
#       whose next revision must reach every holder or the audited sink is not
#       the sink that ran.
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/git.grove.operations.sh"

GROVE="" FROM="" INTO="" MODE="plan" VIA="rsync"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from) FROM="$2"; shift 2 ;;
    --into) INTO="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --via)  VIA="$2"; shift 2 ;;
    --skill|--repo|--role) shift 2 ;;
    -h|--help)
      echo "git.grove.push - push content from here to a grove"
      echo ""
      echo "usage: rhx git.grove.push <grove> --from <local> --into <remote> [--via rsync|tar] [--mode plan|apply]"
      echo ""
      echo "  <grove>       the grove name (from 'git grove list')"
      echo "  --from        local path (dir or file)"
      echo "  --into        remote dir —"
      echo "                  a DIR  --from: its CONTENTS end up here"
      echo "                  a FILE --from: it lands here, under its own name"
      echo "                so a dir's own name belongs in --into and a file's"
      echo "                does NOT. the two kinds take opposite shapes"
      echo "  --via rsync   delta transfer — only changed bytes cross (DEFAULT)"
      echo "  --via tar     needs only tar on the far end; re-sends the whole tree"
      echo "  --mode apply  actually push (default: plan)"
      echo ""
      echo "  a slash at the end of --from changes nought — the layout is the same"
      echo "  either way, and identical on rsync and on tar"
      echo ""
      echo "  .git is NEVER carried. a worktree's .git is a one-line pointer at an"
      echo "  absolute path on THIS machine, and it turns the destination into a"
      echo "  broken repo where even 'git config --global' fails"
      echo ""
      echo "  there is NO automatic fallback. if rsync is unavailable this fails and"
      echo "  tells you to opt in with --via tar, so you always know which carrier ran"
      exit 0
      ;;
    *) [[ -z "$GROVE" ]] && GROVE="$1"; shift ;;
  esac
done

if [[ -z "$GROVE" || -z "$FROM" || -z "$INTO" ]]; then
  echo "✋ usage: rhx git.grove.push <grove> --from <local> --into <remote>" >&2
  exit 2
fi

if [[ ! -e "$FROM" ]]; then
  echo "✋ local path not found: $FROM" >&2
  exit 2
fi

######################################################################
# ⚠️ the two --into hazards, SOLVED AT CAUSE rather than documented
#
#   both measured 2026-07-30. both exited 0 with a green "cowabunga", so an
#   unrelated-looking symptom surfaced the damage later. a hazard a doc can only
#   WARN about is a hazard every caller still meets (rule.require.solve-at-cause).
#
#   they split, because only one of them is deterministically wrong:
#
#   | hazard              | always wrong? | so the skill…             |
#   |---------------------|---------------|---------------------------|
#   | `~/` or `/` prefix  | YES           | REFUSES, and names the fix|
#   | --into names parent | no — a rename | SHOWS the resolved path   |
#
#   a refusal on the second would cry wolf on every legitimate rename
#   (`--from src --into wip/src.old`), and a check that cries wolf gets
#   silenced — see gotcha.a-check-that-cries-wolf-gets-silenced.
######################################################################

# hazard 1 — a `~/` or `/` prefix. ALWAYS wrong, so refuse.
#
# .why it can never be right: both transports expand --into against the grove's
#      $HOME, so `~/git/x` becomes `$HOME/~/git/x` — a directory literally named
#      `~`. an absolute `/git/x` writes outside $HOME entirely. no caller means
#      either one.
if [[ "$INTO" == "~"* || "$INTO" == "/"* ]]; then
  # ⚠️ strip BOTH forms, and strip `~` before `/` — `~/git` needs two removals.
  #      a single `${INTO#/}` handles the absolute case alone and hands the tilde
  #      case back UNCHANGED, so the "fix" line reprints the refused command.
  #      measured on this guard's first run. an error that names a fix which
  #      reproduces the defect is worse than one that names none — the caller
  #      trusts it and pastes it (rule.require.errors-name-the-fix)
  INTO_FIXED="${INTO#\~}"
  INTO_FIXED="${INTO_FIXED#/}"

  # ⚠️ the two prefixes fail DIFFERENTLY, so they owe different reasons. one
  #      shared sentence that claims "a directory named '~'" is false for the
  #      absolute case, and a reason that misdescribes the fault teaches the
  #      reader a wrong model of the tool
  echo "✋ --into must be HOME-RELATIVE: drop the '${INTO:0:1}' prefix" >&2
  echo "   ├─ got:  $INTO" >&2
  if [[ "$INTO" == "~"* ]]; then
    echo "   ├─ why:  the path is already resolved against the grove's \$HOME, so" >&2
    echo "   │        this lands at \$HOME/$INTO — inside a directory literally" >&2
    echo "   │        named '~'. the push would report success." >&2
  else
    echo "   ├─ why:  --into is joined onto the grove's \$HOME, so this lands at" >&2
    echo "   │        \$HOME/$INTO — a doubled slash, never the absolute path you" >&2
    echo "   │        typed. the push would report success." >&2
  fi
  echo "   └─ fix:" >&2
  echo "        rhx git.grove.push $GROVE --from $FROM --into $INTO_FIXED --mode $MODE" >&2
  exit 2
fi

######################################################################
# 🛑 hazard 1b — a `..` TRAVERSAL. also always wrong, so also refuse
#
# .the defect this closes
#      the guard above refuses a `~` or `/` prefix and admits every other value,
#      so `--into ../../tmp/x` passed. `--into` is joined onto the grove's
#      $HOME, so that lands at `$HOME/../../tmp/x` — i.e. `/tmp/x`, outside
#      $HOME entirely — and the push reports success.
#
#      ⇒ that is the same escape the `~`/`/` guard exists to stop, spelled a
#        third way. the guard was not absent; it was NARROWER THAN ITS OWN
#        CLAIM, which reads "--into must be HOME-RELATIVE".
#
# ⚠️ .why the table above did not cover it
#      it grades "--into names parent" as *"no — a rename"*, and shows the
#      resolved path rather than a refusal. that is correct for
#      `--from src --into wip/src.old`, where the parent is NAMED. it is not
#      about `..`, where the parent is ESCAPED TO. one row was read as if it
#      settled both, and the two want opposite verdicts
#      (`gotcha.a-check-that-cries-wolf-gets-silenced`, q7).
#
# .why the same `case` as the pull, and not a new reader
#      `git.grove.pull` already vets every archive member with
#      `case … in /*|..|../*|*/../*|*/..)`. one escape, two boundaries, so they
#      get one shape — a second reader written its own way is free to drift, and
#      the drift is silent (m.9).
#
# ⚠️ `..` is refused ANYWHERE in the path, not merely at the front. `wip/../../x`
#    escapes exactly as well as `../../x`, and a front-anchored test would pass
#    it — the classic way a guard reads as present and is absent.
######################################################################
case "$INTO" in
  ..|../*|*/../*|*/..)
    echo "✋ --into must be HOME-RELATIVE: it may not traverse with '..'" >&2
    echo "   ├─ got:  $INTO" >&2
    echo "   ├─ why:  --into is joined onto the grove's \$HOME, so this lands at" >&2
    echo "   │        \$HOME/$INTO — which resolves OUTSIDE \$HOME. the push would" >&2
    echo "   │        write there and report success." >&2
    echo "   └─ fix:  name the destination from \$HOME, with no '..' —" >&2
    echo "        rhx git.grove.push $GROVE --from $FROM --into <dir-under-home> --mode $MODE" >&2
    exit 2
    ;;
esac

# strip any trailing slash ONCE, up front, so neither branch has to think about
# it. the guarantee is "contents land at --into" either way, so the slash the
# caller typed must not reach a transport that would read meaning into it
FROM="${FROM%/}"
INTO="${INTO%/}"

######################################################################
# ⚠️ .what = `.git` never crosses, on EITHER carrier
#
# .why  a worktree's `.git` is a FILE, not a directory, and it holds one line:
#
#         gitdir: /home/vlad/git/more/dev-env-setup/.git/worktrees/<branch>
#
#       an absolute path on the SOURCE machine, which names no directory on the
#       destination. rsync copies it happily, and the destination becomes a
#       directory git treats as a BROKEN REPO.
#
# ⚠️ .the cost, measured on grove-1 2026-07-30
#       git resolves the repo BEFORE it honors `--global`, so once that file
#       landed, every git command run from that directory died — even ones that
#       never touch a repo:
#
#         $ git config --global --get user.email
#         fatal: not a git repository: /home/vlad/git/more/dev-env-setup/.git/...
#
#       so `2.2.git` reported "git has no identity", "pull.ff is ''", and all ten
#       aliases ABSENT — on a box where every one was correctly set. from /tmp
#       the same commands answered fine. the driver's own header wore the same
#       wound: `commit none@none`.
#
#       three bundles failed their proof on a TRANSPORT defect, and the report
#       named the bundles. a false ✋ that accuses the innocent beats a miss for
#       harm — it sends the reader to fix what is not broken.
#
# .why EXCLUDED rather than translated
#       a grove is an rsync TARGET, not a git checkout — it needs no history, and
#       the settled checkout it keeps is one it cloned itself. no sense of
#       `--from .` wants the source's `.git`. for a full repo it also holds most
#       of the bytes, which the delta transfer would re-walk on every push
#
######################################################################
# ⚠️ `.git` as the ONLY exclusion makes `--from .` unusable
#
#   every howto in this repo then said `--from src/`, and a grove held a `src/`
#   with no `package.json`, no `.agent/`, no `readme.md`, no
#   `grove.bootstrap.sh`. that one narrow push causes five recorded incidents:
#
#     term=asset      — a bundle landed and the asset beside it did not
#     term=shim       — same shape, a second time
#     term=drift      — a pushed src ran no phase, so rung 4 read a stale box
#     howto.rhx-upgrade      — "carries src/ and ONLY src/", then lists 3 more
#     howto.restore-kitty-session — got both callers and no snapper
#
#   ⇒ five briefs each documented the same seam — what a repo does instead of
#     one fix. make `--from .` correct, so the procedure
#     `rule.require.one-command-provision` names is the one that runs.
#
# .why a FIXED LIST and not `--filter=':- .gitignore'`
#   rsync can honor a gitignore; tar cannot. that split puts the two carriers
#   back on different layouts — the exact defect the "two transports" block
#   records. a fixed set is one declaration BOTH obey, and the set has exactly
#   one holder — `GROVE_BOUNDARY_EXCLUDES` in `git.grove.operations.sh`, which
#   every carrier reads and none copies.
#
# .why THIS set
#   it is `.gitignore`'s, and its reasons carry over intact:
#     node_modules  arch-specific binaries; the grove runs its own install
#     .log/ .temp/  per-machine scratch — and `.gitignore` names `.temp/` a dox
#     .agent/.cache/  risk in a PUBLIC repo, which a push to a SHARED box only
#                     sharpens (rule.forbid.dox-in-public-repo)
#     .play/temporary/  gitignored so a scratch play cannot rot into an exhibit
#                     (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.13). a
#                     push carries it INTO a checkout on a shared box, where the
#                     next reader finds it beside tracked artifacts and reads it
#                     as a fixture — the same rot, one hop out.
#                     ⚠️ measured 2026-09-02: a `--from .` put a scratch shim
#                     onto a grove's checkout. the skip costs no reach, since a
#                     play reaches a grove through `--play`, which lands it at
#                     `$HOME/.local/state/grove.play/` instead
#
# 🛑 .why `.play/permanent/` is NOT in that set, and must never be added
#   it is the opposite artifact. a tracked discrimination probe is a CLAMP that
#   must reach every box, so its absence has to be loud — and a skip would make
#   it silent, which is the one failure a clamp exists to prevent
#   (`rule.forbid.repair-plays`, exception 2). same parent dir, opposite promise;
#   read the child, never the parent.
#
# ⚠️ .why the preview below reads the same set, and holds no copy
#   the preview names a sample file to make `--into` legible. a sample drawn
#   from a path that never crosses teaches the reader a layout the push does not
#   produce. so the preview reads the set itself, and a second copy beside the
#   preview is the two-lists defect (rule.forbid.two-writers-on-one-artifact)
#
# 🛑 .the set MOVED to `git.grove.operations.sh` — 2026-08-31
#   every reason above is a reason about a BOUNDARY, and this file is one of its
#   two sides. while the set sat here it was the OUTBOUND half's declaration in
#   the boundary's voice, and `git.grove.pull` carried every one of these members
#   back with no exclusion at all — `.git` included, which is the member the
#   block above spends thirty lines on.
#
#   ⇒ the set now lives in the file BOTH directions source, so no half can say
#     "never crosses" on the other's behalf. the inbound reason — a pulled `.git`
#     is grove-authored code a local tool OBEYS — is written beside it there.
#
#   ⚠️ and this file keeps NO alias for it. a `PUSH_EXCLUDES=("${GROVE_…[@]}")`
#     line reads as a convenience and is a second name for one fact, which is
#     the defect one rename retires and the next reinstates (`term=holder`).
######################################################################

echo "🐚 git.grove.push --via $VIA --mode $MODE"
echo "   ├─ grove: $GROVE"
echo "   ├─ from:  $FROM"
echo "   ├─ into:  $GROVE:$INTO"
echo "   └─ skips: ${GROVE_BOUNDARY_EXCLUDES[*]}"

######################################################################
# hazard 2 — an --into that names the PARENT rather than the destination
#
# .why this is SHOWN and never refused
#      `--from src --into wip/src` is right and `--from src --into wip` is
#      wrong, but `--from src --into wip/src.old` is a legitimate RENAME. so
#      the basenames disagree in one wrong case and one right case, and a
#      refusal keyed on that would block real work. a check that cries wolf
#      gets silenced, and a silenced check protects no one.
#
# .why a SAMPLE PATH is the right shape
#      the brief's test: "after this runs, what is the full path of one file
#      from --from?" — a question a human must otherwise hold in their head.
#      this answers it with a real file, so a wrong --into is READ, not
#      recalled. `--from src --into wip` prints `wip/bash_aliases.sh`, and a
#      caller who wanted `wip/src/…` sees it.
#
#      (rule.require.errors-name-the-fix — the silent exit 0 was the defect)
#
# ⚠️ .the sample must name a REAL source path, and a file is not a directory
#      `$FROM/$SAMPLE` suits a dir, where it is a real file's source path. on a
#      FILE it concatenates the name onto itself and prints a path that exists
#      nowhere —
#
#        .temp/probe.test.ts/probe.test.ts  →  $HOME/…/src/utils/probe.test.ts
#        ^ no such path, on either machine
#
#      measured 2026-08-12. the DESTINATION was right, the SOURCE invented, so
#      the one line written to make `--into` legible read as the least legible
#      thing on screen — and a caller who distrusts the preview reads none of
#      it (gotcha.a-check-that-cries-wolf-gets-silenced)
SAMPLE="" SAMPLE_SRC=""
if [[ -d "$FROM" ]]; then
  # one real file, sorted so the sample is the same on every run of the same
  # push. `|| true` because a `find` that matches none must not fail the push
  #
  # ⚠️ and it must SKIP what the carriers skip. a `--from .` whose sample named
  #    `.agent/.cache/…` would print a destination path no file ever reaches —
  #    the preview's whole job is to be believed, so it may not name a phantom
  #
  # ⚠️ and the membership test is the SHARED one, never an inline copy. a copy
  #    drifts narrow — match `*/$_ex/*` and not `*/$_ex` and an excluded root
  #    at the end of a path reads as carried. one holder, one answer
  #    (`term=holder`)
  while IFS= read -r _cand; do
    [[ -n "$_cand" ]] || continue
    _grove_boundary_excluded "$_cand" && continue
    SAMPLE="$_cand"
    break
  done < <(find "$FROM" -type f -printf '%P\n' 2>/dev/null | sort || true)
  [[ -n "$SAMPLE" ]] && SAMPLE_SRC="$FROM/$SAMPLE"
else
  SAMPLE="$(basename "$FROM")"
  SAMPLE_SRC="$FROM"
fi

if [[ -n "$SAMPLE" ]]; then
  echo ""
  echo "   🔭 so, on $GROVE:"
  echo "      $SAMPLE_SRC  →  \$HOME/$INTO/$SAMPLE"
  echo "      ↑ if that is not where you want it, --into is wrong"
  # a file's --into takes the OPPOSITE shape to a dir's, so say which one is
  # in hand. the caller who just pushed a dir carries the wrong rule otherwise
  [[ -d "$FROM" ]] || echo "      (a FILE --from: --into names the PARENT dir, never the file)"
fi

# .why the slash at the end is APPENDED here, unconditionally
#
#   rsync reads a trailing slash on the SOURCE as "copy the contents", and its
#   absence as "copy the directory itself INTO the target". only the first
#   matches this skill's guarantee, so the slash is not the caller's to choose
#   — it is fixed by the contract.
#
#   this single character is what produced `src/src/`. it is appended after
#   `${FROM%/}` above, so a caller who typed the slash and one who did not both
#   land on exactly one.
#
#   for a FILE, rsync ignores a trailing slash on a non-dir source and copies
#   it into the target dir — which is the same result the tar branch gives, so
#   one form is right for both kinds
RSYNC_SRC="$FROM"
[[ -d "$FROM" ]] && RSYNC_SRC="$FROM/"

######################################################################
# 🛑 .why a STALE file is NAMED and not deleted — measured 2026-08-13
#
#    a push ADDS and overwrites; it removes none. so a file deleted from the
#    checkout lives on the grove forever, and the tree under proof no longer
#    matches the tree in git — silently, with `cowabunga!` on every push.
#
#    the cost: the `4.2.ptyxis` bundle was deleted here, pushed twice, and stood
#    whole on both seats. every measurement after that read a tree the repo does
#    not describe (`rule.require.trust-but-verify`).
#
# 🛑 .why it runs ABOVE the mode gate
#    inside the apply branch, this report reaches the human only AFTER the
#    write — so `--mode plan`, whose whole job is to say what a push would do,
#    goes silent about the files it would leave behind.
#
#    a plan blind to the destination's strays is a plan about the source alone.
#    so the probe sits here: a plan reports and stops, an apply reports then
#    writes, and both say the same thing about the same tree.
#
# ⚠️ .why NOT `--delete`
#    this skill's own header records `--into` mis-aim as a live footgun — it
#    scattered 21 files into a repo root the same day. `--delete` turns that
#    footgun from "some strays to sweep" into "the destination is gone": one
#    wrong `--into $HOME` and rsync erases every file there that is not in
#    `src/`. a destructive default guarded by a flag nobody re-reads is not a
#    trade this skill makes.
#
# ⇒ so it REPORTS. `-n --delete` is rsync's own dry run: it names what would
#   go and removes none. the human decides, with the paths in front of them
#
# .note the `^deleting ` grep matches rsync's own output token, so the word is
#       not ours to pick (rule.forbid.gerunds — a library's wire format)
#
# ⚠️ .why `-v` is load-bear
#    without it this check can never fire: rsync emits its `deleting …` lines
#    only in verbose mode, so `-n --delete` alone prints none and STALE reads
#    empty on every box, stale or clean.
#
#    it went green against a grove with a planted stale file — caught in one
#    move by a probe that made the break on purpose
#    (`gotcha.a-check-that-cries-wolf-gets-silenced`: a check proven in one
#    direction is half proven, and the RED direction is the one that matters)
#
# .note it is SKIPPED where rsync is unavailable on either end, rather than
#       reported as clean — a probe that cannot run proves no claim, and the
#       rsync branch below names the absent end with its own fix
######################################################################
if [[ "$VIA" == "rsync" ]] \
   && command -v rsync >/dev/null 2>&1 \
   && ssh -o BatchMode=yes "$GROVE" "command -v rsync" >/dev/null 2>&1; then
  # ⚠️ stripped AT CAPTURE, never at print. `$STALE` has THREE readers below —
  #    the `-n` test, the `head -20`, and the `wc -l` — and a strip at one of
  #    three is the m.9 shape this repo keeps retired: the reader that drifts is
  #    the one nobody re-reads. one sink, at the seam where the bytes enter.
  STALE="$(rsync -avn --delete "${GROVE_BOUNDARY_EXCLUDE_ARGS[@]}" -e "ssh -o BatchMode=yes" \
    "$RSYNC_SRC" "$GROVE:$INTO/" 2>/dev/null | grep '^deleting ' | sed 's/^deleting //' \
    | __duct_strip_escapes)"

  if [[ -n "$STALE" ]]; then
    echo ""
    echo "🌙 the destination holds files this source does not:"
    printf '%s\n' "$STALE" | head -20 | sed 's|^|      |'
    [[ "$(printf '%s\n' "$STALE" | wc -l)" -gt 20 ]] && echo "      … and more"
    echo "   ⇒ a push adds and overwrites; it removes none. so these are files"
    echo "     deleted from the checkout, still live on the grove — and a proof"
    echo "     run there reads a tree this repo does not describe"
    echo "   remove them by hand, once you have read the list:"
    echo "     rhx git.grove.send $GROVE --bare --why 'sweep a stale path' \\"
    echo "       --what 'rm -rf <the path>'"
  fi
fi

if [[ "$MODE" != "apply" ]]; then
  echo ""
  echo "🐢 heres the wave — run with --mode apply to push"
  exit 0
fi

######################################################################
# ⚠️ `$INTO` is base64'd into the remote command, because ssh takes NO ARGV
#    it joins its arguments into one string and hands that to a login shell, so
#    `$INTO` is CODE on the far side, and single quotes around it are closed by
#    one single quote in the path. base64's alphabet is `[A-Za-z0-9+/=]` and
#    holds no shell metacharacter, so they cannot be
#    (`src/ductwork.sh`'s `__duct_ssh_tmux` carries the reason in full).
#
#    ⇒ `--into` is local argv today, so this is the cheap half of the class
#      rather than a live hole. it is closed anyway: a guarantee that holds
#      only while one caller stays local is one nobody can audit, and `$INTO`
#      reaches TWO remote commands here — this one and the tar extract below
######################################################################
INTO_B64="$(printf '%s' "$INTO" | base64 | tr -d '\n')"
# 🛑 `_grove_ssh_sunk`, never a bare `ssh` — this relays a grove's bytes to a
#    terminal that OBEYS them, and no verb of ours has to ask for them: a
#    `Banner`, an `/etc/ssh/sshrc`, a `~/.zshenv`, or the `mkdir` it serves.
#    the stale-path report above sank the names it PRINTS and left this raw
#    (`git.grove.operations.sh` carries the measurement and both carriers)
if ! _grove_ssh_sunk -o BatchMode=yes "$GROVE" "mkdir -p -- \"\$(printf %s '$INTO_B64' | base64 -d)\""; then
  echo "💥 could not make the remote dir '$INTO' on $GROVE" >&2
  echo "   fix: confirm the grove is awake and trusted —" >&2
  echo "     rhx git.grove.wake $GROVE --mode apply" >&2
  echo "     rhx git.grove.trust.gen --grove $GROVE" >&2
  exit 1
fi

######################################################################
# .why NO SILENT FALLBACK — the caller opts in, or the push fails loud
#
#   settled 2026-07-29 (the human):
#     > could we have that grove push not fallback but recommend that the caller
#     > uses an explicit opt into tar transport instead of rsync which is the default?
#
#   an auto-fallback — rsync, then tar on ANY failure — hides the layout
#   divergence. the caller cannot tell which carrier ran, so the two disagree
#   for months and every push still prints `cowabunga!`.
#
#   worse, it conflates two unrelated failures under one recovery:
#     - rsync is ABSENT on an end        → a legitimate reason to want tar
#     - rsync RAN and failed             → a real error (bad path, full disk,
#                                          refused key) that tar will not fix and
#                                          will merely obscure
#
#   so: rsync is the default, since it is the main case (delta transfer on the
#   iterate loop). where it cannot run, this FAILS and names `--via tar` as the
#   fix. the caller chooses the carrier; the skill never chooses one behind them.
#
#   (rule.require.errors-name-the-fix; and rule.forbid.failhide — an auto-fallback
#   that hides a real rsync error is a failhide with a green report)
######################################################################
if [[ "$VIA" != "rsync" && "$VIA" != "tar" ]]; then
  echo "✋ --via must be 'rsync' or 'tar' (got '$VIA')" >&2
  echo "   ├─ rsync  delta transfer; only changed bytes cross (default)" >&2
  echo "   └─ tar    needs only tar on the far end; re-sends the whole tree" >&2
  exit 2
fi

PUSHED_VIA=""

######################################################################
# transport — rsync. the default: only changed bytes cross the wire
######################################################################
if [[ "$VIA" == "rsync" ]]; then
  # both ends must have it. name WHICH end is absent, so the fix is one move
  HAVE_RSYNC_HERE=1; HAVE_RSYNC_THERE=1
  command -v rsync &>/dev/null || HAVE_RSYNC_HERE=0
  ssh -o BatchMode=yes "$GROVE" "command -v rsync" >/dev/null 2>&1 || HAVE_RSYNC_THERE=0

  if [[ "$HAVE_RSYNC_HERE" == 0 || "$HAVE_RSYNC_THERE" == 0 ]]; then
    echo "✋ rsync is unavailable, so the default transport cannot run" >&2
    [[ "$HAVE_RSYNC_HERE"  == 0 ]] && echo "   ├─ absent HERE (this machine)" >&2
    [[ "$HAVE_RSYNC_THERE" == 0 ]] && echo "   ├─ absent THERE (on $GROVE) — normal on a grove mid-bootstrap" >&2
    echo "   └─ fix: opt into the tar transport, which needs only tar —" >&2
    echo "        rhx git.grove.push $GROVE --from $FROM --into $INTO --via tar --mode apply" >&2
    exit 2
  fi

  # RSYNC_SRC is derived above the mode gate — the stale report needs it too.
  # see that block for why the trailing slash is fixed by the contract

  # see GROVE_BOUNDARY_EXCLUDES (git.grove.operations.sh) for what never
  # crosses, in either direction, and why

  # .why a real rsync failure is NOT swallowed into a tar attempt: rsync that RAN
  #      and failed means a bad path, a full disk, a refused key — a tar retry
  #      would not fix any of those, and would report success for a push that had
  #      a real error (rule.forbid.failhide). so this exits on rsync's own code
  # 🛑 `_grove_err_sunk`, because rsync relays the REMOTE rsync's messages onto
  #    this stderr — and those carry grove-chosen PATH NAMES.
  #
  # ✔ .stdout is left alone, and MEASURED rather than assumed — 2026-09-01,
  #    rsync 3.2.7, against a tree that held a filename with a real OSC 52:
  #
  #      | flags               | stdout                                  |
  #      |---------------------|-----------------------------------------|
  #      | `-az`  (ships here) | 0 bytes                                 |
  #      | `-az --no-links`    | 45 bytes — a skip notice, and it NAMES   |
  #      |                     |   the file it refused                   |
  #      | `-az -v`            | 189 bytes — one line per file           |
  #
  #    ⚠️ the sentence here read *"a sink would buy no safety"* as settled fact
  #      until that run, while `git.grove.pull` recorded the SAME property as
  #      explicitly unmeasured. one fact, two holders, opposite epistemic
  #      status — and the confident copy is the one a later author cites
  #      (`gotcha.my-own-note-became-my-evidence`).
  #
  #    ⇒ the claim survived, and its REASON did not. row 1 is why stdout is
  #      quiet HERE: no flag on this call asks rsync to name a file. row 2 is
  #      the pull's shape, and it names one — so the property belongs to the
  #      FLAGS, never to rsync's stdout as such.
  #
  # ⚠️ so a `-v`, a `--progress`, or a `--no-links` added to THIS line puts
  #    grove-chosen names on an unsunk stream. the safety is a property of the
  #    argument list, and it expires the moment somebody widens it.
  if ! _grove_err_sunk rsync -az "${GROVE_BOUNDARY_EXCLUDE_ARGS[@]}" -e "ssh -o BatchMode=yes" \
       "$RSYNC_SRC" "$GROVE:$INTO/"; then
    echo "💥 rsync ran and failed — this is NOT an rsync-availability problem" >&2
    echo "   ├─ read rsync's own error above; a tar retry would not fix it" >&2
    echo "   └─ if you believe the transport is at fault, opt in explicitly —" >&2
    echo "        rhx git.grove.push $GROVE --from $FROM --into $INTO --via tar --mode apply" >&2
    exit 1
  fi
  PUSHED_VIA="rsync"
fi

######################################################################
# transport — tar. opt-in only: needs just tar on the far end
######################################################################
if [[ "$VIA" == "tar" ]]; then
  # .why the dir/file split, and why --strip-components is NOT a constant
  #
  #   a DIR `src` tars as `src/…` — two or more path components — so stripping
  #   one leaves the contents, which is the guarantee.
  #
  #   a FILE `foo.sh` tars as exactly one component. `--strip-components=1` would
  #   strip that only component and extract NOUGHT, while still exiting 0 — a
  #   silent no-op push reported as success (rule.forbid.failhide)
  TAR_STRIP=0
  [[ -d "$FROM" ]] && TAR_STRIP=1
  # the same exclusions the rsync branch applies — the two carriers owe one result
  # 🛑 `_grove_ssh_sunk` — the remote `tar -x` names every member it refuses, and
  #    those names are the grove's. stdin still carries the archive: the helper
  #    redirects fd 2 only, so the tar stream reaches ssh untouched
  if ! tar -czf - "${GROVE_BOUNDARY_EXCLUDE_ARGS[@]}" \
       -C "$(dirname "$FROM")" "$(basename "$FROM")" \
       | _grove_ssh_sunk -o BatchMode=yes "$GROVE" "tar -xzf - --strip-components=$TAR_STRIP -C \"\$(printf %s '$INTO_B64' | base64 -d)\""; then
    echo "💥 the tar transport failed to carry '$FROM' to $GROVE:$INTO" >&2
    echo "   fix: confirm tar is on the grove —" >&2
    echo "     rhx git.grove.send $GROVE --what 'command -v tar'" >&2
    exit 1
  fi
  PUSHED_VIA="tar"
fi

# a carrier that neither branch set means the --via guard above let a third value
# through. name it rather than report a push that never happened
if [[ -z "$PUSHED_VIA" ]]; then
  echo "💥 no transport ran — '--via $VIA' matched no branch" >&2
  echo "   └─ fix: --via rsync (default) or --via tar" >&2
  exit 1
fi

echo ""
echo "🐢 cowabunga! pushed to $GROVE (via $PUSHED_VIA)"
# ⚠️ a FILE has no "contents", so one shared sentence describes a push that
#    never happened: `contents of .temp/probe.test.ts are now at …/utils/` sends
#    the reader to look for a DIRECTORY of that name. the transports are correct;
#    the report was the defect (measured 2026-08-12)
if [[ -d "$FROM" ]]; then
  echo "   └─ contents of $FROM/ are now at $GROVE:$INTO/"
else
  echo "   └─ $FROM is now at $GROVE:$INTO/$(basename "$FROM")"
fi
