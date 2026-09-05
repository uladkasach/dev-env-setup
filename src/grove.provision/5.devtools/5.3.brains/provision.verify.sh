#!/usr/bin/env bash
######################################################################
# .what = prove all three brains are reachable — claude, rhachet (rhx), codex
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

  return $failed
}
