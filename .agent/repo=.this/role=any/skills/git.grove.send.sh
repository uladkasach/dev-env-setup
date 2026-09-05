#!/usr/bin/env bash
######################################################################
# .what = rhx dispatch to the global `git grove send` bash command
#
# .why  = one allowlistable surface (rhx git.grove.send) lets agents run a
#         command in a grove's duct. the inner ssh rides inside ductwork,
#         invisible to the permission hook — so an agent drives a grove with
#         no raw ssh prompt. a bridge until git.grove lifts into supervisor.
#
# usage:
#   rhx git.grove.send <name> --what "<cmd>"           # ONE step only; fire and forget
#   rhx git.grove.send <name> --reply --what "<cmd>"   # …and return ITS output + exit code
#   rhx git.grove.send <name> --play <name>            # many steps, from a play file
#   rhx git.grove.send <name> --reply --play <name>    # …and return the play's verdict
#   rhx git.grove.send <name> --detach --log <path> --what "<cmd>"   # long job, read the log later
#   rhx git.grove.send <name> --what "<cmd>" --bare --why 'no tmux yet'
#
# .note = `--reply` is what a VERIFY wants. without it the caller gets the exit
#         code of the SEND — `0` whenever the text reached the pane, whatever the
#         command then did — because a duct is tmux and a send is a keystroke.
#         with it, the command's own stdout and its own exit code come back, and
#         the job still rides the duct.
#
# 🛑 .the STREAM CONTRACT, because a caller may capture this
#         under `--reply`, STDOUT carries the command's own output and no other
#         byte. every banner, progress line, and refusal this skill writes goes
#         to STDERR — the duct's own `🔧 … sent` too, which is redirected at the
#         send since `ductwork.sh:1159` writes it to stdout.
#
#         ⇒ so `out="$(… --reply --what '<cmd>')"` yields the answer alone, and
#           a caller may test it against an anchored grammar.
#
# ⚠️ .and `rhx` does NOT preserve that contract — it writes its own
#         `🪨 run solid skill …` banner to stdout, and it is outside this repo.
#         a caller that CAPTURES a reply must invoke this file as an executable:
#
#             out="$(bash "$SEND" "$grove" --reply --what '<cmd>')"
#
#         `rhx git.grove.send` stays correct for a HUMAN at a keyboard, where
#         the banner is the point. the split is capture-vs-read, never taste.
#
#         it is not the default, because the default must stay cheap: a drive
#         (an apply, an install, a clone) wants the duct's survival across a
#         disconnect and has no use for a verdict held on the wire.
#
#         ⇒ a DRIVE sends. a VERIFY sends `--reply`.
#
# .note = `--await <secs>` and `--reply` are different halves and compose:
#           --await   wait for the pane to fall IDLE, then send   (about the duct)
#           --reply   send, then wait for the COMMAND to finish   (about the command)
#
# .note = the duct is the default because it survives a disconnect. but a duct
#         needs tmux ON the grove, and a fresh grove has none — so `--bare`
#         exists for the bootstrap window before the grove.provision lands tmux.
#
# .note = `--bare` REQUIRES `--why`, and that guard was earned. `--bare` is an
#         exemption from the duct, and its trigger is "the duct cannot carry
#         this". a flag that is free to type gets typed from habit long after
#         its trigger stops. that happened: a grove rebuilt on an image that
#         ships tmux, the duct verified live in the same round, and `--bare`
#         passed anyway. the human caught it — "why did you use bare?" — and
#         the honest answer was habit, not reason.
#
#         so the call site states the trigger, rather than trust it to prose
#         (`rule.require.exemptions-name-their-trigger`). `--why` is no
#         password: it prompts a CHECK that the trigger still fires.
#
# .note = `--detach` runs the command in its own session on the grove and keeps
#         the output in a log. a long job (a grove.provision run) then outlives
#         the ssh connection that started it. read the log back with
#         `--what 'tail -40 <log>'`
#
# .note = `--what` takes ONE step. a chained one-liner (`;`, `&&`, `||`, or a
#         newline) is REFUSED — put it in a play file instead. see below.
######################################################################
#
# WHY MULTI-STEP MUST BE A PLAY FILE
#
# a long chained one-liner sent to a grove is the worst of every world:
#   - unreviewable  — a human cannot read a 200-char `a; b; c; d` and judge it
#   - unrepeatable  — the exact command lives only in one shell's history
#   - uninspectable — the repo's pretooluse hooks read the OUTER command, so
#                     each step hidden inside `--what` passes unexamined
#   - undiffable    — a change to it leaves no trace in git
#
# a play file fixes all four. it lives at `.agent/.play/<name>.sh` — a reviewed,
# diffable, re-runnable artifact a human reads before it touches a machine, and
# re-runs by name after.
#
# a play is named for what it is: a set piece, rehearsed and repeatable, never
# an improvisation typed at a prompt.
######################################################################
set -o pipefail

# load the installed aliases (defines git_alias_grove + ductwork).
# to install THIS worktree's version onto this machine, run:
#   rhx grove.provision --from tree --mode apply
source ~/.bash_aliases 2>/dev/null || true

######################################################################
# 🛑 the gate reads EVERY function this skill borrows, never one of them
#
# 📜 measured 2026-08-31: a gate that names `git_alias_grove` alone lets an
#   installed copy that HELD that function and had lost `__duct_strip_escapes`
#   walk straight through, and the two call paths then fail differently:
#
#     | path      | line | exit | what a caller saw                        |
#     | --bare    | 438  | 127  | `__duct_strip_escapes: command not found` |
#     | --reply   | 838  | 0    | the banner, and an EMPTY payload         |
#
#   ⚠️ read that second row against TODAY's streams before you use it to
#     diagnose: the banner it names printed on STDOUT then and prints on
#     STDERR now. so the same fault today shows a caller a WHOLLY EMPTY
#     capture — quieter, and the reason the payload test at `_ask_at` and at
#     `git.grove.provision boot` is what catches it rather than a shape check.
#
#   ⇒ `--reply` pipes the payload through the absent function, so stdout is
#     empty and the pipeline's own rc never reaches the caller. the skill exits
#     0, and `rhx` DROPS a skill's stderr on a zero exit — so the one line that
#     named the cause was discarded, and `echo PROBE_OK` came back blank.
#
#   that empty answer is the third `--reply` state
#   (`term=duct.reply._.choice.reason.md`), and it cost `git.grove.provision boot`
#   a false ✋: its watcher read a blank ~1350 times against an apply that had
#   converged. the WATCHER now tests its payload — and this is the cause, one
#   layer in: the strip was never loaded, and no line survived to say so.
#
# ⚠️ the defect is the SUBSET, not the name. a gate that proves one member of a
#   set and lets the rest through is `gotcha.a-check-that-cries-wolf-gets-silenced`
#   q11 — a count is only as big as its reader's reach.
#
# 🛑 and `__duct_strip_escapes` is the member that MUST NOT be waved through: it
#   is the boundary that keeps grove-chosen bytes off this terminal (line 408,
#   `rule.require.security-paramount`). absent, the safe outcome is a HALT —
#   never a relay of unstripped bytes, and never a silent blank.
#
# ⇒ ONE declaration drives the check. to re-derive the set, ask this file:
#     rg -o '__duct_[a-z_]+|git_alias_[a-z_]+' <this file> | sort -u
######################################################################
GROVE_SEND_BORROWS=(git_alias_grove __duct_strip_escapes)
for _fn in "${GROVE_SEND_BORROWS[@]}"; do
  command -v "$_fn" &>/dev/null && continue
  echo "✋ $_fn not found — the installed aliases are stale" >&2
  echo "   ├─ this skill borrows ${GROVE_SEND_BORROWS[*]} from ~/.bash_aliases" >&2
  echo "   └─ fix: install from a copy that HOLDS it —" >&2
  echo "        rhx grove.provision --what 2.7.aliases --from tree --mode apply" >&2
  #
  # ⚠️ `--from tree`, NOT `--from main`. this gate fires when the installed copy
  #    is BEHIND, so the fix must name a copy that is AHEAD. measured 2026-09-01:
  #    `origin/main:src/ductwork.sh` is the 137-line version and declares no
  #    `__duct_strip_escapes` at all, so a `--from main` apply converges the box
  #    and leaves this gate red — a fix text that names a fix which cannot work
  #    (`rule.require.errors-name-the-fix`).
  exit 2
done

# rhachet forwards its own --skill/--repo/--role flags; drop them.
# a bare `--` ends the strip — every arg after it is literal, so a value that
# looks like a flag (e.g. a grove literally named `--skill`) still reaches through.
ARGS=()
BARE="false" DETACH="false" LOG="" GROVE="" WHAT="" PLAY="" WHY=""
REPLY_WANTED="false" REPLY_WITHIN=900 REPLY_EVERY=2
while [[ $# -gt 0 ]]; do
  case "$1" in
    --) shift; ARGS+=("$@"); break ;;
    --skill|--repo|--role) shift 2 ;;
    --bare) BARE="true"; shift ;;
    --why) WHY="$2"; shift 2 ;;
    --detach) DETACH="true"; shift ;;
    --log) LOG="$2"; shift 2 ;;
    --play) PLAY="$2"; shift 2 ;;
    --what) WHAT="$2"; ARGS+=("$1" "$2"); shift 2 ;;
    ####################################################################
    # ⚠️ `--reply` is CONSUMED here, never forwarded
    #
    #    ductwork's `duct.send` knows `--await` and `--anyway` and refuses any
    #    other arg. `--reply` is this skill's own wrap around a send, so it must
    #    not reach ductwork at all
    ####################################################################
    --reply)  REPLY_WANTED="true"; shift ;;
    --within) REPLY_WITHIN="$2"; shift 2 ;;
    --every)  REPLY_EVERY="$2"; shift 2 ;;
    # the busy-duct pair. named EXPLICITLY, not left to the `-*` catch-all: that
    # branch forwards a flag but not its value, so `--await 600` would forward
    # `--await` and then read `600` as the grove name
    --await) ARGS+=("$1" "$2"); shift 2 ;;
    --anyway) ARGS+=("$1"); shift ;;
    -*) ARGS+=("$1"); shift ;;
    *) [[ -z "$GROVE" ]] && GROVE="$1"; ARGS+=("$1"); shift ;;
  esac
done

if [[ -n "$WHAT" && -n "$PLAY" ]]; then
  echo "✋ pass --what OR --play, not both" >&2
  exit 2
fi

######################################################################
# the trigger guard on --bare
#
# `--bare` is an EXEMPTION from the duct default, and an exemption must name
# the trigger that fires it (rule.require.exemptions-name-their-trigger). the
# rule targets prose; the call site enforces it here, since prose did not hold
######################################################################
if [[ "$BARE" == "true" && -z "$WHY" ]]; then
  echo "✋ --bare needs a --why" >&2
  echo "" >&2
  echo "   why: the duct is the better carriage — it survives a disconnect, which" >&2
  echo "        matters on a grove that hibernates mid-job. --bare gives that up," >&2
  echo "        so it is an exemption, and an exemption must name its trigger" >&2
  echo "" >&2
  echo "   the triggers that earn it:" >&2
  echo "     --why 'no tmux yet'    the bootstrap window; a duct IS tmux, so a" >&2
  echo "                            fresh grove cannot open one at all" >&2
  echo "     --why 'duct is broken' the duct exists but will not relay" >&2
  echo "     --why '… NON-INTERACTIVE shell'" >&2
  echo "                            a duct pane runs an INTERACTIVE zsh, so it" >&2
  echo "                            serves a human's PATH. a probe that asks how" >&2
  echo "                            a PROGRAM sees the box must not use it" >&2
  echo "                            (gotcha.a-tool-found-by-path-answers-only-a-human)" >&2
  echo "" >&2
  echo "" >&2
  echo "   ⚠️ 'a verify needs the remote verdict' is NO LONGER a trigger." >&2
  echo "      it was one, and it was the most-typed --why in this repo — a duct" >&2
  echo "      returns the SEND's exit code, so a verify had to leave the duct to" >&2
  echo "      get an answer. that is now a FEATURE rather than an escape hatch:" >&2
  echo "        rhx git.grove.send $GROVE --reply --what '<cmd>'" >&2
  echo "      it rides the duct AND returns the command's own output and code" >&2
  echo "" >&2
  echo "   if no trigger fires, drop --bare and let the duct carry it:" >&2
  echo "     rhx git.grove.send $GROVE --what '<cmd>'          # a drive" >&2
  echo "     rhx git.grove.send $GROVE --reply --what '<cmd>'  # a verify" >&2
  echo "     rhx git.grove.read $GROVE" >&2
  echo "" >&2
  echo "   note: --why is not a password. it is a prompt to CHECK the trigger" >&2
  echo "         still fires, because the cost of a stale exemption is silent" >&2
  exit 2
fi

######################################################################
# the one-step guard on --what
#
# a chained one-liner is refused, and the error names the play file to write —
# it does not merely say no (rule.require.errors-name-the-fix)
#
# 🛑 .THIS IS A LEGIBILITY CONTROL. IT IS NOT AN INJECTION DEFENSE.
#
#    it refuses `;`, `&&`, `||`, and a newline — the four a HUMAN types to chain
#    two steps. it permits `'`, a backtick, `$( )`, and a bare `&`, which are the
#    four that break OUT of a quote. that is not a gap to close; the two sets
#    answer different questions, and this one asks only "is this ONE step?"
#
#    ⚠️ so do NOT widen this list to "harden" it. that repair is specific,
#       plausible, and wrong (gotcha.a-check-that-cries-wolf-gets-silenced, m.7),
#       and a deny list of characters is a claim about a grammar with more shapes
#       than any author enumerates (m.12). the boundary belongs at the
#       interpolation, never here (rule.require.solve-at-cause).
#
#    where the real boundary sits, per path:
#
#      | path                      | what --what IS     | who makes it safe         |
#      |---------------------------|--------------------|---------------------------|
#      | default (the duct)        | DATA — keystrokes  | `__duct_ssh_tmux`, which  |
#      |                           | typed into a pane  | base64s every argument    |
#      | --bare / --reply /--detach| CODE — a command   | no one, and correctly: to |
#      |                           | the far shell runs | run it IS the contract    |
#
#    ⇒ on the duct path the escape is already closed at cause, in
#      `src/ductwork.sh`. on the `--bare` family there is none to close — a
#      caller who passes a backtick asked for a backtick, on a box they already
#      hold a key to. this guard changes neither; it keeps one send readable,
#      repeatable, and diffable, and keeps each step visible to the pretooluse
#      hooks, which read only the OUTER command.
######################################################################
# ⚠️ .a play lives in ONE of two dirs, and the dir IS the promise
#
#     `.play/temporary/`  GITIGNORED. a probe written to answer one question and
#                         then discarded. a play that is never committed cannot
#                         rot into a clamp nobody runs
#                         (gotcha.a-check-that-cries-wolf-gets-silenced, m.13)
#     `.play/permanent/`  TRACKED. a discrimination probe under
#                         `rule.forbid.repair-plays` exception 2 — a clamp that
#                         must reach every box, so its absence cannot be silent
#
# 🛑 there is no third dir. `.agent/playbooks/` is forbidden and gone; a play
#    placed anywhere else reaches neither runner, and its absence is silent.
#
# ⚠️ .why a name in BOTH dirs HALTS rather than resolves by precedence
#     that is one claim with two holders, free to drift in silence (m.9). a
#     precedence rule would pick a winner and hide the drift; a halt names it.
PLAY_DIR_SCRATCH=".play/temporary"
PLAY_DIR_TRACKED=".play/permanent"
PLAY_DIR_REL="$PLAY_DIR_SCRATCH"   # the dir a --what fix-text points a writer at
if [[ -n "$WHAT" ]]; then
  if [[ "$WHAT" =~ (\;|\&\&|\|\|) || "$WHAT" == *$'\n'* ]]; then
    echo "✋ --what takes ONE step; this command chains several" >&2
    echo "" >&2
    echo "   what: $WHAT" >&2
    echo "" >&2
    echo "   why: a chained one-liner cannot be reviewed, repeated, or diffed, and the" >&2
    echo "        repo's pretooluse hooks read only the OUTER command — so each step" >&2
    echo "        hidden inside --what reaches a machine unexamined" >&2
    echo "" >&2
    echo "   fix: put the steps in a play file, then send it by name —" >&2
    echo "     1. write   $PLAY_DIR_REL/<name>.sh" >&2
    echo "     2. send it rhx git.grove.send $GROVE --play <name>" >&2
    echo "" >&2
    echo "   note: a PIPE is one step and is allowed (\`ps aux | head\`)." >&2
    echo "         it is \`;\`, \`&&\`, \`||\`, and a newline that make several." >&2
    exit 2
  fi
fi

######################################################################
# --play: read a reviewed play file, land it on the grove, run it
######################################################################
if [[ -n "$PLAY" ]]; then
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
  if [[ -z "$REPO_ROOT" ]]; then
    echo "✋ --play needs a git repo to read the play dirs from; this cwd is not in one" >&2
    exit 2
  fi

  PLAY_SLUG="${PLAY%.play.sh}"
  PLAY_HITS=()
  for d in "$PLAY_DIR_SCRATCH" "$PLAY_DIR_TRACKED"; do
    [[ -f "$REPO_ROOT/$d/$PLAY_SLUG.play.sh" ]] && PLAY_HITS+=("$d")
  done

  # 🛑 two holders of one name. do NOT pick — say so
  if [[ "${#PLAY_HITS[@]}" -gt 1 ]]; then
    echo "✋ '$PLAY_SLUG' names a play in BOTH dirs, so which one runs is undeclared" >&2
    for d in "${PLAY_HITS[@]}"; do echo "     • $d/$PLAY_SLUG.play.sh" >&2; done
    echo "" >&2
    echo "   why: one claim with two holders drifts in silence, and a precedence" >&2
    echo "        rule would hide that drift behind a green run" >&2
    echo "   fix: delete the scratch copy, or rename it —" >&2
    echo "     rhx rmsafe --path '$PLAY_DIR_SCRATCH/$PLAY_SLUG.play.sh'" >&2
    exit 2
  fi

  if [[ "${#PLAY_HITS[@]}" -eq 0 ]]; then
    echo "✋ no play named '$PLAY_SLUG' in either play dir" >&2
    echo "" >&2
    echo "   looked in:" >&2
    echo "     • $PLAY_DIR_SCRATCH/   (gitignored — a probe, discarded after)" >&2
    echo "     • $PLAY_DIR_TRACKED/   (tracked — a clamp that reaches every box)" >&2
    for d in "$PLAY_DIR_SCRATCH" "$PLAY_DIR_TRACKED"; do
      [[ -d "$REPO_ROOT/$d" ]] || continue
      echo "" >&2
      echo "   $d/ holds:" >&2
      n=0
      for f in "$REPO_ROOT/$d"/*.play.sh; do
        [[ -f "$f" ]] || continue
        echo "     • $(basename "$f" .play.sh)" >&2
        n=$(( n + 1 ))
      done
      [[ "$n" -gt 0 ]] || echo "     (none)" >&2
    done
    exit 2
  fi

  PLAY_DIR_REL="${PLAY_HITS[0]}"
  PLAY_FILE="$REPO_ROOT/$PLAY_DIR_REL/$PLAY_SLUG.play.sh"

  # land the play under a name that names its origin, so a human who finds it on
  # the grove traces it back to the reviewed file in the repo.
  #
  # ⚠️ it lands under the SEAT'S OWN HOME, never under /tmp. a shared
  #    `/tmp/grove.play.<name>.play.sh` is wrong twice:
  #
  #    1. ONE PATH, MANY SEATS. a grove carries several seats (`term=seat`), and
  #       /tmp is shared by all of them AND carries the sticky bit. so the first
  #       seat to send a play OWNS that path, and every other seat is refused —
  #       `zsh:1: permission denied`. measured on grove-ahbode-v20260810: camper
  #       sent a play, then ground could not send the same play at all.
  #       ⚠️ and the refusal reads as a REACH problem ("could not land the play"),
  #       which sends a reader to check the tunnel that was never broken.
  #    2. /tmp IS FORBIDDEN HERE. it persists and never auto-cleans, so a play
  #       from a prior session outlives the session that wrote it — and a STALE
  #       play that still runs is a check that reports on code nobody edited.
  #
  #    $HOME is per-seat by construction, so the collision cannot recur, and the
  #    dir is named for what it holds so a human can find and clear it.
  #
  # the remote command is SINGLE-quoted, so $HOME expands on the GROVE, not here.
  # a local expansion would write this laptop's home into a remote path.
  PLAY_REMOTE_REL=".local/state/grove.play/${PLAY%.play.sh}.play.sh"
  ####################################################################
  # 🛑 THIS UPLOAD IS A WIRE BOUNDARY, AND IT RUNS BEFORE EVERY TRANSPORT
  #
  #    a `--play` send lands the file FIRST, then branches to `--bare`,
  #    `--detach`, or the duct. so this one ssh is on the path of all four,
  #    and a raw byte here reaches the human's terminal whichever branch runs.
  #
  # 🛑 both streams are grove-chosen, and neither is empty by construction:
  #    - stdout: `mkdir`/`cat`/`chmod` are quiet on success and NOT quiet on
  #      failure, and a remote login rc writes here with no verb of ours run
  #    - stderr: ssh forwards it byte-for-byte over
  #      `SSH_MSG_CHANNEL_EXTENDED_DATA`, so a compromised box writes it
  #      straight onto this terminal — the cheapest half for a grove to reach
  #
  #    ⇒ a terminal OBEYS what it is handed. an OSC 52 from either stream
  #      rewrites the human's clipboard. the sink and its full reason live in
  #      `src/ductwork.sh`; the measurement lives at the `--bare` branch below.
  #
  # 📜 .measured 2026-09-02 — a sweep that named four carriers and missed this
  #    the 2026-08-31 pass listed the ssh carriers at
  #    `git.grove.operations.sh:100-124` and repaired each. this line sits in a
  #    DIFFERENT file, under a branch that returns before it reaches the block
  #    those four share — so a reader who swept the shared block found four of
  #    five and reported a closed class (`gotcha.a-check-that-cries-wolf-gets-
  #    silenced`, m.12: a total is true only of the set the reader could reach).
  #
  # ⚠️ .why a scratch FILE and not `2> >(__duct_strip_escapes >&2)`
  #    a process substitution is asynchronous, so the evidence would reach the
  #    terminal on some runs and vanish on others. a strip honored most of the
  #    time is not one.
  ####################################################################
  PLAY_ERR="$(mktemp "${TMPDIR:-/tmp}/grove.play.err.XXXXXX")" || {
    echo "💥 could not open a scratch file for ssh's stderr — ssh was NOT run" >&2
    exit 1
  }
  # a TRAP, so a Ctrl-C mid-upload leaves no file behind. cleared right after,
  # because this block CONTINUES rather than exits (same shape as `--detach`)
  trap 'rm -f "$PLAY_ERR"' EXIT
  ssh -o BatchMode=yes "$GROVE" \
        'mkdir -p "$HOME/.local/state/grove.play"'" && cat > \"\$HOME/$PLAY_REMOTE_REL\" && chmod +x \"\$HOME/$PLAY_REMOTE_REL\"" \
        < "$PLAY_FILE" 2>"$PLAY_ERR" | __duct_strip_escapes
  # PIPESTATUS[0], not `$?` — `$?` reads the SINK on a clean strip, and the
  # answer this branch acts on is SSH's
  PLAY_UPLOAD_RC="${PIPESTATUS[0]}"
  [[ -s "$PLAY_ERR" ]] && __duct_strip_escapes < "$PLAY_ERR" >&2
  rm -f "$PLAY_ERR"
  trap - EXIT
  if [[ "$PLAY_UPLOAD_RC" -ne 0 ]]; then
    echo "✋ could not land the play on $GROVE" >&2
    echo "" >&2
    echo "   ask in this order — the first two are cheap:" >&2
    echo "     1. is the seat reachable at all?" >&2
    echo "        rhx git.grove.send $GROVE --bare --why 'reach check' --what 'whoami'" >&2
    echo "     2. is the grove awake?" >&2
    echo "        rhx git.grove.wake $GROVE --mode apply" >&2
    echo "     3. is \$HOME writable for this seat? a read-only or absent home" >&2
    echo "        refuses the write while ssh itself works fine" >&2
    exit 1
  fi
  PLAY_REMOTE="\$HOME/$PLAY_REMOTE_REL"

  # ⚠️ THE SHELL IS PROBED PER SEAT, because no fixed choice is right on both a
  #    fresh box and a converged one. a play must see the PATH A HUMAN SEES, and
  #    which shell serves that PATH changes the moment `2.5.zsh` lands:
  #
  #    | seat state     | ~/.bash_profile | `bash -l` reads | rhx on PATH? |
  #    |----------------|-----------------|-----------------|--------------|
  #    | before 2.5.zsh | absent          | ~/.profile      | yes          |
  #    | after  2.5.zsh | execs zsh       | .zshenv only    | NO           |
  #
  #    `bash -l` is correct for the FIRST row alone: `bash <file>` reads neither
  #    ~/.bashrc (ubuntu's returns early when non-interactive) nor ~/.profile
  #    (login-only), and ~/.profile is where a fresh box's PATH lands. measured
  #    2026-08-10: diagnose.grove-github-credential reported "✋ rhx is NOT found
  #    on this PATH" on a box where a human's shell found it fine.
  #
  #    ⚠️ after `2.5.zsh`, ~/.bash_profile EXECS zsh — and that zsh is
  #      NON-interactive, so `.zshenv` loads and `.zshrc` does not. `.zshrc` is
  #      where pnpm's shim dir joins PATH, so `rhx` leaves PATH on exactly the
  #      boxes that are most converged. measured on grove-ahbode-v20260810's
  #      camper, on a box whose own suite tallies 31 passed:
  #
  #        rhx git.grove.send <g> --play prove.aws-reach-set --bare
  #        → …/prove.aws-reach-set.play.sh: line 77: rhx: command not found   (×3)
  #        → ✋ apply1=127 apply2=127
  #
  #      exit 127 is "command not found", so each `rhx` line was a no-op and the
  #      play still printed a verdict — a false ✋ about the SUBJECT that names
  #      a fact about the CARRIAGE
  #      (`gotcha.bash-lc-becomes-a-half-zsh`,
  #       `gotcha.a-check-that-cries-wolf-gets-silenced`).
  #
  #    ⇒ so the choice is measured, never assumed. the probe asks for `~/.zshrc`
  #      — the artifact `2.5.zsh` WRITES — and never for the zsh BINARY, which a
  #      stock ubuntu image carries long before this repo configures a thing.
  #      `.zshrc` is a $HOME artifact, so this is per-SEAT by construction.
  #
  # .note = `zsh -ic <path>` rather than `zsh -i <path>`. the play keeps its own
  #    shebang and runs as a child process, so it inherits the interactive zsh's
  #    exported PATH, and this file holds no opinion about which interpreter the
  #    play itself declares.
  if ssh -o BatchMode=yes "$GROVE" 'test -f "$HOME/.zshrc"' 2>/dev/null; then
    WHAT="zsh -ic $PLAY_REMOTE"
    PLAY_SHELL="zsh -ic (this seat's PATH is served by ~/.zshrc)"
  else
    WHAT="bash -l $PLAY_REMOTE"
    PLAY_SHELL="bash -l (no ~/.zshrc yet, so ~/.profile serves the PATH)"
  fi
  ####################################################################
  # 🛑 STDERR — this banner is reachable ON THE `--reply` PATH
  #
  # `--reply` promises that its stdout carries the command's own output and no
  # other byte, and `--reply --play <name>` is a supported pair (`:14`). this
  # block runs BEFORE the transport branches, so a stdout write here lands
  # ahead of the play's own output in every `--reply --play` capture.
  #
  # 📜 .measured 2026-09-02, and the round-18 repair MISSED it by scope
  #
  #   that repair opened with *"🛑 EVERY WRITE FROM HERE TO THE PAYLOAD GOES
  #   TO STDERR"* — true of the block it headed, and this banner sits ~480
  #   lines EARLIER, on a path that reaches the same promise. so the sentence
  #   read as a claim about the skill and was a claim about one branch of it
  #   (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.4 — a sign-off that
  #   names a wider subject than its rows can support).
  #
  # ⚠️ the two `--bare` / `--detach` banners below stay on STDOUT deliberately.
  #    neither transport makes the one-stream promise: `--detach` returns a
  #    log path for a human, and `--bare` is a plain ssh whose whole page is
  #    for the caller to read. only `--reply` binds stdout, so only writes
  #    reachable from it are moved.
  ####################################################################
  echo "🎭 play: $PLAY_DIR_REL/${PLAY%.play.sh}.play.sh → $GROVE:$PLAY_REMOTE" >&2
  echo "   └─ via: $PLAY_SHELL" >&2
fi

# the ONE transport-fault code, shared by `--detach` and `--reply`. its full
# contract is documented at the `--reply` branch below, under "EXIT 97"
GROVE_SEND_NO_VERDICT=97

# the bare transport: plain ssh, no duct. one-shot, dies with the connection
if [[ "$BARE" == "true" ]]; then
  if [[ -z "$GROVE" || -z "$WHAT" ]]; then
    echo "✋ usage: rhx git.grove.send <name> --what '<one-step>' --bare" >&2
    echo "      or: rhx git.grove.send <name> --play <name> --bare" >&2
    exit 2
  fi

  if [[ "$DETACH" == "true" ]]; then
    LOG="${LOG:-\$HOME/.grove.send.log}"
    echo "🐚 git.grove.send $GROVE --bare --detach"
    echo "   ├─ what: $WHAT"
    echo "   └─ log:  $LOG"
    echo ""

    # the remote job gets its own session, no inherited stdin, and its output
    # kept in the log. stdin must be closed, else the job exits on EOF the
    # moment this ssh connection closes
    REMOTE_DRIVE="setsid bash -lc $(printf '%q' "$WHAT") < /dev/null >> \"$LOG\" 2>&1 & disown; echo \$!"

    # 🛑 ssh's OWN stderr rides fd 2, which this capture does not touch — and
    #    that is the channel the note below already names as one a grove's rc
    #    writes freely on. the capture below took only stdout, so the raw half
    #    reached the terminal untouched (measured 2026-08-31). it is sunk here,
    #    through a scratch file rather than a process substitution, because an
    #    async writer and a command substitution race
    DETACH_ERR="$(mktemp "${TMPDIR:-/tmp}/grove.send.err.XXXXXX")" || {
      echo "💥 could not open a scratch file for ssh's stderr — ssh was NOT run" >&2
      exit 1
    }
    # the removal is a TRAP, so a Ctrl-C mid-ssh leaves no file behind. safe
    # here and NOT in `__duct_ssh_tmux`: this is its own process, where the
    # trap table is ours, and that one is a function in a human's interactive
    # shell, where an EXIT trap would clobber theirs
    trap 'rm -f "$DETACH_ERR"' EXIT
    REMOTE_PID=$(ssh -o BatchMode=yes "$GROVE" "$REMOTE_DRIVE" 2>"$DETACH_ERR" | __duct_strip_escapes)
    [[ -s "$DETACH_ERR" ]] && __duct_strip_escapes < "$DETACH_ERR" >&2
    rm -f "$DETACH_ERR"
    trap - EXIT

    # ⚠️ the pid is VALIDATED before it is echoed, exactly as the duct path does
    #    a grove's shell rc writes freely on that channel, so an unchecked relay
    #    both prints a forged pid and hands a terminal whatever escapes rode
    #    along with it (the strip above is the second half of the pair)
    if [[ ! "$REMOTE_PID" =~ ^[0-9]+$ ]]; then
      echo "💥 the job may have started, and no pid came back" >&2
      echo "   ├─ the far side answered with text that is not a pid" >&2
      echo "   └─ ⇒ read the log to see what ran: tail -40 $LOG" >&2
      exit "$GROVE_SEND_NO_VERDICT"
    fi

    echo "🐢 detached on $GROVE (pid $REMOTE_PID)"
    echo "   read it back:"
    echo "     rhx git.grove.send $GROVE --bare --what 'tail -40 $LOG'"
    exit 0
  fi

  echo "🐚 git.grove.send $GROVE --bare"
  echo "   └─ what: $WHAT"
  echo ""
  ####################################################################
  # 🛑 `__duct_strip_escapes` — grove-chosen bytes, on their way to a terminal
  #    that OBEYS them. the sink and its full reason live in `src/ductwork.sh`
  #
  # ⚠️ the EXIT CODE still comes from ssh, not from the sink. `pipefail` is set
  #    at the top of this file, and the sink returns 0 on every input it can
  #    read — so the pipeline's status is ssh's own, which is what a `--bare`
  #    caller reads as the answer (`gotcha.the-duct-returns-the-send-not-the-answer`)
  #
  # 🛑 .STDERR gets the sink too — a pipe carries one stream of two
  #    📜 measured 2026-08-31: this line stripped stdout and let ssh relay the
  #      remote command's stderr onto this terminal RAW. ssh forwards that half
  #      byte-for-byte (`SSH_MSG_CHANNEL_EXTENDED_DATA`), and it is the half a
  #      grove writes most cheaply — a login rc writes there with no verb of ours
  #      involved. so a `--bare` probe of a compromised box handed kitty an
  #      OSC 52 and rewrote the human's clipboard.
  #
  # ⚠️ .why a scratch FILE and not `2> >(__duct_strip_escapes >&2)`
  #    a process substitution is asynchronous, and `exit` runs the moment the
  #    pipeline returns — so the evidence would reach the terminal on some runs
  #    and vanish on others. a strip that is honored most of the time is not one
  #    (`gotcha.a-check-that-cries-wolf-gets-silenced`).
  #
  #    ⇒ the cost is that stderr arrives at the END rather than interleaved.
  #      each stream stays coherent, and a `--bare` send is a one-shot probe
  #      whose answer a caller reads whole (`rule.require.security-paramount`)
  ####################################################################
  SEND_ERR="$(mktemp "${TMPDIR:-/tmp}/grove.send.err.XXXXXX")" || {
    echo "💥 could not open a scratch file for ssh's stderr — ssh was NOT run" >&2
    exit 1
  }
  # a TRAP, so a Ctrl-C mid-ssh leaves no file behind. safe here and NOT in
  # `__duct_ssh_tmux`: this is its own process, where the trap table is ours
  trap 'rm -f "$SEND_ERR"' EXIT
  ssh -o BatchMode=yes "$GROVE" "$WHAT" 2>"$SEND_ERR" | __duct_strip_escapes
  SEND_RC=$?
  [[ -s "$SEND_ERR" ]] && __duct_strip_escapes < "$SEND_ERR" >&2
  rm -f "$SEND_ERR"
  exit "$SEND_RC"
fi

######################################################################
# --detach on the DUCT path
#
# `--detach` read only inside the --bare branch leaves the duct path to parse it
# and SILENTLY IGNORE it. the command reaches the pane as ordinary text — and a
# busy pane eats that text as the live job's stdin. the caller sees a success
# line, no log lands, and the job they asked for never starts.
#
# a flag that silently does other than what it says is worse than an absent one
# (rule.forbid.failhide). so the duct path honors it too: the same setsid form,
# sent through the duct rather than over plain ssh
#
# 🛑 DELIVERY IS PROVEN ON BOTH PATHS, never on one
#
#    the `--bare` sibling PROVES delivery: `echo \$!` rides back over the ssh
#    channel, so an empty answer means the line never executed. a duct path that
#    prints `🐢 detached` on the SEND's exit code proves no such thing — that
#    code is `0` whenever the TEXT landed
#    (`gotcha.the-duct-returns-the-send-not-the-answer`).
#
#    ⇒ measured 2026-08-15, on a from-scratch grove: a fresh tmux pane swallowed
#      the first character, `setsid` arrived as `etsid`, the send reported
#      success, and the apply never began. it surfaced only because a human
#      asked the box directly with `pgrep -af grove.provision`.
#
#    ⇒ a guarantee is owed to every SIBLING call, not to the one that taught it.
#      so the duct path proves delivery the same way: the drive writes its own
#      pid to a sidecar, and this polls for that file BESIDE the duct, over ssh.
#      the file's presence proves the line executed.
#
# ⚠️ .the claim is DELIVERY and no more — do not "improve" it into a liveness check
#    `setsid` forks when its caller is already a process-group leader, so `\$!`
#    can name a parent that exits at once while the real worker carries on. a
#    `kill -0` on that pid would report a dead job on a healthy 9-minute apply —
#    a false ✋ about a box that works, which is the corrosive half of the pair
#    (`gotcha.a-check-that-cries-wolf-gets-silenced`).
#
#    ⇒ to ask whether the job still runs, read whether the LOG still GROWS. that
#      asks the subject itself, rather than a pid the launcher may not own.
######################################################################
if [[ "$DETACH" == "true" ]]; then
  LOG="${LOG:-\$HOME/.grove.send.log}"

  ####################################################################
  # the pid file is this send's DELIVERY PROOF — the poll below breaks on its
  # existence, so its path gets the same treatment as the reply channel's
  #
  # 🛑 never a `/tmp/duct.detach.$(date +%s).$$.pid`. a second seat pre-creates
  #    that path and makes this report "detached (pid N)" for a job that never
  #    started — a forged DELIVERY, where the reply pair's version forges a
  #    whole VERDICT. the `^[0-9]+$` test at the read below closes the
  #    terminal-relay half alone; it does not reach this one.
  #
  #    the full account of the class, and why $HOME retires it rather than
  #    guards it, sits at the reply channel's own block further down.
  ####################################################################
  DETACH_NONCE="$(od -An -N8 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n')"
  if [[ ! "$DETACH_NONCE" =~ ^[0-9a-f]{16}$ ]]; then
    echo "✋ could not read 16 random hex digits for this send's pid file" >&2
    echo "   ⇒ a PREDICTABLE path lets another seat on the grove pre-create it," >&2
    echo "     which forges the delivery proof this send waits on" >&2
    echo "   fix: check /dev/urandom on THIS machine — od -An -N8 -tx1 /dev/urandom" >&2
    exit "$GROVE_SEND_NO_VERDICT"
  fi
  # `\$HOME` stays literal, so the GROVE's shell expands it
  DETACH_DIR="\$HOME/.local/state/grove.reply"
  DETACH_PID="$DETACH_DIR/${DETACH_NONCE}.pid"
  DETACH_WITHIN=20
  DETACH_EVERY=1

  # `\$!` stays literal so the REMOTE shell expands it, never this one
  DRIVE="mkdir -p \"$DETACH_DIR\" ; chmod 700 \"$DETACH_DIR\" ; setsid bash -lc $(printf '%q' "$WHAT") < /dev/null >> \"$LOG\" 2>&1 & echo \$! > \"$DETACH_PID\"; disown"

  echo "🐚 git.grove.send $GROVE --detach"
  echo "   ├─ what: $WHAT"
  echo "   └─ log:  $LOG"
  echo ""

  # ⚠️ this names NO fix, on purpose. a refusal has several causes — a BUSY
  #    pane, an absent duct, a quiet box — and each needs a different move.
  #    ductwork already printed the precise one above, so a generic
  #    `git.grove.wake` here would be a plausible, specific, wrong instruction
  #    on the most common cause (`gotcha.a-check-that-cries-wolf-gets-silenced`,
  #    m.4 on the over-broad summary, m.7 on the regressive fix-text)
  if ! git_alias_grove send "$GROVE" --what "$DRIVE"; then
    echo "✋ the duct refused the send, so the job never started" >&2
    echo "   ⇒ its own reason and fix are printed directly above" >&2
    exit "$GROVE_SEND_NO_VERDICT"
  fi

  # ⚠️ the poll goes AROUND the pane, never through it. to ask down the duct
  #    would put a command in the very pane whose busyness is the question
  DETACH_WAITED=0
  while [[ "$DETACH_WAITED" -lt "$DETACH_WITHIN" ]]; do
    ssh -o BatchMode=yes -o ConnectTimeout=10 "$GROVE" "test -f \"$DETACH_PID\"" 2>/dev/null && break
    sleep "$DETACH_EVERY"
    DETACH_WAITED=$(( DETACH_WAITED + DETACH_EVERY ))
  done

  if ! ssh -o BatchMode=yes -o ConnectTimeout=10 "$GROVE" "test -f \"$DETACH_PID\"" 2>/dev/null; then
    echo "✋ the text landed, and no job started within ${DETACH_WITHIN}s" >&2
    echo "" >&2
    echo "   why: the pane was busy, so the line was eaten as a live job's stdin —" >&2
    echo "        or the pane mangled it, since a fresh pane can swallow the" >&2
    echo "        first character (setsid → etsid, measured 2026-08-15)" >&2
    echo "" >&2
    echo "   ⇒ this is NOT a verdict that the job failed. LOOK before you re-send," >&2
    echo "     because a blind re-send can start a SECOND copy:" >&2
    echo "       rhx git.grove.send $GROVE --reply --what 'pgrep -af <a word from your command>'" >&2
    echo "       rhx git.grove.send $GROVE --reply --what 'tail -40 $LOG'" >&2
    exit "$GROVE_SEND_NO_VERDICT"
  fi

  DETACH_REMOTE_PID="$(ssh -o BatchMode=yes -o ConnectTimeout=10 "$GROVE" "cat \"$DETACH_PID\"" 2>/dev/null | tr -d '[:space:]')"
  ssh -o BatchMode=yes -o ConnectTimeout=10 "$GROVE" "rm -f \"$DETACH_PID\"" 2>/dev/null

  # ⚠️ an unreadable pid is NOT a pass. the file was there a moment ago, so an
  #    empty read means it went away under us (`rule.forbid.failhide`)
  if [[ ! "$DETACH_REMOTE_PID" =~ ^[0-9]+$ ]]; then
    echo "💥 the job started and its pid could not be read" >&2
    echo "   ├─ pid file: $DETACH_PID (was present, then unreadable)" >&2
    echo "   └─ ⇒ the job may well be fine; read the log to see what it did" >&2
    exit "$GROVE_SEND_NO_VERDICT"
  fi

  echo "🐢 detached on $GROVE (pid $DETACH_REMOTE_PID)"
  echo "   read it back:"
  echo "     rhx git.grove.send $GROVE --reply --what 'tail -40 $LOG'"
  echo "     rhx git.grove.read $GROVE"
  echo "   ask whether it still runs — the LOG grows, which a pid cannot tell you:"
  echo "     rhx git.grove.send $GROVE --reply --what 'stat -c %y $LOG'"
  exit 0
fi

######################################################################
# --reply: send over the DUCT, then return the command's own verdict
#
# 🛑 .what problem this closes
#    a duct is tmux. a plain send writes the command into a pane and returns,
#    so the caller gets the exit code of the SEND — `0` whenever the text
#    landed, whatever the command then did — and stdout is the send's own
#    two-line banner. measured, on a healthy grove:
#
#      $ rhx git.grove.send <g> --what 'test -d /definitely/not/a/real/path'
#      🔧 duct://<g>/main/mechanic sent
#      caller saw exit=0
#
#    a command that CANNOT succeed reported success.
#
# ⚠️ .why this exists rather than another `--bare`
#    `--bare` sidesteps the duct, so it answers correctly — and it gives up all
#    the duct is for: survival across a disconnect, one place to read the box's
#    history, a pane a human can attach to. every verify reached for it until it
#    was pure habit, the decay `rule.require.exemptions-name-their-trigger`
#    names.
#
#    an exemption typed often enough is an ABSENT FEATURE under a flag. so the
#    feature is built: the duct carries the answer back, and a verify has no
#    reason left to leave it (`rule.require.solve-at-cause`).
#
# ⚠️ .why NOT spelled `--await`
#    `--await <secs>` is already taken, and it names the OTHER half: it waits
#    for the pane to fall idle BEFORE the send, so a command does not land in
#    a busy job's stdin (`term=duct.idle`). that is a fact about the DUCT.
#    this is a fact about the COMMAND. one word over two concepts is the
#    ambiguity `rule.forbid.domain-term-synonyms` forbids, so they get one
#    word each — and `send`/`reply` is the symmetric pair
#    (`rule.prefer.symmetric-term-pairs`). the two compose:
#
#      rhx git.grove.send <g> --await 600 --reply --what '<cmd>'
#      #                      └ wait for a free pane   └ then carry the answer back
#
# .how it captures a verdict a pane cannot express
#    the command is wrapped so it records its OWN result to two files — one for
#    its output, one for its rc — then this polls for the rc file and reads both
#    back:
#
# ⚠️ .why these are NOT called markers
#    `term=marker` names a narrower and load-bear concept: a FIXED line a bundle
#    appends into a file it does not own, so a re-run can findsert its block.
#    these are neither fixed, nor lines, nor appended to a foreign file — they
#    are two temp files a run creates and removes. to spell both "marker" would
#    overload the one word the append-idempotence contract rests on
#    (`rule.forbid.domain-term-ambiguity`).
#
#      { <cmd> ; } > <out> 2>&1; echo $? > <rc>
#
# ⚠️ .why the poll goes AROUND the pane, never through it
#    to ask down the duct would put a command in the very pane whose busyness
#    is the question — it would land in the live job's stdin. this is the
#    same constraint `git.grove.play.await` documents, and the same answer: ask
#    over ssh, beside the duct rather than inside it
#
######################################################################
# 🛑 EXIT 97 — "this code is the TRANSPORT's, not the command's"
#
# `--reply` exits with the command's OWN code, which is the whole point. its
# transport faults must borrow from that same range, and 1 and 2 are codes a
# real command returns constantly. a caller cannot then tell:
#
#   · `test -f x` ran and answered false        → 1
#   · the duct refused the send, so it never ran → 1
#
# ⚠️ .what 97 covers, which is WIDER than "refused"
#    every exit from this branch that is not `exit "$REPLY_CODE"`. that is one
#    class, not four: the send was refused, the box went quiet, the bound
#    elapsed, the rc went unreadable, the args were malformed. they differ in
#    CAUSE and agree on the only fact a caller acts on — **no verdict exists**.
#
#    ⇒ so a caller needs ONE test, not a table. a table would have to grow with
#      every new fault, and a caller written before the growth would read the
#      new code as an answer — which is the very defect this closes
#
# ⚠️ .measured 2026-08-13, and it cost a false halt on a healthy grove
#    a backgrounded `git.grove.provision test` still held the pane when a second run
#    started. every probe was refused; `git.grove.ready.verify` read the 1 as an
#    answer and halted with `seat '…' holds src/ but no package.json beside
#    it`, plus a push command for a file that was present the whole time — 610
#    bytes, listed on that same box one command later
#    (`gotcha.a-check-that-cries-wolf-gets-silenced`, the false-✋ half).
#
# ⚠️ .why a reserved CODE, and not a marker in the command
#    a marker wraps every remote command as
#    `{ cmd ; } && echo __TRUE__ || echo __FALSE__`, so an absent marker means
#    "never ran". that cannot work here: `--what` takes ONE step, and the guard
#    above refuses any `;`, `&&`, or `||` in its raw text. to encode past that
#    guard would defeat a control that exists precisely because the pretooluse
#    hooks read only the outer command.
#
#    ⇒ and the knowledge is not the command's to carry. THIS skill already
#      knows — it checks the send's own result at the `git_alias_grove send`
#      call below. it simply had no way to SAY so. now it does
#      (`rule.require.solve-at-cause`).
#
# .why 97 in particular
#    it must be a code no reasonable command returns, so a caller can treat it
#    as unambiguous. 0-2 are everyday; 126-127 are "cannot execute"/"not found";
#    128+n is a signal. 97 sits in the unused middle, and it is OURS — a caller
#    that tests for it depends on this repo's contract rather than on any
#    vendor's phrasing (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.2).
#
# ⇒ every caller that reads a verdict — `_ask_at`, `_shell_at`, `_drive` —
#   treats 97 as "no verdict exists" and halts, rather than as an answer.
#
# ⚠️ .`--detach` reserves the SAME code, for the same reason
#    a detach makes a narrower claim — "the job started" — and it has the same
#    two outcomes: the claim holds, or no fact is known. an unproven delivery is
#    never "the job failed", because the line may have executed and the sidecar
#    write may not have. so a caller must LOOK before it re-sends, and 97 is what
#    stops it from a blind re-send that would start a second copy.
#
# ⚠️ .the declaration sits ABOVE, at the `--bare` branch
#    both consumers need it, and `--detach` is reached first. two declarations of
#    one constant is the m.9 shape — one set, two readers, free to disagree with
#    no signal — so there is exactly one, and this block is its documentation.
######################################################################

if [[ "$REPLY_WANTED" == "true" ]]; then
  if [[ "$DETACH" == "true" ]]; then
    echo "✋ --reply and --detach ask for opposite things" >&2
    echo "   ├─ --detach  start it and let go; the verdict comes later, from a log" >&2
    echo "   └─ --reply   hold on until it finishes, and return ITS exit code" >&2
    echo "   fix: for a long job, detach it and read the log back —" >&2
    echo "     rhx git.grove.send $GROVE --detach --log '\$HOME/job.log' --what '<cmd>'" >&2
    echo "     rhx git.grove.send $GROVE --reply --what 'tail -40 \$HOME/job.log'" >&2
    exit "$GROVE_SEND_NO_VERDICT"
  fi

  if [[ -z "$GROVE" || -z "$WHAT" ]]; then
    echo "✋ usage: rhx git.grove.send <name> --reply --what '<one-step>'" >&2
    echo "      or: rhx git.grove.send <name> --reply --play <name>" >&2
    exit "$GROVE_SEND_NO_VERDICT"
  fi

  ####################################################################
  # 🛑 THE VERDICT CHANNEL LIVES IN THE SEAT'S OWN HOME, NEVER IN /tmp
  #
  # 📜 named 2026-08-31 by a redteam of this file: the `.rc` file IS the verdict
  #    — the poll below breaks on its mere existence, and `exit "$REPLY_CODE"`
  #    returns whatever it holds — so its path is a TRUST ANCHOR, and a
  #    `/tmp/duct.reply.$(date +%s).$$.{out,rc}` puts it in a 1777 dir on a box
  #    this repo assumes is compromised.
  #
  #    a grove carries two seats and the camper is the one that runs agents. so
  #    the camper pre-creates the pair under a guessed id (a second-grained
  #    clock times 32768 pids is a small space, and inotify makes it smaller),
  #    the laptop breaks on the FIRST poll — before the real command ran —
  #    and reads camper's bytes as its stdout and camper's number as its exit
  #    code. every rung above this inverts at once: `_ask_at`, `_shell_at`,
  #    `git.grove.ready.verify`, and `git.grove.provision test`, all of which
  #    read a box through this one channel. a hostile box reports itself
  #    converged and gated (`rule.require.security-paramount`).
  #
  #    two more costs from the same line: `>` creates at the seat's umask, so
  #    every reply's full stdout — `gh auth status`, an `aws sts` identity, a
  #    whole plan — is world-readable on the box; and a symlink planted at the
  #    guessed path makes GROUND's redirect truncate any file ground owns.
  #
  # 🛑 .the play file forty lines up states the same rule in full: "ONE PATH,
  #    MANY SEATS … /tmp is shared by all of them", and lands the play under
  #    `$HOME/.local/state/grove.play/`. one lesson, two holders
  #    (`gotcha.a-check-that-cries-wolf`, m.9).
  #
  # .why $HOME rather than a mode-0700 dir in /tmp
  #      $HOME is per-seat BY CONSTRUCTION, so the collision and the squat are
  #      both gone as a class rather than guarded against
  #      (`rule.require.solve-at-cause`). the `chmod 700` below is belt on top,
  #      for a home some other seat can read.
  #
  # ⚠️ .the id is from urandom, never from the clock
  #      an id a caller can PREDICT is what makes a pre-create possible at all.
  #      `date +%s.$$` is public and small; 8 bytes of urandom is neither.
  #      ⇒ and its absence is a HALT, never a fallback to the clock: a fallback
  #        would restore the whole defect on any box whose urandom read failed,
  #        silently, which is the shape this block exists to retire.
  ####################################################################
  REPLY_NONCE="$(od -An -N8 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n')"
  if [[ ! "$REPLY_NONCE" =~ ^[0-9a-f]{16}$ ]]; then
    echo "✋ could not read 16 random hex digits for this reply's channel" >&2
    echo "   ⇒ a PREDICTABLE channel id lets another seat on the grove" >&2
    echo "     pre-create the rc file, and this skill reads that file AS the" >&2
    echo "     command's verdict — so a guessable id is a forged verdict" >&2
    echo "   ⇒ this halts rather than fall back to the clock, because a clock" >&2
    echo "     id is exactly the defect the nonce replaced" >&2
    echo "   fix: check /dev/urandom on THIS machine — od -An -N8 -tx1 /dev/urandom" >&2
    exit "$GROVE_SEND_NO_VERDICT"
  fi

  # `\$HOME` stays literal, so the GROVE's shell expands it — a local expansion
  # would write THIS laptop's home into a remote path
  REPLY_DIR="\$HOME/.local/state/grove.reply"
  REPLY_OUT="$REPLY_DIR/${REPLY_NONCE}.out"
  REPLY_RC="$REPLY_DIR/${REPLY_NONCE}.rc"

  # `\$?` stays literal so the REMOTE shell expands it, never this one
  REPLY_DRIVE="mkdir -p \"$REPLY_DIR\" ; chmod 700 \"$REPLY_DIR\" ; { $WHAT ; } > \"$REPLY_OUT\" 2>&1; echo \$? > \"$REPLY_RC\""

  ####################################################################
  # 🛑 EVERY WRITE FROM HERE TO THE PAYLOAD GOES TO STDERR. `--reply`'s
  #    STDOUT CARRIES THE COMMAND'S OWN OUTPUT AND NO OTHER BYTE.
  #
  #    that is the contract this file's header states, that
  #    `gotcha.the-duct-returns-the-send-not-the-answer:79` states, and that
  #    `git.grove.operations.sh:495` restates as *"handed on untouched —
  #    there is no marker to strip"*. put these four lines on stdout and all
  #    three claims are FALSE: a caller that captures the reply gets the banner
  #    welded to the front of the answer.
  #
  # .the cost, measured
  #    `git.grove.push.verify:96` does `$( … --reply … | tr -d '\r\n')` and
  #    tests the result against an `^…$`-anchored path grammar. with a banner
  #    in front, THAT MATCH IS IMPOSSIBLE — so the check that makes the
  #    two-carrier push design legitimate can never pass, and its refusal
  #    accuses the GROVE of a wholly local defect.
  #
  # ⚠️ .why the SEND is redirected too, and not only these echoes
  #    `git_alias_grove send` → `duct.send` ends with `echo "🔧 $uri sent"` on
  #    STDOUT (`src/ductwork.sh:1159`). so a redirect of this skill's own lines
  #    alone leaves one banner line behind and reads as complete — the whole
  #    class of defect this repo files under a partial sweep.
  #
  #    ⇒ the drive's progress is PROGRESS. the payload is what the grove's
  #      command wrote. the stream split follows that line, not authorship.
  #
  # 🛑 .do NOT close this in the READER instead
  #    a `tail -1`, or a strip keyed on the banner's TEXT, makes every caller
  #    depend on another component's output FORMAT — an invisible dependency
  #    that appears in no argument and breaks the day that sentence moves
  #    (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.2). it would also
  #    leave all three prose claims above still false.
  ####################################################################
  echo "🐚 git.grove.send $GROVE --reply" >&2
  echo "   ├─ what:   $WHAT" >&2
  echo "   └─ within: ${REPLY_WITHIN}s, asked every ${REPLY_EVERY}s" >&2
  echo "" >&2

  if ! git_alias_grove send "$GROVE" --what "$REPLY_DRIVE" >&2; then
    echo "✋ the duct refused the send, so the command never ran" >&2
    exit "$GROVE_SEND_NO_VERDICT"
  fi

  REPLY_WAITED=0
  REPLY_SAID_BUSY=0
  while [[ "$REPLY_WAITED" -lt "$REPLY_WITHIN" ]]; do
    # ⚠️ an ssh that cannot reach the box answers empty, exactly as a command
    #    still mid-run does. so reachability is asked SEPARATELY — to conflate
    #    them would report a wait that observed no state at all
    #    (`rule.forbid.failhide`)
    if ! ssh -o BatchMode=yes -o ConnectTimeout=10 "$GROVE" true 2>/dev/null; then
      echo "✋ the grove went silent, so the command's verdict is unknown" >&2
      echo "   ⇒ an unreachable box and a finished command both read as quiet," >&2
      echo "     so this refuses to guess between them" >&2
      echo "   fix: rhx git.grove.wake $GROVE" >&2
      exit "$GROVE_SEND_NO_VERDICT"
    fi

    if ssh -o BatchMode=yes "$GROVE" "test -f \"$REPLY_RC\"" 2>/dev/null; then
      break
    fi

    if [[ "$REPLY_SAID_BUSY" -eq 0 ]]; then
      # stderr — progress, not payload. see the stream block above
      echo "   • it runs — this holds until it finishes" >&2
      REPLY_SAID_BUSY=1
    fi

    sleep "$REPLY_EVERY"
    REPLY_WAITED=$(( REPLY_WAITED + REPLY_EVERY ))
  done

  if ! ssh -o BatchMode=yes "$GROVE" "test -f \"$REPLY_RC\"" 2>/dev/null; then
    echo "🌙 still busy after ${REPLY_WITHIN}s — this is a BOUND, not a verdict" >&2
    echo "   ├─ the command may simply need longer: --within <secs>" >&2
    echo "   └─ its output so far, and the pane, both survive the give-up" >&2
    ssh -o BatchMode=yes "$GROVE" "cat \"$REPLY_OUT\"" 2>/dev/null | __duct_strip_escapes
    exit "$GROVE_SEND_NO_VERDICT"
  fi

  ####################################################################
  # the command's OWN output, then its OWN exit code
  #
  # 🛑 `__duct_strip_escapes` — this is the ONE line of this skill that relays
  #    grove-chosen bytes to a terminal verbatim, and a terminal OBEYS them.
  #    with `set-clipboard on` an OSC 52 in this stream writes the human's
  #    clipboard, so the next paste is text the grove chose. the sink and its
  #    full reason live in `src/ductwork.sh`, sourced above via ~/.bash_aliases
  ####################################################################
  ssh -o BatchMode=yes "$GROVE" "cat \"$REPLY_OUT\"" 2>/dev/null | __duct_strip_escapes
  REPLY_CODE="$(ssh -o BatchMode=yes "$GROVE" "cat \"$REPLY_RC\"" 2>/dev/null | tr -d '[:space:]')"
  ssh -o BatchMode=yes "$GROVE" "rm -f \"$REPLY_OUT\" \"$REPLY_RC\"" 2>/dev/null

  # ⚠️ an unreadable rc is NOT a pass. the rc file existed a moment ago, so an
  #    empty read here means the file went away under us — report the break
  #    rather than default to 0 (`rule.forbid.failhide`)
  if [[ ! "$REPLY_CODE" =~ ^[0-9]+$ ]]; then
    echo "💥 the command finished and its exit code could not be read" >&2
    echo "   ├─ rc file: $REPLY_RC (was present, then unreadable)" >&2
    echo "   └─ ⇒ its output is above; the verdict is not knowable, so this" >&2
    echo "        refuses to report a pass it never saw" >&2
    exit "$GROVE_SEND_NO_VERDICT"
  fi

  exit "$REPLY_CODE"
fi

# the duct path: a play was landed above, so hand the duct the command that runs it
[[ -n "$PLAY" ]] && ARGS+=(--what "$WHAT")

git_alias_grove send "${ARGS[@]}"
