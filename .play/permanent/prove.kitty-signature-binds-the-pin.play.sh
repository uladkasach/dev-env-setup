#!/usr/bin/env bash
######################################################################
# .what = prove `4.3.2.emulator`'s tarball-signature gate accepts a signature
#         ONLY from the pinned key — and refuses a good signature from any other
#
# .why
#   - kitty's release tarball is a BINARY this repo installs to /opt and
#     puts on PATH — whoever signs it chooses what the human's terminal
#     executes
#   - the gate must never read:
#       gpg --verify "$sig" "$tarball" | grep "Good signature"
#   - that phrase is emitted for a good signature from ANY key gpg's store
#     knows
#   - a pin check beside it is a CONTAINMENT test — the two never meet
#   - a key file that holds the real key BESIDE an attacker's satisfies both
#   - this repo names that attack one domain over:
#       "a host's public keys are public, so a real key beside a forged one is
#        the cheap attack — every offered key is checked, never just one."
#       (`git.grove.trust.gen`)
#
# 🛑 .why the pattern is READ FROM THE BUNDLE and never retyped here
#   - a probe that restates the pattern proves a pattern nobody ships
#   - two copies drift silently — one set, two holders
#     (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9)
#   - both the pin and the reader are lifted out of `provision.upsert.sh`
#     itself
#   - this play fails LOUDLY if either can no longer be found
#
# .what it does to the box
#   - READS one tracked file, matches four synthetic `--status-fd` lines
#     against the pattern that file declares
#   - no network, no gpg, no install, no write — a `prove.*`, changes no
#     state
#
# guarantee:
#   - arm C is the clamp: feeds the OLD reader's entire evidence
#     ("Good signature") and demands the new one REJECT it. a probe nobody
#     has seen fail is a guess (`rule.require.clamp-edge-cases`)
#   - arm D guards the opposite direction: a SUBKEY-signed release whose
#     primary is the pinned key must still PASS, so the fix cannot become a
#     false ✋
#
# usage:
#   rhx play.run --play prove.kitty-signature-binds-the-pin
#
# exit:
#   0 = the gate binds the signature to the pin
#   1 = it does not
#   2 = the subject could not be read, so no claim was proven
######################################################################

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git -C "$SELF_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
SUBJECT="$ROOT/src/grove.provision/4.terminal/4.3.kitty/4.3.2.emulator/provision.upsert.sh"

echo "🔎 prove.kitty-signature-binds-the-pin"
echo "   └─ subject: ${SUBJECT#"$ROOT"/}"
echo ""

if [[ -z "$ROOT" || ! -r "$SUBJECT" ]]; then
  echo "   ✋ no readable subject at ${SUBJECT:-<no checkout>}" >&2
  echo "      ⇒ an absent subject proves no claim, so this declines" >&2
  exit 2
fi

######################################################################
# .what = 0b. READ THE CODE, NOT THE PROSE
#
# 🛑 .why
#   - every ask below is a claim about what the bundle RUNS
#   - a `#`-led line runs on no box
#   - a reader that scans the raw file can be answered by a sentence ABOUT
#     the gate instead of the gate
#
# 📜 2026-09-02 — inverted this play's own verdict
#   - `provision.upsert.sh:233` is a comment that reads
#     `this read \`gpg --verify … | grep "Good signature"\`, and that phrase…`
#     — the bundle's own record of the defect it closed
#   - the discriminator at `:101` asked the RAW file for `| grep `, so that
#     comment answered it
#   - when both collapse to exit 2, a gate that MOVED (a decline) reports as
#     a gate REVERTED (a failure) — a security regression that had not
#     happened
#   - the prose that documents the fix becomes the evidence the fix was
#     undone (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.7)
#   - the defect entered via the repair that added `:101` the day before —
#     that discriminator targets a stream that holds both code and prose
#
# ⚠️ .why the strip is exact here
#   - the strip also cuts a `#` inside a quoted string
#   - none of the three lines lifted below holds one — the pin is 40 hex,
#     both greps quote a GNUPG status prefix
#   - a file where `#` can sit inside a string needs a real parse
######################################################################
CODE="$(sed 's/#.*$//' "$SUBJECT")"

######################################################################
# 1. lift the PIN out of the bundle
######################################################################
KEY_FPR="$(sed -n 's/.*local key_fpr="\([0-9A-Fa-f]\{40\}\)".*/\1/p' <<<"$CODE" | head -1)"
if [[ -z "$KEY_FPR" ]]; then
  echo "   ✋ the bundle declares no 40-hex key_fpr" >&2
  echo "      ⇒ the pin is what this play measures against, so it cannot proceed" >&2
  exit 2
fi

######################################################################
# .what = 2. lift the READER out of the bundle
#
# .why
#   - the pattern is taken verbatim from the `grep` the phase runs
#   - the bundle's own variable is then expanded
#   - what is measured below is the exact text that ships, never a
#     paraphrase
######################################################################
RAW="$(sed -n 's/.*| grep "\(\^\\\[GNUPG:[^"]*\)".*/\1/p' <<<"$CODE" | head -1)"
if [[ -z "$RAW" ]]; then
  ####################################################################
  # 🛑 .what = two opposite causes land here — told apart before either is
  #     reported
  #
  # .why
  #   - the gate REVERTED to an unbound read — the one condition this play
  #     exists to catch — is a FAILURE (exit 1)
  #   - the gate MOVED, or was respelled past this extraction, so the
  #     subject is gone — is a DECLINE (exit 2)
  #   - when both collapse to exit 2, a revert reports as *"declined — its
  #     subject is absent, so it proved no claim"* (`play.run:200`), while
  #     the subject is fully present and only the PROPERTY is absent
  #   - the one condition this clamp exists to catch would then grade as the
  #     runner's quietest verdict
  #     (`gotcha.a-check-that-cries-wolf-gets-silenced`, q9 — an audit that
  #     claims no verdict gives a reader none to distrust)
  ####################################################################
  # ⚠️ .why this tests `$CODE`, never `$SUBJECT`
  #   - see `:0b`
  #   - a test against the raw file is answered by the comment at the
  #     subject's `:233`, which turns every MOVED gate into a reported
  #     REVERT
  if grep -q '| grep ' <<<"$CODE"; then
    echo "   ✋ the bundle runs a grep on gpg's output, and it is NOT" >&2
    echo "      VALIDSIG-anchored" >&2
    echo "      ⇒ this is the revert this play exists to catch: a bare" >&2
    echo "        'Good signature' passes for ANY key in the local store" >&2
    echo "      read it: ${SUBJECT#"$ROOT"/}" >&2
    exit 1
  fi
  echo "   ✋ the bundle runs no grep on gpg's output at all" >&2
  echo "      ⇒ the gate moved, so this play's subject is absent and it" >&2
  echo "        declines rather than report on a file it cannot find" >&2
  echo "      read it: ${SUBJECT#"$ROOT"/}" >&2
  exit 2
fi

####################################################################
# 🛑 .what = BOTH SPELLINGS of the bundle's variable are expanded
#
# .why
#   - `$key_fpr` and `${key_fpr}` are the same value to bash, different
#     text to a substitution
#   - the `sed` above takes either happily — its `[^"]*` does not care
#   - a gate respelled with braces would reach the pin test below with
#     `${key_fpr}` intact and go RED against a byte-for-byte equally strict
#     check
#   - that is the worst clamp output: a loud ✋ with a named fix, aimed at
#     correct code (m.7)
#   - the brace form is ordinary shell — the trap needs no mistake to fire,
#     only a reformat
####################################################################
PATTERN="${RAW//\$\{key_fpr\}/$KEY_FPR}"
PATTERN="${PATTERN//\$key_fpr/$KEY_FPR}"

if [[ "$PATTERN" != *"$KEY_FPR"* ]]; then
  echo "   ✋ the reader does not name the pinned fingerprint" >&2
  echo "      pattern: $PATTERN" >&2
  echo "      ⇒ a signature check that names no key is the very defect this" >&2
  echo "        play exists to catch" >&2
  exit 1
fi

echo "   ├─ pin:     $KEY_FPR"
echo "   ├─ reader:  $PATTERN"
echo "   ├─ arms"

ATTACKER="DEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEF"
SUBKEY="AAAA1111AAAA1111AAAA1111AAAA1111AAAA1111"
TAIL="2024-01-01 1704067200 0 4 0 1 10 00"

fails=0

# .what = feed one synthetic status stream, report whether the reader matched
_arm() {
  local name="$1" want="$2"; shift 2
  local got="no"
  printf '%s\n' "$@" | grep "$PATTERN" >/dev/null 2>&1 && got="yes"
  if [[ "$got" == "$want" ]]; then
    echo "   │  ├─ $name ✔ (match=$got, as required)"
  else
    echo "   │  ├─ $name ✋ match=$got, required=$want" >&2
    fails=$(( fails + 1 ))
  fi
}

# A — the pinned key signed it. the green direction
_arm "A. pinned key signed        " "yes" \
  "[GNUPG:] NEWSIG" \
  "[GNUPG:] GOODSIG 06BC317B515ACE7C Kovid Goyal" \
  "[GNUPG:] VALIDSIG $KEY_FPR $TAIL $KEY_FPR"

# B — a DIFFERENT key signed it; gpg is perfectly happy about that
_arm "B. another key signed       " "no" \
  "[GNUPG:] NEWSIG" \
  "[GNUPG:] GOODSIG $ATTACKER Someone Else" \
  "[GNUPG:] VALIDSIG $ATTACKER $TAIL $ATTACKER"

# 🛑 .what = C — THE CLAMP
# .why
#   - the OLD reader's entire evidence: gpg's human-read line — it names a
#     signer the pin never approved
#   - the new reader must reject it
#   - a pass here means the gate has reverted
_arm "C. bare 'Good signature'    " "no" \
  'gpg: Signature made Mon 01 Jan 2024' \
  'gpg: Good signature from "Someone Else" [unknown]'

# D — a SUBKEY signed it; the PRIMARY is the pinned key
#     correct, common upstream practice — the gate must NOT redden on it
_arm "D. subkey of the pinned key " "yes" \
  "[GNUPG:] VALIDSIG $SUBKEY $TAIL $KEY_FPR"

echo "   │  └─"
echo ""

if [[ "$fails" -eq 0 ]]; then
  echo "🌲 the signature gate binds to the pin ✔"
  echo "   └─ a good signature from an unpinned key is refused"
  exit 0
fi

echo "   ✋ $fails arm(s) disagree with the required verdict" >&2
echo "      ⇒ read the gate: ${SUBJECT#"$ROOT"/}" >&2
exit 1
