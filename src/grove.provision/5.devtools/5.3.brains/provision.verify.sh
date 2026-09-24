#!/usr/bin/env bash
######################################################################
# .what = prove all three brains are reachable — claude, rhachet (rhx), codex —
#         and that the CANDIDATE claude (`claude.latest`) matches what the tree
#         declares, without any part of it reaching the pinned default
#
# ⚠️ each brain is asked SEPARATELY
#   - one status for three installs names no partial part
#   - ⇒ the gap between "the brains step failed" and "codex is absent"
#
# ⚠️ `command -v` is not the whole claim
#   - a pnpm global bin is a SHIM whose target lives under the global store
#   - a partial `pnpm rm`, a node bump, or a pruned cache kills that target
#   - ⇒ the shim survives, so `command -v` still finds it
#   - ⇒ the shim is RUN, and 126/127 is the one proof no other check gives
#
# .any OTHER exit code is not a failure
#   - a CLI may not support `--version`, or may need a subcommand
#   - ⇒ to fail on that asserts a cli contract this repo does not own
#   - (`gotcha.a-check-that-cries-wolf-gets-silenced`)
#
# .each run is BOUNDED, since a shim on a network store can block outright
#   - (`rule.require.bounded-probes-in-verifies`)
#
# guarantee:
#   - READ-ONLY: it observes and mutates no state
######################################################################

GROVE_BRAIN_PROBE_SECONDS=20

grove_provision_5_3_brains_provision_verify() {
  local failed=0
  local pair name bin rc

  ####################################################################
  # .the BINARY names differ from the package names
  #   - `rhachet` ships `rhx` and `@openai/codex` ships `codex`
  #   - a check against a package name would report a defect on a healthy box
  ####################################################################
  for pair in \
    "claude:claude-code — the brain this session runs on" \
    "rhx:rhachet — every skill in this repo is driven through it" \
    "codex:codex — the second brain, for a cross-read"; do
    bin="${pair%%:*}"
    name="${pair#*:}"

    if ! command -v "$bin" >/dev/null 2>&1; then
      echo "   ✋ $bin is absent from PATH" >&2
      echo "      ⇒ $name" >&2
      echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
      failed=1
      continue
    fi

    # see the header: only 126/127 prove the shim's target is gone
    timeout -k 5 "$GROVE_BRAIN_PROBE_SECONDS" "$bin" --version >/dev/null 2>&1 && rc=0 || rc=$?

    case "$rc" in
      126|127)
        echo "   ✋ $bin is on PATH but does NOT run (exit $rc)" >&2
        echo "      ⇒ $name" >&2
        echo "      ⇒ the pnpm global bin is a shim; its target under the global" >&2
        echo "        store is gone, so 'command -v' finds it and every call dies" >&2
        echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
        failed=1
        ;;
      124)
        echo "   🌙 $bin is on PATH but did not answer within ${GROVE_BRAIN_PROBE_SECONDS}s"
        echo "      ⇒ unproven, not disproven — a loaded box or a slow store"
        ;;
      *)
        echo "   • $bin is on PATH and runs ✔"
        ;;
    esac
  done

  ####################################################################
  # ⚠️ the pin is asked of the BINARY, never of the package metadata
  #   - 📜 2026-07-31: `pnpm list -g` and package.json both said 2.1.87, and the
  #     cli that ran said 2.1.220 — the in-place updater rewrites only `cli.js`
  #   - ⇒ a check on the package answers ✔ on a drifted box, and cannot fail
  #   - (`gotcha.a-check-that-cries-wolf-gets-silenced`, from the other side)
  #
  # .a drift here is a real defect, since every guardrail here is a claude hook
  #   - hooks are TRUNCATED beyond the pin
  #   - ⇒ a floated claude may quietly stop enforcement
  ####################################################################
  if command -v claude >/dev/null 2>&1; then
    local claude_live
    claude_live="$(timeout -k 5 "$GROVE_BRAIN_PROBE_SECONDS" claude --version 2>/dev/null \
      | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"

    if [[ -z "$claude_live" ]]; then
      # ⚠️ stdout, though the ✋ branch below uses stderr
      #   - a 🌙 is a NON-claim, and a healthy run is full of them
      echo "   🌙 claude runs, but did not answer a version this run"
      echo "      ⇒ the pin ($GROVE_BRAIN_CLAUDE_PIN) is unproven here, not disproven"
    elif [[ "$claude_live" == "$GROVE_BRAIN_CLAUDE_PIN" ]]; then
      echo "   • claude is $claude_live, the declared pin ✔"
    else
      echo "   ✋ claude is $claude_live, but the declared pin is $GROVE_BRAIN_CLAUDE_PIN" >&2
      echo "      ⇒ hooks are TRUNCATED beyond the pin, and every guardrail in" >&2
      echo "        this repo is a hook — so a floated claude is a box whose" >&2
      echo "        checks may quietly stop enforcing" >&2
      echo "      ⇒ pnpm may STILL report the pin: the in-place updater rewrites" >&2
      echo "        cli.js and leaves package.json alone. the binary is the truth" >&2
      echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
      echo "      then confirm the updater is off: jq .env ~/.claude/settings.json" >&2
      failed=1
    fi
  fi

  ####################################################################
  # the codex pin, asked of the BINARY for the same reason claude's is
  #
  # ⚠️ this arm exists because a pin with no reader is prose
  #   - 📜 the claude pin lived in a comment, and a drifted box read ✔ for months
  #
  # ⚠️ a mismatch is a ✋, never a 🌙
  #   - a floated codex is an unreviewed third-party publish, live on this box
  ####################################################################
  if command -v codex >/dev/null 2>&1; then
    local codex_live
    codex_live="$(timeout -k 5 "$GROVE_BRAIN_PROBE_SECONDS" codex --version 2>/dev/null \
      | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"

    if [[ -z "$codex_live" ]]; then
      echo "   🌙 codex runs, but did not answer a version this run"
      echo "      ⇒ the pin ($GROVE_BRAIN_CODEX_PIN) is unproven here, not disproven"
    elif [[ "$codex_live" == "$GROVE_BRAIN_CODEX_PIN" ]]; then
      echo "   • codex is $codex_live, the declared pin ✔"
    else
      echo "   ✋ codex is $codex_live, but the declared pin is $GROVE_BRAIN_CODEX_PIN" >&2
      echo "      ⇒ codex is a THIRD-PARTY registry package that reads this repo" >&2
      echo "        and runs shell commands, so an unreviewed publish lands here" >&2
      echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
      echo "      or, if the drift is wanted: bump GROVE_BRAIN_CODEX_PIN first" >&2
      failed=1
    fi
  fi

  ####################################################################
  # rhachet's PEERS — asked by a REQUIRE, because every cheaper probe is blind
  #
  # ⚠️ this claim needs its own check
  #   - `rhx --version` answers ✔ with the peers absent, since it loads no rack
  #   - ⇒ a box passes every line above and still reads no credential
  #   - 📜 grove-1 2026-08-06, seen by a human as "git asked me for a password"
  #
  # ⚠️ a REQUIRE, never a lookup, a `pnpm list`, or a keyrack call
  #   - 📜 measured on grove-1 with `declastruct` removed, by which probe REDDENS:
  #
  #       pnpm list / keyrack list / keyrack status   🌙 blind
  #       keyrack get of an ABSENT key                🌙 blind — absence
  #                                                      short-circuits before
  #                                                      the vault is built
  #       require.resolve('declastruct-aws')          🌙 blind — the FIRST hop
  #                                                      is found; the broken
  #                                                      link was one deeper
  #       keyrack get of the REAL slug                💥 bites — needs a credential
  #       keyrack unlock                              💥 bites — mutates state
  #       require('declastruct-aws')                  💥 bites — and costs neither
  #
  #   - ⇒ the require is the only probe that fails the way the defect fails
  #   - it stays read-only, needs no secret, and reaches past the first hop
  #
  # ⚠️ a LIVE DAEMON hides this, since an unlocked value comes from its memory
  #   - 📜 grove-1 cloned at 02:13 and was dead by 10:31, rack untouched between
  #   - ⇒ the 540m session lapsed, and only the re-unlock needed the peer
  #   - ⇒ a check run while a session is warm proves none of it
  ####################################################################
  local rhachet_dir peer_rc
  rhachet_dir="$(timeout -k 5 "$GROVE_BRAIN_PROBE_SECONDS" pnpm root -g 2>/dev/null)/rhachet"

  if [[ ! -d "$rhachet_dir" ]]; then
    echo "   🌙 rhachet's global dir was not found, so its peers are unproven"
    echo "      ⇒ looked for: $rhachet_dir"
  else
    timeout -k 5 "$GROVE_BRAIN_PROBE_SECONDS" node -e \
      "require('module').createRequire('$rhachet_dir/package.json')('declastruct-aws')" \
      >/dev/null 2>&1 </dev/null && peer_rc=0 || peer_rc=$?

    if [[ "$peer_rc" -eq 0 ]]; then
      echo "   • rhachet's vault peers load ✔ (declastruct-aws → declastruct)"
    elif [[ "$peer_rc" -eq 124 ]]; then
      echo "   🌙 the peer require did not answer within ${GROVE_BRAIN_PROBE_SECONDS}s"
      echo "      ⇒ unproven, not disproven — a loaded box or a cold store"
    else
      echo "   ✋ rhachet's vault peers do NOT load (exit $peer_rc)" >&2
      echo "      ⇒ a global 'pnpm install -g rhachet' pulls in none of its optional" >&2
      echo "        peers, and the chain is rhachet → declastruct-aws → declastruct" >&2
      echo "      ⇒ what this costs: the 'aws.params' vault errors, so a box cannot" >&2
      echo "        read @all.camp.GITHUB_TOKEN — no clone, no gh, no discovery" >&2
      echo "      ⚠️ this stays INVISIBLE while a keyrack session is warm: an" >&2
      echo "         unlocked value is served from the daemon's memory. the box" >&2
      echo "         goes quiet whenever that session lapses (540m), which looks" >&2
      echo "         to a human like github broke overnight" >&2
      echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
      failed=1
    fi
  fi

  ####################################################################
  # 🔴 the shadow that would make a candidate the DEFAULT, silently
  #
  # `~/.zshrc` prepends `~/.local/bin` AFTER `.zshenv` laid down $PNPM_HOME/bin,
  # so that dir outranks the pnpm shims in a human's shell. a file named
  # `claude` there therefore BECOMES the default, and every check above still
  # reads the pnpm copy the tree declares — so the swap is invisible to all of
  # them, which is what makes this its own claim.
  #
  # ⚠️ asked on EVERY run, opted in or out. it grades a hazard about the
  #   DEFAULT, so the candidate's flag has no bearing on whether it applies
  ####################################################################
  if [[ -e "$HOME/.local/bin/claude" ]]; then
    echo "   ✋ a file named 'claude' sits in ~/.local/bin" >&2
    echo "      ⇒ that dir outranks \$PNPM_HOME/bin in a human's shell, so this" >&2
    echo "        file — not the declared pin — is what 'claude' now runs" >&2
    echo "      ⇒ every pin check above still reads the pnpm copy, so it is" >&2
    echo "        green on a box whose claude was swapped out from under it" >&2
    echo "      ⇒ the candidate is reached as 'claude.latest' for exactly this" >&2
    echo "        reason; no bundle here writes a 'claude' to this dir" >&2
    echo "      fix: rm $HOME/.local/bin/claude" >&2
    failed=1
  fi

  ####################################################################
  # the CANDIDATE claude — `claude.latest`
  #
  # ⚠️ the claim INVERTS with the pin. an opted-out box that still carries a
  #   shim offers a command no line in the tree declares, pointed at a version
  #   nobody reviewed — so a torn-down box is CONVERGED, and residue is the
  #   defect this reads for
  ####################################################################
  local latest_prefix="$GROVE_BRAIN_CLAUDE_LATEST_PREFIX"
  local latest_shim="$GROVE_BRAIN_CLAUDE_LATEST_SHIM"
  local latest_pin="$GROVE_BRAIN_CLAUDE_LATEST_PIN"

  if [[ -z "$latest_pin" ]]; then
    if [[ -e "$latest_shim" || -d "$latest_prefix" ]]; then
      echo "   ✋ claude.latest is opted out and the box still carries it" >&2
      echo "      ⇒ shim: ${latest_shim} $([[ -e "$latest_shim" ]] && echo present || echo absent)" >&2
      echo "      ⇒ prefix: ${latest_prefix} $([[ -d "$latest_prefix" ]] && echo present || echo absent)" >&2
      echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
      failed=1
    else
      echo "   • claude.latest is opted out, and no candidate is installed ✔"
      echo "     opt in: set GROVE_BRAIN_CLAUDE_LATEST_PIN in this bundle's _.sh"
    fi
    return $failed
  fi

  ####################################################################
  # 1. the install — the SAME three-valued reader the upsert guarded on, so
  #    the two halves cannot cut this set two ways
  ####################################################################
  local latest_state
  latest_state="$(grove_provision_5_3_brains_claude_latest_state)"

  if [[ "$latest_state" != "whole" ]]; then
    echo "   ✋ the claude.latest candidate reads '$latest_state', not 'whole'" >&2
    echo "      ⇒ expected a runnable bin at $latest_prefix/v$latest_pin, with" >&2
    echo "        '$latest_prefix/latest' naming it" >&2
    echo "      ⇒ found: latest → $(readlink "$latest_prefix/latest" 2>/dev/null || echo '(no symlink)')" >&2
    echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
    failed=1
  else
    echo "   • claude.latest candidate is built at $latest_pin ✔ (latest → v$latest_pin)"
  fi

  ####################################################################
  # 2. the shim is CURRENT, not merely present
  #
  # ⚠️ a presence test would pass on a shim that still names the prior cap, or
  #   the prior target — so it is DIFFED against a fresh render of the one
  #   declaration it was written from
  ####################################################################
  if [[ ! -x "$latest_shim" ]]; then
    echo "   ✋ the claude.latest shim is absent or not executable" >&2
    echo "      ⇒ looked for: $latest_shim" >&2
    echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
    failed=1
  elif ! grove_provision_5_3_brains_claude_latest_shim_render | diff -q - "$latest_shim" >/dev/null 2>&1; then
    echo "   ✋ the claude.latest shim has drifted from this checkout" >&2
    echo "      ⇒ it may still name a prior target or a prior memory cap" >&2
    echo "      read the diff: diff <(…render…) $latest_shim" >&2
    echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
    failed=1
  else
    echo "   • the claude.latest shim matches this checkout ✔"
  fi

  ####################################################################
  # 3. it RUNS, and answers the declared candidate
  #
  # ⚠️ the SHIM is what runs, never the binary behind it — the shim is the path
  #   a human takes, and it carries two branches of its own
  #   (`rule.require.prove-the-path-the-human-runs`)
  #
  # ⚠️ the version is asked of the BINARY for the same reason the pin above is:
  #   claude's in-place updater rewrites `cli.js` and leaves package.json
  #   behind, so a check on the package answers ✔ on a drifted box
  ####################################################################
  if [[ -x "$latest_shim" ]]; then
    local latest_live
    latest_live="$(timeout -k 5 "$GROVE_BRAIN_PROBE_SECONDS" "$latest_shim" --version 2>/dev/null \
      | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"

    if [[ -z "$latest_live" ]]; then
      echo "   🌙 claude.latest ran, but did not answer a version this run"
      echo "      ⇒ the candidate ($latest_pin) is unproven here, not disproven"
    elif [[ "$latest_live" == "$latest_pin" ]]; then
      echo "   • claude.latest is $latest_live, the declared candidate ✔"
    else
      echo "   ✋ claude.latest is $latest_live, but the declared candidate is $latest_pin" >&2
      echo "      ⇒ the candidate drifted, so a trial reports on a version the" >&2
      echo "        tree does not name — and a comparison against the pin is then" >&2
      echo "        one nobody else can reproduce" >&2
      echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
      echo "      or, if the drift is wanted: bump GROVE_BRAIN_CLAUDE_LATEST_PIN first" >&2
      failed=1
    fi

    ##################################################################
    # 4. REACH — a shim no lookup finds is a command the human does not have
    #
    # ⚠️ a 🌙, never a ✋: this reads THIS shell's PATH, and a verify driven
    #   over a duct runs in a shell whose PATH is not the human's
    #   (`gotcha.a-tool-found-by-path-answers-only-a-human`)
    ##################################################################
    local latest_which
    latest_which="$(command -v claude.latest 2>/dev/null || true)"
    if [[ "$latest_which" == "$latest_shim" ]]; then
      echo "   • claude.latest is on PATH ✔"
    else
      echo "   🌙 claude.latest is installed and this shell's PATH does not name it"
      echo "      ⇒ found: ${latest_which:-(no match)}"
      echo "      ⇒ ~/.local/bin reaches PATH from ~/.zshenv (owned by 2.5.zsh), so"
      echo "        a shell that read neither rc will not see it — unproven here"
    fi
  fi

  return $failed
}
