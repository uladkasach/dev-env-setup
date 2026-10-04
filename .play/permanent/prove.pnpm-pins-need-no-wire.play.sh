#!/usr/bin/env bash
######################################################################
# prove: every DECLARED pnpm pin runs with no wire call, and the default holds
#
# .what = two invariants, plus the guard that makes the second one possible:
#
#           1. every pnpm version this tree declares is CACHED, so corepack's
#              `pnpm` shim never asks to fetch one mid-run
#           2. the shim answers a pin with stdin CLOSED — no prompt, no stall
#
#         and the guard both rest on:
#
#           3. the driver exports `COREPACK_DEFAULT_TO_LATEST=0`, so a cache
#              fill cannot repoint the global default as a side effect
#
# 🛑 .why a clamp and not a rule alone — measured 2026-09-26
#
#    `git.grove.provision test grove-aether-v20260921` died at its step 2, and
#    the duct's log held the cause:
#
#      🌙 still busy after 1800s — this is a BOUND, not a verdict
#      ! Corepack is about to download …/pnpm-10.11.0.tgz
#      ? Do you want to continue? [Y/n]
#
#    ⇒ a duct IS tmux, so that question held the pane and ate every command
#      sent after it (`rule.forbid.tty-as-a-proxy-for-a-human`). the gate then
#      reported a DUCT fault — true of the duct, and the cause was this
#      bundle's: a correct verdict over the wrong subject
#      (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.4)
#
# 🛑 .why the probe MUST boot the `pnpm` shim, and never `corepack`
#
#    the two shims disagree about the prompt, and that one line is the whole
#    reason the defect is invisible from any `corepack` call:
#
#      corepack   COREPACK_ENABLE_DOWNLOAD_PROMPT ??= '0'   → never asks
#      pnpm       COREPACK_ENABLE_DOWNLOAD_PROMPT ??= '1'   → ASKS, on stdin
#
#    ⇒ a probe that reaches for `corepack` reads ✔ over a box where every
#      `pnpm install` stalls on a question nobody can answer
#
# 🛑 .why arm 2 exists — `--cache-only` does NOT protect the default
#
#    corepack repoints its own default INSIDE the download path, for any
#    same-major version strictly greater than the one it holds:
#
#      corepack.cjs:22352  if (… semverGreaterThan …) await setLocalPackageManager(…)
#
#    `--cache-only` is read one level OUT, after that has already fired. the
#    only lever is `COREPACK_DEFAULT_TO_LATEST=0`, and the driver declares it.
#    ⇒ so a box can pass arms 0 and 1 while its default has drifted to a
#      version no repo asked for — and `5.1.node`'s claim 6 would then halt
#      naming "TWO pnpms", a correct halt over the wrong cause
#
# .the arms, and why NO ONE of them alone settles it
#   - arm 0 is DECLARED-STATE: every version `grove_pnpm_versions_wanted`
#     names is held in corepack's cache dir. it reads the DIR, never the shim —
#     to ask the shim is to TRIGGER the fetch this arm is about
#     (`rule.require.judge-declared-state-not-live-state`)
#   - arm 1 is LIVE and END-TO-END: the `pnpm` shim answers a declared pin with
#     stdin CLOSED. arm 0 is its known precondition; this one asks the tool, so
#     a second precondition nobody enumerated cannot hide from it
#   - arm 2 is the GUARD claim: the driver declares the env var that keeps the
#     default still. arms 0 and 1 both pass on a box whose default already
#     drifted, so only a read of the driver can name that state
#   ⇒ read all three in one run; accept no one of them alone
#     (`gotcha.a-check-that-cries-wolf-gets-silenced`, q10)
#
# .the rows
#   B   a declared pnpm version is absent from corepack's cache
#   B   the `pnpm` shim cannot answer a declared pin with stdin closed
#   B   the driver does not declare COREPACK_DEFAULT_TO_LATEST=0
#
# guarantee:
#   - READ ONLY of box state. arm 1's one write is a `mktemp -d` fixture,
#     removed on a trap; it never touches $HOME, since a human may hold a
#     `~/package.json` (`rule.require.hermetic-tests`)
#   - every probe is BOUNDED and stdin-closed, so a prompt cannot hold this run
#     (`rule.require.bounded-probes-in-verifies`)
#   - no privilege, no remote reach — needs no grove, no credential
#   - ⚠️ arm 1 reaches the WIRE only when arm 0 is already red, which is the
#     very state this play exists to forbid
#
# usage:
#   rhx play.run --play prove.pnpm-pins-need-no-wire
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
echo "🐢 prove: every declared pnpm pin needs no wire"
echo "   └─ root : $_root"
echo ""

######################################################################
# the DECLARATION — sourced from the bundle that owns it, never copied
#
# 🛑 a copy of `GROVE_PNPM_BASELINE` here would be a SECOND holder of one fact,
#    free to drift from the upsert and the verify with no signal — the shape
#    that let a bundle's two readers cut one set two ways
#    (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9)
######################################################################
export GROVE_SRC="$_root/src"
_bundle="$GROVE_SRC/grove.provision/5.devtools/5.1.node/_.sh"

if [[ ! -f "$_bundle" ]]; then
  echo "   ✋ 5.1.node's _.sh is absent at $_bundle" >&2
  echo "      ⇒ this play reads its declaration from the bundle that owns it," >&2
  echo "        so with the bundle out of reach it can grade no claim at all" >&2
  echo ""
  echo "🐚 prove: 1 blocker (the bundle is out of reach)"
  exit 1
fi

# shellcheck source=/dev/null
source "$_bundle"

_wanted=()
while read -r _v; do [[ -n "$_v" ]] && _wanted+=("$_v"); done < <(grove_pnpm_versions_wanted)

if [[ "${#_wanted[@]}" -eq 0 ]]; then
  echo "   ✋ the tree declares NO pnpm version, so arms 0 and 1 grade no pin" >&2
  echo "      ⇒ expected a non-empty GROVE_PNPM_BASELINE, or a" >&2
  echo "        \"packageManager\": \"pnpm@<x>\" in this repo's package.json" >&2
  echo ""
  echo "🐚 prove: 1 blocker (no declaration)"
  exit 1
fi

echo "   declared: ${_wanted[*]}"
echo ""

######################################################################
echo "   arm 0 — every declared pnpm version is cached"
#
# reads the cache DIR, via the bundle's own `grove_pnpm_cached`. a presence
# test is SOUND here even though shape 6 forbids one in general: corepack
# builds into a tmp dir, writes `.corepack` last, then RENAMES that dir into
# place — so a cut download never lands at this path at all
######################################################################
_uncached=()
for _v in "${_wanted[@]}"; do
  grove_pnpm_cached "$_v" || _uncached+=("$_v")
done

if [[ "${#_uncached[@]}" -eq 0 ]]; then
  echo "      ✔ all ${#_wanted[@]} declared version(s) held in corepack's cache"
else
  echo "      ✋ NOT cached: ${_uncached[*]}" >&2
  echo "         ⇒ a repo whose 'packageManager' names one of those makes" >&2
  echo "           corepack fetch it on 'pnpm install' — and its pnpm shim" >&2
  echo "           ASKS first, on stdin. a duct is tmux, so that question" >&2
  echo "           holds the pane and eats every command sent after it" >&2
  echo "         fix: rhx grove.provision --what 5.1.node --mode apply" >&2
  _fail
fi
echo ""

######################################################################
echo "   arm 1 — the pnpm shim answers a declared pin with stdin CLOSED"
#
# a mktemp fixture with its own `packageManager`, so corepack dispatches on a
# declaration this play controls rather than on the cwd's or the default's.
# NEVER $HOME — a human may hold a `~/package.json`
######################################################################
_pin="${_wanted[${#_wanted[@]}-1]}"
_fixture="$(mktemp -d)"
trap 'rm -rf "$_fixture"' EXIT

printf '{\n  "name": "prove-pnpm-pins",\n  "packageManager": "pnpm@%s"\n}\n' \
  "$_pin" > "$_fixture/package.json"

_answer="$(cd "$_fixture" && CI=1 timeout -k 10 60 pnpm --version </dev/null 2>/dev/null | tail -1)"

if [[ "$_answer" == "$_pin" ]]; then
  echo "      ✔ pnpm@$_pin answers with stdin closed ($_answer)"
else
  echo "      ✋ pnpm@$_pin did not answer: got '${_answer:-<no answer>}'" >&2
  echo "         ⇒ the shim either asked on stdin and was cut, or timed out on" >&2
  echo "           a wire call. either way a duct send would stall here" >&2
  echo "         read it yourself:" >&2
  echo "           cd \$(mktemp -d) && printf '{\"packageManager\":\"pnpm@$_pin\"}' > package.json && pnpm --version" >&2
  echo "         fix: rhx grove.provision --what 5.1.node --mode apply" >&2
  _fail
fi
echo ""

######################################################################
echo "   arm 2 — the driver declares COREPACK_DEFAULT_TO_LATEST=0"
#
# the STATIC guard claim. arms 0 and 1 both pass on a box whose default has
# already drifted, so only a read of the driver can name that state — and
# `--cache-only` cannot substitute, since corepack repoints its default INSIDE
# the download path, one level beneath where that flag is read
######################################################################
_driver="$GROVE_SRC/grove.provision._.sh"

if grep -qE '^[[:space:]]*export[[:space:]]+COREPACK_DEFAULT_TO_LATEST=0' "$_driver"; then
  echo "      ✔ the driver exports COREPACK_DEFAULT_TO_LATEST=0"
else
  echo "      ✋ the driver does NOT export COREPACK_DEFAULT_TO_LATEST=0" >&2
  echo "         ⇒ corepack repoints its own default inside the download path" >&2
  echo "           for any same-major version strictly greater than the one it" >&2
  echo "           holds, so a cache fill silently moves what 'pnpm' means" >&2
  echo "           outside every repo" >&2
  echo "         ⇒ '--cache-only' does not guard this — it is read one level" >&2
  echo "           out, after the repoint has already fired" >&2
  echo "         fix: declare it beside CI=1 in src/grove.provision._.sh" >&2
  _fail
fi
echo ""

######################################################################
# the verdict
######################################################################
if [[ "$FAILED" == 0 ]]; then
  echo "🌲 every declared pnpm pin needs no wire, and the default holds ✔"
  exit 0
fi
echo "✋ a declared pnpm pin can reach the wire mid-run" >&2
echo "   ⇒ the pnpm shim ASKS before it fetches, and a duct is tmux — so the" >&2
echo "     question holds the pane and eats the rest of the run" >&2
exit 1
