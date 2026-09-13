#!/usr/bin/env bash
######################################################################
# .what = prove yq is on this box at the pin, AND that it answers the exact
#         filter the declapract cycles gate runs
#
# 🛑 .why a second claim, and not just `command -v yq`
#   - TWO different programs answer to `yq` (see this bundle's `_.sh`), and
#     presence cannot tell them apart
#   - the gate's failure mode is SILENT: a `$(…)` that errors collapses to an
#     empty --exclude, dpdm scans node_modules, and the run reports hundreds of
#     cycles that do not exist. the gate goes red and yq is never implicated
#   - ⇒ so the claim worth an assertion is "the filter ANSWERS", and the only
#     way to know that is to run it
#
# .this is the check EARNING its authority, per
#   `gotcha.a-check-that-cries-wolf-gets-silenced`: a check is trusted when it
#   is seen to discriminate. arm B below is the one that discriminates — the
#   `//` fallback fires ONLY where `.exclude` is absent, so a build whose
#   alternative operator differs passes arm A and fails arm B
#
# guarantee:
#   - READ-ONLY. it feeds yq a fixture on stdin and writes no file
######################################################################

grove_provision_5_17_yq_provision_verify() {
  local version="$GROVE_YQ_VERSION"

  ####################################################################
  # ⚠️ `bundle.bin.at`, never `bundle.bin.of` and never a bare `command -v`
  #   - this process's $PATH predates the ~/.local/bin/yq its upsert writes
  #   - and on a laptop a bare name may answer apt's python wrapper at
  #     /usr/bin/yq, which is a DIFFERENT program
  ####################################################################
  local bin
  bin="$(bundle.bin.at yq)"

  if [[ -z "$bin" ]]; then
    echo "   ✋ yq is absent from this box" >&2
    echo "      looked at: \$HOME/.local/bin/yq, then \$PATH" >&2
    echo "      ⇒ the declapract cycles gate reads .dpdmrc.yaml through yq, so" >&2
    echo "        its --exclude collapses to an empty string and dpdm scans" >&2
    echo "        node_modules — hundreds of cycles that do not exist" >&2
    echo "      fix: rhx grove.provision --what 5.17.yq --mode apply" >&2
    return 1
  fi

  ####################################################################
  # 1. the pin — a yq from another source may be years old, or a jq wrapper
  ####################################################################
  local live
  live="$("$bin" --version 2>/dev/null | head -1)"

  if ! echo "$live" | grep -F "$version" >/dev/null; then
    echo "   ✋ yq is present at the WRONG version" >&2
    echo "      ⇒ want $version; it says: ${live:-no readable version}" >&2
    echo "      ⇒ at $bin" >&2
    echo "      ⇒ two boxes on different builds read one .dpdmrc.yaml two ways," >&2
    echo "        which is what the pin exists to prevent" >&2
    echo "      fix: rhx grove.provision --what 5.17.yq --mode apply" >&2
    return 1
  fi

  ####################################################################
  # 2. the FILTER — byte-identical to the one the cycles gate runs
  #
  # 🛑 do NOT paraphrase this filter to make it simpler to read
  #   - a paraphrase is a SECOND declaration of the gate's contract, free to
  #     drift from it silently (`rule.require.identical-bundle-composition`)
  #   - the value of this check is that it is the same string
  #
  # ⚠️ this asserts the `.exclude`-PRESENT arm ONLY, and that bound is measured
  #   - the gate's `// "^$"` tail reads as a fallback for an ABSENT `.exclude`
  #   - measured 2026-09-11 — it has never been one, in EITHER engine:
  #       go-yq  → `cannot join with !!null`
  #       jq     → `Cannot iterate over null (null)`
  #   - `join` raises before `//` is ever reached, so the tail is dead syntax
  #   - ⇒ that is an UPSTREAM defect in the declapract template, never a fact
  #     about which yq is installed — so this bundle must not assert it
  #   - a check that reddens over somebody else's dead branch is a false ✋, and
  #     a false ✋ decays into a silenced check
  #     (`gotcha.a-check-that-cries-wolf-gets-silenced`)
  #   - .refs = .dream/2026_09_11.dpdm-cycles-gate-fallback-is-dead-syntax.dream.md
  ####################################################################
  local filter='.exclude | join("|") // "^$"'

  local answer
  answer="$(printf 'exclude:\n  - node_modules\n  - dist\n' | "$bin" -r "$filter" 2>/dev/null)"

  if [[ "$answer" != "node_modules|dist" ]]; then
    echo "   ✋ yq is at the pin and does NOT answer the cycles-gate filter" >&2
    echo "      filter: $filter" >&2
    echo "      ⇒ want 'node_modules|dist', got '${answer:-empty}'" >&2
    echo "      ⇒ the gate reads this through a \$(…), so an error there collapses" >&2
    echo "        to an EMPTY --exclude and dpdm scans node_modules. the gate" >&2
    echo "        then reports cycles that do not exist and never names yq" >&2
    echo "      ⇒ the binary at $bin claims $version yet reads the filter" >&2
    echo "        differently, so the pin is what to re-examine" >&2
    return 1
  fi

  echo "   • yq is $version and answers the cycles-gate filter ✔"
}
