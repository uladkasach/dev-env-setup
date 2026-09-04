#!/usr/bin/env bash
######################################################################
# .what = pull content from a grove to here
#
# .why  = work happens on the grove — logs, artifacts, edits made in a
#         remote tree. pull them back to inspect, diff, or commit from
#         the machine that holds the repo.
#
# usage:
#   rhx git.grove.pull <grove> --from <remote-path> --into <local-path>
#   rhx git.grove.pull grove-box --from '~/.log/install.log' --into .temp/
#
# guarantee:
#   - rides the grove's ssh alias (set by `git grove set`)
#   - creates the local parent dir
#   - a slash at the end of --from pulls CONTENTS (rsync/tar semantics)
#   - plan mode by default (safe preview)
######################################################################
set -o pipefail

# 🛑 the sink comes along — a pull's REFUSALS echo the bytes they refuse
#
# .why  every member name in this file came out of an archive the GROVE built,
#       so each is remote-chosen in full. the vets below refuse a traversal and
#       refuse a link — correctly — and then print the member at fault so a
#       human can read it. a member name may hold an OSC 52, and
#       `src/tmux.conf` sets `set-clipboard on`.
#
#       ⇒ so the refusal path is the ATTACK path: a grove that plants
#         `../../.ssh/authorized_keys` trips the guard, the pull is correctly
#         refused, and the guard's own message hands over the clipboard write
#         as a consolation prize.
#
# ⚠️ `src/ductwork.sh` claims round 5's boundary fix closed this class "for
#    free, because the name it was handed was stripped on the way in". that
#    holds only for names that arrive through `__duct_ssh_tmux`. this file
#    rides its OWN `ssh`, so it inherited none of it — one lesson, two holders,
#    and the second was invisible because the first one's note read complete.
#
# ⚠️ the VETS still read the RAW bytes. only the copy a human reads is
#    stripped, which is what `__duct_strip_escapes`'s own header requires: a
#    strip before the match would make the guard's subject a value the guard
#    itself rewrote.
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/git.grove.operations.sh"

GROVE="" FROM="" INTO="" MODE="plan"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from) FROM="$2"; shift 2 ;;
    --into) INTO="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --skill|--repo|--role) shift 2 ;;
    -h|--help)
      echo "git.grove.pull - pull content from a grove to here"
      echo ""
      echo "usage: rhx git.grove.pull <grove> --from <remote> --into <local> [--mode plan|apply]"
      echo ""
      echo "  <grove>       the grove name (from 'git grove list')"
      echo "  --from        remote path (dir or file). a slash at the end pulls contents"
      echo "  --into        local path"
      echo "  --mode apply  actually pull (default: plan)"
      exit 0
      ;;
    *) [[ -z "$GROVE" ]] && GROVE="$1"; shift ;;
  esac
done

if [[ -z "$GROVE" || -z "$FROM" || -z "$INTO" ]]; then
  echo "✋ usage: rhx git.grove.pull <grove> --from <remote> --into <local>" >&2
  exit 2
fi

echo "🐚 git.grove.pull --mode $MODE"
echo "   ├─ grove: $GROVE"
echo "   ├─ from:  $GROVE:$FROM"
echo "   └─ into:  $INTO"

if [[ "$MODE" != "apply" ]]; then
  echo ""
  echo "🐢 heres the wave — run with --mode apply to pull"
  exit 0
fi

mkdir -p "$INTO" || exit 1

######################################################################
# 🛑 .a PULL is an INGRESS boundary, and the grove is the untrusted half
#
#      the tree on the far side, and every byte of the archive it hands back,
#      is chosen by the GROVE. both transports below used to write into `$INTO`
#      on that side's word alone, so a compromised box chose where a laptop
#      wrote — the trust inversion `rule.require.narrowest-terminal-grant`
#      closes at the terminal, arrived at through a file transfer instead.
#
# ⚠️ .the two halves are closed DIFFERENTLY, and this said so of only one
#
#      the sentence above reads as one closure over both transports. it is two,
#      and the TYPE half and the NAME half are not symmetric:
#
#      | half | tar branch | rsync branch |
#      |---|---|---|
#      | member TYPE (link, device, fifo) | an allowlist, `grep -Ev '^[-d]'` | `--no-links --no-devices --no-specials` |
#      | member NAME (`/abs`, `..` traversal) | an explicit `case` vet | ⚠️ **none of ours** |
#
#      the "TWO carriers must hold the SAME policy" block below equalizes the
#      TYPE row and is silent on the NAME row. so the traversal half on the
#      rsync path is DELEGATED to rsync's own receiver-side name sanitization —
#      a version-dependent property, so it is named here rather than assumed.
#
#      ⇒ this is the twin of the escape note at `:190`, which states the same
#        shape: *"the guarantee belongs to RSYNC'S OWN escape, never to an
#        absence of names."*
#
# 🛑 .do NOT close it with a name vet bolted onto the rsync branch
#      `rsync -az` emits NO file list, so a reader over its output would have no
#      members to read, would find no violation on any input, and would go green
#      forever — a permanent ✔ dressed as a guard, which is worse than the stated
#      delegation (`gotcha.a-check-that-cries-wolf-gets-silenced`, the false-✔
#      half). the honest repair is this note plus a MEASURED version floor, and
#      the floor is owed rather than claimed: no measurement of rsync's name
#      handling has been made from this repo.
#
#   1. rsync `-az` PRESERVES a symlink, so a grove may leave
#      `logs/latest -> /home/<user>/.ssh` in the pulled tree. the next local
#      read of `$INTO/logs/latest/id_ed25519` then reads a key that never left
#      the laptop. `-a` also implies `-D`, so a device node and a FIFO ride
#      along too. so rsync carries FILES AND DIRECTORIES ONLY — `--no-links
#      --no-devices --no-specials` — and REFUSES, by name, when the far tree
#      held a member it would not carry. the full account is at that branch.
#
#   2. tar is worse, because it WRITES. two member shapes escape `-C "$INTO"`:
#        • a name that starts with `/`, or holds a `..` component
#        • a SYMLINK member, plus a later member that writes THROUGH it —
#          `x -> /home/<user>/.ssh`, then `x/authorized_keys`
#      the second is the mean one: each member is legal alone, and only the
#      ORDER makes it an escape. no `-C` flag sees that.
#
#      ⇒ so the archive lands in a temp file, every member is vetted, and the
#        extract runs only if all pass. the vet reads the SAME bytes that get
#        extracted, so there is no TOCTOU gap — a second remote call would open
#        one, because the far side is free to answer differently twice.
#
# ⚠️ .the vet REFUSES the whole archive rather than skip a bad member
#      a skip leaves a partial tree that reads as a complete one, and the caller
#      has no signal (`rule.forbid.failhide`). a refusal names the member.
######################################################################

######################################################################
# 🛑 the TWO carriers must hold the SAME policy, and for a release they did not
#
# .measured 2026-08-31. the two branches below disagreed on what a pull carries:
#
#     tar    refuses EVERY link member, and names the one at fault
#     rsync  `-az --safe-links` — drops an ESCAPING symlink and lands an
#            in-tree one, silently, plus devices and specials via `-a`'s `-D`
#
#   ⇒ and a laptop HAS rsync, so the branch every real pull took was the
#     lightly-guarded one. the hardened branch was the one that never ran.
#     that is `gotcha.a-check-that-cries-wolf` m.9 at the carrier level: one
#     claim, two readers, and the cheaper reader is the one that stays.
#
# .the repair = rsync carries regular files and directories, exactly as tar's
#   vet leaves. `--no-links` cancels `-a`'s `-l`, and `--no-devices
#   --no-specials` cancel its `-D`. `--safe-links` is then moot and gone: it
#   GRADED links, and no link is carried at all now.
#
# ⚠️ a silent drop is not enough — this file's own tar vet says why: "a skip
#    leaves a partial tree that reads as a complete one, and the caller has no
#    signal" (`rule.forbid.failhide`). so rsync's own refusal lines are
#    captured, and a pull that produced any REFUSES and names each member.
#
# ⚠️ the capture is into a temp file, never a second remote read. a second
#    call would open the TOCTOU gap the tar branch below closes on purpose —
#    the far side is free to answer differently twice.
#
# 🛑 .BOTH STREAMS, and the reader must not have to know which one
#
#   📜 measured 2026-08-31. this captured `2>"$PULL_LOG"` alone, and the
#      refusal below was UNREACHABLE — a permanent false ✔ on an ingress
#      boundary, plus the grove's own filenames straight to the terminal.
#
#   rsync sorts its output by CLASS, not by severity: an error goes to stderr
#   and an informational notice goes to STDOUT. `skipping non-regular file`
#   is the second kind, so a stderr-only capture holds no part of it.
#
#   ⇒ the evidence is in this repo, from the other carrier. `git.grove.push`
#     reads rsync's `deleting …` notice — the same class — off STDOUT, with
#     stderr discarded, and that check was SEEN RED against a grove with a
#     stale file planted on purpose. one fact, two holders, and the proven
#     holder is the one that read stdout (m.9).
#
#   ⚠️ and the leak was the worse half. an uncaptured stdout reaches kitty
#      raw, where `set-clipboard on` makes an OSC 52 in a FILENAME write this
#      human's clipboard — the class `__duct_ssh_tmux` exists to retire.
#
#   .why `2>&1` is safe here, and not a widened net: `-az` carries no `-v`,
#    so rsync emits no other stdout, and the grep below is anchored on two
#    literal tokens. a benign line cannot forge a refusal.
#
#   ✔ .the residue is SETTLED — measured 2026-09-01, rsync 3.2.7
#      the notice IS emitted at default verbosity, and it goes to **stdout**:
#
#        $ rsync -az --no-links far/ near/     # far/ held a symlink
#        stdout: skip notice, 45 bytes, and it NAMES the file it refused
#        stderr: (empty)
#
#      so the notice carries a GROVE-CHOSEN path, on the one stream this file
#      does not sink — which reads, on its face, as the dangerous half.
#
#   ✔ .and it is nonetheless INERT
#      rsync escapes a non-printable byte in a filename ITSELF. a symlink named
#      with a real OSC 52 came out as the literal text `\#033]52;c;…`, on both
#      the `-v` file list and the skip notice. no ESC byte reached the terminal.
#
#      ⇒ so no sink is owed here — but the guarantee belongs to RSYNC'S OWN
#        escape, never to an absence of names. that is a load-bear distinction:
#        an absence-of-names story would make `--no-links` look free to add
#        anywhere, and it is not.
#
#   ⚠️ .what would retire the guarantee — `-8` / `--8-bit-output`
#      that flag is exactly the opt-out of the escape measured above. it must
#      never reach an rsync whose output is a grove's to choose.
#
#   🛑 and the repair, if one were ever owed, is NOT a sink inside
#      `_grove_err_sunk`: `:240` below puts a GZIP STREAM on stdout, and a byte
#      filter over that corrupts the archive. it would have to be at the call.
######################################################################
if command -v rsync >/dev/null 2>&1; then
  PULL_LOG="$(mktemp)" || exit 1
  trap 'rm -f "$PULL_LOG"' EXIT

  # ⚠️ the SAME set the outbound half obeys — `GROVE_BOUNDARY_EXCLUDES`, from
  #    `git.grove.operations.sh`, never a copy inside `git.grove.push`. held
  #    there it reads as the boundary's policy while it is one half's, and this
  #    pull then carries `.git` back on both carriers. a pulled `.git` is not
  #    data —
  #    `core.hooksPath`, `core.fsmonitor`, and a `!`-prefixed alias each name a
  #    program git EXECUTES, on the box that holds the real credentials.
  #
  #    ⚠️ and on the INBOUND path a flag the FAR side reads is a REQUEST: the
  #       sender walks the tree, and the sender is the grove. what filters a
  #       hostile sender HERE is rsync's own receiver-side check of the file
  #       list — which is a version-dependent property of rsync, NOT an
  #       invariant, and this repo declares no rsync floor. `:104-122` books
  #       that floor as owed and states plainly that no measurement of rsync's
  #       name vet has been made from this repo.
  #
  #       🛑 so do NOT read this paragraph as the guarantee. `:104-122` is the
  #          single holder of what this branch does and does not prove; this
  #          line said *"what makes this branch a control is…"* until
  #          2026-09-02, which restated a guarantee the table twelve rows up
  #          books as unproven (m.9 — one fact, two holders, and the confident
  #          copy is the one a reader believes).
  #
  #       the tar branch below reaches its guarantee by a route this repo DOES
  #       own: it sends no `--exclude` up the wire at all, and its LOCAL
  #       extractor carries the flag instead (see its own block, at the
  #       `tar -xzf`).
  if ! rsync -az --no-links --no-devices --no-specials \
       "${GROVE_BOUNDARY_EXCLUDE_ARGS[@]}" \
       -e "ssh -o BatchMode=yes" "$GROVE:$FROM" "$INTO" >"$PULL_LOG" 2>&1; then
    echo "💥 pull failed — the grove could not serve '$FROM'" >&2
    # the grove chose these bytes, and they are on their way to a terminal
    __duct_strip_escapes < "$PULL_LOG" | tail -6 | sed 's/^/   /' >&2
    exit 1
  fi

  # rsync names each member it would not carry, one per line. that list IS
  # the refusal — a pull that met one is not a whole pull.
  # .note the two tokens are rsync's own, so the words are not ours to pick
  PULL_SKIPPED="$(grep -E '^(skipping|cannot )' "$PULL_LOG" || true)"
  if [[ -n "$PULL_SKIPPED" ]]; then
    echo "✋ refused — the grove's tree holds member(s) a pull does not carry" >&2
    # the grep above read the RAW bytes; only this copy is stripped
    printf '%s\n' "$PULL_SKIPPED" | __duct_strip_escapes | sed 's/^/   /' >&2
    echo "   ⇒ a pull carries FILES. a link's hazard is not its own: it is legal" >&2
    echo "     alone, and a later member written THROUGH it is legal alone —" >&2
    echo "     only the order escapes '$INTO'" >&2
    echo "   ⚠️ what DID transfer is already under '$INTO', and is a PARTIAL" >&2
    echo "      tree. read it as partial, or drop it and pull the file itself" >&2
    exit 2
  fi
else
  PULL_TMP="$(mktemp -d)" || exit 1
  trap 'rm -rf "$PULL_TMP"' EXIT

  ######################################################################
  # ⚠️ `$FROM` is quoted INTO a remote command, so it is code on that box
  #    ssh takes no argv — it joins its arguments and hands one string to a
  #    login shell. the prior form wrapped `$FROM` in single quotes, which one
  #    single quote in the path closes. base64's alphabet is `[A-Za-z0-9+/=]`
  #    and holds no shell metacharacter, so the quotes cannot be closed
  #    (`src/ductwork.sh`'s `__duct_ssh_tmux` carries the same reason in full)
  ######################################################################
  FROM_B64="$(printf '%s' "$FROM" | base64 | tr -d '\n')"
  # 🛑 `_grove_err_sunk`, and the ERR half ONLY — stdout is a GZIP STREAM here,
  #    and a `| __duct_strip_escapes` in that path would corrupt the archive it
  #    is meant to protect. stderr carries the remote tar's own words about
  #    grove-chosen paths, plus whatever a login rc or a Banner writes there
  if ! _grove_err_sunk ssh "$GROVE" "tar -czf - -- \"\$(printf %s '$FROM_B64' | base64 -d)\"" > "$PULL_TMP/pull.tar.gz"; then
    echo "💥 pull failed — the grove could not read '$FROM'" >&2
    exit 1
  fi

  # 1. every member NAME must stay under the extract root
  #    `|| [[ -n "$member" ]]` because a read loop drops a final line that ends
  #    with no newline (`gotcha.while-read-drops-the-last-line`)
  if ! MEMBERS="$(tar -tzf "$PULL_TMP/pull.tar.gz")"; then
    echo "💥 pull failed — the archive could not be read" >&2
    exit 1
  fi
  while IFS= read -r member || [[ -n "$member" ]]; do
    [[ -z "$member" ]] && continue
    case "$member" in
      /*|..|../*|*/../*|*/..)
        echo "✋ refused — this archive holds a member that escapes '$INTO'" >&2
        # the VET above read the raw bytes; only this copy is stripped
        echo "   member: $(printf '%s' "$member" | __duct_strip_escapes)" >&2
        echo "   ⇒ a pull is an INGRESS boundary and the grove chose this name," >&2
        echo "     so an extract would write where the grove said, not where you did" >&2
        exit 2
        ;;
    esac
  done <<< "$MEMBERS"

  ######################################################################
  # 2. NO link member at all — not a vetted one, not any
  #
  # 🛑 .why the target is never parsed, and the TYPE decides instead
  #      this read the target out of `tar -tv` prose and judged it. two ways
  #      that is unsound, and the grove picks both names:
  #
  #        a HARDLINK renders `name link to target`, with no ` -> ` in it. so
  #        `${line##* -> }` returned the WHOLE line, which starts with `h` and
  #        matched no escape pattern — every hardlink passed, unread.
  #
  #        a FILENAME may itself hold ` -> `. the strip is greedy, so a member
  #        named `x -> /etc/passwd -> ok` hands the vet `ok` while the real
  #        target is absolute. a first-match split fails the mirror way.
  #
  #      ⇒ there is no delimiter that separates a name from a target when the
  #        far side chooses both. so the vet does not look for one. a member's
  #        TYPE is column 1 of `-tv` and the grove cannot punctuate its way out
  #        of that (`rule.require.solve-at-cause`).
  #
  # ⚠️ .why a refusal rather than a stricter parse
  #      a link is not what a pull is for — it carries a checkout's FILES back.
  #      and a link is the one member whose hazard is not its own: `a -> /etc`
  #      is legal alone, and a later `a/passwd` is legal alone, and only the
  #      ORDER writes through it. to refuse the type retires the whole class.
  #      the rsync path above reaches the same end by another route: it does not
  #      GRADE a link, it declines to carry one at all (`--no-links`).
  ######################################################################
  # 🛑 .an ALLOWLIST of types, never a denylist
  #
  #    📜 measured 2026-09-01: a denylist of `grep -E '^[lh]'` reaches symlink
  #      and hardlink, the two types the block above argues about. column 1 of
  #      `-tv` also spells `b` (block), `c` (char), `p` (FIFO), and `s`
  #      (socket), and every one of those passes such a vet and is created by
  #      `tar -x` below.
  #
  #    ⇒ so it makes the sentence at the extract — *"both branches hand back
  #      the same tree"* — FALSE: rsync takes `--no-links --no-devices
  #      --no-specials`, which is files and dirs ONLY. a `^[lh]` tar branch
  #      matches that on two member types of six.
  #
  # ⚠️ .why the INVERSION, and not four more letters
  #      a denylist is a claim about the set of types that exist, and it is only
  #      as complete as its author's picture of tar. `^[-d]` is a claim about
  #      what a pull CARRIES — a file and a directory — which is the sentence
  #      the rsync branch already enforces with a flag. a member type nobody
  #      here has heard of is REFUSED rather than admitted, so the reader cannot
  #      be outgrown (`rule.require.solve-at-cause`).
  #
  # ⚠️ .the sharp end is a HANG, not an escalation
  #      `b` and `c` need `mknod` privilege and fail for an unprivileged user.
  #      a `p` is created freely, and the next local read of that path — a
  #      `cat`, an editor, a grep, the prompt's own git read — blocks forever.
  NOTFILES="$(tar -tvzf "$PULL_TMP/pull.tar.gz" | grep -Ev '^[-d]' || true)"
  if [[ -n "$NOTFILES" ]]; then
    echo "✋ refused — this archive holds member(s) that are not files or dirs" >&2
    # the `grep -Ev '^[-d]'` above read the raw bytes; only this copy is stripped
    printf '%s\n' "$NOTFILES" | __duct_strip_escapes | sed 's/^/   /' >&2
    echo "   ⇒ a LINK's hazard is not its own: it is legal alone, and a later" >&2
    echo "     member written THROUGH it is legal alone. only the order escapes" >&2
    echo "   ⇒ a FIFO's hazard is the read that follows: the next local open of" >&2
    echo "     that path blocks forever, and the prompt opens paths on its own" >&2
    echo "   fix: pull the file itself, or install rsync — the branch above" >&2
    echo "        carries files and dirs only, so it needs no parse of tar's" >&2
    echo "        output to reach the same verdict" >&2
    exit 2
  fi

  ######################################################################
  # 3. vetted — extract, minus what no grove boundary carries
  #
  # `--no-same-owner` so a member cannot ask for a chown.
  #
  # 🛑 .why the exclusion is applied HERE, on the LOCAL extract
  #      the archive was built ON THE GROVE, so a `--exclude` in the remote tar
  #      would be a request the far side may decline — and the far side is the
  #      one this boundary exists to distrust. the local extractor is the only
  #      half of this carrier whose behaviour is ours.
  #
  #      ⇒ so the flag is not sent up the wire at all. the whole tree comes
  #        back and the excluded members are refused as they are written. that
  #        costs bandwidth and buys a control rather than a courtesy.
  #
  # ⚠️ .the SAME plain args the rsync branch takes, and that was MEASURED
  #      each member expanded into four globs rests on the belief that tar
  #      tests a member name on its own and so would carry `.git/config` past
  #      an `--exclude .git`. an archive says otherwise —
  #      GNU tar 1.35 refused `.git/config`, `sub/.git/config`, and
  #      `deep/a/node_modules/pwned` on the plain form, and the extra globs
  #      changed no row. the account sits beside the declaration in
  #      `git.grove.operations.sh`.
  #
  # ⚠️ .and it SKIPS rather than refuses, on purpose
  #      the rsync branch above skips these members silently, so a refusal here
  #      would make one command have two outcomes, split by which tool the box
  #      happens to hold — the exact defect the carrier pair retires
  #      (`term=carrier`). both branches hand back the same tree.
  ######################################################################
  if ! tar -xzf "$PULL_TMP/pull.tar.gz" -C "$INTO" --no-same-owner \
       "${GROVE_BOUNDARY_EXCLUDE_ARGS[@]}"; then
    echo "💥 pull failed — the archive did not extract" >&2
    exit 1
  fi
fi

echo ""
echo "🐢 cowabunga! pulled from $GROVE"
