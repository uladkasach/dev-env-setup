#!/usr/bin/env bash
######################################################################
# .what = prove every off-box read on the TREE PATH goes through the one
#         declared wire boundary, and name each line that does not
#
# .why  = `inventory.security-checks.md` opens with the row it calls "the one
#         that closes the others' shared hole":
#
#           > every reader below it discovers subjects BY THE PRESENCE OF A
#           > CHECK — so a download with no check at all is invisible to each of
#           > them, by construction. only a reader keyed on the FETCH can see it.
#
#         that row named `prove.every-fetch-is-verified`. the play family was
#         culled and every one of those names now resolves to no file, so the
#         ledger claimed sixteen automated proofs and had none. this is the
#         first of the re-homed readers.
#
# 🛑 .the claim, in one line
#         `src/grove.web.sh` is the ONE place a byte may arrive from the wire.
#         a `curl`, a `wget`, or a `git clone` written anywhere else in `src/`
#         is a fetch with no bound, no transport floor, and no pin — and it is
#         invisible to every pin-keyed reader, because a pin-keyed reader finds
#         its subjects by their pins.
#
# ⚠️ .why it COUNTS shapes rather than tests for the boundary's presence
#         the regression here is ADDITIVE, never a revert. nobody deletes
#         `web_fetch`. somebody adds a bundle, copies its vendor's published
#         one-liner — `curl -fsSL <url> | sh` — and ships it, because that is
#         what every vendor's install doc says. a check for the boundary's mere
#         presence stays green straight through that edit.
#
# 🛑 .why the subject is `src/`, and NOT every tracked shell file
#         the boundary is DECLARED for the tree path and for no other. a skill
#         under `.agent/` has no such rule to violate, so a reader that flagged
#         one would go red against a tree with no rule behind it — and a check
#         that argues with correct code is silenced by the first human to read
#         it (`gotcha.a-check-that-cries-wolf-gets-silenced`).
#
#         ⚠️ this is a NAMED GAP, not an oversight: a `curl … | sh` inside a
#         skill is a real defect and this reader will not see it. the repair is
#         to declare a boundary there first, then widen this subject — never to
#         widen the pattern against an undeclared rule.
#
# ⚠️ .what this does NOT do
#         it reads bytes and prints rows. no network, no privilege, no grove.
#         `--prove` is the one mode that writes, and it writes a break it
#         removes again (`rule.forbid.repair-plays`, exception 2).
#
# usage:
#   rhx wire.verify                    # sweep the tree path
#   rhx wire.verify --root <dir>       # name the checkout explicitly
#   rhx wire.verify --prove            # plant a bare fetch, confirm it BITES
#
# exit:
#   0 = every off-box read is inside the boundary, and files were read
#   1 = at least one escape — each named with its file, line, and fix
#   2 = no repo found, or the subject set was empty (proves no claim)
######################################################################
set -uo pipefail

ROOT=""
PROVE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)  ROOT="${2:-}"; shift 2 ;;
    --prove) PROVE=1; shift ;;
    --help|-h)
      grep '^#' "$0" | head -60
      exit 0 ;;
    # ⚠️ rhachet injects `--skill <slug>` ahead of the caller's args; a case
    #    that did not absorb them would read the slug as a subject
    --skill|--repo|--role) shift 2 ;;
    *) shift ;;
  esac
done

######################################################################
# 🛑 the subject checkout is derived from THIS FILE, never from the cwd
#    — measured 2026-08-31, and it produced a false ✔
#
#    the first form asked `git rev-parse --show-toplevel`, which answers about
#    the CWD. `rhx` does not guarantee a cwd, so three consecutive runs of the
#    same command reported three different subjects:
#
#      root: …/_worktrees/dev-env-setup.vlad.boot-grove-box   204 tree files
#      root: …/_worktrees/dev-env-setup.vlad.boot-grove-box     8 tree files
#      root: /home/vlad/git/more/dev-env-setup                341 tracked files
#
#    every one printed ✔. the middle run read a partial set and the last read a
#    DIFFERENT CHECKOUT — one with none of the edits under test — and neither
#    said so. a green verdict about the wrong tree is the purest false ✔ there
#    is (`gotcha.a-check-that-cries-wolf-gets-silenced`, q2: does the evidence
#    name the SUBJECT?).
#
#    ⇒ this skill lives INSIDE the checkout it reads, so its own path is the
#      one anchor that cannot drift with the cwd. `--root` stays the explicit
#      override, and is now the only way to point elsewhere.
#
# ⚠️ and the checkout test asks GIT, never `-d .git`: a WORKTREE's `.git` is a
#    FILE (a `gitdir:` pointer), not a directory — and a worktree is where this
#    repo does its work, so `-d` was red on the common path.
######################################################################
if [[ -z "$ROOT" ]]; then
  SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ROOT="$(git -C "$SELF_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [[ -z "$ROOT" ]] || ! git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  echo "   ✋ no git checkout found, so there is no subject set to read" >&2
  echo "      fix: pass --root <dir> to state which checkout to read" >&2
  exit 2
fi

######################################################################
# the boundary — the ONE file allowed to touch the wire
#
# ⚠️ it is a file, never a directory. `grove.web.sh` holds `web_fetch`,
#    `git_clone`, and the four package-manager wrappers; a second file added
#    beside it would be a second boundary, which is the defect
#    (`rule.forbid.two-writers-on-one-artifact`).
######################################################################
BOUNDARY='src/grove.web.sh'

######################################################################
# one rule = a name, a pattern, the fix, and its OWN line-level exempts
#
# 🛑 .the exempt rides IN the tuple — measured 2026-08-31 on `dox.verify`
#    its email exempt sat in a separate var behind a name test. the rule was
#    renamed in one edit and the guard was not, so the exemption silently
#    stopped and the repo's own dummy went red. one set, two holders, drifted
#    by the very edit that touched one of them (m.9).
#
# ⚠️ the delimiter is `§`, never `|` — every pattern below CONTAINS `|`
######################################################################
RULES=(
  ####################################################################
  # 🛑 .why the pattern demands a FLAG or a URL after the tool name
  #    `curl` appears in this tree far more often as an ARGUMENT than as a
  #    command: `pkg_install curl gnupg`, `command -v curl`, `for tool in … curl
  #    gpg`, and a dozen `read why:` strings that quote an apt line.
  #
  #    a bare `\bcurl\b` reddens every one of those. that is ~10 false ✋ against
  #    correct code on the first run — and 53 of exactly that kind is what
  #    `dox.verify` measured on the same shape. a fetch is `curl -flags` or
  #    `curl http…`; an argument never is.
  #
  # ⚠️ the exempt is the IMDS address. 169.254.169.254 is link-local, never
  #    routed, never https, and answered by the hypervisor — so a transport
  #    floor and a pin are meaningless there. the three sites that read it
  #    (`grove.env.sh`, `5.6.aws`) each carry their own `-m` bound, which is
  #    the guarantee that DOES apply (`rule.require.exemptions-name-their-trigger`).
  ####################################################################
  # ⚠️ the exempt matches the IMDS ADDRESS **or** its header name, because a
  #    real IMDS read spans two lines and the address sits on the second:
  #
  #      role="$(curl -sS -m 3 -H "X-aws-ec2-metadata-token: $tok" \     ← line N
  #        'http://169.254.169.254/latest/meta-data/…' 2>/dev/null)"     ← line N+1
  #
  #    a line-keyed reader sees only line N, so an address-only exempt reddens a
  #    correct IMDS call — measured, on `5.6.aws/configure.upsert.sh:68`.
  #    ⇒ this is q11 one layer in: the exempt matched a SUBSET of the forms the
  #      subject is written in, and the row it missed was correct code.
  "a raw fetch outside the boundary§(^|[^_[:alnum:]-])(curl|wget)[[:space:]]+(-|http|'|\")§web_fetch (src/grove.web.sh)§169\\.254\\.169\\.254|metadata-token"

  ####################################################################
  # ⚠️ a bare `git clone` is WORSE than a bare curl, not merely equal —
  #    `grove.web.sh:814` carries the measurement. git's http transport is
  #    libcurl, so it stalls the same way, AND it can block on a credential
  #    prompt that curl has no analogue for.
  #
  # 🛑 .the `(-c …)*` clause, and why its absence was the sharp kind of blind
  #
  #    the pattern demanded `clone` IMMEDIATELY after `git`, so it could not see
  #    `git -c protocol.allow=never clone …` — which is the exact form this
  #    repo's OWN boundary writes, and the form a `WEB_GIT_FLOOR` copy takes.
  #    a narrower reader is blind to the shape its own house style produces.
  #
  #    ⚠️ measured 2026-09-01: the wide pattern matches the SAME 8 lines as the
  #      narrow one across every tracked `.sh`, and all 8 are
  #      prose the strips above already drop. so this closes a shape and costs
  #      no false ✋ (q7 — is there a site this matches where the right answer
  #      is different? measured: no).
  #
  # 🛑 .the residue it does NOT close — a clone split over CONTINUATION LINES
  #    `grep -nE` reads one physical line, so `git -c … \` on one line and
  #    `clone "$url"` three lines down match no single-line pattern, however
  #    wide. `grove.bootstrap.sh` is written exactly that way.
  #
  #    ⇒ that file is the tree's one documented exemption from the boundary, so
  #      to miss it is correct HERE — and it is luck, not design. a NEW file
  #      that split its clone the same way would be missed just as silently.
  #      `scan_git_floor_is_copied` joins continuations before it reads; this
  #      rule does not, and a reader that says so is worth more than one that
  #      lets the next person assume otherwise.
  ####################################################################
  "a raw clone outside the boundary§(^|[^_[:alnum:]-])git[[:space:]]+(-c[[:space:]]+[^[:space:]]+[[:space:]]+)*clone[[:space:]]§git_clone (src/grove.web.sh)§"

  ####################################################################
  # ⚠️ this one has NO exempt, deliberately. a fetch piped into a shell hands
  #    the far side arbitrary code with this box's own reach, and there is no
  #    bound, pin, or signature that makes it safe — a pin would have to cover
  #    an artifact the vendor rewrites at will.
  ####################################################################
  #
  # 🛑 .the trailing context is `[^[:alnum:]_-]`, and it was `[[:space:]]` —
  #    measured 2026-08-31, by this reader's OWN probe
  #    the probe plants `curl -fsSL <url> | sh;` — the shape a vendor's install
  #    doc hands somebody, inside a function body. that line trips TWO rules, so
  #    the expected delta is 2. it moved the count by ONE: `| sh;` ends in a
  #    semicolon, which is neither a space nor an end-of-line, so this rule was
  #    blind to every `| sh` that closes a compound statement.
  #
  #    ⇒ and the reason it was CAUGHT is worth more than the fix: the probe
  #      declares its expected delta, so "the count rose" was not accepted as
  #      the answer. a probe that only asserts a rise would have shipped this
  #      rule permanently blind, under a green ✔ (m.12 / q11, self-inflicted).
  "a fetch piped into a shell§\\|[[:space:]]*(sudo[[:space:]]+)?(sh|bash)([^[:alnum:]_-]|\$)§fetch to a file, verify it, then run it§"
)

######################################################################
# 🛑 .the NAMED GAP — what these rules do NOT reach
#
#    `grove.web.sh` declares SIX wire entry points. the rules above reach the
#    raw form of TWO:
#
#      | entry point    | a rule reaches its raw form? |
#      |----------------|------------------------------|
#      | `web_fetch`    | ✔ curl/wget, and pipe-into-shell |
#      | `git_clone`    | ✔ `git clone`                |
#      | `web_npm`      | ✋ no rule                    |
#      | `web_pnpm`     | ✋ no rule                    |
#      | `web_corepack` | ✋ no rule                    |
#      | `web_flatpak`  | ✋ no rule                    |
#
#    so a raw REGISTRY install — `cargo install`, `npm install -g`,
#    `pnpm install`, `corepack install`, `flatpak install` — goes off the wire
#    and is invisible here.
#
# ⚠️ .a MEASURED row, so the gap is not hypothetical
#    `src/grove.provision/5.devtools/5.14.treesitter/provision.upsert.sh:36`
#
#      cargo install tree-sitter-cli --version "$GROVE_TREESITTER_PIN"
#
#    version-pinned, and it carries NO `timeout` — the unbounded shape the curl
#    rule exists for, over crates.io rather than https direct. blast radius is
#    small (https + crates.io checksums + the pin), so this is a gap to NAME,
#    never a defect to shout.
#
# 🛑 .why the rule is not simply added here
#    a bare-word `cargo` pattern reddens ~8 correct lines in `5.2.rust` alone —
#    `command -v cargo`, and prose that quotes a cargo command. so it must demand
#    a SUBCOMMAND, exactly as the curl rule demands a flag or a url. even then one
#    prose row survives the echo-strip: `5.1.node/provision.upsert.sh:438`
#    interpolates `$pnpm_want`, so the strip's `[^$]*$` clause does not fire (q8 —
#    the strip is a reader too, and it has its own blind spot).
#
#    ⇒ so the rule needs its OWN exempt, and it needs `src/zshrc.sh` judged: its
#      `npm install -g pnpm` at :367 runs in a HUMAN's shell, where
#      `grove.web.sh` is never sourced — the same reason four files sit in
#      `EXCLUDED`, which was enumerated from `2.7.aliases`'s assets and so never
#      considered `2.5.zsh`'s.
#
# ⚠️ .until that lands, the VERDICT names the three shapes it reaches
#    an unqualified "every off-box read is inside the boundary" is the exact
#    shape round 12 measured: a guard that names one hazard immunizes the others.
#    a reader who sees ✔ on *every* read stops the search for a registry fetch —
#    and the care in the rules above makes that stop MORE confident, not less
#    (`inventory.security-checks.md`, the lesson above the classes).
######################################################################

######################################################################
# 🛑 a rule that carries the WRONG FIELD COUNT halts — measured 2026-09-01
#
#    `${x#*§}` on a `§`-less string returns x UNCHANGED. so a rule written with
#    three fields instead of four does not error — it silently yields
#    `exempt == fix`, and the reader then filters its own matched rows through
#    the FIX TEXT. that is an exemption nobody declared, and it DROPS rows.
#
#    ⚠️ the DIRECTION is what earns this a halt rather than a warning: a wrong
#      exempt here is a false ✔, never a false ✋. it argues with no one. it
#      just quietly sees less, under a green verdict
#      (`gotcha.a-check-that-cries-wolf-gets-silenced`, the false-✔ half).
#
#    ⚠️ every rule above carries the trailing `§` today, so this is LATENT.
#      it is checked anyway because the next rule somebody adds is written by
#      hand, and an empty fourth field is invisible at the end of a long line.
#
# .why it runs ONCE, at boot, and not inside the scan
#    the field count is a property of the DECLARATION. it gives the same answer
#    for every file, so a per-file check is ~4000 redundant reads of one fact —
#    and worse, a per-file halt has to travel back up through a caller that
#    discards its return code. one check, one holder, one exit
#    (`rule.require.solve-at-cause`).
#
# .the test is "did the expansion actually REMOVE a separator?"
#    which is locale-safe. `§` is two bytes in utf-8 and one character, so
#    neither a byte count nor a character count is a reliable field counter
#    under an unknown `LC_ALL`. an expansion that removed no separator is exact.
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
        echo "        reader would filter its own matches through the fix text" >&2
        echo "        and drop rows in silence — a false ✔" >&2
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

HITS=0
FILES=0
FLOOR_SAID=""

######################################################################
# ⚠️ FULL-LINE COMMENTS are stripped before every read
#
#    this tree documents its own defects at length: `grove.web.sh` quotes the
#    bare `curl -fsSL` it replaced, `5.8.docker` quotes the `sudo curl` it
#    retired, `6.5.onepassword` quotes a vendor's `curl … | sh`. every one of
#    those is prose ABOUT the defect, and to flag them would make this reader
#    red against the very comments that explain why it exists.
#
#    a TRAILING comment on a code line still counts, correctly.
######################################################################
scan_one() {
  local file="$1" rel="${1#"$ROOT"/}"
  local rule name pat fix exempt rest out

  [[ "$rel" == "$BOUNDARY" ]] && return 0

  for rule in "${RULES[@]}"; do
    # 🛑 this split is SAFE ONLY because `rules_are_wellformed` ran first —
    #    see its header for what a short rule does to `exempt`
    name="${rule%%§*}";   rest="${rule#*§}"
    pat="${rest%%§*}";    rest="${rest#*§}"
    fix="${rest%%§*}";    exempt="${rest#*§}"

    ##################################################################
    # ⚠️ the line numbers must come from the FILE, so each strip below is a
    #    filter over the MATCHED ROWS rather than over the input
    #
    # 🛑 .the second strip: an `echo`/`printf` line that holds no `$(`
    #    this tree explains its own defects in its OUTPUT, not only its
    #    comments — `2.2.git/provision.verify.sh:21` reads
    #    `echo "  … and every later git clone fails too"`. that is a sentence a
    #    human reads, never a clone.
    #
    #    ⚠️ and the `$(` clause is why this is not simply "skip echo lines":
    #    `echo "$(curl …)"` IS a real fetch on an echo line. an unconditional
    #    echo skip would be a false ✔ on the one echo shape that matters.
    ##################################################################
    out="$(grep -nEI "$pat" "$file" 2>/dev/null \
      | grep -vE '^[0-9]+:[[:space:]]*#' \
      | grep -vE '^[0-9]+:[[:space:]]*(echo|printf)[[:space:]][^$]*$' || true)"
    [[ -n "$exempt" ]] && out="$(printf '%s' "$out" | grep -vE "$exempt" || true)"
    [[ -n "$out" ]] || continue

    while IFS= read -r line; do
      [[ -n "$line" ]] || continue
      echo "   ✋ $rel:${line%%:*}" >&2
      echo "      $name  →  use $fix" >&2
      HITS=$(( HITS + 1 ))
    done <<< "$out"
  done
}

######################################################################
# 🛑 .the subject is EVERY published `.sh`, minus a NAMED exclusion list
#
#    ⚠️ this reader's subject was DERIVED once — from the entrypoint's own
#      `source` lines — and that derivation is what broke it. measured
#      2026-08-31: a rename moved `src/grove.provision/**` to
#      `src/grove.provision/**` on DISK, a sweep rewrote the patterns below to
#      match, and the corpus is enumerated from the INDEX, which still held the
#      old paths. the filter matched no row, the subject fell 204 → 8, and the
#      reader printed ✔.
#
#    ⇒ the lesson is not "derive harder". it is:
#
#        a reader whose SUBJECT comes from one store and whose CORPUS comes
#        from another disagrees with itself the moment the two stores drift.
#
#      so both halves now read the INDEX, and the filter is a SUPERSET with an
#      explicit subtraction. a file added under `src/` is IN by default, which
#      is the safe direction; a file left out is named here, in the open.
#
# ⚠️ the excluded files are the ones `2.7.aliases` copies to `$HOME`. they run
#    in a HUMAN's interactive shell, where `grove.web.sh` is never sourced, so
#    `web_fetch` does not exist to call — a ✋ there names a fix the file cannot
#    apply. measured on the first run: four such rows against correct code.
#
#    🛑 those four fetches are a REAL defect and this reader will not see them —
#      a NAMED GAP. the repair is to declare a boundary for a human's aliases
#      first, then delete the row below; never to widen the pattern against an
#      undeclared rule.
######################################################################
EXCLUDED=(
  src/bash_aliases.sh   # copied to $HOME — a human's interactive shell
  src/ductwork.sh       # sourced BY bash_aliases, same shell
  src/termwork.sh       # sourced BY bash_aliases, same shell
  src/backup_env.sh     # human-run utility, reads the machine and writes OUT
  src/util.yubikey.ssh.sh
)

subject_holds() {
  local f="$1" skip

  # the bootstrap runs before the repo exists, so it sits outside src/
  [[ "$f" == "grove.bootstrap.sh" ]] && return 0

  # every OTHER published shell file under src/, at every depth
  [[ "$f" == src/*.sh ]] || return 1
  for skip in "${EXCLUDED[@]}"; do
    [[ "$f" == "$skip" ]] && return 1
  done
  return 0
}

######################################################################
# 🛑 the SECOND half of the ledger's first row — every fetch is VERIFIED
#
#    "no fetch escapes the boundary" and "every fetch through the boundary is
#    checked" are two claims, and the rules above prove only the first. a
#    `web_fetch` is bounded and https-floored and still hands you whatever bytes
#    the far side chose — the pin is what makes them the RIGHT bytes.
#
# .why the claim is FILE-scoped, and not per-call
#    a `.sig` and a signer key are both fetched and neither is verified on its
#    own — each is the INSTRUMENT of the verification, so a per-call rule would
#    redden three correct sites (`4.3.2.emulator`, `5.6.aws` twice) and teach a
#    reader to skip this row.
#
#    ⇒ the honest checkable claim is one step coarser: a file that reaches the
#      wire must also carry a check. that catches the real regression — a new
#      bundle that fetches a tarball and installs it unverified — and it argues
#      with no correct site.
#
# ⚠️ its residue, stated: a file with TWO fetches and ONE verify passes. that is
#    a known bound of the file scope, not an oversight. the per-call form needs
#    the instrument/artifact split made explicit at the call, which is a change
#    to `grove.web.sh`, not to this reader.
######################################################################
scan_fetch_is_verified() {
  local file="$1" rel="${1#"$ROOT"/}" body

  [[ "$rel" == "$BOUNDARY" ]] && return 0

  # ⚠️ comments and output lines are stripped first: nine bundles EXPLAIN
  #    `web_fetch` in a `#` block or an `echo "  ⇒ web_fetch named the wire
  #    fault above"`, and every one of those would otherwise read as a call
  body="$(grep -vE '^[[:space:]]*#' "$file" 2>/dev/null \
        | grep -vE '^[[:space:]]*(echo|printf)[[:space:]][^$]*$' || true)"

  ####################################################################
  # 🛑 a HERESTRING, never a pipe — measured 2026-09-01
  #    these two lines read `printf '%s' "$body" | grep -qE …`, and that is
  #    the idiom `gotcha.pipefail-grep-q` names, in a file that sets
  #    `set -uo pipefail` at its top.
  #
  #    `grep -q` exits on its FIRST match and closes the pipe. while the body
  #    fits the pipe buffer the producer has already finished and never
  #    notices; past it, printf takes SIGPIPE and pipefail hands the caller
  #    141 — for a grep that SUCCEEDED. measured, one body, match on line 1:
  #
  #      body bytes   pipe + grep -q   herestring + grep -q
  #      65536        ✔ rc=0           ✔ rc=0
  #      262144       🛑 rc=141        ✔ rc=0
  #
  #    ⇒ so the verdict turned on the file's SIZE rather than its contents,
  #      and `|| return 0` reads a 141 as "no fetch here" — a false ✔ on the
  #      one claim this reader exists to make.
  #
  #    ⚠️ its reach today is one file: `src/bash_aliases.sh`, whose stripped
  #      body is 73262 bytes. that file carries no wire call, so the defect
  #      cost no row — the CLAIM was false, not the outcome bad, and that is
  #      the reason it is fixed (`rule.forbid.failhide`).
  #
  #    a herestring is an fd on a temp file, so there is no producer to
  #    signal. `-q` keeps its early exit and pipefail has no pipe to grade.
  ####################################################################
  grep -qE '(^|[^_[:alnum:]])web_fetch[[:space:]]' <<< "$body" || return 0
  grep -qE '(^|[^_[:alnum:]])web_verify_' <<< "$body" && return 0

  echo "   ✋ $rel" >&2
  echo "      a fetch with no check in the same file  →  add a web_verify_* call" >&2
  echo "         ⇒ web_fetch bounds the transfer and floors the transport. it" >&2
  echo "           says none of whether the bytes are the RIGHT bytes" >&2
  HITS=$(( HITS + 1 ))
}

######################################################################
# 🛑 a subject file ABSENT from disk is REPORTED, never skipped in silence
#    — measured 2026-08-31, and it printed ✔ over a quarter of the corpus
#
#    `git ls-files` reported 804 and the dox reader beside this one read 603.
#    the delta was 197 files a parallel rename had MOVED on disk while the index
#    still held their old paths. each failed `[[ -f ]]`, each was skipped
#    silently, and the verdict did not move.
#
#    ⇒ q13: a count is a claim about a set, and this set has TWO stores. the
#      index answers one way, the disk another, and a `-f` guard that just
#      `continue`s picks one and tells nobody.
#
#    ⚠️ the skip is correct — an absent file cannot be read. what was wrong is
#      that it was SILENT.
######################################################################
GONE=0

######################################################################
# .what = the transport floor is DECLARED once and COPIED once. compare them
#
# 🛑 .why a reader, and not a comment
#    `grove.bootstrap.sh` cannot source `grove.web.sh` — it runs before the
#    repo that holds it exists — so `WEB_GIT_FLOOR` has two holders. its own
#    header teaches why that is the dangerous direction: *"a copy of a guarantee
#    is worth more than a copy of a check, because a check that drifts REPORTS,
#    and a guarantee that drifts HANGS."*
#
#    📜 2026-09-01: a comment claimed the copy was *"swept BY NAME"* while no
#      reader swept it. that sentence rested on a neighbour's citation of
#      `prove.wire-fetches-are-bounded`, a play the tree does not hold — so a
#      dead pointer became the ground for a fresh claim, in the repo's own
#      voice (`gotcha.my-own-note-became-my-evidence`). this function is what
#      that sentence claimed.
#
# ⚠️ .it reads the CLONE call, never "every git call in the file"
#    the `git -C … pull` at `grove.bootstrap.sh:192` must NOT carry
#    `protocol.allow=never`: its remote is whatever `.git/config` holds, and
#    `5.10.repos/configure.upsert.sh` tells a human to clone over SSH. so a
#    floor asserted across the file would be a false ✋ WITH a plausible fix —
#    the costliest kind (q7).
#
# ⚠️ .the want-list is SOURCED, never grepped
#    `WEB_GIT_FLOOR`'s elements carry trailing `#` comments, so a line-derived
#    reader hands the comparison the comment too (q8). a subshell source yields
#    the array as bash built it.
######################################################################
FLOOR_COPY='grove.bootstrap.sh'

scan_git_floor_is_copied() {
  local want got miss=""

  want="$(bash -c '
    set -uo pipefail
    source "$1" >/dev/null 2>&1 || exit 1
    [[ "${#WEB_GIT_FLOOR[@]}" -gt 0 ]] || exit 1
    printf "%s\n" "${WEB_GIT_FLOOR[@]}"
  ' _ "$ROOT/$BOUNDARY" 2>/dev/null | grep -v '^-c$' || true)"

  if [[ -z "$want" ]]; then
    echo "   ✋ $BOUNDARY declares no WEB_GIT_FLOOR this reader could source" >&2
    echo "      the transport floor has no declaration, so its copy cannot be checked" >&2
    HITS=$(( HITS + 1 ))
    return
  fi

  if [[ ! -f "$ROOT/$FLOOR_COPY" ]]; then
    echo "   ✋ $FLOOR_COPY is absent, so the floor's one copy could not be read" >&2
    HITS=$(( HITS + 1 ))
    return
  fi

  # join the backslash continuations, then take the CLONE line alone
  got="$(sed -e ':a' -e '/\\$/{N;s/\\\n//;ta}' "$ROOT/$FLOOR_COPY" 2>/dev/null \
        | grep -F 'clone "$REPO_URL"' | head -1)"
  if [[ -z "$got" ]]; then
    echo "   ✋ $FLOOR_COPY holds no 'clone \"\$REPO_URL\"' this reader could find" >&2
    echo "      ⇒ the bootstrap's clone moved or was rewritten, so the floor's" >&2
    echo "        copy is unlocated — this reader proves no claim about it" >&2
    HITS=$(( HITS + 1 ))
    return
  fi

  local n=0
  while IFS= read -r flag; do
    [[ -n "$flag" ]] || continue
    n=$(( n + 1 ))
    grep -qF -- "$flag" <<< "$got" || miss+="        · $flag"$'\n'
  done <<< "$want"

  ####################################################################
  # 🛑 a PASS here states the SUBJECT it read, never only its verdict
  #
  #    a bare `[[ -z "$miss" ]] && return 0` is a silent green. from the OUTPUT
  #    alone a reader cannot tell a compare that ran and held from a function
  #    that was never called at all, and the two look identical on the one run
  #    that matters.
  #
  #    ⚠️ round 13's own lesson, landed on the clamp written to close round 14:
  #      A CLAMP IS THE LEAST-REVIEWED CODE AND THE MOST TRUSTED. it is q1
  #      turned inward — does the evidence agree with the verdict? — and a
  #      verdict with no evidence beneath it cannot be asked that question.
  #
  #    ⇒ so the row names the COUNT and the FLAGS, and `say_floor` prints it on
  #      every exit path, the halt included.
  ####################################################################
  if [[ -z "$miss" ]]; then
    FLOOR_SAID="   ├─ floor: $FLOOR_COPY carries all $n flag(s) of ${BOUNDARY##*/}'s WEB_GIT_FLOOR"$'\n'"   │         $(printf '%s ' $want)"
    return 0
  fi

  echo "   ✋ $FLOOR_COPY:clone" >&2
  echo "      its copy of the transport floor has DRIFTED from WEB_GIT_FLOOR" >&2
  echo "      absent from the bootstrap's clone:" >&2
  printf '%s' "$miss" >&2
  echo "      ⇒ this is the FIRST fetch a fresh box makes, so the copy that lost" >&2
  echo "        a guarantee is the one on the box nobody re-tests" >&2
  echo "      fix: copy the flag into $FLOOR_COPY's clone. it cannot source" >&2
  echo "        $BOUNDARY — it runs before the repo that holds it exists" >&2
  HITS=$(( HITS + 1 ))
}

sweep() {
  HITS=0
  FILES=0
  GONE=0
  local file
  while IFS= read -r file; do
    subject_holds "$file" || continue
    # 🛑 `-e` asks the q13 question ("is any entry here"); `-f` asks a SECOND
    #    one, and to fuse them reports a tracked DIRECTORY as absent — a false
    #    ✋ that never clears. see the 📜 in `dox.verify`'s sweep, measured
    #    2026-09-02 on `.radio`, a tracked symlink at a dir
    if [[ ! -e "$ROOT/$file" ]]; then
      GONE=$(( GONE + 1 ))
      continue
    fi
    [[ -f "$ROOT/$file" ]] || continue   # a dir holds no shell to scan
    FILES=$(( FILES + 1 ))
    scan_one "$ROOT/$file"
    scan_fetch_is_verified "$ROOT/$file"
  done < <(git -C "$ROOT" ls-files)

  # ⚠️ driven ONCE, outside the per-file loop: its subject is the RELATIONSHIP
  #    between two files, so a per-file call would ask it once per subject and
  #    report the same drift N times
  scan_git_floor_is_copied
}

# .what = state what the floor-copy compare actually read, on every exit path
# .why  = a silent ✔ cannot be told from a check that never ran (see the 🛑 at
#         `scan_git_floor_is_copied`). the drift branch speaks for itself, so
#         this says the PASS — which is the half nobody audits.
say_floor() {
  [[ -n "$FLOOR_SAID" ]] || return 0
  echo "$FLOOR_SAID"
}

# .what = say so when the index and the disk disagree about the subject
say_gone() {
  [[ "$GONE" -gt 0 ]] || return 0
  echo "   ⚠️ $GONE subject file(s) are ABSENT from disk and were NOT read" >&2
  echo "      ⇒ the index and the working tree disagree about the subject, so" >&2
  echo "        this verdict covers $FILES files and says none about those $GONE" >&2
  echo "      read why: git status --short" >&2
}

######################################################################
# 📜 .why NO derivation stands here — measured 2026-08-31
#
#    a subject derived from the entrypoint's `source` lines misses
#    `src/emoji.index.build.sh`, which a bundle runs as
#    `bash "$GROVE_SRC/emoji.index.build.sh"` from BOTH its phases — and whose
#    own header records two unbounded `curl -sfL` calls. the file this reader
#    most obviously wants is the one its subject omits: q11 one layer up, where
#    the DERIVATION matches a subset of the forms a run reaches a file in.
#
#    add a second `bash "$…_SRC/…"` grammar and a rename breaks both at once.
#    two failures, one cause: a derived allowlist can silently empty, and an
#    empty allowlist reads as a clean sweep.
#
#    ⇒ a SUPERSET with a named subtraction cannot empty. `subject_holds` above
#      is that superset, and every subtraction is a readable row.
######################################################################

######################################################################
# 🛑 --prove: a PLANTED break in a REAL bundle file, never a fixture
#
#    a fixture is written by whoever wrote the reader, so it inherits that
#    reader's blind spot verbatim (m.12 / q11). the break goes into a file the
#    bundle tree actually dispatches, in the exact form a vendor's install doc
#    would hand somebody.
#
# ⚠️ `rule.forbid.repair-plays` EXCEPTION 2, all four conditions:
#    the restore is a `trap … EXIT`; it REFUSES a subject it did not find; the
#    break is one appended line; and it REPORTS whether the restore took.
######################################################################
######################################################################
# 🛑 the rules are checked BEFORE the corpus — a malformed rule makes this
#    reader quietly see less, so it must never reach a file
#
# 🛑 .and BEFORE `--prove`, which is the ordering this gate lacked until
#    2026-09-01. the gate sat below the prove branch, so the one mode whose
#    whole purpose is to CERTIFY the rules ran them past their own guard.
#
#    ⚠️ that is not a cosmetic ordering. the split at `scan_one` carries the
#      comment *"SAFE ONLY because `rules_are_wellformed` ran first"* — a
#      precondition `--prove` falsified on every run. a short rule silently
#      makes `exempt` hold the whole tail, so the reader exempts every file and
#      the probe then reports a clean +3 over rules that reach no line.
#
#    ⇒ a check that certifies X must itself be the strictest consumer of X.
#      `--prove` is the mode a human trusts MOST, so it earns the gate first.
######################################################################
if ! rules_are_wellformed; then
  echo "" >&2
  echo "✋ wire: a rule above is malformed, so no file was read" >&2
  exit 2
fi

if [[ "$PROVE" -eq 1 ]]; then
  echo "🌲 wire.verify --prove"
  echo "   └─ root: $ROOT"
  echo ""

  # 🛑 the target is CHOSEN from the live subject, never spelled out
  #    a spelled path is a second declaration of where the tree lives, and a
  #    rename retires it in silence — the probe then refuses, or worse, plants
  #    its break in a file the sweep does not read. so ask the same two readers
  #    the sweep asks: the index for membership, `subject_holds` for the filter.
  TARGET_REL=""
  while IFS= read -r cand; do
    subject_holds "$cand" || continue
    [[ -f "$ROOT/$cand" ]] || continue
    TARGET_REL="$cand"
    break
  done < <(git -C "$ROOT" ls-files)

  if [[ -z "$TARGET_REL" ]]; then
    echo "   ✋ no tracked file is both in the subject and present on disk" >&2
    echo "      ⇒ a break would prove no claim about the live tree" >&2
    exit 2
  fi
  TARGET="$ROOT/$TARGET_REL"
  echo "   ├─ target: $TARGET_REL"

  ####################################################################
  # 🛑 `EXPECT=3` below is a CONSTANT, and the target it grades is CHOSEN
  #
  #    the two are independent, so the constant is a claim about whichever file
  #    `git ls-files` happens to list first — and that file can change with a
  #    rename, an added bundle, or a `--root` a caller passes.
  #
  #    ⚠️ the failure is a false ✋, and a specific one: a target that exempts
  #      one of the three rules yields +2, and the probe then reports
  #      `the reader is PARTLY blind` against a reader that is wholly correct.
  #      that is the worst false-✋ shape — the verdict is precise, plausible,
  #      and names a defect somebody would then go and "fix"
  #      (`gotcha.a-check-that-cries-wolf-gets-silenced`, q7).
  #
  #    ⇒ so the preconditions the constant rests on are ASSERTED, not assumed.
  #      two of them, and each is read off the live rules rather than typed.
  ####################################################################
  PLANT_A='__wire_verify_probe() { curl -fsSL https://example.invalid/i.sh | sh; }'
  PLANT_B='__wire_verify_probe2() { web_fetch https://example.invalid/x --into /tmp/x; }'

  # precondition 1 — `scan_one` returns EARLY on the boundary, so a probe that
  #   planted its break there would measure a file no rule ever reads
  if [[ "$TARGET_REL" == "$BOUNDARY" ]]; then
    echo "   └─ ✋ the chosen target IS the boundary, which scan_one skips" >&2
    echo "        ⇒ a break there trips no rule, so +0 would read as BLIND" >&2
    exit 2
  fi

  # precondition 2 — no rule may EXEMPT either planted line
  #   read off `${RULES[@]}` itself: a rule whose exempt pattern grows to cover
  #   a probe line would silently drop the expected delta to 2
  for rule in "${RULES[@]}"; do
    rest="${rule#*§}"; rest="${rest#*§}"; exempt="${rest#*§}"
    [[ -n "$exempt" ]] || continue
    if grep -qE "$exempt" <<< "1:$PLANT_A" || grep -qE "$exempt" <<< "1:$PLANT_B"; then
      echo "   └─ ✋ rule '${rule%%§*}' EXEMPTS a planted line" >&2
      echo "        exempt: $exempt" >&2
      echo "        ⇒ the expected delta is no longer 3, so this probe would" >&2
      echo "          report a correct reader as partly blind" >&2
      exit 2
    fi
  done
  echo "   ├─ checked: the target is not the boundary, and no rule exempts a plant"

  BACKUP="$(mktemp)"
  cp "$TARGET" "$BACKUP"
  trap 'cp "$BACKUP" "$TARGET"; rm -f "$BACKUP"' EXIT

  sweep
  BEFORE="$HITS"
  echo "   ├─ before: $HITS escape(s) across $FILES tree files"

  # TWO breaks, so every rule is exercised on one run:
  #   line A — the shape a vendor's install doc hands somebody   (2 rules)
  #   line B — a fetch through the boundary with no check beside it (1 rule)
  # ⚠️ the SAME two strings the preconditions above tested, never typed twice —
  #    one fact, two holders, and the copy that drifts is the one the
  #    assertions read, so the guard would certify a plant the probe never
  #    made (m.9)
  printf '\n%s\n%s\n' "$PLANT_A" "$PLANT_B" >> "$TARGET"

  sweep
  AFTER="$HITS"
  echo "   ├─ after:  $HITS escape(s), with one bare fetch planted"

  cp "$BACKUP" "$TARGET"

  ####################################################################
  # 🛑 the restore is compared to the BACKUP, never to the git index
  #    — measured 2026-08-31 on `dox.verify`, whose first form asked
  #    `git diff --quiet`. that compares the working tree to the INDEX, which
  #    is a different subject: a file already `M ` there makes the check answer
  #    a question about git's own index state, and its ✔ never proved the
  #    break was gone (q2 — does the evidence name the SUBJECT?).
  ####################################################################
  if cmp -s "$BACKUP" "$TARGET"; then
    rm -f "$BACKUP"
    trap - EXIT
    echo "   ├─ restore: ✔ $TARGET_REL is byte-identical to its pre-probe copy"
  else
    echo "   ├─ restore: ✋ $TARGET_REL DIFFERS from its pre-probe copy" >&2
    echo "   │            a copy is kept at: $BACKUP" >&2
    echo "   │            restore it: cp $BACKUP $TARGET" >&2
    trap - EXIT
    exit 1
  fi

  ####################################################################
  # 🛑 the probe asserts its EXPECTED DELTA, never merely a rise
  #
  #    the planted lines trip THREE rules — the bare fetch, the pipe into a
  #    shell, and the unchecked `web_fetch` — so the only correct answer is +3.
  #
  #    ⚠️ this clause has already earned its keep once. on its first run the
  #    count moved +1, because the pipe rule required whitespace after `sh` and
  #    the planted line reads `| sh;`. a probe that accepted any rise would have
  #    reported 🌴 BITES over a rule that was blind to every `| sh` closing a
  #    compound statement — a false ✔ wearing a probe's authority.
  #
  #    ⇒ so a partial bite is a FAILURE here, and it names which half held.
  ####################################################################
  EXPECT=3
  DELTA=$(( AFTER - BEFORE ))

  if [[ "$DELTA" -eq "$EXPECT" ]]; then
    echo "   └─ 🌴 the reader BITES — the planted fetch moved the count $BEFORE → $AFTER (+$DELTA, as expected)"
    exit 0
  fi

  if [[ "$DELTA" -eq 0 ]]; then
    echo "   └─ ✋ the reader is BLIND — a bare 'curl … | sh' moved no count" >&2
    echo "        ⇒ every tree file has been unproven since this reader landed" >&2
    exit 1
  fi

  echo "   └─ ✋ the reader is PARTLY blind — moved +$DELTA, and the planted lines" >&2
  echo "        trip $EXPECT rules (a bare fetch, a pipe into a shell, and a" >&2
  echo "        web_fetch with no check beside it)" >&2
  echo "        ⇒ one rule saw it and one did not. a rise is not a bite: the" >&2
  echo "          rule that stayed quiet is blind on every real line too" >&2
  exit 1
fi

######################################################################
# the sweep
######################################################################
echo "🌲 wire.verify"
echo "   └─ root: $ROOT"
echo ""

sweep

if [[ "$FILES" -eq 0 ]]; then
  echo "   ✋ no tree shell files were read, so this proves no claim" >&2
  echo "      ⇒ a reader that reaches no file reports clean, a false ✔" >&2
  exit 2
fi

# ⚠️ BOTH speak before ANY verdict branches, so the halt path carries them too.
#    a subject-row printed only under ✔ is absent from precisely the run where
#    a reader most needs to know what was, and was not, actually read.
say_floor
say_gone

if [[ "$HITS" -gt 0 ]]; then
  echo "" >&2
  echo "🌲 wire: $HITS escape(s) across $FILES published shell files (named above)" >&2
  echo "   ⇒ a fetch outside $BOUNDARY carries no bound, no transport" >&2
  echo "     floor, and no pin — and every pin-keyed reader is blind to it," >&2
  echo "     because a pin-keyed reader finds its subjects BY their pins" >&2
  exit 1
fi

# 🛑 an INCOMPLETE subject is not a pass — see the same gate in dox.verify
if [[ "$GONE" -gt 0 ]]; then
  echo "✋ wire: no escape across the $FILES files this reader could open —" >&2
  echo "   and $GONE subject file(s) it could NOT, so the sweep proves no claim" >&2
  echo "   fix: reconcile the index with the tree, then re-run" >&2
  exit 2
fi

######################################################################
# 🛑 the verdict names the SHAPES it read, never "every off-box read"
#
#    the rules reach three shapes out of the boundary's six entry points, so
#    "every off-box read" claims a set four times the size of the one swept.
#
#    ⚠️ the damage is not the overclaim on its own; it is that a careful reader
#      BELIEVES it. thirty lines of measured argument sit above each rule, so
#      the ✔ under them reads as settled, and the next person does not go
#      looking for the `cargo install` that no rule sees. see `.the NAMED GAP`
#      beside the rules for the row this reader cannot reach.
######################################################################
######################################################################
# 🛑 .the verdict names EVERY gap it has, never the one that was on my mind
#
#    it named the SHAPE gap and stayed silent on the SUBJECT gap until
#    2026-09-01 — so a reader learned that some off-box reads go unread, and
#    learned no word about five whole files this sweep never opens.
#
#    ⚠️ one gap disclosed makes the others HARDER to find, not easier. a
#      verdict that volunteers a limitation reads as candid, and a candid
#      verdict is trusted further than a bare one — which is round 12's lesson
#      (a guard that names one hazard immunizes the others), landed on a ✔ line.
#
#    ⇒ so the EXCLUDED count is derived from the array, never typed. a sixth
#      entry added tomorrow moves this row on its own.
######################################################################
echo "🌲 wire: no raw curl, wget, clone, or fetch-into-shell outside the boundary ✔"
echo "   ├─ read: $FILES published shell files"
echo "   ├─ ⚠️ gap 1 of 2 — THREE shapes, not every off-box read. a raw registry"
echo "   │     install (cargo/npm/pnpm/corepack/flatpak) has no rule at all"
echo "   ├─ ⚠️ gap 2 of 2 — ${#EXCLUDED[@]} published file(s) are OUT of the subject, so no"
echo "   │     rule reaches them: ${EXCLUDED[*]}"
echo "   └─ prove it bites: rhx wire.verify --prove"
exit 0
