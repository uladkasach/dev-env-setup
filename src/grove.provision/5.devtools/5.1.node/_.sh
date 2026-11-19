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

# the node versions this box carries BESIDE its default. lives here since the
# upsert and the verify both read it (rule.require.identical-bundle-composition).
# an absent `.nvmrc` version makes fnm's cd hook ASK on stdin rather than fall back
# (rule.forbid.tty-as-a-proxy-for-a-human). exact patches, never a major
# (rule.require.pinned-versions); to add one, append a line
# .refs = gotcha.5-1-node.demo=fnm-pnpm-install-measurements, m4
GROVE_NODE_BASELINE=(
  22.21.0   # the widest-used 22.x line; also what this repo's .nvmrc pins today
)

# .what = the checkout root this run reads its pins from (`.nvmrc`, `package.json`)
# .why there is no GROVE_REPO; the root sits beside GROVE_SRC, and every pin
#   reader here asks this ONE answer, so the node pin and the pnpm pin cannot
#   read two directories
grove_node_checkout_root() { dirname "$GROVE_SRC"; }

# .what = the version this checkout's .nvmrc pins, bare (no `v`); empty when none
# .why  = `.nvmrc` accepts `22.21.0` and `v22.21.0` alike, and the verify prefixes
#   its own `v`. ONE reader strips it, so a `v`-form pin can never read `vv22.21.0`
#   and fail a verify no apply can cure
grove_node_nvmrc_pin() {
  local pinned_file pinned=""; pinned_file="$(grove_node_checkout_root)/.nvmrc"
  [[ -f "$pinned_file" ]] && pinned="$(tr -d '[:space:]' < "$pinned_file")"
  printf '%s' "${pinned#v}"
}

# the baseline PLUS whatever this checkout's .nvmrc pins, deduped, so a
# .nvmrc bump needs no edit here
grove_node_versions_wanted() {
  local out=("${GROVE_NODE_BASELINE[@]}") pinned
  pinned="$(grove_node_nvmrc_pin)"
  [[ -n "$pinned" ]] && out+=("$pinned")
  printf '%s\n' "${out[@]}" | sort -u
}

# the box's DEFAULT node — the version this checkout's .nvmrc declares, else the
# first baseline. never `lts-latest`, which moves: rhachet's `run.jit` passes
# `--experimental-transform-types`, which node 26 removed, so a box whose
# default followed lts to v26 had no `rhx` that ran — no keyrack, no rack, no gh
# token (measured 2026-11-14, the first hetzner grove). the declared
# version is the one this repo's own toolchain is proven on
grove_node_version_default() {
  local pinned; pinned="$(grove_node_nvmrc_pin)"
  echo "${pinned:-${GROVE_NODE_BASELINE[0]}}"
}

# .what = put corepack on the node fnm has in use, when that node bundles none
# 🛑 node 25+ bundles NO corepack, and lts-latest is such a node. its absence
#    fails every corepack call after, the pnpm CACHE included, on every box whose
#    default node is current. the pin matches the corepack the baseline node
#    bundles, so every node on the box runs one corepack
# .note = a miss is reported and tolerated: the caller's npm fallback for pnpm
#    still runs, and its own tally names a node with no pnpm
grove_node_corepack_findsert() {
  local ver="$1"
  command -v corepack >/dev/null 2>&1 && return 0

  # corepack ships its own `pnpm` shim, so an npm-placed pnpm on THIS node (a
  #   prior run's fallback) blocks the install with EEXIST. that pnpm sits in
  #   fnm's own per-node dir, which this bundle owns
  web_npm uninstall -g pnpm >/dev/null 2>&1 || true
  if bundle.run web_npm install -g "corepack@$GROVE_COREPACK_VERSION" >/dev/null; then
    echo "   • corepack $GROVE_COREPACK_VERSION installed for node v$ver (it bundles none)"
    return 0
  fi
  echo "   • corepack could not be installed for node v$ver (pnpm falls back to npm)"
  bundle.said "     " "$BUNDLE_SAID"
}

# .what = findsert node's own shared-library dep, libatomic1
# .why  = the prebuilt node 24+ links libatomic.so.1, and a minimal ubuntu image (a
#   hetzner box) ships without it; a later bundle's build-essential pulls it in, so
#   only a FIRST apply fails (measured 2026-11-14, ground seat). owned before any node
# .note = rc 0 when present, installed, or declined by name (a seat with no
#   root, `bundle.root.owns`); rc 1 only when a seat WITH root fails the install,
#   and then its own 💥 names the fault with apt's words nested under it
grove_node_libatomic_findsert() {
  pkg_present libatomic1 && return 0
  bundle.root.owns "node's libatomic1" "libatomic1 is not installed" || return 0
  if ! bundle.run pkg_install libatomic1; then
    echo "   💥 MalfunctionError: could not install libatomic1, which node links at load" >&2
    bundle.said "      " "$BUNDLE_SAID" >&2
    echo "      ⇒ a node installed now would not start" >&2
    return 1
  fi
  echo "   • libatomic1 installed (node links it at load)"
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
  local manifest; manifest="$(grove_node_checkout_root)/package.json"
  [[ -f "$manifest" ]] || return 0
  sed -n 's/.*"packageManager"[[:space:]]*:[[:space:]]*"pnpm@\([^"]*\)".*/\1/p' \
    "$manifest" | head -1
}

# the pnpm versions this box CACHES, BESIDE the one it defaults to. lives here
# since the upsert and the verify both read it
# (rule.require.identical-bundle-composition)
#
# 🛑 a CACHE, where the pin above is a DEFAULT — the two answer different questions
#    and no amount of the second buys the first. corepack's `pnpm` shim FETCHES a
#    version it does not hold and ASKS FIRST, on stdin, where a duct is tmux
#    (rule.forbid.tty-as-a-proxy-for-a-human)
#    .refs = gotcha.5-1-node.demo=fnm-pnpm-install-measurements, m11
#
# ⚠️ exact patches, never a range — `pnpm@10` moves weekly
#    (rule.require.pinned-versions). to add one, append a line
GROVE_PNPM_BASELINE=(
  10.11.0   # measured: aether/svc-aether-auctions declares it (the gate's fetch above)
  10.34.5   # named by the human 2026-09-26; which repo declares it is unmeasured here
)

# the corepack a node that bundles none is given (node 25+). pinned to the one
# the baseline node (v22) bundles, so every node on a box dispatches pnpm alike
GROVE_COREPACK_VERSION="0.34.0"

# the baseline PLUS the declared default, deduped. the default belongs in the
# cache too — `corepack install -g` caches it as a side effect, so a verify may
# read this ONE set with no special case for the member that is also the default
grove_pnpm_versions_wanted() {
  local out=("${GROVE_PNPM_BASELINE[@]}") declared
  declared="$(grove_pnpm_version_wanted)"
  [[ -n "$declared" ]] && out+=("$declared")
  printf '%s\n' "${out[@]}" | sort -u
}

# corepack's cache dir for ONE pnpm version
#
# ⚠️ ONE dir per $HOME, shared across every node version the box holds — read
#    from corepack's own source (`getCorepackHomeFolder`, and
#    `INSTALL_FOLDER_VERSION = 1` for the `v1` segment). so the cache pass runs
#    ONCE, never per node, and the honest cost is one download per version
#
# 🛑 .why a PRESENCE test here is SOUND, where shape 6 forbids one
#    corepack builds into a TMP dir, writes `.corepack` last, then RENAMES it into
#    place — so a cut download never lands at this path and there is no partial
#    state to mistake for a whole one. `.corepack` is asked for rather than the dir,
#    since it is written last and so still discriminates if that rename ever goes
grove_pnpm_cached() {
  local ver="$1"
  local home="${COREPACK_HOME:-${XDG_CACHE_HOME:-$HOME/.cache}/node/corepack}"
  [[ -f "$home/v1/pnpm/$ver/.corepack" ]]
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

# .what = make the declared node the fnm default, and name a move of it
# .why  = installed first, since `fnm default` refuses a version the box does not
#   hold; a move changes every new shell's node, so it is said, was → now
grove_node_default_findsert() {
  local want="$1" was now
  was="$(fnm list 2>/dev/null | grep -w default | grep -oE 'v[0-9][0-9.]*' | head -1 || true)"
  if ! grove_node_version_present "$want" "$(fnm list 2>/dev/null || true)"; then
    bundle.run fnm install "$want" || {
      echo "   💥 MalfunctionError: fnm could not install the default node v$want" >&2
      bundle.said "      " "$BUNDLE_SAID" >&2
      echo "      ⇒ check the version is real: fnm list-remote | grep v$want" >&2
      return 1
    }
  fi
  if ! bundle.run fnm default "$want"; then
    echo "   💥 MalfunctionError: fnm could not set v$want as the default node" >&2
    bundle.said "      " "$BUNDLE_SAID" >&2
    echo "      ⇒ with no default, node is on PATH in no shell. read what it holds: fnm list" >&2
    return 1
  fi
  fnm use "$want"
  hash -r
  now="$(fnm current 2>/dev/null)"
  echo "   • node $now set as the fnm default (declared by .nvmrc)"
  if [[ -n "$was" && "$was" != "$now" ]]; then
    echo "     ⇒ the default MOVED: $was → $now, for every new shell on this box"
    echo "       $was stays installed: fnm use $was"
  fi
}

# .what = remove each shadowed pnpm shim from the dir pnpm no longer writes
# .why  = in pnpm's OWN dirs only; the live dir is pnpm's ANSWER, never a constant (m10)
grove_pnpm_shim_shadows_prune() {
  local shadow shadows=() pruned=() live_dir fossil_dir
  live_dir="$(grove_pnpm_shim_dir_live)"
  while read -r shadow; do
    [[ -n "$shadow" ]] || continue
    shadows+=("$shadow")
  done < <(grove_pnpm_shim_shadows)
  if [[ "${#shadows[@]}" -eq 0 ]]; then
    echo "   • no shadowed pnpm shims ✔ (live dir: ${live_dir:-<pnpm did not answer>})"
    return 0
  fi
  fossil_dir="$PNPM_HOME/bin"
  [[ "$live_dir" == "$PNPM_HOME/bin" ]] && fossil_dir="$PNPM_HOME"
  for shadow in "${shadows[@]}"; do
    rm -f "$fossil_dir/$shadow" && pruned+=("$shadow")
  done
  echo "   • pruned ${#pruned[@]} shadowed shim(s) from $fossil_dir: ${pruned[*]}"
  echo "     (each also lives in $live_dir, which is the dir pnpm writes)"
}

grove_provision_5_1_node() {
  bundle.upgrade 5.1.node.provision.upsert
  bundle.upgrade 5.1.node.provision.verify
  bundle.upgrade 5.1.node.configure.upsert
  bundle.upgrade 5.1.node.configure.verify
}
