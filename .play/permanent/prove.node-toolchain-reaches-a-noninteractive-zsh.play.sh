#!/usr/bin/env bash
######################################################################
# prove: the node toolchain reaches a NON-INTERACTIVE zsh, not a human's alone
#
# .what = one invariant, over the shell an AGENT actually gets:
#
#           `zsh -c` carries every half of the node toolchain that
#           `bash -lc` and `zsh -ic` carry.
#
#         the halves are two, and they are independent:
#           1. the `fnm` BINARY, on PATH
#           2. `FNM_MULTISHELL_PATH`, which only `fnm env` sets
#
# 🛑 .why a clamp and not a rule alone — measured 2026-09-19, issue #140
#
#    a converged grove, from an agent's non-interactive zsh:
#
#      $ which node fnm pnpm
#      …/aliases/default/bin/node     ← zshenv:166 ✔
#      fnm not found                  ← $FNM_DIR absent from PATH
#      …/aliases/default/bin/pnpm     ← zshenv:166 ✔
#
#    and with the binary forced on by hand, the second half surfaced:
#
#      $ fnm use
#      error: We can't find the necessary environment variables to replace
#      the Node version. You should setup your shell profile to evaluate
#      `fnm env`
#
#    ⇒ `~/.profile` held the CURRENT hook the whole time and was simply never
#      read — a non-interactive zsh reads `~/.zshenv` alone. so the claim was
#      declared, correct, and in the one file that shell does not open.
#
# 🛑 .why the clamp MUST boot `zsh -c`, and no other shell
#
#    the whole defect is that `zsh -ic` and `bash -lc` are HEALTHY. a verify
#    that runs in either reads ✔ over a box where every agent, cron, jest
#    child, and `zsh -c` finds `fnm: command not found`.
#    ⇒ a check that cannot see the break it names is a false ✔ by construction
#      (`gotcha.a-check-that-cries-wolf-gets-silenced`, the failhide half).
#
# ⚠️ .why the harm is INVISIBLE from a human's seat
#    a human at a keyboard reads `~/.zshrc`, gets both halves, and finds a
#    healthy box. the split reports itself only to callers who cannot speak
#    (`gotcha.a-tool-found-by-path-answers-only-a-human`).
#
# .the arms, and why NO ONE of them alone settles it
#   - arm 0  is LIVE: `zsh -c` finds the `fnm` binary
#   - arm 0b is LIVE: `zsh -c` carries `FNM_MULTISHELL_PATH`. a SECOND claim —
#     arm 0 can hold while this one reddens, and that is the exact state #140
#     measured once the binary was forced on by hand
#   - arm 0c is LIVE and END-TO-END: `fnm use` exits 0 from `zsh -c`. arms 0 and
#     0b are its two known preconditions; this one asks the tool itself, so a
#     third precondition nobody enumerated cannot hide from it
#   - arm 1  is STATIC: the TREE declares both halves in `zshenv.sh`. arm 0's
#     subject is the INSTALLED dotfile, so on an unconverged box arm 0 grades a
#     file this checkout does not own
#   - arm 2  is the PARITY claim: `zsh -c` and `bash -lc` agree. the defect is a
#     DIFFERENCE between two shells, and only a comparison can name one
#   ⇒ read all five in one run; accept no one of them alone
#     (`gotcha.a-check-that-cries-wolf-gets-silenced`, q10)
#
# .the rows
#   B   a non-interactive zsh lacks a half a login bash holds
#   B   the tree declares a half the installed rc does not, or the reverse
#
# guarantee:
#   - READ ONLY. it boots shells and reads the checkout; it writes no box state
#   - the one write is arm 0c's `mktemp -d` fixture, removed on a trap
#   - no network, no privilege, no remote reach — needs no grove, no credential
#
# usage:
#   rhx play.run --play prove.node-toolchain-reaches-a-noninteractive-zsh
######################################################################
set -uo pipefail

FAILED=0
_fail() { FAILED=1; }

_self="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)" || _self=""
if   [[ -n "$_self" && -f "$_self/src/grove.provision._.sh" ]]; then _root="$_self"
elif [[ -f "$PWD/src/grove.provision._.sh" ]];                 then _root="$PWD"
else                                                                _root="$HOME/git/more/dev-env-setup"
fi

echo ""
echo "🐢 prove: the node toolchain reaches a non-interactive zsh"
echo "   └─ root : $_root"
echo ""

######################################################################
# the shell every arm below boots
#
# ⚠️ `zsh -c`, never `zsh -ic` and never `bash -lc`. see the header: those two
#    are healthy on the very box this defect breaks, so either would read ✔
#
# 🛑 .why the environment is SCRUBBED — measured 2026-09-19, on this play's
#    own first run, before it had ever graded the fix it exists for
#
#    a bare `zsh -c` INHERITS every exported var its parent holds. run from a
#    human's terminal — or from an agent whose session began in one — the
#    parent already evaluated `fnm env`, so the child gets `fnm` on PATH and
#    `FNM_MULTISHELL_PATH` set, and neither came from `~/.zshenv` at all.
#
#      $ zsh -c 'command -v fnm'
#      /home/<user>/.local/share/fnm/fnm      ← inherited, never declared
#
#    ⇒ this play's first run read ✔ on three arms over a tree that declares
#      NEITHER half. a verdict about its own caller, dressed as a verdict
#      about the box (`gotcha.a-check-that-cries-wolf-gets-silenced`, q2).
#
#    #140's measurement was taken over ssh into a grove, where a fresh session
#    inherits no such var. `env -i` is what reproduces that faithfully here:
#    the shell then holds exactly what its rc files give it, and no more.
#
# ⚠️ HOME is kept because `.zshenv` is found through it, and an absent HOME
#    would make every arm fail for a reason that is not the defect
######################################################################
if ! command -v zsh >/dev/null 2>&1; then
  echo "   🌙 zsh is absent here, so no arm can boot the shell under test"
  echo "      ⇒ arm 1 is static and still holds below"
  ZSH_OK=0
else
  ZSH_OK=1
  ZSH_BIN="$(command -v zsh)"
  BASH_BIN="$(command -v bash)"
fi

# boot a zsh that holds ONLY what its rc files give it
_zsh_c() { env -i HOME="$HOME" USER="${USER:-$(id -un)}" TERM=dumb "$ZSH_BIN" -c "$1" 2>/dev/null; }

# the same, for a LOGIN bash — the shell that is healthy today, and the
# baseline arm 2 compares against
_bash_lc() { env -i HOME="$HOME" USER="${USER:-$(id -un)}" TERM=dumb "$BASH_BIN" -lc "$1" 2>/dev/null; }

######################################################################
# arm 0 — the `fnm` BINARY is on PATH, from `zsh -c`
#
# ⚠️ this is NOT the same claim as "node is on PATH". `aliases/default/bin`
#    holds node and pnpm and NOT fnm itself — `zshenv.sh:139` records the
#    measurement where that distinction cost a box its `command -v node`
######################################################################
echo "   arm 0 — 'zsh -c' finds the fnm binary"
if [[ "$ZSH_OK" == 1 ]]; then
  fnm_at="$(_zsh_c 'command -v fnm')"
  if [[ -n "$fnm_at" ]]; then
    echo "      ✔ fnm → $fnm_at"
  else
    echo "      ✋ 'zsh -c' finds no fnm binary" >&2
    echo "         ⇒ every agent, cron, jest child and 'zsh -c' on this box" >&2
    echo "           dies at 'fnm: command not found', while a human's shell" >&2
    echo "           is healthy — so no human report will ever surface it" >&2
    echo "         fix: declare the fnm BINARY dir in ~/.zshenv, then" >&2
    echo "              rhx grove.provision --what 2.5.zsh --mode apply" >&2
    _fail
  fi
fi
echo ""

######################################################################
# arm 0b — `FNM_MULTISHELL_PATH` is set, from `zsh -c`
#
# 🛑 a SECOND and INDEPENDENT claim. a fix that only puts the binary on PATH
#    passes arm 0 and leaves `fnm use` exactly as broken as it found it — #140
#    measured that state directly, by forcing the binary on at the prompt
#
# ⚠️ the var is a PER-SHELL symlink dir that `fnm env` mints fresh. a shared
#    constant would pass this arm and let two concurrent shells fight over one
#    node version, so arm 0c is what keeps this arm honest
######################################################################
echo "   arm 0b — 'zsh -c' carries FNM_MULTISHELL_PATH"
if [[ "$ZSH_OK" == 1 ]]; then
  ms="$(_zsh_c 'printf "%s" "${FNM_MULTISHELL_PATH:-}"')"
  if [[ -n "$ms" ]]; then
    echo "      ✔ FNM_MULTISHELL_PATH → $ms"
  else
    echo "      ✋ 'zsh -c' carries no FNM_MULTISHELL_PATH" >&2
    echo "         ⇒ 'fnm use' cannot replace a node version without it, so a" >&2
    echo "           repo's .nvmrc is unhonorable from every automated caller" >&2
    echo "         fix: eval \"\$(fnm env --shell zsh)\" in ~/.zshenv, then" >&2
    echo "              rhx grove.provision --what 2.5.zsh --mode apply" >&2
    _fail
  fi
fi
echo ""

######################################################################
# arm 0c — END TO END: `fnm use` exits 0 from `zsh -c`
#
# 🛑 .why it exists when arms 0 and 0b already passed
#    those two are the preconditions a READER could enumerate. this arm asks
#    the TOOL, so a third precondition nobody thought of cannot hide from it
#    (`gotcha.a-check-that-cries-wolf-gets-silenced`, q11 — a pattern reaches
#    only the shapes its author could see)
#
# ⚠️ the fixture pins a version fnm ALREADY holds, so the arm needs no download
#    and no network. a version fnm does not hold would make this arm a network
#    probe, which is a different claim and a slower one
#
# ⚠️ the version is read off `node-versions/`, NOT off `readlink aliases/default`
#    — that symlink resolves to `node-versions/<version>/installation`, so a
#    `basename` of it answers `installation` and pins a version fnm refuses:
#
#      error: Requested version installation is not currently installed
#
#    measured on this play's own first run. the arm reddened for its own defect
#    rather than the subject's, which is the false-✋ half
######################################################################
echo "   arm 0c — 'fnm use' exits 0 from 'zsh -c'"
if [[ "$ZSH_OK" == 1 ]]; then
  want_version=""
  for d in "${FNM_DIR:-$HOME/.local/share/fnm}"/node-versions/*/; do
    [[ -d "$d" ]] || continue
    want_version="$(basename "$d")"
    break
  done
  if [[ -z "$want_version" ]]; then
    echo "      🌙 fnm holds no installed node version here, so none can be pinned"
    echo "         ⇒ this arm is unproven on this box; arms 0 and 0b still hold"
  else
    fixture="$(mktemp -d)"
    trap 'rm -rf "$fixture"' EXIT
    printf '%s\n' "$want_version" > "$fixture/.nvmrc"
    if _zsh_c "cd '$fixture' && fnm use" >/dev/null; then
      echo "      ✔ fnm use honored .nvmrc ($want_version)"
    else
      why="$(env -i HOME="$HOME" USER="${USER:-$(id -un)}" TERM=dumb \
              "$ZSH_BIN" -c "cd '$fixture' && fnm use" 2>&1 | head -2)"
      echo "      ✋ 'fnm use' died from a non-interactive zsh" >&2
      echo "         it said: $why" >&2
      echo "         ⇒ any caller that honors a repo's .nvmrc dies here —" >&2
      echo "           'rhx declapract.upgrade exec' is where this was found" >&2
      _fail
    fi
  fi
fi
echo ""

######################################################################
# arm 1 — the TREE declares both halves, so a fresh box inherits them
#
# ⚠️ arms 0/0b/0c grade the INSTALLED `~/.zshenv`. that is a feature and a bound
#    at once: they measure the box a caller actually runs in, and on an
#    unconverged box they grade a file this checkout does not own. this arm ties
#    the two together, so a green box with a silent tree still reddens
######################################################################
echo "   arm 1 — src/…/2.5.zsh/zshenv.sh declares both halves"
zshenv="$_root/src/grove.provision/2.shell/2.5.zsh/zshenv.sh"
if [[ ! -f "$zshenv" ]]; then
  echo "      💥 no zshenv.sh at $zshenv" >&2
  echo "         ⇒ this run's own checkout is incomplete" >&2
  _fail
else
  ######################################################################
  # 🛑 the CODE, never the prose — measured on this play's own first run
  #
  #    `zshenv.sh:131` carries the sentence
  #
  #      .what stays in ~/.zshrc, deliberately: `eval "$(fnm env)"`, …
  #
  #    which says the OPPOSITE of what this arm asks, and a bare
  #    `grep 'fnm env'` matched it and reported ✔. a reader that cannot part
  #    a call from a comment about a call grades the comment
  #    (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.8).
  #
  # ⇒ so every line is stripped of its comment BEFORE the pattern reads it
  ######################################################################
  code="$(sed 's/#.*//' "$zshenv")"

  if printf '%s' "$code" | grep -qE 'FNM_BIN_DIR|-x[[:space:]]+"\$\{?FNM'; then
    echo "      ✔ the fnm binary dir is declared"
  else
    echo "      ✋ zshenv.sh declares no fnm BINARY dir" >&2
    echo "         it declares 'aliases/default/bin', which holds node and" >&2
    echo "         pnpm and NOT fnm itself" >&2
    _fail
  fi

  if printf '%s' "$code" | grep -qE 'eval[[:space:]]+"\$\(fnm env'; then
    echo "      ✔ fnm env is evaluated"
  else
    echo "      ✋ zshenv.sh never evaluates 'fnm env'" >&2
    echo "         ⇒ FNM_MULTISHELL_PATH reaches no non-interactive zsh" >&2
    _fail
  fi
fi
echo ""

######################################################################
# arm 2 — PARITY: every PATH dir a login bash holds, a `zsh -c` holds too
#
# 🛑 .why a comparison, when arms 0-0c already grade zsh absolutely
#    the defect's SHAPE is a difference between two shells on one box, and #140
#    names the class as wider than fnm: ANY claim that lives in `~/.profile` or
#    `~/.zshrc` and not `~/.zshenv` has this same split, latent.
#    ⇒ the absolute arms catch the fnm instance. this one catches the NEXT tool
#      to be declared in one file and not the other
#
# 🛑 .why it compares PATH DIRS and holds NO list of tools
#    this arm read `for tool in fnm node pnpm` until it was reviewed against
#    `rule.require.one-command-provision`, which grades a hand-written tool
#    list inside a reader that judges what reaches off the box a BLOCKER:
#    such a list cannot report the member nobody added.
#
#    ⇒ and this play would have been the worst place for one. its whole subject
#      is a claim that reached one shell and not another; a list of three names
#      is blind to the fourth by construction, which is m.12 — a count is a
#      claim about a set only as large as the reader's reach.
#
#    so the subject is DERIVED: both shells are asked for their own PATH, and
#    the arm reports every dir the login bash holds that the scrubbed zsh does
#    not. a tool added tomorrow, by a bundle nobody here anticipated, reddens
#    the day its dir lands in the wrong rc.
######################################################################
echo "   arm 2 — every PATH dir a login bash holds, a 'zsh -c' holds too"
if [[ "$ZSH_OK" == 1 ]]; then
  # ⚠️ the LAST line only. a login bash sources `/etc/profile.d/*`, and a member
  #    that prints on boot (`keynav started`, measured here) lands ahead of the
  #    answer — so a whole-stdout read reports a banner as a PATH
  zsh_path="$(_zsh_c 'printf "%s" "$PATH"' | tail -1)"
  bash_path="$(_bash_lc 'printf "%s" "$PATH"' | tail -1)"

  ####################################################################
  # the SUBJECT is a dir under $HOME, and that bound is derived rather
  # than listed — 🛑 measured on this arm's own first run
  #
  #    its first cut read EVERY dir and reddened on four, of which three were
  #    a false ✋: `/usr/local/sbin`, `/usr/sbin`, `/sbin`. those come from
  #    `/etc/profile`, which a LOGIN shell reads and `zsh -c` does not — the
  #    OS's claim, never this repo's, and no rc here can place them.
  #
  #    ⇒ the first repair was an exclusion list, and that is exactly the defect
  #      this arm had just removed from its own tool loop: a hand-written list
  #      cannot report the member nobody added. it was struck within the minute.
  #
  # ⇒ the bound that holds instead: **this repo writes PATH claims under $HOME
  #   and nowhere else.** a dir outside it belongs to the OS, so its absence
  #   from `zsh -c` names a login/non-login difference rather than a misplaced
  #   claim. one test, no list, and it cannot go stale.
  ####################################################################
  #
  # ⚠️ the fnm multishell dir is the one $HOME dir that MUST differ
  #    `fnm env` mints it per shell, on purpose — so bash's and zsh's never
  #    match, and an equality test over it argues against the isolation this
  #    fix exists to preserve. arm 0b grades that var directly and by name, so
  #    the claim is held; it is only unholdable HERE
  #    (`rule.require.exemptions-name-their-trigger`)
  MULTISHELL='/fnm_multishells/'

  split=0
  while IFS= read -r dir; do
    [[ -z "$dir" ]] && continue
    [[ "$dir" == "$HOME"/* ]] || continue          # the OS's dirs are not ours
    [[ "$dir" == *"$MULTISHELL"* ]] && continue    # per-shell by design
    case ":$zsh_path:" in
      *":$dir:"*) ;;
      *)
        echo "      ✋ $dir — a login bash holds it, 'zsh -c' does not" >&2
        echo "         ⇒ a PATH claim declared in ~/.profile and not ~/.zshenv;" >&2
        echo "           every tool in that dir is absent from every agent" >&2
        split=1
        _fail
        ;;
    esac
  done < <(printf '%s' "$bash_path" | tr ':' '\n')

  [[ "$split" == 0 ]] && echo "      ✔ no \$HOME PATH dir reaches a login bash alone"
fi
echo ""

######################################################################
# arm 3 — the COST BOUND `~/.zshenv` declares for itself
#
# 🛑 .why the fix owes this arm — issue #140 left it as an open judgment call
#
#    `zshenv.sh` states its own budget in its header:
#
#      .zshenv runs on every zsh, including hot paths. it must hold no prompt
#      work, no completion load, and no command that costs more than a test.
#
#    and the fix for #140 adds `eval "$(fnm env --shell zsh)"`, which FORKS a
#    binary — the first thing in that file to exceed a test. so the budget is
#    no longer self-evident, and a sentence in a header cannot hold it.
#
# ⇒ the call is settled the only way a budget can be: by a CHECK, so the next
#   author who reaches for a heavier line learns it from a red row rather than
#   from a comment they were free to read past.
#
# ⚠️ .why the bound is LENIENT, deliberately
#    a timing arm on a loaded box is the classic flaky check, and a flaky check
#    gets silenced — after which it guards naught
#    (`gotcha.a-check-that-cries-wolf-gets-silenced`). the regression this
#    guards against is a SHAPE — a network call, an install probe, a
#    completion load — which costs seconds, never milliseconds. so the bound
#    is set far above the honest cost and still catches every such shape.
######################################################################
echo "   arm 3 — ~/.zshenv stays inside its declared cost budget"
if [[ "$ZSH_OK" == 1 ]]; then
  BUDGET_MS=400
  t0=$(date +%s%N)
  for _ in 1 2 3 4 5; do _zsh_c true; done
  t1=$(date +%s%N)
  each_ms=$(( (t1 - t0) / 5000000 ))
  if [[ "$each_ms" -le "$BUDGET_MS" ]]; then
    echo "      ✔ a scrubbed 'zsh -c true' costs ${each_ms}ms (budget ${BUDGET_MS}ms)"
  else
    echo "      ✋ a scrubbed 'zsh -c true' costs ${each_ms}ms, over its ${BUDGET_MS}ms budget" >&2
    echo "         ⇒ ~/.zshenv runs on EVERY zsh, so this is paid by every" >&2
    echo "           nested shell, every jest child, and every duct send" >&2
    echo "         fix: the newest line in zshenv.sh is the suspect — it must" >&2
    echo "              hold no network call, no install probe, no completion load" >&2
    _fail
  fi
fi
echo ""

######################################################################
# the verdict
######################################################################
if [[ "$FAILED" == 0 ]]; then
  echo "🌲 the node toolchain reaches every zsh ✔"
  exit 0
fi
echo "✋ a non-interactive zsh lacks a half a human's shell holds" >&2
echo "   ⇒ the split is invisible from a keyboard; every automated caller pays it" >&2
exit 1
