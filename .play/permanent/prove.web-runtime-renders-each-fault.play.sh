#!/usr/bin/env bash
######################################################################
# .what = prove each fault `src/grove.web.sh` can raise renders its own qualified
#         header and its own repair, and snap every one
#
# .why this play exists
#   - the runtime's headers are what a human reads when a first apply meets the wire,
#     and every one opens `✋ ConstraintError:` or `💥 MalfunctionError:`
#   - the live plays prove the happy path and the digest miss. this one proves the
#     rest, hermetic: curl, gpg, git, timeout, mktemp and chmod are stubbed per arm,
#     inside a subshell, so no arm reaches the wire or the box's keystore
#
# .the arms — each grades the exit code and one phrase, then snaps the stderr
#   - F1–F7  web_fetch: curl 28, 22, 6, another code · no url · unknown flag · two urls
#   - S1–S4  web_verify_sha256: no args · absent file · mismatch · unknown arg
#   - G1–G5  web_verify_gpg_fingerprints: no args · absent key · gpg absent · mismatch · unknown arg
#   - V1–V5  web_verify_gpg_signature: no args · absent files · gpg absent · key unreadable · bad sig
#   - C1–C8  git_clone: no dir · no --at · unknown flag · a third arg · timeout · git error ·
#            wrong commit · absent commit
#   - T1–T2  web_tempdir: mktemp fails · chmod fails
#
# usage:
#   rhx play.run --play prove.web-runtime-renders-each-fault
#   rhx play.run --play prove.web-runtime-renders-each-fault --resnap
#
# exit:
#   0 = every arm holds
#   1 = an arm failed
#   2 = no checkout, or a source failed — so no claim was graded
######################################################################

set -uo pipefail

# .what = the checkout under proof — `PROVE_ROOT` (the red half), this play's own, or the cwd
_root_of() {
  [[ -n "${PROVE_ROOT:-}" ]] && { printf '%s' "$PROVE_ROOT"; return 0; }
  local self; self="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)"
  [[ -n "$self" && -f "$self/src/grove.provision._.sh" ]] && { printf '%s' "$self"; return 0; }
  [[ -f "$PWD/src/grove.provision._.sh" ]] && { printf '%s' "$PWD"; return 0; }
  return 1
}
_root="$(_root_of)" || { echo "   ✋ ConstraintError: no checkout found" >&2; exit 2; }

echo "🔎 prove.web-runtime-renders-each-fault"
echo "   └─ root: $_root"
echo ""

# shellcheck source=/dev/null
source "$_root/src/grove.web.sh" || { echo "   ✋ ConstraintError: could not source grove.web.sh" >&2; exit 2; }
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/.snap.operations.sh"

FIX="$(mktemp -d "/tmp/prove-web-faults.XXXXXXXX")" || { echo "   ✋ ConstraintError: no temp dir — no claim graded" >&2; exit 2; }
trap 'rm -rf "$FIX"' EXIT
mkdir -p "$FIX/nopath"
printf 'bytes\n' > "$FIX/artifact"
printf 'sig\n' > "$FIX/artifact.sig"
printf 'key\n' > "$FIX/key.gpg"

URL="https://example.com/x.tgz"
FPR_PIN="AAAA1111BBBB2222CCCC3333DDDD4444EEEE5555"
FPR_ODD="FFFF9999FFFF9999FFFF9999FFFF9999FFFF9999"
SHA_PIN="0000000000000000000000000000000000000000000000000000000000000000"
AT_PIN="1111111111111111111111111111111111111111"
AT_ODD="2222222222222222222222222222222222222222"
export FIX URL FPR_PIN FPR_ODD SHA_PIN AT_PIN AT_ODD

failed=0

# .what = run one arm body in a subshell; grade its exit code and one phrase; snap its stderr
_arm() {
  local arm="$1" label="$2" want_rc="$3" phrase="$4" body="$5"
  local out rc
  out="$( ( "$body" ) 2>&1 )"; rc=$?
  if [[ "$rc" -eq "$want_rc" && "$out" == *"$phrase"* ]]; then
    # the ✔ prints only once the snap holds, so a drifted message never reads green
    play_snap_assert arm="$arm" rendered="$out" mask="$FIX" || { failed=$(( failed + 1 )); return 0; }
    echo "   ├─ $arm. $label ✔"
    return 0
  fi
  echo "   ├─ $arm. $label: rc=$rc (want $want_rc), phrase '$phrase' $([[ "$out" == *"$phrase"* ]] && echo found || echo absent)" >&2
  printf '%s\n' "$out" | sed 's/^/   │     /' >&2
  failed=$(( failed + 1 ))
}

# ── web_fetch ───────────────────────────────────────────────────────
_f1() { curl() { return 28; }; web_fetch "$URL" --into "$FIX/out"; }
_f2() { curl() { return 22; }; web_fetch "$URL" --into "$FIX/out"; }
_f3() { curl() { return 6;  }; web_fetch "$URL" --into "$FIX/out"; }
_f4() { curl() { return 7;  }; web_fetch "$URL"; }
_f5() { web_fetch; }
_f6() { web_fetch "$URL" --onto "$FIX/out"; }
_f7() { web_fetch "$URL" "$URL.sig"; }
_arm F1 "a stall reads as a wire fault, not an absent file" 1 "TIMED OUT (curl 28)" _f1
_arm F2 "an http refusal reads as a url fault, not the wire" 1 "REFUSED the fetch (curl 22" _f2
_arm F3 "a dns miss names the resolver" 1 "could not be RESOLVED (curl 6)" _f3
_arm F4 "another curl code names the command to read why" 1 "the fetch failed (curl 7)" _f4
_arm F5 "no url is a caller fault" 2 "web_fetch: no url given" _f5
_arm F6 "an unknown flag is a caller fault" 2 "unknown flag '--onto'" _f6
_arm F7 "two urls are a caller fault" 2 "takes ONE url" _f7

# ── web_verify_sha256 ───────────────────────────────────────────────
_s1() { web_verify_sha256 --file "$FIX/artifact"; }
_s2() { web_verify_sha256 --file "$FIX/absent" --sha256 "$SHA_PIN"; }
_s3() { web_verify_sha256 --file "$FIX/artifact" --sha256 "sha256:$SHA_PIN"; }
_s4() { web_verify_sha256 --path "$FIX/artifact"; }
_arm S1 "a check with no hash is a caller fault" 2 "needs --file AND --sha256" _s1
_arm S2 "an absent file fails, never passes" 1 "no file at" _s2
_arm S3 "a mismatch names both hashes and both causes" 1 "INTEGRITY CHECK FAILED" _s3
_arm S4 "an unknown argument is a caller fault" 2 "unknown argument '--path'" _s4

# ── web_verify_gpg_fingerprints ─────────────────────────────────────
# the stub gpg reads one primary key, $GPG_FPR, and one subkey that must never count
_gpg_stub() {
  gpg() {
    case " $* " in
      *" --show-keys "*) printf 'pub:u:4096:1:X:0:::-:::scESC::::::23::0:\nfpr:::::::::%s:\nsub:u:4096:1:Y:0::::::e::::::23:\nfpr:::::::::%s:\n' "$GPG_FPR" "$FPR_ODD" ;;
      *" --import "*) return "${GPG_IMPORT_RC:-0}" ;;
      *" --verify "*) return "${GPG_VERIFY_RC:-0}" ;;
    esac
  }
}
_g1() { web_verify_gpg_fingerprints --file "$FIX/key.gpg"; }
_g2() { web_verify_gpg_fingerprints --file "$FIX/absent.gpg" --fpr "$FPR_PIN"; }
_g3() { PATH="$FIX/nopath"; web_verify_gpg_fingerprints --file "$FIX/key.gpg" --fpr "$FPR_PIN"; }
_g4() { _gpg_stub; GPG_FPR="$FPR_ODD"; web_verify_gpg_fingerprints --file "$FIX/key.gpg" --fpr "$FPR_PIN"; }
_g5() { web_verify_gpg_fingerprints --key "$FIX/key.gpg"; }
_arm G1 "a check with no pin is a caller fault" 2 "needs --file AND at least one --fpr" _g1
_arm G2 "an absent key file fails" 1 "no key file at" _g2
_arm G3 "an absent gpg refuses to trust the key" 1 "gpg is absent, so this key cannot be checked" _g3
_arm G4 "a wrong primary key names both sets" 1 "KEY FINGERPRINT MISMATCH" _g4
_arm G5 "an unknown argument is a caller fault" 2 "unknown argument '--key'" _g5

# ── web_verify_gpg_signature ────────────────────────────────────────
_v1() { web_verify_gpg_signature --file "$FIX/artifact" --sig "$FIX/artifact.sig"; }
_v2() { web_verify_gpg_signature --file "$FIX/artifact" --sig "$FIX/absent.sig" --key "$FIX/absent.gpg" --fpr "$FPR_PIN"; }
_v3() { PATH="$FIX/nopath"; web_verify_gpg_signature --file "$FIX/artifact" --sig "$FIX/artifact.sig" --key "$FIX/key.gpg" --fpr "$FPR_PIN"; }
_v4() { _gpg_stub; GPG_FPR="$FPR_PIN"; GPG_IMPORT_RC=2; web_verify_gpg_signature --file "$FIX/artifact" --sig "$FIX/artifact.sig" --key "$FIX/key.gpg" --fpr "$FPR_PIN"; }
_v5() { _gpg_stub; GPG_FPR="$FPR_PIN"; GPG_VERIFY_RC=1; web_verify_gpg_signature --file "$FIX/artifact" --sig "$FIX/artifact.sig" --key "$FIX/key.gpg" --fpr "$FPR_PIN"; }
_arm V1 "a check short of its four inputs is a caller fault" 2 "needs --file, --sig, --key and --fpr" _v1
_arm V2 "absent inputs are named, every one" 1 "absent file(s)" _v2
_arm V3 "an absent gpg refuses to run the artifact" 1 "gpg is absent, so this signature cannot be checked" _v3
_arm V4 "a key gpg cannot import fails" 1 "could not read the pinned public key" _v4
_arm V5 "a signature the pinned key did not make fails, with three causes" 1 "SIGNATURE CHECK FAILED" _v5

# ── git_clone ───────────────────────────────────────────────────────
# the stub timeout drops its bounds and runs the rest; the stub git plays the remote
_git_stub() {
  timeout() { [[ "$1" == "-k" ]] && shift 2; shift; "$@"; }
  git() {
    case " $* " in
      *" clone "*) [[ "${GIT_CLONE_RC:-0}" -eq 0 ]] || return "$GIT_CLONE_RC"; mkdir -p "${@: -1}" ;;
      *" checkout "*) return "${GIT_CHECKOUT_RC:-0}" ;;
      *" rev-parse "*) printf '%s\n' "$GIT_HEAD" ;;
    esac
  }
}
_c1() { git_clone "$URL"; }
_c2() { git_clone "$URL" "$FIX/clone"; }
_c3() { git_clone "$URL" "$FIX/clone" --depth 1; }
_c4() { git_clone "$URL" "$FIX/clone" "$FIX/third" --at "$AT_PIN"; }
_c5() { _git_stub; timeout() { mkdir -p "$FIX/clone"; return 124; }; git_clone "$URL" "$FIX/clone" --at "$AT_PIN" --within 30; }
_c6() { _git_stub; GIT_CLONE_RC=128; git_clone "$URL" "$FIX/clone" --at "$AT_PIN"; }
_c7() { _git_stub; GIT_HEAD="$AT_ODD"; git_clone "$URL" "$FIX/clone" --at "$AT_PIN"; }
_c8() { _git_stub; GIT_CHECKOUT_RC=1; git_clone "$URL" "$FIX/clone" --at "$AT_PIN"; }
_arm C1 "a clone with no dir is a caller fault" 2 "needs a url AND a target dir" _c1
_arm C2 "an unpinned clone is refused, with where to find the sha" 2 "--at <commit> is required" _c2
_arm C3 "an unknown flag is a caller fault" 2 "unknown flag '--depth'" _c3
_arm C4 "a third positional is a caller fault" 2 "got a third" _c4
_arm C5 "a timeout reads as a wire fault, and the partial clone goes" 1 "the clone TIMED OUT after 30s" _c5
_arm C6 "a git error points at git's own words, and the partial clone goes" 1 "the clone failed (git 128)" _c6
_arm C7 "a checkout that lands elsewhere names both commits" 1 "checked out the WRONG commit" _c7
_arm C8 "a commit the remote lacks forbids a relaxed pin" 1 "the pinned commit is absent" _c8

# ── web_tempdir ─────────────────────────────────────────────────────
_t1() { mktemp() { return 1; }; web_tempdir prove; }
_t2() { chmod() { return 1; }; mktemp() { mkdir -p "$FIX/tempdir.fixed"; printf '%s\n' "$FIX/tempdir.fixed"; }; web_tempdir prove; }
_arm T1 "no private dir refuses a fixed name as fallback" 1 "could not make a private temp dir for 'prove'" _t1
_arm T2 "a dir that cannot be made private is removed" 1 "(chmod 700 failed)" _t2

echo ""
[[ "$failed" -eq 0 ]] || { echo "   💥 MalfunctionError: $failed arm(s) failed" >&2; exit 1; }
echo "🌲 each runtime fault renders its own qualified header and its own repair"
