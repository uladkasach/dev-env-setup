#!/usr/bin/env bash
######################################################################
# .what = prove `4.5.nvim` fences its imagemagick rules INTO the policy file the
#         tool reads, keeps every other byte, and converges on a re-run
#
# .why  = measured 2026-11-15, im6 6.9.12: only rules inlined in
#         `/etc/ImageMagick-6/policy.xml` bite. a seat copy was cmp-clean and
#         inert for months, and the verify's ✋ fired on every box. this clamps
#         the transform and the upsert's root seam, with no root and no imagemagick
#
# guarantee:
#   - hermetic: a fixture policy, a stub `identify`, a stub `sudo`; all in mktemp
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
B="$HERE/src/grove.provision/4.terminal/4.5.nvim"
SRC="$B/imagemagick.policy.xml"

fixture="$(mktemp -d)" || { echo "💥 MalfunctionError: could not make a temp dir" >&2; exit 1; }
trap 'rm -rf "$fixture"' EXIT

failed=0
check() {
  local label="$1"; shift
  if "$@"; then echo "   • $label ✔"; else echo "   💥 MalfunctionError: $label" >&2; failed=1; fi
}

echo "🌲 prove.imagemagick-policy-is-fenced"

# a debian-shaped policy: a comment that quotes policy lines, then the real map
seed() {
  {
    printf '<?xml version="1.0" encoding="UTF-8"?>\n<!--\n  an example:\n    <policy domain="coder" rights="none" pattern="*" />\n-->\n'
    printf '<policymap>\n  <policy domain="Undefined" rights="none"/>\n'
    printf '  <policy domain="delegate" rights="none" pattern="URL" />\n</policymap>\n'
  } > "$1"
}

# shellcheck source=/dev/null
source "$B/_.sh"
fence_open="$GROVE_PROVISION_4_5_NVIM_POLICY_OPEN"
fence_shut="$GROVE_PROVISION_4_5_NVIM_POLICY_SHUT"
nrules="$(awk '/^<policymap>/{f=1;next} /^<\/policymap>/{f=0} f && /^[[:space:]]*<policy /' "$SRC" | wc -l)"
check "fixture · the checkout declares rules to fence ($nrules)" test "$nrules" -gt 0

####################################################################
# arm 1 — the transform: fence after <policymap>, rest byte-equal, idempotent
####################################################################
seed "$fixture/p.xml"
grove_provision_4_5_nvim_policy_render "$fixture/p.xml" "$SRC" > "$fixture/r1.xml"; rc=$?
check "render · exits 0" test "$rc" -eq 0
check "render · one fence" test "$(grep -cxF "$fence_open" "$fixture/r1.xml")" -eq 1
check "render · the fence sits right after <policymap>" \
  test "$(grep -A1 -x '<policymap>' "$fixture/r1.xml" | tail -1)" == "$fence_open"
check "render · every checkout rule is inside the fence" \
  test "$(awk -v o="$fence_open" -v s="$fence_shut" '$0==o{f=1;next} $0==s{f=0} f' "$fixture/r1.xml" | wc -l)" -eq "$nrules"
check "render · every byte outside the fence is debian's" \
  bash -c 'diff <(awk -v o="$2" -v s="$3" "\$0==o{f=1;next} \$0==s{f=0;next} !f" "$1") "$4"' _ "$fixture/r1.xml" "$fence_open" "$fence_shut" "$fixture/p.xml"
grove_provision_4_5_nvim_policy_render "$fixture/r1.xml" "$SRC" > "$fixture/r2.xml"
check "render · a re-render is byte-equal (idempotent)" cmp -s "$fixture/r1.xml" "$fixture/r2.xml"

####################################################################
# arm 2 — a stale fence is replaced in place, never doubled
####################################################################
awk -v o="$fence_open" -v s="$fence_shut" '{print} /^<policymap>/{print o; print "  <policy domain=\"coder\" rights=\"none\" pattern=\"STALE\" />"; print s}' \
  "$fixture/p.xml" > "$fixture/stale.xml"
grove_provision_4_5_nvim_policy_render "$fixture/stale.xml" "$SRC" > "$fixture/r3.xml"
check "stale · still one fence" test "$(grep -cxF "$fence_open" "$fixture/r3.xml")" -eq 1
check "stale · the stale rule is gone" bash -c "! grep -q STALE '$fixture/r3.xml'"
check "stale · equals a fresh render" cmp -s "$fixture/r1.xml" "$fixture/r3.xml"

####################################################################
# arm 3 — no <policymap> to anchor on: rc 2, no output
####################################################################
printf '<?xml version="1.0"?>\n' > "$fixture/bare.xml"
grove_provision_4_5_nvim_policy_render "$fixture/bare.xml" "$SRC" > "$fixture/r4.xml"; rc=$?
check "bare · rc 2" test "$rc" -eq 2
check "bare · empty output" test ! -s "$fixture/r4.xml"

####################################################################
# arm 3b — a broken fence (a lone open marker, or two fences): rc 3, no output.
#   a skip that ran to EOF would drop </policymap> and hand root a malformed map
####################################################################
awk -v o="$fence_open" '{print} /^<policymap>/{print o}' "$fixture/p.xml" > "$fixture/lone.xml"
grove_provision_4_5_nvim_policy_render "$fixture/lone.xml" "$SRC" > "$fixture/r5.xml"; rc=$?
check "lone open marker · rc 3" test "$rc" -eq 3
check "lone open marker · empty output" test ! -s "$fixture/r5.xml"
awk -v s="$fence_shut" '{print} /^<policymap>/{print s}' "$fixture/p.xml" > "$fixture/loneshut.xml"
grove_provision_4_5_nvim_policy_render "$fixture/loneshut.xml" "$SRC" > /dev/null; rc=$?
check "lone shut marker · rc 3" test "$rc" -eq 3
cat "$fixture/r1.xml" "$fixture/r1.xml" > "$fixture/twice.xml"
grove_provision_4_5_nvim_policy_render "$fixture/twice.xml" "$SRC" > /dev/null; rc=$?
check "two fences · rc 3" test "$rc" -eq 3

####################################################################
# arm 4 — the upsert: a seat with no root declines and writes no byte;
#   a seat with root fences the file the tool names; a re-run is a no-op
####################################################################
mkdir -p "$fixture/bin" "$fixture/home"
printf '#!/usr/bin/env bash\necho "Path: %s"\necho "Path: [built-in]"\n' "$fixture/etc.xml" > "$fixture/bin/identify"
chmod +x "$fixture/bin/identify"
run_upsert() {  # $1 = can sudo (yes|no)
  (
    export PATH="$fixture/bin:$PATH" HOME="$fixture/home" XDG_CONFIG_HOME="$fixture/home/.config"
    # shellcheck source=/dev/null
    source "$HERE/src/bundle.upgrade.sh"   # bundle.run, bundle.said — as the entrypoint loads them
    # shellcheck source=/dev/null
    source "$B/_.sh"
    # shellcheck source=/dev/null
    source "$B/configure.upsert.sh"
    if [[ "$1" == yes ]]; then pkg_can_sudo() { return 0; }; else pkg_can_sudo() { return 1; }; fi
    pkg_assert_sudo() { return 0; }
    bundle.root.declines() { echo "   🌙 $1 is a BOX-WIDE fact, and this seat has no root"; }
    # sudo stub: run as this user, minus the owner flags only root may pass
    #   with INSTALL_REFUSED set, the root write fails as a full or read-only disk would
    sudo() {
      [[ -n "${INSTALL_REFUSED:-}" && "$1" == install ]] && { echo "install: cannot create regular file: Read-only file system" >&2; return 1; }
      local a=() x skip=0; for x in "$@"; do (( skip )) && { skip=0; continue; }; case "$x" in -o|-g) skip=1 ;; *) a+=("$x") ;; esac; done; "${a[@]}"
    }
    grove_provision_4_5_nvim_policy_upsert "${2:-$SRC}"
  )
}
seed "$fixture/etc.xml"; cp "$fixture/etc.xml" "$fixture/etc.before"
mkdir -p "$fixture/home/.config/ImageMagick"; cp "$SRC" "$fixture/home/.config/ImageMagick/policy.xml"

# .what = every line the upsert prints, per arm, the fixture path masked — the
#         bytes a human reads, pinned so a fix-text cannot drift unseen
transcript=""
record() { transcript+="## $1"$'\n'"${2//$fixture/<fix>}"$'\n\n'; }

out="$(run_upsert no 2>&1)"
record "no root, an inert seat copy present" "$out"
check "no root · declines" bash -c "[[ \"\$1\" == *'BOX-WIDE fact'* ]]" _ "$out"
check "no root · writes no byte" cmp -s "$fixture/etc.xml" "$fixture/etc.before"
check "no root · the inert seat copy is removed" test ! -e "$fixture/home/.config/ImageMagick/policy.xml"

out="$(run_upsert yes 2>&1)"
record "root, first apply" "$out"
check "root · reports the fence" bash -c "[[ \"\$1\" == *'rules fenced into'* ]]" _ "$out"
check "root · the file equals a render" cmp -s "$fixture/etc.xml" "$fixture/r1.xml"
cp "$fixture/etc.xml" "$fixture/etc.after1"
out="$(run_upsert yes 2>&1)"
record "root, second apply" "$out"
check "root · a re-run reports already fenced" bash -c "[[ \"\$1\" == *'already fenced'* ]]" _ "$out"
check "root · a re-run writes no byte" cmp -s "$fixture/etc.xml" "$fixture/etc.after1"

####################################################################
# arm 5 — the declines: no readable policy file, and one with no <policymap>
####################################################################
printf '#!/usr/bin/env bash\necho "Path: [built-in]"\n' > "$fixture/bin/identify"
out="$(run_upsert yes 2>&1)"
record "root, imagemagick names no readable policy file" "$out"
check "no file · declines by name" bash -c "[[ \"\$1\" == *'names no readable policy file'* ]]" _ "$out"

printf '#!/usr/bin/env bash\necho "Path: %s"\n' "$fixture/bare.xml" > "$fixture/bin/identify"
cp "$fixture/bare.xml" "$fixture/bare.before"
out="$(run_upsert yes 2>&1)"
record "root, a policy file with no <policymap>" "$out"
check "no policymap · declines by name" bash -c "[[ \"\$1\" == *\"holds no '<policymap>' line\"* ]]" _ "$out"
check "no policymap · writes no byte" cmp -s "$fixture/bare.xml" "$fixture/bare.before"

printf '#!/usr/bin/env bash\necho "Path: %s"\n' "$fixture/lone.xml" > "$fixture/bin/identify"
cp "$fixture/lone.xml" "$fixture/lone.before"
out="$(run_upsert yes 2>&1)"; rc=$?
record "root, a policy file with a lone fence marker" "$out"
check "broken fence · ✋ by name" bash -c "[[ \"\$1\" == *'✋ ConstraintError: '*'holds a broken grove fence'* ]]" _ "$out"
check "broken fence · fails the phase (rc 1)" test "$rc" -eq 1
check "broken fence · writes no byte" cmp -s "$fixture/lone.xml" "$fixture/lone.before"

# a checkout with no policy of its own: the upsert leaves the box as found
out="$(run_upsert yes "$fixture/no-such-policy.xml" 2>&1)"; rc=$?
record "root, the checkout holds no policy" "$out"
check "no checkout policy · declines by name (rc 0)" bash -c "[[ \"\$1\" -eq 0 && \"\$2\" == *'this checkout has no imagemagick.policy.xml'* ]]" _ "$rc" "$out"

# root held, and the write itself refused: a fault, never a decline
seed "$fixture/ro.xml"; cp "$fixture/ro.xml" "$fixture/ro.before"
printf '#!/usr/bin/env bash\necho "Path: %s"\n' "$fixture/ro.xml" > "$fixture/bin/identify"
out="$(INSTALL_REFUSED=1 run_upsert yes 2>&1)"; rc=$?
record "root, the write refused" "$out"
check "write refused · a 💥 (rc 1)" bash -c "[[ \"\$1\" -eq 1 && \"\$2\" == *'MalfunctionError: could not write'*'with root held'* ]]" _ "$rc" "$out"
check "write refused · the file stays as found" cmp -s "$fixture/ro.xml" "$fixture/ro.before"

####################################################################
# arm 6 — the verify's currency claim, each verdict a human reads
####################################################################
run_currency() {  # $1 = the checkout policy the verify compares against
  (
    export PATH="$fixture/bin:$PATH"
    # shellcheck source=/dev/null
    source "$B/_.sh"
    # shellcheck source=/dev/null
    source "$B/configure.verify.sh"
    grove_provision_4_5_nvim_policy_currency_verify "$1"
  )
}
printf '#!/usr/bin/env bash\necho "Path: %s"\n' "$fixture/etc.xml" > "$fixture/bin/identify"

out="$(run_currency "$SRC" 2>&1)"; rc=$?
record "verify, the file imagemagick reads carries the fence" "$out"
check "verify · a current fence ✔" bash -c "[[ \"\$1\" == *\"carries this checkout's imagemagick rules ✔\"* ]]" _ "$out"
check "verify · currency never fails the phase (rc 0)" test "$rc" -eq 0

seed "$fixture/etc.xml"
out="$(run_currency "$SRC" 2>&1)"
record "verify, the file imagemagick reads holds no fence" "$out"
check "verify · an absent fence names the box-wide fix" bash -c "[[ \"\$1\" == *'lacks this checkout'*'sudo -v && rhx grove.provision --what 4.5.nvim --mode apply'* ]]" _ "$out"

out="$(run_currency "$fixture/no-such-policy.xml" 2>&1)"
record "verify, the checkout holds no policy" "$out"
check "verify · a checkout with no policy says so" bash -c "[[ \"\$1\" == *'this checkout has no imagemagick.policy.xml'* ]]" _ "$out"

printf '#!/usr/bin/env bash\necho "Path: [built-in]"\n' > "$fixture/bin/identify"
out="$(run_currency "$SRC" 2>&1)"
record "verify, imagemagick names no readable policy file" "$out"
check "verify · no readable file names how to read why" bash -c "[[ \"\$1\" == *\"names no readable policy file — read why: identify -list policy\"* ]]" _ "$out"

# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
play_snap_verify dir="$HERE/.play/permanent/prove.imagemagick-policy-is-fenced.snap" name=transcript actual="$transcript" || failed=1

echo ""
if [[ $failed -ne 0 ]]; then
  echo "💥 MalfunctionError: prove.imagemagick-policy-is-fenced: a claim did not hold" >&2
  exit 1
fi
echo "🌲 all claims held ✔"
