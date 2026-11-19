#!/usr/bin/env bash
######################################################################
# .what = prove `5.1.node`'s two hetzner-born seams, each verdict a human reads:
#         the libatomic1 findsert (owned before any node lands) and the verify's
#         default-node claim (the declared node, never the lts alias)
#
# .why  = measured 2026-11-14 on a minimal ubuntu box: node 24+ died on load with
#         no libatomic1, and a default that followed lts to v26 left no rhx that
#         ran. both were first-apply faults a second apply hid. this clamps each
#         branch with no root, no apt, and no fnm
#
# guarantee:
#   - hermetic: a fixture checkout, a stub `fnm`, stub pkg seams; all in mktemp
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
B="$HERE/src/grove.provision/5.devtools/5.1.node"

fixture="$(mktemp -d)" || { echo "💥 MalfunctionError: could not make a temp dir" >&2; exit 1; }
trap 'rm -rf "$fixture"' EXIT

failed=0
check() {
  local label="$1"; shift
  if "$@"; then echo "   • $label ✔"; else echo "   💥 MalfunctionError: $label" >&2; failed=1; fi
}

transcript=""
record() { local body="${2:-(no output)}"; transcript+="## $1"$'\n'"${body//$fixture/<fix>}"$'\n\n'; }

echo "🌲 prove.node-default-and-libatomic"

# a fixture checkout: src/ beside a .nvmrc that declares the default
mkdir -p "$fixture/repo/src" "$fixture/bin" "$fixture/state"
printf '22.21.0\n' > "$fixture/repo/.nvmrc"

####################################################################
# arm 1 — libatomic1: present, declined, installed, failed
####################################################################
# $1 = root here (yes|no)
run_libatomic() {
  (
    export GROVE_SRC="$fixture/repo/src" GROVE_ENV_SERVER="cloud@hetzner.hetzbot"
    # shellcheck source=/dev/null
    source "$HERE/src/bundle.upgrade.sh"
    slug="5.1.node.provision.upsert"
    if [[ "$1" == yes ]]; then pkg_can_sudo() { return 0; }; else pkg_can_sudo() { return 1; }; fi
    pkg_present() { [[ -f "$fixture/state/libatomic1" ]]; }
    pkg_install() {
      echo "$1" >> "$fixture/state/installs"
      [[ -f "$fixture/state/install-fails" ]] && { echo "E: stub apt refused $1" >&2; return 100; }
      touch "$fixture/state/libatomic1"
    }
    # shellcheck source=/dev/null
    source "$B/_.sh"
    grove_node_libatomic_findsert
  )
}
installs() { [[ -f "$fixture/state/installs" ]] && wc -l < "$fixture/state/installs" || echo 0; }

touch "$fixture/state/libatomic1"
out="$(run_libatomic no 2>&1)"; rc=$?
record "libatomic1, already present" "$out"
check "libatomic · present → rc 0" test "$rc" -eq 0
check "libatomic · present → no install asked" test "$(installs)" -eq 0
check "libatomic · present → silent" test -z "$out"

rm -f "$fixture/state/libatomic1"
out="$(run_libatomic no 2>&1)"; rc=$?
record "libatomic1, absent, a seat with no root" "$out"
check "libatomic · no root → rc 0 (a decline, never a fault)" test "$rc" -eq 0
check "libatomic · no root → no install asked" test "$(installs)" -eq 0
check "libatomic · no root → the decline names the subject" bash -c "[[ \"\$1\" == *\"node's libatomic1\"* ]]" _ "$out"

out="$(run_libatomic yes 2>&1)"; rc=$?
record "libatomic1, absent, a seat with root" "$out"
check "libatomic · root → rc 0" test "$rc" -eq 0
check "libatomic · root → one install of libatomic1" test "$(installs)" -eq 1
check "libatomic · root → the package is now present" test -f "$fixture/state/libatomic1"
check "libatomic · root → the install reports what it changed" bash -c "[[ \"\$1\" == *'libatomic1 installed'* ]]" _ "$out"

out="$(run_libatomic yes 2>&1)"; rc=$?
check "libatomic · a re-run asks no second install (idempotent)" test "$(installs)" -eq 1

rm -f "$fixture/state/libatomic1"; touch "$fixture/state/install-fails"
out="$(run_libatomic yes 2>&1)"; rc=$?
record "libatomic1, absent, root, apt refuses" "$out"
check "libatomic · a failed install → rc 1, so the upsert names it at its cause" test "$rc" -ne 0
check "libatomic · apt's own reason reaches the human" bash -c "[[ \"\$1\" == *'stub apt refused libatomic1'* ]]" _ "$out"

####################################################################
# arm 2 — the verify's default-node claim
####################################################################
# $1 = the `fnm list` body the stub prints
run_default() {
  printf '%s\n' "$1" > "$fixture/state/fnm-list"
  printf '#!/usr/bin/env bash\n[[ "$1" == list ]] && cat %q\n' "$fixture/state/fnm-list" > "$fixture/bin/fnm"
  chmod +x "$fixture/bin/fnm"
  (
    export GROVE_SRC="$fixture/repo/src"
    # shellcheck source=/dev/null
    source "$B/_.sh"
    # shellcheck source=/dev/null
    source "$B/provision.verify.sh"
    grove_provision_5_1_node_default_verify "$fixture/bin/fnm"
  )
}

out="$(run_default $'* v22.21.0 default\n* v26.0.0' 2>&1)"; rc=$?
record "default, the declared node" "$out"
check "default · declared → ✔" bash -c "[[ \"\$1\" == *\"fnm's default node is v22.21.0 ✔\"* ]]" _ "$out"
check "default · declared → rc 0" test "$rc" -eq 0

out="$(run_default $'* v22.21.0\n* v26.0.0 default, lts-latest' 2>&1)"; rc=$?
record "default, followed lts past the toolchain" "$out"
check "default · lts drift → names both versions" bash -c "[[ \"\$1\" == *'ConstraintError: fnm'*'default node is v26.0.0, and this checkout declares v22.21.0'* ]]" _ "$out"
check "default · lts drift → rc 1" test "$rc" -eq 1

out="$(run_default '* v22.21.0' 2>&1)"; rc=$?
record "default, no alias at all" "$out"
check "default · none → names the empty alias" bash -c "[[ \"\$1\" == *\"ConstraintError: fnm has no default node (it aliases 'none')\"* ]]" _ "$out"
check "default · none → rc 1" test "$rc" -eq 1

out="$(run_default '* system default' 2>&1)"; rc=$?
record "default, the system node" "$out"
check "default · system → read as no fnm default" bash -c "[[ \"\$1\" == *\"it aliases 'system'\"* ]]" _ "$out"
check "default · system → rc 1" test "$rc" -eq 1

# a `v`-form pin is the same version: one reader strips it, never `vv22.21.0`
printf 'v22.21.0\n' > "$fixture/repo/.nvmrc"
out="$(run_default $'* v22.21.0 default' 2>&1)"; rc=$?
record "default, a v-form .nvmrc pin" "$out"
check "default · v-form pin → ✔ (never vv)" bash -c "[[ \"\$1\" == *\"fnm's default node is v22.21.0 ✔\"* && \"\$1\" != *vv* ]]" _ "$out"
check "default · v-form pin → rc 0" test "$rc" -eq 0

# a partial pin names a family: `fnm default 22` aliases the newest 22.x held
printf '22\n' > "$fixture/repo/.nvmrc"
out="$(run_default $'* v22.21.0 default' 2>&1)"; rc=$?
record "default, a partial .nvmrc pin (22)" "$out"
check "default · partial pin 22 accepts v22.21.0 (rc 0)" test "$rc" -eq 0
out="$(run_default $'* v2.0.0 default' 2>&1)"; rc=$?
check "default · partial pin 22 refuses v2.0.0 (rc 1)" test "$rc" -eq 1
printf '2\n' > "$fixture/repo/.nvmrc"
out="$(run_default $'* v22.21.0 default' 2>&1)"; rc=$?
check "default · partial pin 2 refuses v22.21.0 (a . boundary, rc 1)" test "$rc" -eq 1
printf '22.21.0\n' > "$fixture/repo/.nvmrc"

####################################################################
# arm 3 — the upsert's default findsert: the move a human must hear, and each 💥
#   the stub fnm keeps its state in files: the versions held, and the default
####################################################################
cat > "$fixture/bin/fnm" <<STUB
#!/usr/bin/env bash
S="$fixture/state/fnm"
case "\$1" in
  list) while read -r v; do
          [[ "\$v" == "\$(cat "\$S.default" 2>/dev/null)" ]] && echo "* v\$v default" || echo "* v\$v"
        done < "\$S.held" ;;
  install) [[ -f "\$S.install-fails" ]] && { echo "error: no such version" >&2; exit 1; }; echo "\$2" >> "\$S.held" ;;
  default) [[ -f "\$S.default-fails" ]] && { echo "error: cannot alias" >&2; exit 1; }; echo "\$2" > "\$S.default" ;;
  current) echo "v\$(cat "\$S.default")" ;;
esac
exit 0
STUB
chmod +x "$fixture/bin/fnm"
run_findsert() {
  ( PATH="$fixture/bin:$PATH"
    # shellcheck source=/dev/null
    source "$HERE/src/bundle.upgrade.sh"
    # shellcheck source=/dev/null
    source "$B/_.sh"
    grove_node_default_findsert "$1" )
}
printf '26.0.0\n' > "$fixture/state/fnm.held"; printf '26.0.0\n' > "$fixture/state/fnm.default"
out="$(run_findsert 22.21.0 2>&1)"; rc=$?
record "findsert, the default followed lts to v26" "$out"
check "findsert · a moved default names was → now (rc 0)" \
  bash -c "[[ \"\$1\" -eq 0 && \"\$2\" == *'the default MOVED: v26.0.0 → v22.21.0'* && \"\$2\" == *'fnm use v26.0.0'* ]]" _ "$rc" "$out"
check "findsert · the declared node was installed first" grep -qx 22.21.0 "$fixture/state/fnm.held"
out="$(run_findsert 22.21.0 2>&1)"; rc=$?
record "findsert, a re-run" "$out"
check "findsert · a re-run names no move (rc 0)" bash -c "[[ \"\$1\" -eq 0 && \"\$2\" != *MOVED* ]]" _ "$rc" "$out"
touch "$fixture/state/fnm.install-fails"
out="$(run_findsert 99.0.0 2>&1)"; rc=$?
record "findsert, the declared node cannot install" "$out"
check "findsert · an unreal version is a 💥 that names the check (rc 1)" \
  bash -c "[[ \"\$1\" -eq 1 && \"\$2\" == *'fnm list-remote | grep v99.0.0'* ]]" _ "$rc" "$out"
rm -f "$fixture/state/fnm.install-fails"; touch "$fixture/state/fnm.default-fails"
out="$(run_findsert 22.21.0 2>&1)"; rc=$?
record "findsert, fnm refuses the alias" "$out"
check "findsert · a refused alias is a 💥 that names the read (rc 1)" \
  bash -c "[[ \"\$1\" -eq 1 && \"\$2\" == *'could not set v22.21.0 as the default node'* ]]" _ "$rc" "$out"
rm -f "$fixture/state/fnm.default-fails"

####################################################################
# arm 4 — the upsert's own halts, as a human reads them: libatomic1 refused,
#   and a baseline node fnm cannot install. the fetch, the digest, and the unzip
#   are stubbed; the stub fnm the unzip "unpacks" answers --lts and refuses a pin
####################################################################
cat > "$fixture/bin/fnm.upsert" <<'STUB'
#!/usr/bin/env bash
case "$1 ${2:-}" in
  "env "*)        exit 0 ;;
  "install --lts") exit 0 ;;
  "install "*)    echo "error: Can't find version in dotfiles. Please provide a version manually" >&2; exit 1 ;;
esac
exit 0
STUB
chmod +x "$fixture/bin/fnm.upsert"
# $1 = the fault: libatomic | baseline
run_upsert() {
  local fault="$1"
  ( export HOME="$fixture/home.$fault" GROVE_SRC="$fixture/repo/src"
    mkdir -p "$HOME" "$fixture/utmp.$fault"
    # shellcheck source=/dev/null
    source "$HERE/src/bundle.upgrade.sh"
    # shellcheck source=/dev/null
    source "$B/_.sh"
    # shellcheck source=/dev/null
    source "$B/provision.upsert.sh"
    web_tempdir() { printf '%s' "$fixture/utmp.$fault"; }
    web_fetch() { : > "$3"; }
    web_verify_sha256() { return 0; }
    unzip() { mkdir -p "$fixture/utmp.$fault/out"; cp "$fixture/bin/fnm.upsert" "$fixture/utmp.$fault/out/fnm"; }
    # the real findsert runs; apt is the stub, so its own 💥 is what the human reads
    slug="5.1.node.provision.upsert"
    pkg_can_sudo() { return 0; }
    pkg_present() { [[ "$fault" != libatomic ]]; }
    pkg_install() { echo "E: stub apt refused $1" >&2; return 100; }
    grove_node_version_default() { echo 22.21.0; }
    grove_node_default_findsert() { return 0; }
    grove_node_versions_wanted() { echo 18.20.4; }
    grove_node_version_present() { return 1; }
    grove_provision_5_1_node_provision_upsert )
}
out="$(run_upsert libatomic 2>&1)"; rc=$?
record "upsert, apt refuses libatomic1" "$out"
check "upsert · libatomic1 refused is a 💥 that names it (rc 1)" \
  bash -c '[[ "$1" -eq 1 && "$2" == *"💥 MalfunctionError: could not install libatomic1, which node links at load"* ]]' _ "$rc" "$out"
check "upsert · apt's own reason sits above the halt" bash -c '[[ "$1" == *"stub apt refused libatomic1"* ]]' _ "$out"

out="$(run_upsert baseline 2>&1)"; rc=$?
record "upsert, a baseline node fnm cannot install" "$out"
check "upsert · a baseline node fnm refuses is a 💥 that names it (rc 1)" \
  bash -c '[[ "$1" -eq 1 && "$2" == *"💥 MalfunctionError: fnm could not install node v18.20.4"* ]]' _ "$rc" "$out"
check "upsert · it names the duct prompt and the read" \
  bash -c '[[ "$1" == *"which a duct cannot answer"* && "$1" == *"fnm list-remote | grep v18.20.4"* ]]' _ "$out"

####################################################################
# arm 5 — corepack on a node that bundles none: present, placed, refused
#   PATH holds fixture dirs alone, so a host corepack can never answer; corebin
#   carries only the coreutils `bundle.run` needs to keep a tool's own words
####################################################################
mkdir -p "$fixture/cpbin" "$fixture/corebin"
ln -s "$(command -v mktemp)" "$fixture/corebin/mktemp"
ln -s "$(command -v cat)" "$fixture/corebin/cat"
ln -s "$(command -v rm)" "$fixture/corebin/rm"
# $1 = corepack on PATH (yes|no) · $2 = npm's answer (ok|fail)
run_corepack() {
  local has="$1" npm="$2"
  rm -f "$fixture/cpbin/corepack" "$fixture/state/npm.calls"
  [[ "$has" == yes ]] && { printf '#!/bin/sh\nexit 0\n' > "$fixture/cpbin/corepack"; chmod +x "$fixture/cpbin/corepack"; }
  ( export GROVE_SRC="$fixture/repo/src"
    # shellcheck source=/dev/null
    source "$HERE/src/bundle.upgrade.sh"
    export PATH="$fixture/cpbin:$fixture/corebin"
    # shellcheck source=/dev/null
    source "$B/_.sh"
    web_npm() {
      printf '%s\n' "$*" >> "$fixture/state/npm.calls"
      [[ "$1" == install && "$npm" == fail ]] && { echo "npm error code E404" >&2; return 1; }
      return 0
    }
    grove_node_corepack_findsert 26.0.0 )
}
# grep -c prints 0 AND exits 1 on no match, so the absent file is the one fallback
npm_installs() { [[ -f "$fixture/state/npm.calls" ]] || { echo 0; return; }; grep -c '^install' "$fixture/state/npm.calls" || :; }

out="$(run_corepack yes ok 2>&1)"; rc=$?
record "corepack, the node bundles one" "${out:-(no output)}"
check "corepack · bundled → silent, rc 0, no npm call" bash -c '[[ -z "$1" && "$2" -eq 0 && "$3" -eq 0 ]]' _ "$out" "$rc" "$(npm_installs)"

out="$(run_corepack no ok 2>&1)"; rc=$?
record "corepack, the node bundles none, npm places it" "$out"
check "corepack · placed → names the version and the node (rc 0)" \
  bash -c '[[ "$2" -eq 0 && "$1" == *"corepack "*" installed for node v26.0.0 (it bundles none)"* ]]' _ "$out" "$rc"
check "corepack · placed → one npm install" test "$(npm_installs)" -eq 1

out="$(run_corepack no fail 2>&1)"; rc=$?
record "corepack, the node bundles none, npm refuses" "$out"
check "corepack · refused → names the node and points at npm's reason" \
  bash -c '[[ "$1" == *"corepack could not be installed for node v26.0.0"* && "$1" == *"⇒ it said: npm error code E404"* ]]' _ "$out"
check "corepack · refused → tolerated (rc 0), the pnpm fallback still runs" test "$rc" -eq 0

# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
play_snap_verify dir="$HERE/.play/permanent/prove.node-default-and-libatomic.snap" name=transcript actual="$transcript" || failed=1

echo ""
if [[ $failed -ne 0 ]]; then
  echo "💥 MalfunctionError: prove.node-default-and-libatomic: a claim did not hold" >&2
  exit 1
fi
echo "🌲 all claims held ✔"
