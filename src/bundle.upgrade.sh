#!/usr/bin/env bash
######################################################################
# the bundle runtime — ONE operation, at every depth
#
# .what = `bundle.upgrade <slug>` looks up the function the slug names, and calls
#         it. that is all it does.
#
#         a body is free to do either, and the runtime does not care which:
#           dispatch      `bundle.upgrade <child>` for each part it composes
#           do the work   the packages, the copies, the checks
#
#         so a phase is a bundle too, and the tree is turtles all the way down.
#
# .why no node kinds, and no tally
#         `bundle_composite` / `bundle_leaf`, an exit code 5, and a rule about
#         which kind may read the environment all exist to keep a COUNT honest.
#         the count IS the defect: a parent scored `0` lands in `ran` beside its
#         children, so `4.3.kitty` prints ✔ on a headless box whose only
#         applicable child was skipped.
#
#         each body already reports its own outcome with the fix named
#         (rule.require.errors-name-the-fix). that is the report. the run's exit
#         code says whether anything failed, which is the one fact a caller needs.
#
# .the mode gate lives HERE
#         a slug's trailing verb says whether it mutates: `upsert` writes,
#         `verify` reads. so `--mode plan` is one test against the name, in one
#         place — not a `[[ $GROVE_MODE == apply ]]` guard copied into every
#         upsert body.
#
# .requires — what the SOURCER must set first
#   WHAT=()          the `--what` allowlist; empty means every bundle
#   GROVE_MODE      plan|apply
#   grove_env_*     the predicates a body may read (grove.env.sh)
#
# usage:
#   source bundle.upgrade.sh
#   bundle.upgrade 2.shell               # from the driver, or from any body
######################################################################

# the depth of the current dispatch, for the report's indent
BUNDLE_DEPTH=0

# whether any bundle failed. a single bit for the run's exit code — not a count
BUNDLE_FAILED=0

######################################################################
# the bundles whose phase chain has already broken, space-delimited
#
# ⚠️ .why this is `BUNDLE_BROKEN` and not `BUNDLE_LEAF_BROKEN`
#      it was the latter when first written, on 2026-07-31, and that was a drift
#      back toward a split this repo deleted the day before.
#
#      `grove.provision._.sh` states the model outright: *"there are NO node kinds.
#      no leaf, no composite, no tag, no tally."* a phase IS a bundle, so what is
#      recorded here is a bundle — specifically the PARENT of the phase that failed.
#
#      `leaf` reads as a KIND, and a kind is what produced `bundle_composite` /
#      `bundle_leaf`, the third exit code, and the tally that let `4.3.kitty` print
#      ✔ on a box whose only applicable child was skipped. the word in a runtime
#      identifier invites that belief straight back in.
#
#      the ~30 `leaf` mentions in bundle COMMENTS are left alone and are fine — a
#      comment may name a concept from another angle (rule.forbid.domain-term-
#      synonyms). an IDENTIFIER is a contract, and a contract takes the canonical
#      word. see the dispute in `term=bundle._.choice.reason.md`
#
# ⚠️ .what problem this exists to solve
#      a bundle's four phases are a CHAIN, not a set: `provision.upsert` makes the
#      subject exist, `provision.verify` proves it, `configure.upsert` shapes it,
#      `configure.verify` proves that. each one presumes the one before it.
#
#      so when the first fails, the rest fail too — and each prints its own ✋
#      with its own fix line, all of which name the SAME repair. measured on this
#      laptop 2026-07-30, `5.9.yubikey` printed:
#
#        ✋ yubikey-agent is absent from PATH      fix: --what 5.9.yubikey --mode apply
#        ✋ ykman is absent from PATH              fix: --what 5.9.yubikey --mode apply
#        ✋ no agent socket at /run/user/…         fix: --what 5.9.yubikey --mode apply
#
#      three failures, three identical fixes, ONE cause: it was never installed.
#      a reader cannot tell which line is the root and which are its shadows, so
#      the report's volume is inversely related to its usefulness.
#
# .why this is a failhide problem behind the opposite mask
#      `rule.forbid.failhide` forbids a defect that hides. this is a defect that
#      SHOUTS — three times — and the noise buries the one line that matters.
#      both end the same way: the reader cannot act on what the run told them.
#
# .why it is a variable and not a `||` in each bundle's `_.sh`
#      the alternative is `bundle.upgrade a && bundle.upgrade b && …` in all 43
#      dispatchers. that is 43 files to hold one rule, and 43 places for it to be
#      forgotten on the next bundle somebody adds
#      (rule.require.bundle-as-sole-declaration, read at the runtime's level)
######################################################################
BUNDLE_BROKEN=""

######################################################################
# which `--what` entries actually reached a bundle
#
# ⚠️ .why this exists
#      the scope test below skips a slug that no `--what` entry matches. so a
#      `--what` that names NO bundle — a typo, or a bare function name where a
#      concern is not a bundle — matches every slug against an empty number,
#      runs zero bundles, and the run prints "🌲 done" and exits 0.
#
#      that is the failhide shape this repo forbids: the human asked for work,
#      none was done, and the run said it converged. worse, the two cases look
#      identical — `--what 2.6.starship` on a converged box is also quiet — so a
#      typo is indistinguishable from a no-op.
#
#      ⚠️ this is NOT a COVERAGE tally. a tally that counts bundles lets a
#      parent's `0` read as coverage its children never had. this records one
#      fact per ARGUMENT: did the human's
#      request reach anything at all. the run's report is still each body's own
######################################################################
BUNDLE_WHAT_HIT=()

######################################################################
# the OPT-IN set — the apps a run was asked to install, by `--include`
#
# 🛑 .why an app needs a second axis at all, when `--what` already scopes a run
#      `--what` asks WHICH BUNDLES RUN. `--include` asks, of a bundle that IS
#      running, whether the human wants the thing it installs. they are different
#      questions and a run needs both: a bare `grove.provision` must still visit
#      `6.apps` — that is how its verifies report — while it installs no client
#      nobody asked for.
#
#      ⚠️ the two are deliberately NOT collapsed into one flag. to spell an
#      opt-in as `--what 6.2.codium` would mean a run that names ONE app scopes
#      the whole tree down to it, so a human could not both converge their box
#      and install an editor in one command — and one command is the bar
#      (`rule.require.one-command-provision`).
#
# .why the DEFAULT is none
#      these are a human's desktop clients, and a human's taste is not a fact
#      about the machine. every other bundle in the tree converges a box toward
#      one declared state; these five install a preference. so the tree declares
#      what is AVAILABLE and the command declares what is WANTED.
#
# ⚠️ .what this does NOT do: it never uninstalls. an app dropped from `--include`
#      is simply not upgraded — the opposite would make a forgotten flag
#      destructive, which `rule.require.safe-by-default` forbids
######################################################################
GROVE_INCLUDE=()
GROVE_INCLUDE_HIT=()

######################################################################
# the app names this checkout OFFERS — appended by each bundle that owns one
#
# 🛑 .why an ARRAY the bundles append to, and not a list in the entrypoint
#      a list beside the parser would be a SECOND declaration of what the tree
#      already holds, and it would go stale the day an app is added — with no
#      signal, because a name absent from it is indistinguishable from a typo
#      (`rule.require.bundle-as-sole-declaration`).
#
#      the entrypoint sources every bundle file before it dispatches, so a
#      bundle that appends here IS the declaration, and the parser validates
#      against a set the tree built.
######################################################################
GROVE_OPTIN_APPS=()

######################################################################
# .what = did the human ask for this app?  `grove_optin spotify`
# .why  = one predicate, so five bundles cannot each answer it differently
#
# ⚠️ it records the HIT against the `--include` entry that matched, which is what
#    lets the entrypoint tell "installed none because none were asked for" from
#    "installed none because the name was a typo". without that, a misspelled
#    `--include codum` would decline every bundle and the run would report 🌲 done
#    (`rule.forbid.failhide`)
######################################################################
grove_optin() {
  local want="$1" i
  for i in "${!GROVE_INCLUDE[@]}"; do
    if [[ "${GROVE_INCLUDE[$i]}" == "$want" ]]; then
      GROVE_INCLUDE_HIT[$i]=1
      return 0
    fi
  done
  return 1
}

######################################################################
# .what = the line a bundle prints when an app it owns was not asked for
# .why  = a decline, never a claim. the box is not wrong; it was not asked
#
#         one helper so all five read identically, and so the `--include` fix is
#         spelled at the point a reader meets the absence
#         (`rule.require.errors-name-the-fix`)
#
# 🛑 .why it pads ITSELF, and is called only from a bundle's `_.sh` body
#      the runtime's `sed` pad wraps a PHASE and never a parent — see the
#      `.why only a PHASE is wrapped` note below. so a parent's own lines are
#      printed raw, and a decline from one must carry the indent its siblings
#      get for free, or it lands at column 3 while the bundle it speaks for sits
#      six levels in.
#
#      ⚠️ the corollary is that a PHASE must not call this: its output is
#      already padded, so the two pads would stack. a bundle whose apps are all
#      opted out declines at the bundle, and its phases then never run — which
#      is also why no phase needs to say it twice.
#
#      the arithmetic: a bundle's header was printed at `(depth + 1) * 3` and
#      `depth` was then incremented, so from inside the body the header sits at
#      `BUNDLE_DEPTH * 3` and its content one level further in
######################################################################
grove_optin_decline() {
  local names="$1" flags="${2:-$1}"
  printf '   %*s🌙 %s — not opted in; add it with: grove.provision --include %s\n' \
    $(( (BUNDLE_DEPTH + 1) * 3 )) '' "$names" "$flags"
}

######################################################################
# .what = the function a slug names — `2.6.starship` → `grove_provision_2_6_starship`
# .why  = the slug is the identity a human types; the shell needs a legal
#         identifier. derived in one place, so the two cannot drift
######################################################################
bundle.fn.of() { echo "grove_provision_${1//./_}"; }

######################################################################
# .what = the NUMERIC PATH a slug carries — `4.3.1.terminfo` → `4.3.1`
#
# .why  = the number is the slug's position in the tree; the name after it is a
#         label on that node. so ancestry — "does `--what 4.3.kitty` reach
#         `4.3.1.terminfo`?" — is a question about the numbers alone.
#
#         a value with no leading digits (a bare function name) yields the empty
#         string, which callers read as "not a slug"
######################################################################
bundle.num.of() {
  local seg num=""
  local IFS='.'
  for seg in $1; do
    [[ "$seg" =~ ^[0-9]+$ ]] || break
    num="${num:+$num.}$seg"
  done
  echo "$num"
}

######################################################################
# .what = the PATH BINARY a name resolves to — blind to functions and aliases
#
# ⚠️ .why a bare `command -v` is not enough
#         `2.7.aliases` declares shell functions that carry the SAME NAME as a
#         real binary — `nvim` (the memory cap), `usql` (the keyrack wrapper),
#         `npm`, `npx`, `tsx`. `command -v` answers a function with its bare
#         NAME and exits 0, so a verify that asks `command -v usql` is told yes
#         by the alias file, not by the box.
#
#         measured 2026-07-30 on this laptop: `5.11.usql.provision.verify`
#         reported "usql is on PATH at the WRONG version" while `usql --version`
#         exited 127, command not found. the binary was ABSENT; the function
#         answered for it. the verify named the wrong defect AND the wrong fix.
#
# ⚠️ .why it is declared HERE and not repeated per phase
#         the first fix for this was an `unset -f nvim` written inline at the one
#         call site that had been caught. a second call site in the SAME bundle
#         kept the defect, and `5.11.usql` was written later with it fresh — so a
#         per-site guard was measured, twice, to be forgettable.
#
#         one helper is not forgettable in the same way: a phase either routes
#         through it or plainly does not (rule.require.solve-at-cause).
#
# .why  a subshell
#         `unset -f` in the caller's shell would DELETE the human's alias for the
#         rest of the run. the subshell makes the blindness local to the question
######################################################################
bundle.bin.of() { ( unset -f "$1" 2>/dev/null; command -v "$1" 2>/dev/null ); }

######################################################################
# .what = the path of a bin THIS TREE DECLARES — a fact about the BOX
#
# 🛑 .why `bundle.bin.of` CANNOT answer for a bin the same run just placed
#         a process inherits `$PATH` at exec time and never re-reads it. so an
#         upsert that writes `~/.local/bin/<name>` has changed the BOX, and the
#         `$PATH` of the shell that is mid-run was captured before the file
#         existed. `command -v` asks the PROCESS; the claim is about the BOX.
#
# ⚠️ .measured 2026-08-12, grove-ahbode-v20260811, FIRST apply on a fresh box.
#      the contradiction printed two lines apart, on one screen:
#
#        ├─ 5.11.usql.provision.upsert
#           • usql 0.19.14 installed → /home/camper/.local/bin/usql   ← the BOX has it
#        ├─ 5.11.usql.provision.verify
#        ✋ usql is absent from PATH                                   ← the PROCESS does not
#
#      six rows carried that one defect (the three finders, the two usage
#      commands, usql). every one cleared on a SECOND apply, because the second
#      process exec'd with `~/.local/bin` already on its inherited PATH.
#
# 🛑 a second apply is NOT the fix. `rule.require.one-command-provision` asks for
#   ONE apply per seat, so a claim that only a re-run clears means the bar is
#   unmet — and the failure is invisible to anyone who habitually runs it twice.
#
# .why  it FALLS BACK to PATH rather than to `~/.local/bin` alone
#       a bin may legitimately live elsewhere (a distro package in /usr/bin), and
#       this operation must serve that box too. the declared path is asked FIRST
#       because it is the one place this repo's own upserts write.
#
# ⚠️ .when to reach for `bundle.bin.of` INSTEAD
#      when the question genuinely is "will a future shell find this" — a reach
#      claim, not a presence claim. say so at the call site when you do, because
#      a fresh box's first run cannot answer that one
#      (`gotcha.a-tool-found-by-path-answers-only-a-human`).
######################################################################
bundle.bin.at() {
  local declared="$HOME/.local/bin/$1"
  if [[ -x "$declared" ]]; then
    printf '%s\n' "$declared"
    return 0
  fi
  bundle.bin.of "$1"
}

######################################################################
# .what = say that a BOX-WIDE fact does not hold and this seat cannot set it —
#         the 🌙 a seat without root owes, declared once
#
# 🛑 .why it exists — measured on a two-seat grove, 2026-08-12
#         a grove has two seats. `ground` holds NOPASSWD sudo; the `camper` —
#         the seat that does the work — holds none, by design (`term=seat`).
#
#         an upsert that writes a box-wide fact and asserts root FIRST fails the
#         camper's phase, and every later phase of that bundle is skipped — over
#         a fact `ground` had already set, with the same bundle, minutes
#         earlier. and the ✋ it prints names two HAND STEPS on the provision
#         path:
#
#           · run this from a terminal, so sudo can prompt you
#           · on a grove, give the user NOPASSWD for apt-get
#
#         both are blockers under `rule.require.one-command-provision`, and
#         neither is owed by anyone.
#
# .the ORDER this exists to make cheap
#         | step | asks                                    | root? |
#         |------|-----------------------------------------|-------|
#         | 1    | does the box-wide fact already hold?     | never |
#         | 2    | it holds → `•` and return 0              | —     |
#         | 3    | it does not, and no root here → THIS      | —     |
#         | 4    | it does not, and root is here → set it    | yes   |
#
#         step 1 is always free: every box-wide fact has a read-only query
#         (`update-alternatives --query`, `sysctl -n`, `cmp` on a unit file).
#         `pkg_install` has had this order since 2026-08-10; a DIRECT `sudo`
#         is what still needs it.
#
# ⚠️ .why it returns 0
#         a seat that cannot make a box-wide claim has not FAILED — it has no
#         work to do. the grant has an owner, and the owner is the seat with
#         root, made to do it by this same bundle
#         (`rule.require.seam-claims-have-an-owner`). so this ends the phase
#         cleanly and lets its siblings run.
#
# usage:
#   pkg_can_sudo || { bundle.root.declines "the default terminal" \
#     "x-terminal-emulator → ${live:-（unset）}"; return 0; }
######################################################################
bundle.root.declines() {
  local subject="$1" observed="${2:-}"

  echo "   🌙 $subject is a BOX-WIDE fact, and this seat has no root"
  [[ -n "$observed" ]] && echo "      ⇒ $observed"
  echo "      ⇒ a seat converges its own \$HOME; this lives outside it, and the"
  echo "        seat with sudo runs this same bundle and sets it there"
  echo "      ⇒ no step is owed by this seat, and none by a human"
  return 0
}

######################################################################
# .what = may this seat write the box? — and if not, DECLINE and say so
#
# .why it exists beside the two halves it pairs
#         `pkg_can_sudo` answers, and `bundle.root.declines` reports. every
#         call site wants both, in the same order, with the same verdict — so
#         the pair is declared once rather than re-spelled at each site, where
#         it can drift (`rule.require.bundle-as-sole-declaration`).
#
# 🛑 .why EVERY direct `pkg_assert_sudo` in an upsert is wrong
#         a subject that needs root lives outside every `$HOME` — `/etc`,
#         `/opt`, `/usr/local`, a systemd unit, an apt source. that is the
#         definition of box-wide. a per-seat subject lives IN `$HOME` and wants
#         no sudo at all.
#
#         ⇒ so on a seat with no root, a `pkg_assert_sudo` in an upsert is
#           ALWAYS a decline wearing a ✋, and its fix-text is always wrong:
#
#             · run this from a terminal        — the camper holds no sudo entry,
#                                                 so a terminal changes it none
#             · sudo -v to warm the credential  — there is none to warm
#             · give the user NOPASSWD          — that is root-equivalent reach on
#                                                 the host, the precise power this
#                                                 seat exists WITHOUT (`term=seat`)
#
#         `4.5.nvim` recorded this falsehood in a comment on 2026-08-10 and kept
#         the ✋ that spoke it — an explanation written in place of a fix, which
#         is what `rule.forbid.deferred-provision-defects` forbids by name.
#
# ⚠️ .why a decline here cannot hide an unconverged box
#         the upsert declines; the bundle's own `*.verify` still reads the fact
#         and still ✋s when it is absent
#         (`rule.require.upgrade-entries-verify-themselves`). so the box's TRUTH
#         is reported either way, and no seat is blamed for a power it was
#         never given.
#
# exit:
#   0 = this seat can write the box; carry on into the root half
#   1 = it cannot; the 🌙 is printed, and the caller returns 0
#
# usage:
#   bundle.root.owns "the pinned kitty build" "kitty $have installed" || return 0
######################################################################
bundle.root.owns() {
  pkg_can_sudo && return 0
  bundle.root.declines "$@"
  return 1
}

######################################################################
# .what = drive one bundle
######################################################################
bundle.upgrade() {
  local slug="$1"
  local fn; fn="$(bundle.fn.of "$slug")"

  ####################################################################
  # the indent
  #
  # .why depth+1 and not depth
  #      the driver's header ends with `   └─ bundles` at one level of indent, and
  #      every top-level bundle is a CHILD of that line. at `BUNDLE_DEPTH * 3` a
  #      depth-0 bundle printed at the same indent as the word `bundles` itself, so
  #      the tree read flat — `2.shell` looked like a peer of the header rather
  #      than the first entry beneath it
  ####################################################################
  local pad=""; pad="$(printf '%*s' $(( (BUNDLE_DEPTH + 1) * 3 )) '')"

  ####################################################################
  # 1. in scope?
  #
  # .why the match is on the NUMBER and not the slug string
  #      ⚠️ a STRING prefix matched not one child: a slug is `<number>.<name>`,
  #      so `4.3.1.terminfo` is not prefixed by `4.3.kitty` — the name segment
  #      sits between them. `--what 4.3.kitty` dispatched the parent and skipped
  #      both children, in the filter written to prevent exactly that.
  #
  # .why BOTH directions
  #      a descendant asked for must still run its ANCESTORS, or no parent is
  #      there to dispatch it. a peer is an ancestor of neither, so it stays out.
  #      a phase's slug extends its parent's, so it shares the number and is
  #      never filtered out on its own — a human asks for a concern, not half one
  ####################################################################
  if [[ ${#WHAT[@]} -gt 0 ]]; then
    local wanted="false" i one onum snum
    snum="$(bundle.num.of "$slug")"
    for i in "${!WHAT[@]}"; do
      one="${WHAT[$i]}"
      if [[ "$slug" == "$one" ]]; then
        wanted="true"; BUNDLE_WHAT_HIT[$i]=1; break
      fi
      onum="$(bundle.num.of "$one")"
      [[ -z "$onum" ]] && continue        # a function name, not a slug; not ours
      if [[ "$snum" == "$onum" || "$snum" == "$onum".* || "$onum" == "$snum".* ]]; then
        wanted="true"; BUNDLE_WHAT_HIT[$i]=1; break
      fi
    done
    [[ "$wanted" == "true" ]] || return 0
  fi

  ####################################################################
  # 2. declared?
  #
  # .why loud: an undeclared slug means its file did not source — a typo, or a
  #      bundle dir that never arrived. a silent return would read as "this box
  #      needed no work" (rule.forbid.failhide)
  ####################################################################
  if ! declare -F "$fn" &>/dev/null; then
    echo "   $pad✋ $slug — undeclared; its bundle dir did not source" >&2
    BUNDLE_FAILED=1
    return 1
  fi

  ####################################################################
  # 3. has an EARLIER phase of this same bundle already failed?
  #
  # see `BUNDLE_BROKEN` above for the cascade this prevents.
  #
  # ⚠️ .why APPLY only, and never under plan
  #      the two modes ask opposite questions.
  #
  #      `--mode plan` is a SURVEY: it skips every upsert, so a verify that fails
  #      is the expected voice of an unconverged box. to break the chain there
  #      would hide the rest of the work a human asked to see — the plan would
  #      report one item and fall silent, which is the failhide shape itself.
  #
  #      `--mode apply` is an ACT: the upsert ran and did not take, so every
  #      later phase would act on a base that is known broken. there the cascade
  #      is noise, and the first failure is the whole story.
  ####################################################################
  # the phase's PARENT bundle — `2.8.tmux.configure.upsert` → `2.8.tmux`
  local parent=""
  if [[ "$slug" == *.upsert || "$slug" == *.verify ]]; then
    parent="${slug%.*}"; parent="${parent%.*}"
    if [[ "${GROVE_MODE:-apply}" == "apply" \
       && " $BUNDLE_BROKEN " == *" $parent "* ]]; then
      echo "   $pad├─ $slug — skipped; an earlier phase of $parent failed"
      return 0
    fi
  fi

  ####################################################################
  # 4. does it mutate, and is this a plan?
  #
  # a verify still RUNS under plan — "what does this box already hold?" is the
  # most useful thing a plan can say
  ####################################################################
  if [[ "$slug" == *.upsert && "${GROVE_MODE:-apply}" != "apply" ]]; then
    echo "   $pad├─ $slug — would run (plan)"
    return 0
  fi

  ####################################################################
  # 5. call it — with a PHASE's own output indented to its depth
  #
  # ⚠️ .why the redirect is `exec > >(sed -u …)` and NOT `"$fn" | sed -u …`
  #      a pipe puts the PHASE in a subshell, and a phase's exports carry weight
  #      here: `5.1.node/provision.upsert.sh` does
  #
  #        export PATH="$HOME/.local/share/fnm:…"
  #        eval "$(fnm env --shell bash)"
  #
  #      precisely so the phases AFTER it can see fnm, node, and pnpm. piped,
  #      both die with the subshell, and `5.1.node.provision.verify` would then
  #      call node absent on a box that had just installed it — a false ✋.
  #
  #      `exec > >(…)` inverts which side is forked: the FILTER is the subshell,
  #      the phase stays in this shell.
  #
  #      measured 2026-07-30, both forms side by side: `cmd | sed` runs the phase
  #      in a subshell, so an `export` inside it reaches no later phase; `exec >
  #      >(sed)` leaves the phase in this shell and its exports stand. re-run that
  #      pair before you doubt this — two `export X=1; echo $X` phases is enough.
  #
  # ⚠️ .why `sed -u` and not `sed`
  #      GNU sed LINE-buffers to a tty and BLOCK-buffers to a pipe. a
  #      grove.provision run is piped to `tail` or `grep` constantly, so the block
  #      case is the common one — measured at a 2s stall before the first line
  #      appeared. on a `5.8.docker` apply that is minutes of dead terminal, and
  #      a human reaches for ctrl-c. `-u` is what makes the pad free.
  #
  # .why the fd is closed, and its pid awaited
  #      the filter is a separate process, so it can still hold output when
  #      stdout is restored — its last lines would then land after whatever the
  #      caller prints next. to close fd 1 gives sed its EOF; the wait lets it
  #      finish before the next line is written.
  #
  # .why only a PHASE is wrapped
  #      a parent's body only calls `bundle.upgrade` for its children, and each
  #      child already pads its own lines. to wrap a parent would add its pad on
  #      top of each child's, so depth would count twice per level.
  #
  # .why stderr is left alone
  #      a second `exec 2> >(…)` is a second pipe, and two pipes have no order
  #      between them — a ✋ could land above the `•` that preceded it. so the ✋
  #      lines keep the old indent, which also means a failure does not align
  #      with its siblings and therefore draws the eye. that is the outcome we
  #      want anyway.
  ####################################################################
  echo "   $pad├─ $slug"
  BUNDLE_DEPTH=$(( BUNDLE_DEPTH + 1 ))

  local code
  if [[ "$slug" == *.upsert || "$slug" == *.verify ]] \
     && command -v sed >/dev/null 2>&1; then
    local body_pad="$pad   "
    local pad_pid
    exec 3>&1
    exec > >(sed -u "s/^./$body_pad&/"); pad_pid=$!
    "$fn"
    code=$?
    exec 1>&3 3>&-
    [[ -n "$pad_pid" ]] && wait "$pad_pid" 2>/dev/null
  else
    "$fn"
    code=$?
  fi

  BUNDLE_DEPTH=$(( BUNDLE_DEPTH - 1 ))

  if [[ $code -ne 0 ]]; then
    BUNDLE_FAILED=1
    # remember WHICH bundle broke, so its later phases are skipped rather than
    # left to restate the same defect with the same fix (see the ⚠️ at the top)
    [[ -n "$parent" ]] && BUNDLE_BROKEN="$BUNDLE_BROKEN $parent"
  fi
  return $code
}
