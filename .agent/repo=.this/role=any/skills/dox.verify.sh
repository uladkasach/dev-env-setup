#!/usr/bin/env bash
######################################################################
# .what = sweep every TRACKED file for an identifier that names a real
#         account, host, principal, or person — and name each hit
#
# .why  = `rule.forbid.dox-in-public-repo` is the one row in
#         `inventory.security-checks.md` the ledger ALWAYS knew had no reader.
#         it is also the rule that got violated: an aws account id shipped in a
#         shell comment, and it was found by a human's eye, once.
#
#         this repo is PUBLIC, and it is the repo a fresh machine is told to
#         `curl` from — so its readership is strangers by design. git keeps the
#         blob after a redaction, so the only cheap moment is BEFORE the push.
#         a reader that runs is the difference between a rule and a wish.
#
# 🛑 .why TRACKED files, and not a path glob
#         the boundary is PUBLICATION. `git ls-files` IS that set — it cannot
#         omit a file somebody added, and it cannot include a scratch file
#         `.gitignore` already holds back. a hand-written glob is a second
#         declaration of one set, free to drift (m.9), and it reports clean on
#         the file nobody added it to.
#
#         ⚠️ this is the inversion `5.1` asks for. every other security reader
#         here discovers its subjects BY THE PRESENCE OF A CHECK, so a subject
#         with no check is invisible to it. this one keys on the SUPERSET —
#         every published file — so a new file is in scope the moment it is
#         added, with no edit here.
#
# ⚠️ .what this does NOT do
#         it reads bytes and prints rows. it installs no package, contacts no
#         network, and needs no privilege or grove. `--prove` is the one mode
#         that writes, and it writes a canary it removes again (see below).
#
# .note = a SECRET is a different and worse category. an api key or private key
#         in this repo is not dox — it is a breach, and it wants rotation, not a
#         redaction. this reader does not hunt secrets.
#
# usage:
#   rhx dox.verify                        # sweep every tracked file
#   rhx dox.verify --root <dir>           # name the checkout explicitly
#   rhx dox.verify --quiet                # only the hits and the tally
#   rhx dox.verify --prove                # plant four canaries, confirm each BITES
#
# exit:
#   0 = no dox found, and at least one file was read
#   1 = at least one hit — each is named with its file, line, and rule
#   2 = no repo found, or the set was empty (proves no claim)
#
# ✔ .SEEN TO DISCRIMINATE, 2026-09-01 — three forms, and the two defects
#   each caught. a check proven in one direction only is half proven, so each
#   row below was watched RED under the defect and GREEN under the repair.
#
#   | the form planted           | with the defect | repaired |
#   |----------------------------|-----------------|----------|
#   | mid-line `<!-- id -->`     | ✔ seen          | ✔ seen   |
#   | end of line `account: id`  | ✋ UNSEEN       | ✔ seen   |
#   | beside a dummy, one line   | ✋ UNSEEN       | ✔ seen   |
#
#   row 2 needed the account rule's closing class to carry `|$`; row 3 needed
#   the dummy/exempt filters to ask the matched VALUE rather than the line.
#   both defects were live and both probes were green, because the probe
#   planted only row 1 — the one form its author could see (q11).
######################################################################
set -uo pipefail

ROOT=""
QUIET=0
PROVE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)  ROOT="${2:-}"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    --prove) PROVE=1; shift ;;
    --help|-h)
      sed -n '/^# usage:/,/^#####/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//;$d'
      exit 0
      ;;
    --repo|--role|--skill) shift 2 ;;
    # an unknown flag HALTS. a swallowed narrowing flag returns a verdict about
    # a subject the caller never named (shell.syntax.verify measured this)
    *)
      echo "   ✋ unknown flag: $1" >&2
      echo "      valid: --root <dir>  --quiet  --prove  --help" >&2
      exit 2
      ;;
  esac
done

######################################################################
# 🛑 the subject checkout is derived from THIS FILE, never from the cwd
#    — measured 2026-08-31, and it produced a false ✔
#
#    the first form tested `$PWD` and, when that missed, fell back to a
#    HARDCODED `$HOME/git/more/dev-env-setup`. `rhx` does not guarantee a cwd,
#    so three consecutive runs of the same command reported three subjects:
#
#      root: …/_worktrees/dev-env-setup.vlad.boot-grove-box   802 tracked files
#      root: …/_worktrees/dev-env-setup.vlad.boot-grove-box   705 tracked files
#      root: /home/vlad/git/more/dev-env-setup                341 tracked files
#
#    every one printed ✔. the last read a DIFFERENT CHECKOUT — one that holds
#    none of the edits under test — and said so only in a header nobody reads
#    twice. a green verdict about the wrong tree is the purest false ✔ there is
#    (`gotcha.a-check-that-cries-wolf-gets-silenced`, q2: does the evidence name
#    the SUBJECT?).
#
#    ⚠️ the FALLBACK was the worst half: it does not fail when it cannot find a
#    checkout, it silently reads a different one. an absent subject would have
#    exited 2 and been obvious.
#
#    ⇒ this skill lives INSIDE the checkout it reads, so its own path is the one
#      anchor that cannot drift with the cwd. `--root` stays the explicit
#      override, and is now the only way to point elsewhere.
######################################################################
if [[ -z "$ROOT" ]]; then
  SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ROOT="$(git -C "$SELF_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
fi

if [[ ! -d "$ROOT/.git" ]] && [[ ! -f "$ROOT/.git" ]]; then
  echo "   ✋ no git checkout at $ROOT" >&2
  echo "      ⇒ the tracked set would be empty, and a tally of 0 reads as a pass" >&2
  exit 2
fi

######################################################################
# 🛑 the DUMMIES — allowed by VALUE, never by file
#
#    `rule.forbid.dox-in-public-repo` and `term=dox` teach with examples, so the
#    corpus legitimately holds a fake account id and a fake instance id. those
#    files must still be READ — an allowlist keyed on a PATH would blind the two
#    files most likely to grow a real identifier next, since they are the ones
#    about identifiers.
#
#    ⇒ so the exemption is the exact conventional dummy VALUE, and no more. a
#      real account id is never `123456789012`, so no real value hides behind
#      this (`rule.require.exemptions-name-their-trigger`)
######################################################################
DUMMY='123456789012|0123456789abcdef|012345678901|111122223333|999999999999'

# .what = one rule = a name, a pattern, what to use instead, and its OWN exempts
# .why  = a row that names the FIX is actionable; one that names a smell is not
#         (rule.require.errors-name-the-fix)
#
# 🛑 .why the exempt pattern rides IN the tuple — measured 2026-08-31
#    it sat in a separate `EMAIL_OK` var, applied behind
#    `[[ "$name" == "email address" ]]`. the rule was then renamed to
#    `personal email` in one edit and the guard was not — so the exemption
#    silently stopped applying, and `jane.doe@gmail.com`, the repo's own
#    documented dummy, went red in two files.
#    ⇒ one set, two holders, drifted by the very edit that touched one of them
#      (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9). the exemption now
#      cannot be separated from the rule it exempts.
#
# 🛑 .why a private ip has TWO rules — measured 2026-08-31
#    the dot rule reported `2 hit(s)`, and that read as *the corpus*. it meant
#    *the part I matched*: aws writes a private ip into a hostname with DASHES
#    (`ip-<a>-<b>-<c>-<d>`), so every such hostname reached no rule and produced
#    no row. ⚠️ the shape is spelled with placeholders here on purpose — a
#    literal one would make this comment a permanent ✋ against its own rule.
#
#    ⇒ the dash rule bit on its FIRST run, in two briefs nobody had looked at —
#      a verbatim pane capture and a worked example, each of which had carried a
#      live grove's address since the day it was written.
#
#    ⚠️ no fixture would have caught this. an arm plants only a shape its author
#       can see, so one written beside the dot rule inherits the dot rule's blind
#       spot verbatim (`gotcha.a-check-that-cries-wolf-gets-silenced`, q11).
#       what caught it was a read of the LIVE tree with a second form in hand.
#
#    ⇒ so before you trust a count here, ask: in how many FORMS is this subject
#      written, and which does the pattern match?
#
# 🛑 .why the account rule's bounds are ZERO-WIDTH — measured 2026-09-01
#    a bracket class must EAT a character, and that one property cost this
#    rule two separate defects. both were found by a redteam round whose
#    subject was this file:
#
#    | the form it held | what it could not reach |
#    |---|---|
#    | `…([0-9]{12})[^0-9a-zA-Z_-]`   | an id at END OF LINE |
#    | `[^0-9a-zA-Z_.-]([0-9]{12})…`  | an id at COLUMN 0 |
#    | either, under `grep -o`        | a SECOND id whose left delimiter the first match ate |
#
#    ⚠️ an `|$` on the CLOSING class alone repairs row 1 and leaves the head
#      half of the identical shape in place. a repair that closes one end of a
#      symmetric defect is the m.10 shape: the correction reproduces the defect
#      it corrects, one end over.
#
#    ⚠️ the third is the one no count could show. the LINE pass selects a line,
#      then the VALUE pass offers each match to the dummy filter — and
#      `grep -o` matches do not overlap, so `account: <dummy> <real>` yields
#      the dummy alone. the line is selected, its only real value is dropped,
#      and the reader prints ✔. a false ✔ on a security control, invisible in
#      every number this file emits.
#
#    ⇒ `(?<![0-9a-zA-Z_.-])[0-9]{12}(?![0-9a-zA-Z_-])` retires all three at
#      once, because a zero-width bound makes the match BE the value: there is
#      no delimiter to eat, so no end is privileged and no neighbour is lost.
#      ONE pattern now serves both passes. measured over 13 lines — every
#      position, both dummy orders, a dotted run, a 13-digit run, a leading
#      `_`, a following `-` — and all 13 land correctly.
#
#    ⚠️ the asymmetry is DELIBERATE and survives: `.` may FOLLOW an id (a
#      sentence period) and may not PRECEDE it (a dotted version string).
#
# 🛑 .this reader needs `grep -P`, and it HALTS rather than degrade
#    the account rule's bounds are ZERO-WIDTH assertions (see the block
#    above). an ERE form would write them as classes that eat a character,
#    which is precisely the pair of defects that assertion retires — so a
#    silent fallback would restore a false ✔ on a security control while
#    the row still printed ✔. an unread claim is never a pass.
if ! printf 'x\n' | grep -qP 'x' 2>/dev/null; then
  echo "✋ this grep carries no -P, and every rule below needs it" >&2
  echo "   ⇒ the account rule's bounds are zero-width assertions; an ERE" >&2
  echo "     form of them cannot match an id at column 0, and eats the" >&2
  echo "     delimiter a second id on the same line needs" >&2
  echo "   fix: install a grep built with PCRE (debian/ubuntu ship one)" >&2
  exit 2
fi

# ⚠️ the delimiter is `§`, never `|` — every pattern below CONTAINS `|`
RULES=(
  "aws account id§(?<![0-9a-zA-Z_.-])[0-9]{12}(?![0-9a-zA-Z_-])§<acct>§"
  "instance/vpc/subnet/ami id§\\b(i|vpc|subnet|ami|sg|eni|vol)-[0-9a-f]{8,17}\\b§<instance-id>§"
  "private ipv4§\\b(10\\.[0-9]{1,3}|192\\.168|172\\.(1[6-9]|2[0-9]|3[01]))\\.[0-9]{1,3}\\.[0-9]{1,3}\\b§<host>§"
  "private ipv4, dash form§\\bip-(10|192-168|172-(1[6-9]|2[0-9]|3[01]))-[0-9]{1,3}-[0-9]{1,3}(-[0-9]{1,3})?\\b§<private-ip>§"
  "personal email§[a-zA-Z0-9._%+-]+@([a-zA-Z0-9-]+\\.)*(gmail|googlemail|outlook|hotmail|live|yahoo|ymail|protonmail|proton|icloud|aol|fastmail|zoho|gmx|ehmpath|ehmpathy|ahbode)\\.[a-z]{2,}§<user>§seaturtle@ehmpath\\.com|noreply@anthropic\\.com|jane\\.doe@|<user>@|user@example|you@example"
)

######################################################################
# 🛑 .why the email rule matches a DOMAIN LIST, and not `x@y.z`
#    — measured 2026-08-31, on this reader's first run
#
#    the obvious pattern — `[\w.]+@[\w.]+\.\w{2,}` — returned **53 hits, and
#    every one was a false ✋**:
#
#      cloud@aws.ec2   the server tag this repo's whole `--for` axis is built on
#      local@unix      its peer
#      git@github.com  the ssh remote, in 6 files
#
#    ⇒ a reader that goes red on `local@unix` is red on every run, against
#      correct code, in the files a human reads most. it does not stay a false
#      ✋ — it gets silenced, and takes the account-id rule down with it
#      (`gotcha.a-check-that-cries-wolf-gets-silenced`, `.the corollary`).
#
#    ⚠️ and the tempting repair is the wrong one: an EXCLUDE list for `git@`,
#      `@unix`, `@aws.ec2` is a claim about a grammar with more shapes than any
#      author enumerates (m.12), and it grows on every new server tag.
#
#    ⇒ so the rule INCLUDES instead. a real person's address sits at a consumer
#      mail host or at this org's own domain; a structural pseudo-address never
#      does. the list is short, closed, and cannot be widened by a new tag.
######################################################################

######################################################################
# ⚠️ each rule's exempt field, explained once
#
#    a bot identity that already appears in every commit this repo carries is
#    public by construction, so to flag it is a false ✋.
#
#    each email entry is a full address, never a domain: a bare `@ehmpath.com`
#    would exempt every future address there, including a human's.
#
#    ⚠️ every entry is a VALUE, and the loop asks it against the matched value.
#      an entry that names a CONTEXT — `e\.g\.`, a comment marker, a filename —
#      cannot be value-scoped, and its reach is the whole line wherever that
#      context appears. one such entry blinded 102 lines to buy 1; a doc that
#      wants an example uses the dummy convention (`term=dox._.choice._.md`)
#      and needs no exemption at all.
######################################################################

HITS=0
FILES=0

######################################################################
# 🛑 a rule that carries the WRONG FIELD COUNT halts — measured 2026-09-01
#
#    `${x#*§}` on a `§`-less string returns x UNCHANGED. so a rule written with
#    three fields instead of four does not error — it silently yields
#    `exempt == fix`, and this reader then treats its own fix text (`<acct>`,
#    `<host>`) as an exemption pattern. every matched value that happens to
#    carry that text is dropped, unannounced.
#
#    ⚠️ the DIRECTION earns the halt: a wrong exempt here is a false ✔, never a
#      false ✋. it argues with no one — it just sees less, under a green
#      verdict (`gotcha.a-check-that-cries-wolf-gets-silenced`, the false-✔
#      half). in a dox reader, a value seen less is a real id published.
#
#    ⚠️ all five rules carry the final `§` today, so this is LATENT. it is
#      checked anyway because the next rule is written by hand, and an empty
#      fourth field is invisible at the end of a long pattern line.
#
# .why it runs ONCE, at boot, rather than inside the scan
#    the field count is a property of the DECLARATION — same answer for every
#    file. a per-file check re-reads one fact ~4000 times and then has to carry
#    a halt back through a caller that discards return codes
#    (`rule.require.solve-at-cause`).
#
# .the test is "did the expansion actually REMOVE a separator?"
#    which is locale-safe. `§` is two bytes in utf-8 and one character, so a
#    byte count and a character count each lie under some `LC_ALL`. an
#    expansion that removed no separator is exact under every locale.
######################################################################
rules_are_wellformed() {
  local rule rest bad=0 i

  for rule in "${RULES[@]}"; do
    rest="$rule"
    for i in 1 2 3; do
      if [[ "${rest#*§}" == "$rest" ]]; then
        echo "   ✋ a rule declares only $i field(s), and 4 are required" >&2
        echo "      rule: ${rule:0:72}" >&2
        echo "      ⇒ the absent separator makes 'exempt' equal 'fix', so this" >&2
        echo "        reader would exempt every value that carries its own fix" >&2
        echo "        text, and drop those rows in silence — a false ✔" >&2
        echo "      fix: name〈what〉§〈pattern〉§〈fix text〉§〈exempt, may be empty〉" >&2
        bad=$(( bad + 1 ))
        break
      fi
      rest="${rest#*§}"
    done
  done

  [[ "$bad" -eq 0 ]] || return 1
  return 0
}

######################################################################
# 🛑 an exemption is scoped to the matched VALUE, never to the LINE
#    — measured 2026-09-01
#
#    both filters ran as `grep -vE` over the whole grep OUTPUT LINE, so a line
#    that carried a documented dummy ANYWHERE was dropped whole — the real id
#    beside it included. the header two blocks up claims the exemption is about
#    a value ("an id a doc introduces with `e.g.` is an example, never an
#    identifier"), and the code claimed a line.
#
#    the cost was measured, per rule, as what each field BUYS against what it
#    BLINDS — the lines where a real id would land unread:
#
#      instance id   `e\.g\.|<instance-id>`   buys 1    blinds 102 in 50 files
#      dash-form ip  `<private-ip>`           buys 0    blinds   6 in  5 files
#      personal email                         buys 1    blinds   9 in  4 files
#
#    ⇒ two of the three bought at most one line each and blinded a hundred.
#      both were RETIRED rather than tuned (`rule.forbid.exemption-as-habit`):
#      `<instance-id>` and `<private-ip>` cannot match their own rules at all,
#      and the one line `e\.g\.` bought carried a fabricated id where the
#      declared convention (`term=dox._.choice._.md`) names a dummy the DUMMY
#      list already holds.
#
#    ⇒ with those gone, every entry left is a VALUE pattern, so the loop below
#      asks each matched value on its own. a line is a hit when any value on it
#      survives.
######################################################################
scan_one() {
  local file="$1" rel="${1#"$ROOT"/}"
  local rule name pat fix exempt rest out hit lineno text val kept

  for rule in "${RULES[@]}"; do
    name="${rule%%§*}";   rest="${rule#*§}"
    pat="${rest%%§*}";    rest="${rest#*§}"
    fix="${rest%%§*}"
    exempt="${rest#*§}"

    out="$(grep -nPI "$pat" "$file" 2>/dev/null || true)"
    [[ -n "$out" ]] || continue

    while IFS= read -r hit; do
      [[ -n "$hit" ]] || continue
      lineno="${hit%%:*}"
      text="${hit#*:}"

      # ask each matched value on its own. `kept` stays 0 when every value on
      # the line is a documented dummy — the only case a drop is owed
      kept=0
      while IFS= read -r val; do
        [[ -n "$val" ]] || continue
        if printf '%s\n' "$val" | grep -qE "$DUMMY"; then continue; fi
        if [[ -n "$exempt" ]] && printf '%s\n' "$val" | grep -qE "$exempt"; then continue; fi
        kept=1
      done < <(printf '%s\n' "$text" | grep -oP "$pat" || true)

      [[ "$kept" -eq 1 ]] || continue
      echo "   ✋ $rel:$lineno" >&2
      echo "      rule: $name  →  use $fix" >&2
      HITS=$(( HITS + 1 ))
    done <<< "$out"
  done
}

######################################################################
# 🛑 a tracked file ABSENT from disk is REPORTED, never skipped in silence
#    — measured 2026-08-31, and it printed ✔ over a quarter of the corpus
#
#    `git ls-files` reported 804 and this reader read 603. the delta was 197
#    files a parallel rename had MOVED on disk while the index still held their
#    old paths. each failed `[[ -f ]]` and each was skipped — silently — so the
#    tally fell by a quarter and the verdict did not move.
#
#    ⇒ that is q13: a count is a claim about a set, and this set has TWO stores.
#      the index reports one answer, the disk another, and a `-f` guard that
#      just `continue`s picks one and tells nobody.
#
#    ⚠️ the skip itself is correct — an absent file cannot be read. what was
#      wrong is that it was SILENT. a reader that quietly shrinks its own
#      subject reports clean on the exact corpus it stopped reading.
#
# 🛑 .`-f` ALONE CANNOT SAY "ABSENT" — it conflates gone with not-a-regular-file
#
#    📜 .measured 2026-09-02, and it was a PERMANENT false ✋ on every box
#      `.radio` is tracked, and it is a symlink at a DIRECTORY. `-f` follows the
#      link, finds a dir, and returns false — so this reader counted it absent
#      and refused a verdict. the file was there the whole time, on every box,
#      forever, and `git ls-files --deleted` named no path at all.
#
#      ⚠️ that is the worst false-✋ shape: it never clears, so the first human
#        to meet it learns the check lies, and a check that always reddens gets
#        silenced — and takes every honest row beside it down
#        (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.13).
#
#    ⇒ so the two questions are asked SEPARATELY, because they take opposite
#      repairs and only one of them is a defect:
#
#        no entry at the path at all     → GONE. the index and tree disagree
#        an entry, but not a plain file  → out of subject. a dir holds no text
#
#      a symlink at a regular file still reads normally — `-e` and `-f` both
#      hold — so this narrows the refusal without narrowing the corpus.
######################################################################
GONE=0

sweep() {
  HITS=0
  FILES=0
  GONE=0
  local file
  while IFS= read -r file; do
    # ⚠️ `-e` first: it answers "is any entry here", which is the q13 question.
    #    a path that fails `-e` is the index/tree split this block exists for
    if [[ ! -e "$ROOT/$file" ]]; then
      GONE=$(( GONE + 1 ))
      continue
    fi
    # present, but a dir (or a link at one) holds no text for a dox rule to
    # match. out of subject, and NOT a gap — so it is skipped without a count
    if [[ ! -f "$ROOT/$file" ]]; then
      continue
    fi
    FILES=$(( FILES + 1 ))
    scan_one "$ROOT/$file"
  done < <(git -C "$ROOT" ls-files)
}

# .what = say so when the index and the disk disagree about the subject
# ⚠️ this rides stderr, which `rhx` BUFFERS and relays only on a non-zero exit.
#    so every caller of this function must exit non-zero — see the two gates
#    below. an advisory printed on a zero-exit path is discarded by the
#    transport and reaches nobody (`gotcha.the-duct-returns-the-send-not-the-answer`,
#    the same shape one layer out: the transport decides what the caller sees).
say_gone() {
  [[ "$GONE" -gt 0 ]] || return 0
  echo "   ⚠️ $GONE tracked file(s) are ABSENT from disk and were NOT read" >&2
  echo "      the index and the tree disagree about the subject" >&2
  echo "      read why: git status --short" >&2
}

######################################################################
# 🛑 --prove: a PLANTED row in the LIVE corpus, never a fixture alone
#
#    a fixture is written by whoever wrote the reader, so it inherits that
#    reader's blind spot verbatim — it proves the reader obeys its author, and
#    says none of whether the author saw the corpus
#    (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.12 / q11).
#
#    ⇒ so the canary goes into a REAL tracked file, in the form the corpus
#      uses. if the count does not move, this reader cannot see that form, and
#      every file has been unproven since the day it landed.
#
# ⚠️ this is `rule.forbid.repair-plays` EXCEPTION 2 — a discrimination probe.
#    it is a ROUND TRIP whose net effect is zero, and it honors all four
#    conditions: the restore is a `trap … EXIT`; it REFUSES a subject it did not
#    find; the break is one appended line; and it REPORTS whether the restore
#    took, byte-for-byte.
######################################################################
# 🛑 the rules are checked BEFORE any sweep, and BOTH entrypoints sweep — a
#    malformed rule makes this reader quietly exempt more, so it reaches no file
if ! rules_are_wellformed; then
  echo "" >&2
  echo "✋ dox: a rule above is malformed, so no file was read" >&2
  exit 2
fi

if [[ "$PROVE" -eq 1 ]]; then
  echo "🌲 dox.verify --prove"
  echo "   └─ root: $ROOT"
  echo ""

  TARGET="$ROOT/readme.md"
  if ! git -C "$ROOT" ls-files --error-unmatch readme.md >/dev/null 2>&1; then
    echo "   ✋ readme.md is not tracked, so it is outside the subject set" >&2
    echo "      ⇒ a canary there would prove no claim about the live corpus" >&2
    exit 2
  fi

  BACKUP="$(mktemp)"
  cp "$TARGET" "$BACKUP"
  # the restore is unconditional — every step below can fail, and each would
  # otherwise leave a fake account id in a tracked file with no note of why
  trap 'cp "$BACKUP" "$TARGET"; rm -f "$BACKUP"' EXIT

  sweep
  BEFORE="$HITS"
  echo "   ├─ before: $HITS hit(s) across $FILES tracked files"

  # one canary, in the form the corpus uses — a bare id in a comment
  #
  # 🛑 .why the id is JOINED and not written whole — measured 2026-08-31
  #    this reader scans `git ls-files`, and the moment it was tracked that set
  #    included ITSELF. a literal `4815162342` + `99` in one run would make this
  #    line a permanent ✋ against its own source — a reader red on the file that
  #    holds it is silenced by the first human to read it
  #    (`gotcha.a-check-that-cries-wolf-gets-silenced`).
  #
  #    ⇒ and an exemption would be the WRONG repair: it would carve a hole in the
  #      rule this reader most needs whole. the join leaves no 12-digit run in
  #      the file at all, so no exemption is owed (`rule.forbid.exemption-as-habit`).
  CANARY="4815162342""99"   # ⚠️ not `local` — this block is top level, not a function

  # 🛑 FOUR canaries, one per POSITION the id can occupy — measured 2026-09-01
  #    a probe that plants one form proves one form, and this probe has now
  #    twice reported ✔ over a reader blind to a form it never planted:
  #
  #      · for a day only the MID-LINE form was here, while the rule's closing
  #        class could not reach an id at END OF LINE
  #      · then both of those, while the head class could not reach COLUMN 0
  #
  #    ⇒ the canary set is now derived from the POSITIONS a line affords —
  #      start, middle, end — rather than from the shapes already in mind.
  #      that is the m.12 / q11 repair: enumerate from the SUBJECT's side.
  printf '\n<!-- canary %s -->\n' "$CANARY" >> "$TARGET"   # mid-line
  printf '\n    account: %s\n' "$CANARY" >> "$TARGET"      # end of line
  printf '\n%s\n' "$CANARY" >> "$TARGET"                   # column 0, and alone

  # ⚠️ the fourth canary shares its line with a DOCUMENTED DUMMY, separated by
  #    ONE SPACE, and it is the only one that can tell a value-scoped filter
  #    from a line-scoped one AND catch a value pass that loses a neighbour.
  #
  #    🛑 the separator must stay a BARE SPACE. a `<dummy> and <id>` regenerates
  #      a delimiter between the two ids, so the canary passes under a value
  #      pass whose matches ate their own delimiters and dropped the second id.
  #      a fixture that supplies the very character the defect removes tests
  #      the fixture, never the reader.
  printf '\n    account: 123456789012 %s\n' "$CANARY" >> "$TARGET"

  sweep
  AFTER="$HITS"
  echo "   ├─ after:  $HITS hit(s), with four canaries planted"

  cp "$BACKUP" "$TARGET"

  ####################################################################
  # 🛑 the restore is compared to the BACKUP, never to the git index
  #    — measured 2026-08-31, on this probe's first run
  #
  #    the first form asked `git diff --quiet -- readme.md`, which compares the
  #    working tree to the INDEX. that is a different subject: readme.md was
  #    already `M ` in the index when the probe ran, so the check answered a
  #    question about git's own bookkeeping and was read as a statement about
  #    whether the canary had been removed.
  #
  #    ⇒ it would report ✋ on an untouched file that merely carried unstaged
  #      edits, and — worse — its ✔ never actually proved the canary was gone.
  #      the one artifact that knows the prior bytes is the backup
  #      (`gotcha.a-check-that-cries-wolf-gets-silenced`, q2: does the evidence
  #      name the SUBJECT, or something the check happened to reach for?)
  ####################################################################
  if cmp -s "$BACKUP" "$TARGET"; then
    rm -f "$BACKUP"
    trap - EXIT
    echo "   ├─ restore: ✔ readme.md is byte-identical to its pre-probe copy"
  else
    echo "   ├─ restore: ✋ readme.md DIFFERS from its pre-probe copy" >&2
    echo "   │            a copy is kept at: $BACKUP" >&2
    echo "   │            restore it: cp $BACKUP $TARGET" >&2
    trap - EXIT
    exit 1
  fi

  ####################################################################
  # ⚠️ the verdict is EXACTLY +4, never `-gt` — measured 2026-09-01
  #    a `-gt` passes when one form lands and the others do not, so it grades
  #    the set by its strongest member. that is how the end-of-line miss
  #    survived: one form was enough to move the count, so the probe reported
  #    the reader BITES about a reader that saw a third of its subject.
  ####################################################################
  MOVED=$(( AFTER - BEFORE ))
  if [[ "$MOVED" -eq 4 ]]; then
    echo "   └─ 🌴 the reader BITES — all four planted forms moved the count $BEFORE → $AFTER"
    exit 0
  fi
  echo "   └─ ✋ the reader is PARTLY BLIND — four planted ids moved the count by $MOVED" >&2
  echo "        ├─ mid-line:       <!-- canary <id> -->" >&2
  echo "        ├─ end of line:    account: <id>" >&2
  echo "        ├─ column 0:       <id>, alone on its line" >&2
  echo "        ├─ beside a dummy: account: <dummy> <id>, ONE space between" >&2
  echo "        └─ a form that moves no count has been unread since this rule landed" >&2
  exit 1
fi

######################################################################
# the sweep
######################################################################
echo "🌲 dox.verify"
echo "   └─ root: $ROOT"
echo ""

sweep

if [[ "$FILES" -eq 0 ]]; then
  echo "🌲 read 0 tracked files — the set was empty, so this proves no claim" >&2
  echo "   fix: confirm the checkout has commits — git -C $ROOT ls-files | head" >&2
  exit 2
fi

say_gone

if [[ "$HITS" -gt 0 ]]; then
  echo "" >&2
  echo "🌲 dox: $HITS hit(s) across $FILES tracked files (each named above)" >&2
  echo "   ⇒ this repo is PUBLIC, and git keeps the blob after a redaction." >&2
  echo "     the cheap moment is BEFORE the push (rule.forbid.dox-in-public-repo)" >&2
  exit 1
fi

# 🛑 an INCOMPLETE subject is not a pass
#    a ✔ here would read as a claim about the publication set, and it would
#    cover $FILES of its $(( FILES + GONE )) members. that is q13 shipped as a
#    verdict: a count is a claim about a set, and this set has two stores.
#    ⇒ so this is a CONSTRAINT the caller resolves, never a ✔ with a footnote.
if [[ "$GONE" -gt 0 ]]; then
  echo "✋ dox: no hit across the $FILES files this reader could open —" >&2
  echo "   and $GONE tracked file(s) it could NOT, so the sweep proves no claim" >&2
  echo "   fix: reconcile the index with the tree, then re-run" >&2
  exit 2
fi

echo "🌲 dox: none found across $FILES tracked files ✔"
echo "   └─ prove it bites: rhx dox.verify --prove"
exit 0
