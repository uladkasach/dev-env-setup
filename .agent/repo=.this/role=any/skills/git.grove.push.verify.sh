#!/usr/bin/env bash
######################################################################
# .what = rhx dispatch to the layout check for `git.grove.push`
#
# .why  = `git.grove.push` carries one payload by two carriers (rsync by default,
#         tar on `--via tar`). that pair is only safe while the two AGREE on where
#         content lands — and on 2026-07-29 they did not, which wrote a shadow
#         copy at `src/src/` and reported success.
#
#         so the check is the guard that makes the two-carrier design legitimate.
#         it is a skill, not a play, because a check nobody can invoke by name is
#         a check nobody runs (rule.require.wrap-cli-in-skills) — and a play lives
#         in the gitignored `.play/temporary/`, so a skill that shelled out to one
#         would break on every fresh checkout.
#
# .why it runs FROM here, not ON the grove
#         its subject is the LOCAL push skill, so it must invoke the very code
#         under test. it still reaches the grove only through skills
#         (rule.require.reach-a-grove-through-its-duct).
#
# usage:
#   rhx git.grove.push.verify grove-1
#
# guarantee:
#   - READ-ONLY with respect to the repo; writes only under temp dirs it makes,
#     locally and on the grove, and removes both
#   - drives BOTH carriers explicitly via --via, so neither branch can rot unseen
#
# exit:
#   0 = both carriers agree, for a dir, a dir with a slash, and a single file
#   1 = at least one claim failed; each is named
#   2 = usage
######################################################################
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$HERE" rev-parse --show-toplevel)"
PUSH="$REPO_ROOT/.agent/repo=.this/role=any/skills/git.grove.push.sh"
SEND="$REPO_ROOT/.agent/repo=.this/role=any/skills/git.grove.send.sh"

GROVE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill|--repo|--role) shift 2 ;;
    -h|--help)
      echo "git.grove.push.verify - assert both push carriers land content alike"
      echo ""
      echo "usage: rhx git.grove.push.verify <grove>"
      echo ""
      echo "  <grove>  the grove to push test fixtures to (they are removed after)"
      exit 0
      ;;
    *) [[ -z "$GROVE" ]] && GROVE="$1"; shift ;;
  esac
done

if [[ -z "$GROVE" ]]; then
  echo "✋ git.grove.push.verify: a grove is required" >&2
  echo "   └─ e.g. rhx git.grove.push.verify grove-1" >&2
  exit 2
fi

FAILED=0
pass() { echo "   ✔ $1"; }
fail() { echo "   ✋ $1" >&2; FAILED=$(( FAILED + 1 )); }

# a local sandbox to push FROM, and a remote sandbox to push INTO
LOCAL_TMP="$(mktemp -d)"

# 🛑 .why the remote sandbox is MINTED BY THE GROVE, not named by this laptop
#
#    a grove's `/tmp` is SHARED between its two seats (`term=seat`, and
#    `rule.forbid.fixed-paths-in-a-shared-tmp`), so a
#    `/tmp/git.grove.push.verify.$$` is:
#
#      1. PREDICTABLE — a pid is a small integer, and the prefix is this
#         file's own name, in a public repo. the other seat can enumerate it
#      2. PRE-CREATABLE — the seat that gets there first owns the inode. a
#         symlink planted at that path is followed by the push that writes
#         through it AND by the `rm -rf` that cleans up after
#
#    ⇒ so a check that exists to prove a push lands content correctly has its
#      content land somewhere the other seat chose, and then deletes that
#      place. `mktemp -d` on the grove closes both halves at once: the
#      kernel picks the name (unguessable) and creates the dir 0700 with
#      `O_EXCL` (unsquattable) — a CLASS fix, not a race made narrower.
#
#    ⚠️ `--reply` and not a bare send: a bare send returns the SEND's exit
#       code and the send's own banner, so the path read back would be two
#       lines of decoration (`gotcha.the-duct-returns-the-send-not-the-answer`).
#    ⚠️ the template sits directly under `$HOME`, not under `$HOME/.cache`: a
#       `--what` carries ONE step (it refuses `;`, `&&`, `||`), so there is no
#       `mkdir -p` to pair with it, and `.cache` may not exist. `$HOME` always
#       does, and it is per-seat — the one property that matters here, since a
#       `/tmp` shared across seats is the whole defect.
REMOTE_TMP="$(bash "$SEND" "$GROVE" --reply --what 'mktemp -d "$HOME/.git.grove.push.verify.XXXXXXXX"' | tr -d '\r\n')"

######################################################################
# 🛑 the ANSWER is held to the grammar the TEMPLATE fixes
#
# 📜 measured 2026-08-31. a test of `"$REMOTE_TMP" != /*` accepts `/` itself —
#    a glob `*` matches the empty string — so the cleanup below can be aimed at
#    the grove's own root. a `'` in the answer closes the quote at that same
#    `rm -rf` and appends a command.
#
#   ⚠️ and "it came back from a `mktemp -d`" is the answer used as its own
#   evidence (`gotcha.my-own-note-became-my-evidence`): a grove is ASSUMED
#   COMPROMISED, so what comes back is whatever it chose to send, and the
#   template describes what we ASKED for rather than what we were told.
#
# ⚠️ .severity — every consequence lands on the UNTRUSTED side
#    the `rm -rf` runs on the grove, and the basename becomes a `--into` for
#    five pushes to that same grove. an attacker who can pick this string
#    already owns the box, so this buys them no reach they lacked. the grammar
#    is owed because the CLAIM would be false, not because the outcome is.
#
# .the grammar: an absolute path, then this skill's own literal prefix, then
#  mktemp's eight `[A-Za-z0-9]`. it is checkable because WE wrote the template
#
# ✔ .SEEN TO DISCRIMINATE, 2026-09-01
#      PASS     /home/camper/.git.grove.push.verify.aB3xY9zQ
#      refused  /                          ← what a bare `!= /*` accepts
#      refused  /home/camper               ← a bare home
#      refused  /etc
#      refused  …aB3xY9zQ'; touch pwned    ← the quote that closes the rm's arg
#      refused  ….verify.short             ← a suffix of the wrong length
######################################################################
REMOTE_TMP_GRAMMAR='^/[A-Za-z0-9._/-]*/\.git\.grove\.push\.verify\.[A-Za-z0-9]{8}$'
if [[ -z "$REMOTE_TMP" ]]; then
  echo "✋ git.grove.push.verify: the grove named no sandbox dir to push into" >&2
  echo "   └─ fix: check the duct answers — rhx git.grove.send $GROVE --reply --what 'echo ok'" >&2
  exit 1
fi
if [[ ! "$REMOTE_TMP" =~ $REMOTE_TMP_GRAMMAR ]]; then
  echo "✋ git.grove.push.verify: the grove's answer is not a sandbox this skill asked for" >&2
  # the value is about to be PRINTED, and a grove chose it — so C0 and DEL come
  # out first. a parameter expansion, not the duct's sink: this file does not
  # source ductwork, and a call to a function that is not in scope would be
  # `command not found` on the one path that reports a refusal
  #
  # 🛑 .this expansion is NOT a full escape guard, and the bound is measured
  #    `[[:cntrl:]]` in bash does NOT reach C1 — `src/zshrc.sh:90-107` records
  #    the run: bash 5.2 cut neither `c2 9b` nor a bare `9b`. so a payload
  #    spelled `c2 9d` `52;c;<b64>` `c2 9c` is a complete OSC 52 that carries
  #    no ESC and no C0 byte at all, and this line would pass it whole.
  #
  #    ⇒ what actually bounds C1 here is UPSTREAM: `git.grove.send:891` pipes
  #      the reply's payload through `__duct_strip_escapes`, whose third stage
  #      cuts both C1 spellings. this line is the belt to that suspenders, and
  #      it is written down because the CLAIM was wider than the primitive —
  #      not because a byte reaches a terminal today.
  #
  # ⚠️ do NOT "fix" this by a call to `__duct_strip_escapes`. the reason two
  #    paragraphs up still holds: the function is not in scope, and a
  #    `command not found` on the one path that reports a refusal is a worse
  #    outcome than a residue the send already cut
  echo "   └─ it answered: '${REMOTE_TMP//[[:cntrl:]]/}'" >&2
  echo "   └─ expected:   <abs-path>/.git.grove.push.verify.<8 alnum>" >&2
  echo "   ⇒ the cleanup below is an 'rm -rf' on this value, so an answer that" >&2
  echo "     is not the dir we asked for is refused rather than aimed at" >&2
  exit 1
fi
cleanup() {
  rm -rf "$LOCAL_TMP"
  # .why `rm -rf` on a path the GROVE minted for this run, and only that path:
  #      the answer was held to REMOTE_TMP_GRAMMAR above, so it names a dir
  #      under a home with this skill's own prefix and mktemp's own suffix —
  #      never a repo, never a bare home, never another seat's file
  bash "$SEND" "$GROVE" --what "rm -rf '$REMOTE_TMP'" >/dev/null 2>&1 || true
}
trap cleanup EXIT

mkdir -p "$LOCAL_TMP/atree/nested"
echo "leaf-content" > "$LOCAL_TMP/atree/leaf.txt"
echo "deep-content" > "$LOCAL_TMP/atree/nested/deep.txt"
echo "file-content" > "$LOCAL_TMP/afile.txt"

echo "🌲 does git.grove.push land content where --into says, on BOTH carriers?"
echo ""

######################################################################
# .what = push one shape by one carrier, then report what the grove holds
#
# .why  = the assertion is always the same — "the CONTENT is at --into, and no
#         extra directory level was inserted" — so it is written once. an earlier
#         draft spelled each claim inline and one of them drifted from the others
######################################################################
probe() {
  local label="$1" carrier="$2" from="$3" expect_rel="$4"

  # 🛑 TWO spellings of one directory, and each is required by a different caller
  #
  #    `--into` REFUSES an absolute path (`git.grove.push.sh:205`), because both
  #    transports expand it against the grove's `$HOME` — so `/x` would write
  #    outside `$HOME` and `~/x` would make a directory literally named `~`.
  #    `--what`, by contrast, runs in the grove's own shell, where only the
  #    absolute path is unambiguous.
  #
  #    📜 the round-5 fix that made the grove MINT this dir (`mktemp -d`, so the
  #       name is unguessable and unsquattable) returned an ABSOLUTE path, and
  #       handed it straight to `--into`. every probe then took the
  #       "the push itself failed" branch — under `>/dev/null 2>&1`, so the real
  #       cause never reached a screen. a security fix silenced the check beside
  #       it (`gotcha.a-check-that-cries-wolf-gets-silenced`).
  #
  #    ⇒ the basename IS the `$HOME`-relative path, because the template puts
  #      the dir directly under `$HOME`. so this needs no knowledge of the
  #      grove's `$HOME` and no second round trip to ask for it.
  local dest_rel="${REMOTE_TMP##*/}/$label"
  local dest="$REMOTE_TMP/$label"
  bash "$SEND" "$GROVE" --what "rm -rf '$dest'" >/dev/null 2>&1 || true

  # .why `--via` and not a PATH shim: to reach the tar branch without it, a check
  #      must shadow rsync with a stub that exits 127. `--via` makes the carrier
  #      a first-class input instead (the human: "have that grove push not
  #      fallback but recommend that the caller uses an explicit opt into tar").
  #
  #      that is the better shape for a check too: a check that must SABOTAGE its
  #      subject to reach a branch exercises the sabotage as much as the branch
  # ⚠️ the push's own output is CAPTURED, never discarded. under `>/dev/null 2>&1`
  #    the absolute-path refusal above hides entirely: the fail-text says "the
  #    push itself failed" while the push already said exactly WHY, into
  #    /dev/null (`rule.forbid.failhide`)
  local push_out push_rc=0
  push_out="$(bash "$PUSH" "$GROVE" --from "$from" --into "$dest_rel" --via "$carrier" --mode apply 2>&1)" || push_rc=$?
  if [[ "$push_rc" -ne 0 ]]; then
    fail "$label [$carrier] — the push itself failed (rc=$push_rc); it said:
$(printf '%s\n' "$push_out" | tail -6 | sed 's/^/          /')"
    return
  fi

  # the claim: the expected relative path exists under --into
  if bash "$SEND" "$GROVE" --what "test -f '$dest/$expect_rel'" >/dev/null 2>&1; then
    pass "$label [$carrier] — $expect_rel is at --into"
  else
    fail "$label [$carrier] — $expect_rel is ABSENT under --into.
        the content went elsewhere; read the tree with
          rhx git.grove.send $GROVE --what 'find $dest'"
    return
  fi

  # the anti-claim that catches the src/src/ shape specifically. a nested repeat
  # of the source's basename under --into is the exact defect of 2026-07-29
  local base; base="$(basename "${from%/}")"
  if bash "$SEND" "$GROVE" --what "test -e '$dest/$base/$expect_rel'" >/dev/null 2>&1; then
    fail "$label [$carrier] — a NESTED '$base/' level was inserted under --into.
        this is the src/src/ shadow-copy defect; the carrier does not honor
        'contents land at --into'"
  else
    pass "$label [$carrier] — no nested '$base/' level was inserted"
  fi
}

echo "  1. a directory, no slash at the end — the shape that broke"
probe dir-noslash-rsync rsync "$LOCAL_TMP/atree"  nested/deep.txt
echo ""
echo "  2. a directory, WITH a slash at the end — must be identical to 1"
probe dir-slash-rsync   rsync "$LOCAL_TMP/atree/" nested/deep.txt
echo ""
echo "  3. the same directory, forced through the tar fallback"
probe dir-noslash-tar   tar   "$LOCAL_TMP/atree"  nested/deep.txt
echo ""
echo "  4. a single FILE by rsync — the shape tar's --strip-components broke"
probe file-rsync        rsync "$LOCAL_TMP/afile.txt" afile.txt
echo ""
echo "  5. the same file, forced through the tar fallback"
probe file-tar          tar   "$LOCAL_TMP/afile.txt" afile.txt
echo ""

if [[ "$FAILED" -eq 0 ]]; then
  echo "🌲 both carriers agree — '--into X' puts the content at X, every shape"
  exit 0
fi
echo "🌲 $FAILED claim(s) failed (named above)" >&2
exit 1
