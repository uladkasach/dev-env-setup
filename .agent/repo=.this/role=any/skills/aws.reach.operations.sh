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
#
# 🛑 it reads the END line too, never the begin line alone
#   - infra's [default] writer on a hetzner grove drops every line from
#     [default] to the next `[` header, so a reach fence right after [default]
#     loses its begin line (`src/grove.aws.sh` header)
#   - the end line survives, so a list keyed on both still names that fence,
#     and `5.13.reach` can still reap it
aws_reach_fence_list() {
  local cfg tpl opre osuf spre ssuf line name seen=$'\n'
  cfg="$(aws_reach_config)"
  [[ -f "$cfg" ]] || return 0

  # .derive the affixes from the WRITER, so the reader cannot drift from it
  #   - \x01 cannot appear in a profile name: every value composed into this
  #     file is grammar-clamped to [A-Za-z0-9._-] by `aws.reach.set`
  tpl="$(aws_reach_fence_open $'\x01')"
  opre="${tpl%%$'\x01'*}"; osuf="${tpl##*$'\x01'}"
  tpl="$(aws_reach_fence_shut $'\x01')"
  spre="${tpl%%$'\x01'*}"; ssuf="${tpl##*$'\x01'}"

  # ⚠️ `|| [[ -n "$line" ]]`, because a file with no final newline hands the
  #   last line to `read` with a non-zero status and the loop would drop it
  #   (`gotcha.while-read-drops-the-last-line`)
  while IFS= read -r line || [[ -n "$line" ]]; do
    name=""
    if [[ "$line" == "$opre"*"$osuf" ]]; then
      name="${line#"$opre"}"; name="${name%"$osuf"}"
    elif [[ "$line" == "$spre"*"$ssuf" ]]; then
      name="${line#"$spre"}"; name="${name%"$ssuf"}"
    fi
    [[ -n "$name" && "$seen" != *$'\n'"$name"$'\n'* ]] || continue
    seen+="$name"$'\n'
    printf '%s\n' "$name"
  done < "$cfg"
}

# .what = copy the config through, minus ONE profile's fenced block
# .why every line outside that fence is copied byte for byte, so a reap is the
#   removal of one block and never a rewrite of the file — the same guarantee
#   `aws.reach.set`'s upsert makes, read from the same two writers
# 🛑 the drop is `src/grove.aws.sh`'s, which also drops a fence whose BEGIN line
#   infra's [default] writer ate (that file's header says how). a local copy
#   keyed on the begin line alone would miss that block, and the next upsert
#   would append a twin `[profile …]`
# .note it prints to stdout; the caller owns the write and the compare
aws_reach_fence_drop() {
  local profile="$1"
  grove_aws_config_fence_drop cfg="$(aws_reach_config)" \
    open="$(aws_reach_fence_open "$profile")" shut="$(aws_reach_fence_shut "$profile")" \
    header="[profile $profile]"
}

# .what = the line range of each `[profile <name>]` block that sits OUTSIDE its fence
# .why  = a refusal of a hand-laid twin must point at the block a human deletes;
#   "lines 12-15" is a fix, "somewhere in the file" is a hunt
# .note one `<first>-<last>` per block; a block ends before the next `[` header,
#   a fence marker, or EOF. a fence whose BEGIN line infra's writer ate reads as
#   unfenced here — the refusal's GATE is `aws_reach_fence_drop`, never this list
aws_reach_unfenced_ranges() {
  local profile="$1" cfg open shut
  cfg="$(aws_reach_config)"
  [[ -f "$cfg" ]] || return 0
  open="$(aws_reach_fence_open "$profile")"; shut="$(aws_reach_fence_shut "$profile")"
  awk -v hdr="[profile $profile]" -v open="$open" -v shut="$shut" '
    function close_block() { if (start) { print start "-" last; start = 0 } }
    $0 == open { close_block(); fenced = 1; next }
    $0 == shut { fenced = 0; next }
    /^\[/ || /^# grove: / { close_block() }
    $0 == hdr && !fenced { start = NR }
    start && NF { last = NR }
    END { close_block() }
  ' "$cfg"
}

# .what = the unfenced ranges as one comma list, for a human-read refusal
aws_reach_unfenced_ranges_csv() { aws_reach_unfenced_ranges "$1" | paste -sd, -; }

# .what = how many `[profile <name>]` headers survive this skill's fence drop?
# .why  = a count above zero is a hand-laid twin outside the fence, which an
#   append would double; the refusal gates on it
aws_reach_twin_count() {
  local profile="$1"
  aws_reach_fence_drop "$profile" | grep -cFx "[profile $profile]" || true
}

# .what = copy the config through, with ONE profile's fence set IN PLACE
# .why  = the upsert's half of the same guarantee: the block lands where it stood,
#   so a re-run with an equal body writes no byte, and `5.6.aws`'s block never moves
# .note it prints to stdout; the caller owns the write and the compare
aws_reach_fence_set() {
  local profile="$1" body="$2"
  grove_aws_config_fence_set cfg="$(aws_reach_config)" \
    open="$(aws_reach_fence_open "$profile")" shut="$(aws_reach_fence_shut "$profile")" \
    header="[profile $profile]" body="$body"
}

######################################################################
# .what = load the repo's shared runtime — the platform and the aws identity
#
# .why  = the box KIND decides the body this family writes, and
#         `src/grove.env.sh` is the one place that kind is derived. a probe of
#         169.254.169.254 here would be a second derivation, and it already
#         drifted: it read a hetzner grove as a laptop
#
# .why the root is checked by LANDMARK after the hop
#   - `../../../..` is this dir's idiom for the repo root, and a symlinked or
#     relocated skill would hop to the wrong dir with no error
#   - ⇒ `src/grove.env.sh` must sit at the end of the hop, or this refuses
#
# .why it LOADS and never derives
#   - `aws.reach.del` reaps a fence on any box and needs no box kind; a derive
#     here would refuse it on an undeclared seat for no gain
#   - `aws.reach.set` calls `grove_env_derive` itself, which keeps a
#     GROVE_ENV_SERVER already set (`5.13.reach` runs inside a provision) and
#     refuses an undeclared box as `grove.provision` does (on a laptop over
#     ssh: GROVE_ENV_SERVER=local@unix)
#
# rc: 0 = loaded · 2 = no runtime beside this skill
######################################################################
aws_reach_runtime_load() {
  local root
  root="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)" || return 2
  if [[ ! -r "$root/src/grove.env.sh" || ! -r "$root/src/grove.aws.sh" ]]; then
    echo "✋ ConstraintError: this skill found no src/grove.env.sh beside it (looked under $root)" >&2
    echo "   ⇒ it reads the box kind from the repo's runtime, and runs from a dev-env-setup checkout" >&2
    echo "   fix: run it from the checkout, e.g. rhx aws.reach.set … from ~/git/more/dev-env-setup" >&2
    return 2
  fi
  # shellcheck source=../../../../src/grove.env.sh
  source "$root/src/grove.env.sh"
  # shellcheck source=../../../../src/grove.aws.sh
  source "$root/src/grove.aws.sh"
}
