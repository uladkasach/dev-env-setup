#!/usr/bin/env bash
######################################################################
# git.grove.operations — the shared transport every grove READ rides on
#
# .what = the operations that ask a grove a question and get THAT question's
#         answer back, plus the tallies that read the answer as a number.
#
# .why a shared file = these carry the two most expensive lessons this repo has
#         paid for, and both are invisible in the code that calls them:
#
#           1. a duct returns the SEND's verdict, never the command's
#           2. the right remote shell FLIPS once `2.5.zsh` lands
#
#         a second copy of either takes the next fix in one place and leaves the
#         other stale (`rule.forbid.two-writers-on-one-artifact`). they left
#         `git.grove.ready.verify` on 2026-08-12, when `git.grove.provision test`
#         came to need the same transport.
#
# .how to use = source it; set no variable first. every operation takes its seat
#         as an argument, so this file holds no state of its own:
#
#           source "$(dirname "${BASH_SOURCE[0]}")/git.grove.operations.sh"
#           out=$(_ask_at "$GROVE" 'command -v tmux')
#
# .safety = READ-ONLY, all of it. every operation here observes; none mutates.
#         a caller that must WRITE sends its own command — and says why.
######################################################################

######################################################################
# 🛑 ductwork comes along, because `__duct_strip_escapes` must reach every
#    consumer of this file
#
# .why = every skill that sources this one relays GROVE-CHOSEN bytes to a
#        terminal somewhere, and a terminal OBEYS them. the sink that strips
#        them lives in `src/ductwork.sh`, and the skills that call it directly
#        (`git.grove.send`, `git.grove.play.await`) each reach it their own way.
#        the ones that source THIS file had no route to it at all.
#
#        ⇒ an absent sink is not a quiet degrade: `set -o pipefail` turns a
#          `| __duct_strip_escapes` into a 127, so a caller that forgot would
#          fail loudly at the worst moment. one source line here gives the whole
#          family the sink, rather than four files that each remember
#          (`rule.forbid.two-writers-on-one-artifact`, the same reason the
#          transport itself moved into this file).
#
# ⚠️ the CHECKOUT's copy, never `~/.bash_aliases.ductwork.sh`. a skill in this
#    tree is judged against this tree — an installed copy may be an older
#    revision, and then the sink a reader audits is not the sink that ran.
######################################################################
if ! command -v __duct_strip_escapes >/dev/null 2>&1; then
  _grove_ops_ductwork="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)/src/ductwork.sh"
  if [[ -r "$_grove_ops_ductwork" ]]; then
    # shellcheck disable=SC1090
    source "$_grove_ops_ductwork"
  else
    echo "✋ ductwork is absent from this checkout, so grove bytes cannot be stripped" >&2
    echo "   looked at: $_grove_ops_ductwork" >&2
    echo "   ⇒ it owns __duct_strip_escapes, the one sink between a grove's" >&2
    echo "     stdout and a terminal that OBEYS what it is sent" >&2
    exit 1
  fi
fi

######################################################################
# 🛑 the send's path, resolved ONCE and asserted at SOURCE time
#
# .why here and not inline in `_ask_at`: an unresolvable path found at the
#      moment of a remote read is a fault raised in the middle of a ladder,
#      where a caller has already reported rungs. resolved here, an absent
#      send halts before the first rung speaks.
#
# ⚠️ `BASH_SOURCE[0]` at file scope names THIS file, so the send sits beside
#    it. resolve at source time — inside a function `BASH_SOURCE[0]` still
#    names this file, but the resolution would then run once per call for a
#    value that cannot change.
#
# .why the CHECKOUT's copy: the same reason the sink above takes it — a skill
#      in this tree is judged against this tree
#      (`rule.require.repo-as-source-of-truth`)
######################################################################
_grove_ops_send="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)/git.grove.send.sh"
if [[ ! -r "$_grove_ops_send" ]]; then
  echo "✋ git.grove.send is absent from this checkout, so no seat can be asked" >&2
  echo "   looked at: $_grove_ops_send" >&2
  echo "   ⇒ every remote read in this family goes through it, and it is" >&2
  echo "     invoked as an executable so its stdout is the command's alone" >&2
  exit 1
fi

######################################################################
# 🛑 _grove_ssh_sunk / _grove_err_sunk — the sink APPLIED, not merely reachable
#
# .what = run a command whose streams a grove chose, with `__duct_strip_escapes`
#         between those streams and the terminal. two shapes, because stdout is
#         not always text:
#
#           _grove_ssh_sunk  <ssh args…>   both streams sunk; stdout must be TEXT
#           _grove_err_sunk  <command…>    stdout UNTOUCHED; only stderr sunk
#
# 📜 .measured 2026-09-01 — the block above made the sink REACHABLE, and four
#      calls that reach a grove never reached it:
#
#        git.grove.push:532  the remote `mkdir -p`         both streams raw
#        git.grove.push:601  the rsync apply               both streams raw
#        git.grove.push:629  the remote `tar -xzf -`       both streams raw
#        git.grove.pull:236  the tar-branch archive read   stderr raw
#
#      each file's header claimed the sink for itself — *"stripped AT CAPTURE,
#      never at print … one sink, at the seam where the bytes enter"* — and each
#      applied it to its REFUSAL texts alone (rsync's stale-path list, the tar
#      member at fault). those are the paths a reader looks at, because they are
#      the paths the comment is about.
#
# ⚠️ .this is round 12's shape at the transport
#      *a guard that names ONE hazard immunizes the others.* the named hazard —
#      a grove-chosen FILENAME echoed back in a refusal — was handled carefully,
#      at length, correctly. the unnamed twin is the same grove's bytes on the
#      SAME ssh channel with no verb of ours involved: a `Banner`, an
#      `/etc/ssh/sshrc`, a `~/.zshenv`, or the `mkdir` it serves. ssh forwards
#      that half byte-for-byte (`SSH_MSG_CHANNEL_EXTENDED_DATA`).
#
#      `git.grove.send:466-472` had already MEASURED this exact twin on
#      2026-08-31 and repaired it in that one file. so the lesson existed, in
#      this family, and did not reach the two carriers (m.9 at the idiom level).
#
# 🛑 .NO `trap … EXIT` here, and that is deliberate
#      `git.grove.send` uses one and is right to: it is its own process, where
#      the trap table is its own. THIS file is SOURCED, so a trap set in a
#      function is the CALLER's EXIT trap — it would silently replace whatever
#      the caller had. the scratch file is removed inline instead, and the
#      residue is a leftover in `$TMPDIR` if a Ctrl-C lands mid-ssh: benign,
#      where a clobbered trap is not.
#
# ⚠️ .why a scratch FILE and not `2> >(__duct_strip_escapes >&2)`
#      a process substitution is asynchronous, so the evidence reaches the
#      terminal on some runs and vanishes on others. a strip honored most of the
#      time is not one (`gotcha.a-check-that-cries-wolf-gets-silenced`).
######################################################################
_grove_err_sunk() {   # $@ = the command. stdout UNTOUCHED — for a BINARY stdout.
  local err rc=0
  err="$(mktemp "${TMPDIR:-/tmp}/grove.err.XXXXXX")" || {
    echo "💥 could not open a scratch file for stderr — the command was NOT run" >&2
    return 1
  }
  "$@" 2>"$err" || rc=$?

  # 🛑 the sink's failure is LOUD and does NOT become this function's code
  #    `_grove_err_sunk` promises the COMMAND's exit code, and a caller branches
  #    on it. to raise it because the RELAY broke would report a push that
  #    worked as a push that failed — a false ✋ over correct work.
  #    ⇒ so `_grove_relay_sunk` shouts on stderr and its status is deliberately
  #      not merged here. the `|| :` says that on purpose, rather than by an
  #      omission a later reader would take for an oversight.
  _grove_relay_sunk "$err" || :

  rm -f "$err"
  return "$rc"
}

######################################################################
# .what = relay a captured stderr file THROUGH the sink, and say so if the
#         sink itself could not run
#
# 🛑 .why this is a function and not two inline lines
#      it was two inline lines, in two callers, and BOTH discarded the sink's
#      exit code — so `__duct_strip_escapes`' own promise of *"a non-zero exit
#      for every caller"* was false at the only two callers that mattered.
#      one guarantee, two hand-written consumers, and each drifted the same way
#      (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9).
#
# ⚠️ .the SAFETY half never depended on this — measured 2026-09-01
#      an absent stage makes the sink emit ZERO bytes, so a stream is dropped
#      rather than relayed unstripped. what was lost was the SIGNAL: a caller
#      was told the strip had succeeded when the sink had not run at all. that
#      is why it survived every spot-check — the dangerous half was fine.
######################################################################
_grove_relay_sunk() {   # $1 = a file that holds captured stderr
  local err="$1"
  [[ -s "$err" ]] || return 0
  __duct_strip_escapes < "$err" >&2 && return 0
  echo "💥 the escape sink could not run — the text above is INCOMPLETE" >&2
  echo "   ├─ a stage of __duct_strip_escapes is absent (iconv is glibc)" >&2
  echo "   └─ ⚠️ no unstripped byte reached you: an absent stage DROPS the" >&2
  echo "        stream. what is lost is the message, never the guarantee" >&2
  return 1
}

_grove_ssh_sunk() {   # $@ = ssh args. BOTH streams sunk; stdout must be TEXT.
  local err rc=0
  err="$(mktemp "${TMPDIR:-/tmp}/grove.err.XXXXXX")" || {
    echo "💥 could not open a scratch file for ssh's stderr — ssh was NOT run" >&2
    return 1
  }
  # ⚠️ the code must be SSH's, never the sink's. the sink returns 0 on every
  #    input it can read, so `$?` alone would report success for a refused ssh
  ssh "$@" 2>"$err" | __duct_strip_escapes
  rc="${PIPESTATUS[0]}"

  # ⚠️ the STDOUT sink's own status is in `${PIPESTATUS[1]}` and is read by no
  #    line here, deliberately: the safety half needs no reading (an absent
  #    stage drops the stream), and ssh's code is what a caller branches on.
  #    the stderr relay below is where a sink failure becomes visible.
  _grove_relay_sunk "$err" || :

  rm -f "$err"
  return "$rc"
}

######################################################################
# 🛑 GROVE_BOUNDARY_EXCLUDES — what never crosses, in EITHER DIRECTION
#
# .what = the one set of tree members a grove boundary does not carry. it is
#         declared HERE, in the file both carriers of both directions source,
#         because it is ONE policy and a second copy is free to drift.
#
# 📜 .measured 2026-08-31 — it HAD two holders, and they disagreed
#       `git.grove.push` declared, at length, that `.git` NEVER crosses. it was
#       the outbound half's declaration and it read as the boundary's.
#       `git.grove.pull` carried `.git` straight back, on both carriers, and
#       named no exclusion at all — so the sentence "never crosses" was true of
#       one direction and false of the other, with no check between them (m.9).
#
# ⚠️ .why the INBOUND half is the sharper one
#       outbound, a stray `.git` is a CORRECTNESS defect: a worktree's `.git` is
#       a one-line pointer at a path that names no directory on the far side, so
#       it lands as a broken repo (the block in `git.grove.push` has the full
#       measurement, and it cost three bundles a false ✋).
#
#       inbound, the same member is CODE THE GROVE WROTE, on the box that holds
#       the real credentials. a `.git` directory is not data a local tool reads;
#       it is configuration a local tool OBEYS:
#
#         .git/config  `core.hooksPath` and `core.fsmonitor` each name a program
#                      git EXECUTES, and `[alias] x = !sh -c …` is shell any
#                      `git x` runs
#         .git/hooks/  executables git runs on commit, checkout, and merge
#
#       ⇒ and no deliberate `git` command is needed to reach them. the prompt
#         reads git state in every directory the human enters, so a `cd` into a
#         pulled tree is the whole trigger. that is the same shape as `2.5.zsh`'s
#         `chpwd` hook, where a pulled tree's config reached a package manager.
#
#       the other members carry the same inversion. `node_modules/.bin/*` are
#       executables the grove chose, on the local `npx` resolution path;
#       `.agent/.cache` is the dox hazard `.gitignore` names, inbound rather
#       than outbound.
#
# 🛑 .the BOUND on this set, stated rather than papered over
#       an exclusion is enforced by whichever side WALKS the tree, and on a pull
#       that side is the GROVE. so a flag the FAR side reads is a request, and
#       each inbound carrier therefore keeps a LOCAL enforcer beside it:
#
#         · rsync — the filter reaches the sender AND the receiver. an honest
#           grove skips; a hostile one is still filtered here, against the file
#           list it declares
#         · tar   — no `--exclude` is sent up the wire at all. the whole tree
#           comes back and the LOCAL `tar -x --exclude` skips the excluded
#           members as it writes. that costs bandwidth and buys a control
#
#       ⇒ a `--exclude` the FAR side would apply is a courtesy; the copy the
#         LOCAL side applies is the guarantee. both carriers hold that copy.
#
# 🛑 .neither inbound carrier vets member NAMES against this set
#       `_grove_boundary_excluded` below serves the OUTBOUND half alone
#       (`git.grove.push`), where this box walks its own tree and so can decide
#       per name. inbound, the guarantee is the local extractor's own flag — and
#       that suffices precisely because the extractor is ours.
#
#       ⚠️ a claim that `git.grove.pull` "vets the MEMBER NAMES it read locally,
#         before any extract" is FALSE — `_grove_boundary_excluded` has exactly
#         one caller, in push. `git.grove.pull` states the truth at its own tar
#         branch, so such a claim gives one fact two holders, and the holder no
#         reader can disprove by a glance is the one that drifts
#         (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9).
#
#       ⇒ a comment that names a FUNCTION asserts a call. grep for the caller
#         before you write one, and again before you trust one.
#
# .why a FIXED LIST and not `--filter=':- .gitignore'`
#       rsync can honor a gitignore; tar cannot. that split puts the carriers of
#       one direction back on different layouts — the very defect the carrier
#       pair exists to retire (`term=carrier`). a fixed set is one declaration
#       all four obey.
######################################################################
# 🛑 .THE TEST A MEMBER MUST FAIL TO EARN A ROW HERE
#       the paragraphs above argue `.git` from two facts, and both generalize:
#       it names a program, and NO DELIBERATE COMMAND reaches it. so the test is
#
#         does this member name a program that runs BEFORE a human can read the
#         diff that carried it?
#
#       that line, and not "is it config", is what sorts the tree:
#
#         .git/config, .git/hooks/*   ✋ the prompt reads git state on every `cd`
#         node_modules/.bin/*         ✋ on the local `npx` resolution path
#         .claude/settings.json       ✋ its hooks fire when a session OPENS here
#         .agent/**/skills/*.sh       ✔ code, but a human types `rhx <name>` first
#         src/**                      ✔ code, but `grove.provision` is deliberate
#
#       ⇒ the tracked tree is REVIEWED — a pull lands in a worktree and `git diff`
#         is the gate. the four rows above run before that gate can be reached, so
#         for them the diff arrives too late to be a control.
#
# 📜 .measured 2026-09-02 — `.claude` met this test and was absent
#       `.claude/settings.json` in this checkout declares `SessionStart`,
#       `PreToolUse`, and `Stop` hooks. `PreToolUse` is the gate every bash
#       command on this laptop passes, so a grove that writes that one file owns
#       the local agent outright, and collects at the NEXT session open — before
#       any human reads any diff. that is `.git/hooks` in a second costume, and
#       the argument written for `.git` covered it the whole time.
#
#       ⚠️ the block above named `.git`, `node_modules/.bin`, and `.agent/.cache`
#         and stopped. it read as an enumeration of the class; it was three
#         members of it (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.12 —
#         a total is true only of the set the reader could reach). ⇒ the TEST is
#         now written down above the list, so the next member is derivable rather
#         than remembered.
#
# ⚠️ .the OUTBOUND cost of `.claude`, stated rather than papered over
#       one array serves both directions, so this row also stops `.claude` on the
#       way UP, and a grove-side agent in this checkout loses the repo's hooks.
#       that cost is bounded and was measured: a grove's harness config is
#       written by `5.3.brains` into `$HOME/.claude/settings.json`, not by this
#       push — so the grove keeps a settings file either way.
#
#       ⇒ and the trade is not close. inbound, the loss is the laptop's own
#         `PreToolUse` gate, on the box that holds the real credentials. outbound,
#         the loss is a repo-level hook set on a box we already ASSUME COMPROMISED
#         (`rule.require.security-paramount`).
GROVE_BOUNDARY_EXCLUDES=(
  ".git"
  "node_modules"
  ".log"
  ".temp"
  ".agent/.cache"
  ".claude"
  ".play/temporary"
)

# every carrier here takes repeated `--exclude`, so the args are DERIVED from
# the set above rather than typed a second time. ONE array serves all four
# carriers, so they cannot drift apart by an edit to only one of them.
#
# 📜 .why NO SECOND array of four globs — measured 2026-08-31
#      the argument for one reads: "tar tests each member name on its own at
#      extract, so a pattern that matches `.git` settles no question about
#      `.git/config`" — and on that it expands each member into four globs
#      (`x`, `x/*`, `*/x`, `*/x/*`).
#
#      that argument is REFUTED by the archive it claims to describe. GNU tar
#      1.35, three arms over one archive:
#
#        arm 0 — no exclusion at all    → 7 refused members landed
#        arm 1 — the plain form         → 0 landed, 0 carried members lost
#        arm 2 — the four-glob form     → 0 landed, 0 carried members lost
#
#      arm 0 is what makes arms 1 and 2 readable: the probe was seen to catch a
#      miss before its green was read (`gotcha.a-check-that-cries-wolf-gets-
#      silenced`, `.the corollary`). `.git/config`, `sub/.git/config`, and
#      `deep/a/node_modules/pwned` were each refused by the PLAIN form.
#
#   ⇒ so the extra array buys no reach, and its comment is a false claim
#     dressed as caution. an exemption that is never needed is the shape
#     `rule.forbid.exemption-as-habit` names, and a second expansion of one
#     policy is a second artifact to keep in step for a benefit measured at zero.
GROVE_BOUNDARY_EXCLUDE_ARGS=()
for _grove_ex in "${GROVE_BOUNDARY_EXCLUDES[@]}"; do
  GROVE_BOUNDARY_EXCLUDE_ARGS+=(--exclude "$_grove_ex")
done
unset _grove_ex

######################################################################
# _grove_boundary_excluded — does this member name sit under an excluded root?
#
# .what = the LOCAL half of the policy above. a caller that reads member names
#         before it writes them (the tar carrier) asks this per member.
#
# .why  = an `--exclude` handed to the far side is a request. this is the check
#         that does not depend on the far side's good behaviour.
#
# .how  = a member is excluded when the excluded name is the whole path, or is
#         any prefix segment of it. the `./` tar often emits is dropped first,
#         so `./.git/config` and `.git/config` are one answer.
#
#   returns 0 = excluded (refuse it) · 1 = not excluded
#
# ✔ .SEEN TO DISCRIMINATE, 2026-08-31 — BOTH directions, 25 rows
#     refused: `.git`, `.git/config`, `.git/hooks/post-checkout`,
#              `./.git/config`, `sub/.git`, `sub/.git/config`,
#              `deep/a/b/.git/hooks/pre-commit`, `node_modules`,
#              `node_modules/.bin/x`, `app/node_modules/.bin/x`,
#              `.agent/.cache`, `.agent/.cache/k`, `x/.agent/.cache/k`,
#              `.log/a`, `.temp/a`
#     carried: `src/index.ts`, `.gitignore`, `a/.gitignore`,
#              `.github/workflows/ci.yml`, `git`, `my.git.notes`,
#              `node_modulesx/a`, `.agent/keyrack.yml`, `.agent/cache/k`,
#              `readme.md`
#
#   ⚠️ the CARRY half is the one that earns its keep. `.gitignore`,
#      `.github/`, and `.agent/keyrack.yml` each sit one character from a
#      refused name, so a pattern loose by one would eat them and the push's
#      preview would name a file that never crosses — a false ✋ that accuses
#      the innocent (`gotcha.a-check-that-cries-wolf-gets-silenced`).
######################################################################
_grove_boundary_excluded() {
  local member="${1#./}" ex
  for ex in "${GROVE_BOUNDARY_EXCLUDES[@]}"; do
    [[ "$member" == "$ex" || "$member" == "$ex"/* ]] && return 0
    # an excluded root may sit at any depth — a `.git` under a nested checkout
    # is the same hazard as one at the top
    [[ "$member" == */"$ex" || "$member" == */"$ex"/* ]] && return 0
  done
  return 1
}

######################################################################
# _ask_at — ask ONE seat a question, and get THAT question's answer
#
# ⚠️ NOT a plain `git.grove.send`. the duct is tmux, so a send writes the
#    command into a pane and returns the SEND's exit code — which is 0 whenever
#    the text landed, whatever the command then did with it. so this is true on
#    a healthy grove:
#
#      rhx git.grove.send <g> --what 'test -d /definitely/not/a/real/path'
#      → 🔧 sent … exit 0
#
#    and its stdout is not even empty: it is the send's own two-line banner,
#    which is worse, since an empty capture at least reads as suspicious
#    (`gotcha.the-duct-returns-the-send-not-the-answer`).
#
# ⚠️ THE `--bare` TRIGGER, named as `rule.require.exemptions-name-their-trigger`
#    demands. the two triggers `git.grove.send` ships ('no tmux yet', 'duct is
#    broken') both describe a duct that CANNOT carry the command. this is a
#    third and it differs in kind: the duct carries it perfectly and discards
#    the answer. that is fine for a drive and fatal for a read.
#
# ⚠️ AND IT RIDES A LOGIN SHELL — the second scar. `ssh host 'cmd'` is
#    non-interactive AND non-login, so it reads neither ~/.bashrc (ubuntu's
#    returns early when non-interactive) nor ~/.profile (login shells only).
#
#    a plain `ssh host 'bash …/grove.provision._.sh --mode plan'` therefore runs
#    every verify against a PATH the box never actually serves. measured on
#    grove-ahbode-v20260810, 2026-08-10, one minute apart:
#
#        ssh …            'bash …plan'   →  ✋ 18
#        ssh … 'bash -lc "bash …plan"'   →  ✋  5
#
#    thirteen of the eighteen were the CHECK's defect. the binaries sat on disk
#    the whole time — `machine_resource_*`, `usql`, `git-credential-keyrack` all
#    in ~/.local/bin, while the read called them "absent from PATH". that is the
#    false-✋ half of `gotcha.a-check-that-cries-wolf-gets-silenced`, and it cost
#    two applies against an already-converged box.
#
# .note = `printf %q` quotes the command as ONE argument, so the login shell
#    receives it whole rather than re-split on its spaces.
######################################################################
# ⚠️ .why `--reply` and never `--bare --why '…'`
#    a `--bare` here reads the duct's own defect as a reason to LEAVE the duct,
#    under a `--why` string that never varies across the repo. an exemption
#    whose justification is constant names a permanent condition, and a
#    permanent condition is an absent feature (`rule.forbid.exemption-as-habit`).
#
#    `--reply` is that feature: it sends over the duct, waits for the command to
#    finish, and returns the command's OWN stdout and OWN exit code. so this
#    helper keeps the verdict it needs AND rides the carriage that survives a
#    disconnect (`gotcha.the-duct-returns-the-send-not-the-answer`, closed).
#
# .note every caller of this reaches it at rung 4 or later, and rung 3 proves the
#    duct — so the duct is known good before a single `_ask_at` runs.
#
######################################################################
# 🛑 .why the verdict rides a MARKER, never the exit code
#
# every caller writes `if ! _ask_at "$SEAT" 'test -f …'; then halt "…absent…"`,
# so a falsy return reads as a FACT ABOUT THE BOX. that read is sound only if a
# falsy return can mean one thing. it can mean two:
#
#   · the command ran, and answered false          — a fact about the box
#   · the command NEVER RAN                        — a fact about the transport
#
# ⚠️ .measured 2026-08-13, and it cost a full false halt
#    a duct is tmux, and a send is a keystroke into ONE pane — so a duct already
#    occupied by another job REFUSES the send outright, before the command
#    exists. `git.grove.send` says so plainly and exits non-zero:
#
#      ✋ duct.send: '…' is BUSY — 'run.bun.rhachet-run.bc' holds the pane
#      ✋ the duct refused the send, so the command never ran
#
#    every caller swallowed that with `>/dev/null 2>&1` and reported:
#
#      ✋ seat '…' holds src/ but no package.json beside it
#      fix: rhx git.grove.push … --from package.json …
#
#    the file sat there the whole time — 610 bytes, listed on that same box one
#    command later. so the ladder halted a READY grove, named a wrong fix, and
#    would send a human to push a file already present
#    (`gotcha.a-check-that-cries-wolf-gets-silenced`, the false-✋ half).
#
# ⇒ so `git.grove.send --reply` reserves exit **97** for "no verdict" — every
#   transport fault it has, under one code no command returns. this reads 97 as
#   a fault and halts loudly, never as a falsy answer about a box nobody asked
#   (`rule.forbid.failhide`).
#
# ⚠️ .why a reserved CODE, and not a marker in the command
#    a wrap like `{ cmd ; } && echo __TRUE__ || echo __FALSE__` cannot work:
#    `--what` takes ONE step, and `git.grove.send`'s own guard refuses any `;`,
#    `&&`, or `||` in its raw text. to encode past that guard defeats a control
#    that exists because the pretooluse hooks read only the outer command.
#
#    ⇒ and the knowledge was never this function's to rebuild. the SEND already
#      knew — it checks its own delivery. it had no way to say so
#      (`rule.require.solve-at-cause`).
#
# ⚠️ .why 97 is OURS and not a read of the send's refusal text
#    the cheaper fix is to grep the refusal message for 'BUSY'. that makes this
#    check depend on ANOTHER component's output FORMAT — an invisible dependency
#    that appears in no argument and breaks silently the day that sentence
#    moves. the same shape broke the idempotency play when an output pad shifted
#    its subject's indent (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.2).
#    an exit code is a declared contract; a sentence is not.
#
# .why `--await` as well, and not only the marker
#    the marker turns a lie into a loud fault, which is a strict improvement and
#    still a halt. `--await` removes the common cause entirely: a pane busy with
#    a job that will finish is simply waited for. the two are complementary —
#    one prevents the fault, the other refuses to misreport it.
######################################################################
_ask_at() {
  local seat="$1" cmd="$2"

  ####################################################################
  # 🛑 `_shell_at` is resolved into a VARIABLE first, and its fault is re-raised
  #
  # ⚠️ inline — `--what "$(_shell_at "$seat") …"` — silently disarms its fault.
  #    `_shell_at` exits 3 when it cannot learn a seat's shell, and inside `$( )`
  #    that exit kills only the SUBSHELL: the substitution yields an empty string
  #    and `_ask_at` carries on to send a command with no shell in front of it.
  #
  #    .measured 2026-08-13 by `prove.duct-contention-faults`, on its first run
  #         against this fix: rows 1 and 2 printed `_shell_at`'s whole fault
  #         block, then reported ✔. a helper written to halt printed its halt,
  #         and the caller returned an answer anyway.
  #
  # ⇒ the general trap: `$(…)` converts an `exit` into a discarded status. a
  #   function that halts is only a halt where its caller reads the status back
  #   (`rule.forbid.failhide`)
  ####################################################################
  local shell
  shell="$(_shell_at "$seat")" || exit 3
  [[ -n "$shell" ]] || exit 3

  ####################################################################
  # ⚠️ `|| rc=$?` and NOT `|| true`, and the difference is the whole feature
  #
  #    `out="$(…)"` under `set -e` would abort this function on any non-zero
  #    reply — including a perfectly good `test -f` that answered false. so the
  #    substitution is allowed to fail, and `$?` is read in the SAME statement,
  #    which is the only place the code still exists. a `|| true` would discard
  #    it and leave this function unable to tell 1 from 97 — the very defect
  ####################################################################
  ####################################################################
  # 🛑 the send is invoked as an EXECUTABLE, never through `rhx` — because
  #    `rhx` writes its own banner to STDOUT
  #
  #    measured 2026-09-02:
  #
  #        $ rhx duct.list | cat -v
  #        M-pM-^_M-*M-( run solid skill repo=.this/role=any/skill=duct.list
  #        (blank)
  #        …
  #
  #    so through `rhx` every `_ask_at` answer arrives with two lines of
  #    decoration in front of it, and `:494`'s claim below — *"handed on
  #    untouched"* — is false.
  #
  # .the cost, measured
  #    `git.grove.provision.boot:390` holds an arm for the third `--reply`
  #    state: a payload that is empty while the rc is 0. its own evidence says
  #    *"`tail` was empty on ~1350 polls"*, a 2700s burn against a converged
  #    box. with a banner always present, `[[ -z "${tail//[[:space:]]/}" ]]` is
  #    UNREACHABLE — the arm written to end that burn could never fire, so the
  #    burn would recur verbatim.
  #
  # ⚠️ `rhx` is OUTSIDE this repo, so its banner is not ours to move. what IS
  #    ours is which entrypoint we call. the file is the same code with one
  #    fewer wrapper, and `git.grove.push.verify:39` reaches it this way too.
  #
  # 🛑 do NOT close this by a strip keyed on the banner's TEXT. that is the m.2
  #    shape `:443-449` already forbids by name, three paragraphs up.
  ####################################################################
  local out rc=0
  out="$(bash "$_grove_ops_send" "$seat" --reply --await "${GROVE_ASK_AWAIT:-900}" \
    --what "$shell $(printf '%q' "$cmd")")" || rc=$?

  # the command's OWN stdout, handed on untouched — there is no marker to strip
  if [[ -n "$out" ]]; then
    printf '%s\n' "$out"
  fi

  # 97 is the send's reserved "no verdict" code; anything else IS the answer
  if [[ "$rc" -ne 97 ]]; then
    return "$rc"
  fi

  ####################################################################
  # 🛑 exit 97 — the command never ran, so there is no answer to give
  #
  # this must not return, at all. a `return 1` here is the exact defect above,
  # and a `return 0` would be a false ✔. the only honest move is to stop and
  # say the transport failed, because every LATER probe in this run would be
  # just as unfounded (`rule.require.solve-at-cause` — one cause, not N claims)
  ####################################################################
  echo ""
  echo "  ✋ the probe never ran on '$seat', so this run can judge no rung"
  echo ""
  echo "  why: a duct is tmux, and a send is a keystroke into ONE pane. a pane"
  echo "       another job already holds refuses the send outright — so the"
  echo "       command was never delivered, and its absence of an answer is a"
  echo "       fact about the DUCT rather than about the box."
  echo ""
  echo "       it waited ${GROVE_ASK_AWAIT:-900}s for the pane and it did not free."
  echo ""
  echo "  ⚠️ an unanswered probe is NOT 'the file is absent' — read that way, a"
  echo "     halt names a push for a file that is already there."
  echo ""
  echo "  the command it tried to send —"
  echo "    $cmd"
  echo ""
  echo "  fix: see what holds the pane, then run this again —"
  echo "    rhx git.grove.read $seat --lines 40"
  echo "    rhx duct.list"
  echo ""
  echo "  ⇒ the usual cause is a SECOND grove read still in flight. a"
  echo "    backgrounded verify and a foreground one contend for one pane, and"
  echo "    the foreground one is the one that reports the fault."
  exit 3
}

######################################################################
# _shell_at — the remote shell that actually serves THIS seat's PATH
#
# ⚠️ there is no single right answer, and a fixed choice is wrong on half the
#    boxes a grove read exists to judge. the flip is `2.5.zsh`:
#
#    | seat state          | ~/.bash_profile | `bash -lc` reads | rhx on PATH? |
#    |---------------------|-----------------|------------------|--------------|
#    | before 2.5.zsh      | absent          | ~/.profile       | yes          |
#    | after  2.5.zsh      | execs zsh       | .zshenv only     | NO           |
#
#    after `2.5.zsh` lands, `~/.bash_profile` execs zsh — and the zsh it execs
#    is NON-interactive, so `.zshenv` loads and `.zshrc` does not. `.zshrc` is
#    where pnpm's shim dir joins PATH, so `rhx` vanishes from a `bash -lc` on
#    exactly the boxes that are most converged.
#
#    measured on grove-ahbode-v20260810, 2026-08-10, on a box whose suite
#    tallies 31 passed when asked through an interactive zsh:
#
#        --what 'bash -lc env -C …/svc-chat rhx git.repo.test …'
#        → env: 'rhx': No such file or directory
#
#    ⇒ the suite rung then reported `passed: 0` and halted with "it did not
#      run" — a false ✋ against a READY box, whose cause was entirely in the
#      transport this operation chooses (`gotcha.bash-lc-becomes-a-half-zsh`).
#
# ⚠️ the probe asks for `~/.zshrc`, never for the zsh BINARY. the binary ships
#    on a stock ubuntu image long before this repo configures anything, so its
#    presence says only that zsh COULD run — never that this seat's PATH is
#    served by it. `.zshrc` is the artifact `2.5.zsh` writes, and it is
#    per-seat, which is why this is keyed by seat rather than by box.
#
# ⚠️ AND THE SEATS DISAGREE ON ONE BOX. measured 2026-08-12: `2.5.zsh` runs
#    `sudo chsh`, so the seat WITH sudo gets a zsh record and the seat without
#    keeps bash — on the same machine, in the same run:
#
#        ground:  …:/usr/bin/zsh     ← chsh succeeded
#        camper:  …:/bin/bash        ← refused; no sudo on this seat
#
#    so a per-BOX answer would be wrong for one of them, always.
#
# .note = memoized per seat, so a caller that asks seven questions pays for
#    this probe once per seat rather than once per read.
#
######################################################################
# 🛑 .why this probe reads the SAME reserved 97 as `_ask_at`, and needs it MORE
#
# a plain `if rhx git.grove.send … >/dev/null 2>&1; then zsh else bash` drops a
# REFUSED send — a pane another job holds — into the `else`, and answers
# `bash -lc`.
#
# ⚠️ that beats the `_ask_at` defect for harm, in two ways:
#
#    1. it is not a wrong answer to one question; it is the WRONG TRANSPORT for
#       every question that follows. and `bash -lc` on a converged box loses
#       `rhx` entirely — which is the precise cause of the false ✋ recorded
#       above (`gotcha.bash-lc-becomes-a-half-zsh`).
#
#    2. it MEMOIZES. one refused probe pins `bash -lc` for the rest of the run,
#       so the damage outlives the contention that caused it and every later
#       read is degraded by a pane that has since freed.
#
# ⇒ so a refusal must be told apart from a real `test -f` failure, and it is
#   told apart the same way `_ask_at` does it: 97 ⇒ it never ran ⇒ fault, and
#   the memo is left unset. 0 and 1 are the two real answers, and both memoize.
#
# .note it cannot call `_ask_at` for this — `_ask_at` calls THIS to choose its
#    shell, so the two would recurse. the probe stays shell-agnostic (a bare
#    `test -f`, no login shell at all), which is what makes that safe.
######################################################################
_shell_at() {
  local seat="$1"
  local var="_SHELL_${seat//[^a-zA-Z0-9]/_}"
  local memo="${!var-}"
  if [[ -z "$memo" ]]; then
    # ⚠️ the same executable `_ask_at` calls, and for a second reason beside
    #    its stdout: this probe's whole contract is that 97 arrives EXACTLY.
    #    a wrapper is one more component free to remap an exit code, and a
    #    97 that arrived as anything else would land in the `*)` arm and
    #    memoize `bash -lc` — the precise harm the block above names. two
    #    readers of one transport are free to drift; one entrypoint cannot
    local rc=0
    bash "$_grove_ops_send" "$seat" --reply --await "${GROVE_ASK_AWAIT:-900}" \
      --what 'test -f $HOME/.zshrc' >/dev/null 2>&1 || rc=$?

    case "$rc" in
      0)  memo='zsh -ic' ;;
      97) memo='' ;;      # falls into the fault block below
      *)  memo='bash -lc' ;;
    esac

    if [[ -z "$memo" ]]; then
        ##############################################################
        # 🛑 97 — the probe never ran, so this seat's shell is UNKNOWN.
        #    to guess `bash -lc` here is what caused a converged box's suite to
        #    report `passed: 0`, and to memoize that guess would carry it
        #    through the whole run (`rule.forbid.failhide`)
        ##############################################################
        echo "" >&2
        echo "  ✋ could not learn which shell serves '$seat' — the probe never ran" >&2
        echo "" >&2
        echo "  why: a duct is tmux, and a pane another job holds refuses the" >&2
        echo "       send outright. it waited ${GROVE_ASK_AWAIT:-900}s and the pane" >&2
        echo "       did not free." >&2
        echo "" >&2
        echo "  ⚠️ there is NO fallback to 'bash -lc': on a CONVERGED box it" >&2
        echo "     serves no rhx at all, so the suite rung would report" >&2
        echo "     'passed: 0' against a healthy grove, and the guess would be" >&2
        echo "     cached for the rest of the run." >&2
        echo "" >&2
        echo "  fix: see what holds the pane, then run this again —" >&2
        echo "    rhx git.grove.read $seat --lines 40" >&2
        echo "    rhx duct.list" >&2
        exit 3
    fi

    printf -v "$var" '%s' "$memo"
  fi
  printf '%s' "$memo"
}

######################################################################
# _count — count matches in a file, always as ONE integer
#
# .why  = ⚠️ this was a FALSE ✔ on the ready ladder's own first climb, and it is
#         the exact shape `rule.forbid.failhide` names. `grep -c` prints `0` and
#         exits 1 when it matches none, so the obvious `|| echo 0` appends a
#         SECOND zero. the capture is then `0\n0`, which is not a number — so
#         `[[ "$n" -eq 0 ]]` does not read false, it ERRORS. bash treats an
#         errored `[[ ]]` as false, the guard stands down, and the caller prints
#         its success line on evidence it never read.
#
#         the tell was in the output the whole time: the count printed across
#         two lines. a malformed number is visible; the disarmed guard is not.
######################################################################
_count() {
  local n
  n=$(grep -c "$1" "$2" 2>/dev/null || true)
  echo "${n:-0}"
}

######################################################################
# _count_claims — count the ✋ lines a bundle-tree plan raised as CLAIMS, excluding
#                 the runner's closing summary, which wears the same glyph
#
# .why  = `✋ grove.provision finished with failures` is a TOTAL, not a finding,
#         so to count it inflates every failing seat by exactly one and makes
#         the number disagree with the list a reader can see right above it
#         (`gotcha.a-check-that-cries-wolf-gets-silenced`, measurement 1).
#
# 🛑 .the glyph marks THREE kinds of line, not two — measured 2026-08-25
#         the name exclusion above settles the SUMMARY. a third kind was found
#         on a from-scratch grove, and it is the glyph used as PROSE inside
#         another claim's fix-text:
#
#           ✋ gh is present but unauthed                    ← a CLAIM
#           fix: bash … --what 5.4.gh --mode apply
#                its ✋ names the exact 'rhx keyrack set' …  ← PROSE about a claim
#
#         rung 4 reported `✋ 6` for a seat whose log holds exactly 5 claims —
#         the same one-off this function exists to prevent, arrived at from a
#         direction the name exclusion cannot see.
#
# ⇒ .the discriminator is POSITION, and it costs one anchor
#         a claim's glyph opens its line; a prose mention sits mid-sentence. so
#         `^[[:space:]]*✋` admits every claim and every summary, and admits no
#         fix-text — and the name exclusion still removes the summary.
#
#         a pattern over the WORDS would have to grow a row per fix-text that
#         mentions the glyph, which is a second list of a fact the layout
#         already carries (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.12).
#
# ⚠️ .why this is worth a fix though the VERDICT was right
#         the halt was correct — 5 claims is not 0, so rung 4 held its ground
#         either way. what was wrong is the NUMBER printed beside the list, and
#         this function's own `.why` names that as the whole point: the count
#         must not "disagree with the list a reader can see right above it".
#         a tally a reader can refute by eye is how a check loses its authority.
#
# .note = same `|| true` / `${n:-0}` care as `_count`, for the same reason.
######################################################################
_count_claims() {
  local n
  n=$(grep -E '^[[:space:]]*✋' "$1" 2>/dev/null | grep -vc 'grove.provision finished' || true)
  echo "${n:-0}"
}

######################################################################
# _tally — read the LAST `<n> <word>` tally a suite printed, as one integer
#
# .why  = a jest run restates its counts per-suite and then once in a summary;
#         the last is the total. same one-integer guarantee as `_count`, for the
#         same reason.
######################################################################
_tally() {
  local n
  n=$(grep -oE "[0-9]+ $1" "$2" 2>/dev/null | tail -1 | grep -oE '[0-9]+' || true)
  echo "${n:-0}"
}
