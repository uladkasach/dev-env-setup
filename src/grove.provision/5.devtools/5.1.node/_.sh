#!/usr/bin/env bash
# .what = node via fnm, plus pnpm — and the login-shell PATH hook a ROBOT needs
# .why
#   - split from configure: provision puts fnm/node/pnpm on the box, configure
#     declares the ~/.profile hook a login shell reads — a box can hold node
#     that no robot can find, which is its own fact
#   - the PATH hook lives in ~/.profile, NEVER ~/.bashrc — `ssh host cmd`,
#     `bash -lc`, and a detached run are non-interactive bash, and ubuntu's
#     ~/.bashrc returns EARLY for exactly that case; bash reads ~/.profile for
#     a LOGIN shell, interactive or not
#   - applies to EVERY machine — a grove runs the same node-driven rhachet
#     skills a laptop does
#
# usage:
#   rhx grove.provision --what 5.1.node --mode apply

# the node versions this box carries BESIDE its lts default. lives here since
# the upsert and the verify both read it (rule.require.identical-bundle-composition).
# a `.nvmrc` pins a version per repo, and fnm's cd hook switches to it; when
# that version is absent fnm ASKS on stdin rather than fall back, and a duct
# is tmux so the question holds the pane and eats the next command sent down
# it (rule.forbid.tty-as-a-proxy-for-a-human). exact patches, never a major —
# `fnm install 22` moves each month (rule.require.pinned-versions). to add
# one, append a line; the repo's own `.nvmrc` pin is read at runtime
GROVE_NODE_BASELINE=(
  22.21.0   # the widest-used 22.x line; also what this repo's .nvmrc pins today
)

# the baseline PLUS whatever this checkout's .nvmrc pins, deduped, so a
# .nvmrc bump needs no edit here
grove_node_versions_wanted() {
  local out=("${GROVE_NODE_BASELINE[@]}")

  # derived from GROVE_SRC, since there is no GROVE_REPO; .nvmrc sits at the
  # repo root beside the src dir
  local pinned_file="$(dirname "$GROVE_SRC")/.nvmrc"
  if [[ -f "$pinned_file" ]]; then
    local pinned
    pinned="$(tr -d '[:space:]' < "$pinned_file")"
    [[ -n "$pinned" ]] && out+=("$pinned")
  fi

  printf '%s\n' "${out[@]}" | sort -u
}

# is this exact node version on the box? `fnm list` prints both `* v22.21.0`
# and `* v22.21.0 default`, so a loose match would also accept `v22.21.05` —
# the tail is anchored
grove_node_version_present() {
  local want="$1" roster="$2"
  grep -qE "v?${want//./\\.}([[:space:]]|$)" <<< "$roster"
}

# the pnpm version this org DECLARES, read from `packageManager` — declapract
# stamps `"packageManager": "pnpm@<x>"` into every repo, so a second copy
# drifts the moment declapract bumps it (rule.require.identical-bundle-composition).
# this pin is load-bear, never tidiness: corepack's `pnpm` is a DISPATCHER
# that runs the version the nearest `packageManager` names, and its GLOBAL
# DEFAULT where none is above the cwd, so an unpinned default holds two
# pnpms — and two global shim dirs — on one box at once
# .refs = gotcha.5-1-node.demo=pnpm-shim-dir-split, m1
# sed, never jq — this is bundle 5.1 and jq lands in a later one
# echoes: the bare version (e.g. `10.24.0`), or empty when undeclared
grove_pnpm_version_wanted() {
  # derived from GROVE_SRC, since there is no GROVE_REPO
  local manifest="$(dirname "$GROVE_SRC")/package.json"
  [[ -f "$manifest" ]] || return 0
  sed -n 's/.*"packageManager"[[:space:]]*:[[:space:]]*"pnpm@\([^"]*\)".*/\1/p' \
    "$manifest" | head -1
}

# the dir pnpm CURRENTLY writes its global shims into — pnpm ITSELF is asked,
# since the answer moves between pnpm versions and per-cwd. bounded, and the
# LAST line: pnpm can print an update notice above its answer, and under
# corepack it also reads stdin (rule.require.bounded-probes-in-verifies)
grove_pnpm_shim_dir_live() {
  CI=1 timeout -k 10 60 pnpm bin -g </dev/null 2>/dev/null | tail -1
}

# the name of every command that has a shim in BOTH pnpm dirs, where the copy
# OUTSIDE the live dir is the one no install will refresh. pnpm moved its
# global shim dir between versions, so a box that ran both layouts holds two
# files for one command, and the non-live copy outranks it whenever PATH
# names it first. the live dir is ASKED, never assumed, since the answer is
# per-cwd — `grove_pnpm_version_wanted` closes the source, never the fossil
# .refs = gotcha.5-1-node.demo=pnpm-shim-dir-split, m2
# only DUPLICATES are named, since a command in one dir alone has no race
# (`term=shim`: a duplicate is a stale answer that outranks a correct one)
grove_pnpm_shim_shadows() {
  local live fossil home
  live="$(grove_pnpm_shim_dir_live)"
  [[ -n "$live" && -d "$live" ]] || return 0

  home="${PNPM_HOME:-$HOME/.local/share/pnpm}"
  if [[ "$live" == "$home/bin" ]]; then fossil="$home"; else fossil="$home/bin"; fi
  [[ -d "$fossil" && "$fossil" != "$live" ]] || return 0

  local path name
  for path in "$fossil"/*; do
    [[ -f "$path" ]] || continue
    name="$(basename "$path")"
    [[ -e "$live/$name" ]] && printf '%s\n' "$name"
  done
  return 0
}

grove_provision_5_1_node() {
  bundle.upgrade 5.1.node.provision.upsert
  bundle.upgrade 5.1.node.provision.verify
  bundle.upgrade 5.1.node.configure.upsert
  bundle.upgrade 5.1.node.configure.verify
}
