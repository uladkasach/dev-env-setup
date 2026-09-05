#!/usr/bin/env bash
# .what = prove fnm, node, and pnpm are on this box
# .why
#   - looks in the fnm dirs when PATH comes up empty — this run is
#     `bash <file>`, which reads no rc file, so a PATH-only check would
#     report a defect of this process alone. the claim here is "the box HAS
#     it"; "a robot can FIND it" belongs to configure.verify, through a
#     login shell
#
# guarantee:
#   - READ-ONLY. it observes; it mutates no state

grove_provision_5_1_node_provision_verify() {
  local failed=0

  # 1. fnm is on the box
  local fnm=""
  fnm="$(bundle.bin.of fnm)"
  if [[ -n "$fnm" ]]; then
    :
  elif [[ -x "$HOME/.local/share/fnm/fnm" ]]; then
    fnm="$HOME/.local/share/fnm/fnm"
  elif [[ -x "$HOME/.fnm/fnm" ]]; then
    fnm="$HOME/.fnm/fnm"
  fi

  if [[ -z "$fnm" ]]; then
    echo "   ✋ fnm is absent from this box" >&2
    echo "      ⇒ node is unmanaged here, so no rhachet skill can run" >&2
    echo "      fix: rhx grove.provision --what 5.1.node --mode apply" >&2
    return 1
  fi
  echo "   • fnm is present ✔"

  # 2. fnm has a DEFAULT node — fnm can hold three versions and put none on
  # PATH, and the default alias is what a new shell lands on. reads `fnm
  # list`, never `fnm current` — the latter answers the CALLING SHELL, and a
  # bar built on it would cry ✋ on every non-interactive provision
  # .refs = gotcha.5-1-node.demo=verify-read-shape, m1
  local default_node
  default_node="$("$fnm" list 2>/dev/null \
    | awk '/(^|[ ,])default([ ,]|$)/ { print $2; exit }')"
  if [[ -n "$default_node" && "$default_node" != "system" ]]; then
    echo "   • fnm's default node is $default_node ✔"
  else
    echo "   ✋ fnm has no default node (it aliases '${default_node:-none}')" >&2
    echo "      ⇒ fnm may hold several versions and still alias NONE as default," >&2
    echo "        so an 'installed' node is unreachable from any new shell" >&2
    echo "      read it yourself: $fnm list   # the 'default' marker is the claim" >&2
    echo "      fix: rhx grove.provision --what 5.1.node --mode apply" >&2
    failed=1
  fi

  # 2b. every WANTED version is on the box, never merely the default — the
  # use-on-cd hook does not fall back on an absent pin, it ASKS on stdin, and
  # a duct is tmux so that question eats the next command as its answer
  # .refs = gotcha.5-1-node.demo=fnm-pnpm-install-measurements, m4
  local roster want absent=()
  roster="$("$fnm" list 2>/dev/null || true)"
  while read -r want; do
    [[ -n "$want" ]] || continue
    grove_node_version_present "$want" "$roster" || absent+=("v$want")
  done < <(grove_node_versions_wanted)

  if [[ "${#absent[@]}" -eq 0 ]]; then
    echo "   • every wanted node version is present ✔"
  else
    echo "   ✋ a wanted node version is ABSENT: ${absent[*]}" >&2
    echo "      ⇒ fnm's use-on-cd hook does not fall back when a pinned version" >&2
    echo "        is absent — it opens an interactive install prompt on stdin" >&2
    echo "      ⇒ on a duct that prompt holds the pane and then eats the next" >&2
    echo "        command sent down it as its answer" >&2
    echo "      fix: rhx grove.provision --what 5.1.node --mode apply" >&2
    failed=1
  fi

  # 3. pnpm — the package manager every repo here declares, by VERSION,
  # since that is what a lockfile dispute turns on. it does NOT count the
  # binaries on PATH — that count observes THIS PHASE'S OWN SIDE EFFECT and
  # cries wolf; the real hazard is two pnpm VERSIONS, which claim 6 asks
  # .refs = gotcha.5-1-node.demo=fnm-pnpm-install-measurements, m9
  local pnpm_bin
  pnpm_bin="$(bundle.bin.of pnpm)"
  [[ -n "$pnpm_bin" || ! -x "$HOME/.local/share/pnpm/pnpm" ]] || pnpm_bin="$HOME/.local/share/pnpm/pnpm"

  if [[ -n "$pnpm_bin" ]]; then
    echo "   • pnpm is present ✔ ($("$pnpm_bin" --version 2>/dev/null))"
  else
    echo "   ✋ pnpm is absent from this box" >&2
    echo "      ⇒ every repo here declares pnpm as its package manager, so an" >&2
    echo "        install falls back to npm and writes the wrong lockfile" >&2
    echo "      fix: rhx grove.provision --what 5.1.node --mode apply" >&2
    failed=1
  fi

  # 4. pnpm answers under EVERY node this box holds, never merely the
  # default — corepack's pnpm shim lives in ONE node version's bin dir, so
  # claim 3 can pass while a 'cd' into another pin gets no pnpm at all. asks
  # `fnm exec` rather than switch this process, which later phases run in.
  # each probe is BOUNDED — corepack's shim can ask a question on stdin
  # .refs = gotcha.5-1-node.demo=fnm-pnpm-install-measurements, m1, m4
  local ver ver_bare without=()
  while read -r ver; do
    [[ -n "$ver" ]] || continue
    ver_bare="${ver#v}"
    if ! CI=1 timeout -k 5 20 "$fnm" exec --using "$ver_bare" -- pnpm --version </dev/null >/dev/null 2>&1; then
      without+=("v$ver_bare")
    fi
  done < <(grove_node_versions_wanted)

  if [[ "${#without[@]}" -eq 0 ]]; then
    echo "   • pnpm answers under every wanted node version ✔"
  else
    echo "   ✋ pnpm is ABSENT under: ${without[*]}" >&2
    echo "      ⇒ corepack's pnpm shim lives in ONE node version's bin dir, and" >&2
    echo "        fnm's cd hook switches version per repo — so a 'cd' into a repo" >&2
    echo "        pinned to one of these lands a shell on a node with no pnpm" >&2
    echo "      ⇒ an install there falls back to npm and writes the wrong" >&2
    echo "        lockfile, which then conflicts with every other checkout" >&2
    echo "      fix: rhx grove.provision --what 5.1.node --mode apply" >&2
    failed=1
  fi

  # 5. no command has TWO pnpm shims — claims 3-4 ask whether PNPM answers,
  # this asks whether the commands pnpm INSTALLS answer. a shadowed shim
  # leaves pnpm healthy while its globals point at a fossil, and the
  # inventory can read fully RIGHT while the box still runs the wrong
  # binary. names the commands rather than a count, since the fix is per one
  # .refs = gotcha.5-1-node.demo=fnm-pnpm-install-measurements, m10
  local shadow shadows=()
  while read -r shadow; do
    [[ -n "$shadow" ]] || continue
    shadows+=("$shadow")
  done < <(grove_pnpm_shim_shadows)

  if [[ "${#shadows[@]}" -eq 0 ]]; then
    echo "   • no command has two pnpm shims ✔"
  else
    echo "   ✋ ${#shadows[@]} command(s) have TWO pnpm shims: ${shadows[*]}" >&2
    echo "      ⇒ pnpm moved its global shim dir between versions, so a box that" >&2
    echo "        ran both layouts holds two files for one command" >&2
    echo "      ⇒ only the live dir's copy is ever refreshed; the other answers" >&2
    echo "        with whatever it held the day pnpm moved, and outranks the" >&2
    echo "        live one wherever PATH names its dir first" >&2
    echo "      read them: type -a ${shadows[0]}" >&2
    echo "      fix: rhx grove.provision --what 5.1.node --mode apply" >&2
    failed=1
  fi

  # 6. ONE pnpm — the same version answers inside a repo and outside one.
  # corepack's `pnpm` runs the version the nearest `packageManager` names,
  # and its GLOBAL DEFAULT wherever no package.json sits above the cwd, so a
  # box can hold two pnpms at once behind one binary on PATH — and every
  # claim above reads ✔, since all ask from inside the repo. the probe uses
  # a mktemp dir, never $HOME, since a human may hold a `~/package.json`
  # (`rule.require.hermetic-tests`, applied to a verify)
  # .refs = gotcha.5-1-node.demo=pnpm-shim-dir-split, m1
  local pnpm_want
  pnpm_want="$(grove_pnpm_version_wanted)"
  if [[ -z "$pnpm_want" ]]; then
    echo "   ✋ this checkout declares no pnpm version" >&2
    echo "      ⇒ expected \"packageManager\": \"pnpm@<x>\" in package.json" >&2
    echo "      ⇒ without a declared pin, no claim here can name what is wanted" >&2
    failed=1
  else
    local outside outside_dir
    outside_dir="$(mktemp -d)"
    outside="$(cd "$outside_dir" && CI=1 timeout -k 10 60 pnpm --version </dev/null 2>/dev/null | tail -1)"
    rmdir "$outside_dir" 2>/dev/null || true

    if [[ "$outside" == "$pnpm_want" ]]; then
      echo "   • one pnpm ✔ ($pnpm_want, inside a repo and outside one alike)"
    else
      echo "   ✋ TWO pnpms: repos get $pnpm_want, everywhere else gets ${outside:-<no answer>}" >&2
      echo "      ⇒ corepack dispatches on the nearest 'packageManager', so a" >&2
      echo "        cwd with none above it gets corepack's GLOBAL DEFAULT — a" >&2
      echo "        second pnpm, installed by an unpinned 'corepack install -g'" >&2
      echo "      ⇒ pnpm 10.x and 11.x disagree about the global bin dir, so an" >&2
      echo "        install run outside a repo lands its shims in the OTHER dir," >&2
      echo "        and a pinned command grows a second, stale shim that" >&2
      echo "        outranks it — with no version drift and no elapsed time" >&2
      echo "      fix: rhx grove.provision --what 5.1.node --mode apply" >&2
      failed=1
    fi
  fi

  return $failed
}
