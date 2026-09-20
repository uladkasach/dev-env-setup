#!/usr/bin/env bash
######################################################################
# .what = the ONE holder of the reach FENCE grammar in ~/.aws/config
#
# .why
#   - `aws.reach.set` owns one `# grove: reach <profile>` fence per profile,
#     and `5.6.aws` owns the separate `# grove: begin`…`# grove: end` block.
#     that split is what keeps two writers off one artifact
#     (`rule.forbid.two-writers-on-one-artifact`, and `aws.reach.set`'s own
#     `.why this file writes to ~/.aws/config` header)
#   - 🛑 but a grammar only one verb can WRITE is a grammar no verb can READ
#     BACK, so the family could add a reach and never name or remove one
#   - ⇒ that is the cause behind a real defect: `5.13.reach` wrote a fence per
#     declared row and reaped none, so a box's profiles were a function of
#     every row this repo ever held rather than of the rows it holds now —
#     `rule.require.one-command-provision`'s determinism clause, broken
#   - 📜 measured 2026-09-18 on grove-ahbode-v20260901: an `ehmpathy:demo` row
#     was wired, applied its profile body, died at keyrack's env enum, and was
#     rewired to `ehmpathy:test` + `ehmpathy:prep`. the row left the table and
#     `[profile ehmpathy.demo.ehmpath]` stayed on the box — live, assuming a
#     real role in a real account, under a name no declaration owned
#
# 🛑 the READER derives its affixes from the WRITER, and never restates them
#   - a `sed -n 's/^# grove: reach \(.*\) — begin$/\1/p' ` is the obvious list
#     reader and it is a SECOND copy of this grammar, free to drift from the
#     `printf` above it. the em dash alone is a byte nobody re-types correctly
#   - ⇒ `_fence_list` calls `_fence_open` with a sentinel and splits on it, so
#     one edit to the writer moves the reader with it, by construction
#   - (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9 — one fact, two
#      readers, and the cheaper one is always the one that drifts)
#
# usage: sourced, never run
#   source "$(dirname "${BASH_SOURCE[0]}")/aws.reach.operations.sh"
######################################################################

# .what = the file every reach fence lives in
# .why aws offers no second file for profiles, so the fence IS the boundary
aws_reach_config() { printf '%s/.aws/config' "$HOME"; }

# .what = the profile name a given reach is written under
# .why one rule, so the writer, the reaper, and the rack all name one string
aws_reach_profile() { printf '%s.%s.%s' "$1" "$2" "$3"; }   # org env owner

# .what = the two lines that fence one profile's block
# 🛑 these are the ONLY two places this grammar is spelled
aws_reach_fence_open() { printf '# grove: reach %s — begin' "$1"; }
aws_reach_fence_shut() { printf '# grove: reach %s — end' "$1"; }

# .what = every profile name this box holds a reach fence for, one per line
# .why it answers "what reach does this box actually carry", which no verb
#   could ask before — and a set that cannot be read cannot be converged
aws_reach_fence_list() {
  local cfg tpl pre suf line
  cfg="$(aws_reach_config)"
  [[ -f "$cfg" ]] || return 0

  # .derive the affixes from the WRITER, so the reader cannot drift from it
  #   - \x01 cannot appear in a profile name: every value composed into this
  #     file is grammar-clamped to [A-Za-z0-9._-] by `aws.reach.set`
  tpl="$(aws_reach_fence_open $'\x01')"
  pre="${tpl%%$'\x01'*}"
  suf="${tpl##*$'\x01'}"

  # ⚠️ `|| [[ -n "$line" ]]`, because a file with no trailing newline hands the
  #   last line to `read` with a non-zero status and the loop would drop it
  #   (`gotcha.while-read-drops-the-last-line`)
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == "$pre"*"$suf" ]] || continue
    line="${line#"$pre"}"
    printf '%s\n' "${line%"$suf"}"
  done < "$cfg"
}

# .what = copy the config through, minus ONE profile's fenced block
# .why every line outside that fence is copied byte for byte, so a reap is the
#   removal of one block and never a rewrite of the file — the same guarantee
#   `aws.reach.set`'s upsert makes, read from the same two writers
# .note it prints to stdout; the caller owns the write and the compare
aws_reach_fence_drop() {
  local profile="$1" cfg open shut
  cfg="$(aws_reach_config)"
  [[ -f "$cfg" ]] || return 0
  open="$(aws_reach_fence_open "$profile")"
  shut="$(aws_reach_fence_shut "$profile")"
  awk -v open="$open" -v shut="$shut" '
    $0 == open { skip = 1; next }
    $0 == shut { skip = 0; next }
    !skip { print }
  ' "$cfg"
}
