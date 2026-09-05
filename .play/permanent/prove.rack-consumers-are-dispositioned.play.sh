#!/usr/bin/env bash
######################################################################
# .what = prove EVERY consumer of a rack secret is dispositioned, and redden
#         the day a new one appears with no recorded verdict
#
# 🛑 .why a play, not a brief
#   - `inventory.security-checks.md` carries a row: `| credentials via keyrack | a secret at rest on a box | rhx keyrack | ✋ |`
#   - it reads ✋ because the guarded property is FALSE
#   - `5.4.gh` pipes the pat into `gh auth login --with-token`
#   - gh persists it to `~/.config/gh/hosts.yml` in cleartext, on every grove, on the paved path
#   - a human found that instance in prose, by hand, not by scan
#   - the CLASS — which consumers of a rack secret write it down — had never been swept
#   - the row named one member of an uncounted set: `inventory.security-checks.md`'s own heuristic #2, A CLAIM WIDER THAN ITS READER
#
# 🛑 .why it keys on the SOURCE, never a tool list
#   - the obvious reader greps for the tools that persist: `gh auth login`, `npm config set`, `docker login`, `.netrc`, `cargo login`
#   - that reader is a HAND-WRITTEN TOOL LIST, which `rule.require.one-command-provision` grades a blocker by name: "it cannot report the member nobody added"
#   - the tool that persists a secret tomorrow is absent from that list today
#   - such a reader is blind to exactly the member it exists to catch
#   - every secret on a box arrives through the rack (`rule.require.reach-credentials-through-keyrack`)
#   - a walk over `keyrack get` call sites cannot miss a consumer, whatever tool it hands the value to
#
# 🛑 .what "dispositioned" means, why a count and not a verdict
#   - this play does NOT decide whether a consumer persists its value
#   - dataflow across a shell function is opaque to a grep
#   - a reader that pretended otherwise would manufacture false verdicts in both directions (`gotcha.a-check-that-cries-wolf-gets-silenced`)
#   - it asks the one question a grep CAN answer honestly: has a human looked at this call site and recorded what it does with the value?
#   - the census below is that record
#   - a file that calls `keyrack get` and is absent from the census reddens
#   - a file whose CALL COUNT grew past its recorded number reddens
#   - a census row whose file no longer calls the rack reddens
#   - a stale record reads as coverage just as loudly as an absent one
#
# .what it does to the box
#   - it READS tracked files and reports
#   - no write, no network, no secret fetched — the rack is never called, only its CALL SITES are read
#   - safe on a laptop and on a grove alike
#
# guarantee:
#   - it DISCOVERS its subjects, so a consumer written tomorrow is measured tomorrow (`rule.require.bundle-as-sole-declaration`)
#   - it strips comments and fix-text `echo`/`printf` lines before it counts — this repo documents its own call shapes in prose beside them (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.8: a reader that re-authors its subject has a second place to be wrong)
#   - it proves its own counter discriminates before it aims at a real file
#   - it HALTS (exit 2) on an empty subject set rather than report a clean page about a set it never reached (m.12)
#
# 📜 2026-09-02: SEEN RED, all three directions
#   - a clamp never seen to fail is a guess (`rule.require.clamp-edge-cases`)
#   - the census was perturbed three ways in one run, each fired its own row:
#
#     | perturbation                        | it reported        |
#     | dropped aws.ec2.get.sh's row        | ✋ UNDISPOSITIONED |
#     | set aws.whoami.sh's count 1 → 9     | ✋ COUNT MOVED     |
#     | added a row for a file with no call | ✋ STALE ROW       |
#
#   - exit 1, three defects, the other nine rows stayed ✔ — the reader discriminates per-row, not on the first fault
#
# ⚠️ .why the green half is proven separately
#   - every clean run proves the green half
#   - a check proven in one direction only is half proven (`gotcha.a-check-that-cries-wolf-gets-silenced`, `.the corollary`)
#
# usage:
#   rhx play.run --play prove.rack-consumers-are-dispositioned
#
# exit:
#   0 = every consumer is dispositioned, and every disposition is live
#   1 = a consumer is undispositioned, has grown, or a row went stale
#   2 = the subject could not be read, so no claim was proven
######################################################################

set -uo pipefail

echo "🔎 prove.rack-consumers-are-dispositioned"
echo "   └─ subject: every 'keyrack get' call site in this repo"
echo ""

######################################################################
# 0. stand in the repo root, so the subject is THIS tree
######################################################################
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
if [[ -z "$ROOT" ]]; then
  echo "   └─ 🌙 not inside a git checkout, so the subject tree is unnamed" >&2
  echo "      · run this from within the dev-env-setup checkout" >&2
  exit 2
fi

# 🛑 .what = the reader's own path, taken BEFORE the cd — NOT a subject
#
# 📜 2026-09-02: play went ✋ UNDISPOSITIONED against ITSELF, claimed 5 live calls
#   - all five were its own machinery: two `keyrack get` pattern literals (counter, discovery), three fixture strings
#   - not one was a rack consumer
#
# .why
#   - the corpus is `git grep`, which walks TRACKED files
#   - `.play/permanent/*` became tracked when the clamps were committed
#   - the reader entered its own subject set
#   - a fixture that LOOKS like what it hunts is what a fixture is for
#   - `howto.run-a-redteam-round` names this shape: a REPAIR is the likeliest site of the next defect
#   - the commit of the clamps was that repair
#
# ⚠️ .why the false ✋ matters
#   - it was a FALSE ✋, the corrosive half
#   - a clamp that reddens against correct code gets silenced
#   - a silenced clamp takes the twelve true rows with it (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.13)
SELF_ABS="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null || echo "")"

cd "$ROOT" || exit 2

# ⚠️ .why the exclusion is NARROWEST possible: this ONE file, never `.play/` wholesale
#    - another play that genuinely reads the rack is a real security decision
#    - it still owes a census row (`rule.require.narrowest-terminal-grant`)
SELF_REL=""
[[ -n "$SELF_ABS" ]] && SELF_REL="$(realpath -m --relative-to="$ROOT" "$SELF_ABS" 2>/dev/null || echo "")"

######################################################################
# .what = 1. THE CENSUS — one row per file that reaches the rack
#
# format:  <path>|<live call count>|<class>|<where the value goes>
#
# class:
#   NAME     the key names a PROFILE, not a secret. an AWS_PROFILE selects
#            a local ~/.aws stanza; it authorizes none of its own, so
#            at-rest is not a question about it
#   MEMORY   a real secret; it never reaches disk
#   MIXED    both classes in one file, itemized in the note
#   PERSISTS a real secret, and it IS written down — every row here is a
#            live finding and must carry its own justification
#
# ⚠️ .why no row exists to silence this play
#   - a new SECRET consumer is a security decision
#   - the row records the decision; it never avoids it
######################################################################
CENSUS=(
  "src/grove.provision/2.shell/2.7.aliases/bash_aliases.sh|2|MIXED|:57 AWS_PROFILE → export (NAME). :3650 a DSN → mktemp 0700 tmpfs + config 0600 + trap rm (MEMORY, RAM-only)"
  "src/grove.provision/2.shell/2.2.git/git-credential-keyrack.sh|1|MEMORY|:404 GITHUB_TOKEN → stdout, git's credential-helper protocol. git holds no copy; it re-asks per fetch"
  "src/grove.provision/5.devtools/5.4.gh/configure.upsert.sh|1|PERSISTS|:207 GITHUB_TOKEN → gh auth login --with-token → ~/.config/gh/hosts.yml CLEARTEXT. an OPEN finding — see its justification below"
  "src/grove.provision/2.shell/2.7.aliases/brains.auth.sh|1|PERSISTS|:894 the parked claude oauth token → ~/.claude/.credentials.json on a swap. ACCEPTED, not open — see its justification below"
  "src/grove.provision/5.devtools/5.13.reach/configure.verify.sh|1|NAME|:60 AWS_PROFILE → compared against the declared name"
  "src/grove.provision/5.devtools/5.12.rack/configure.verify.sh|2|MEMORY|:72/:155 fetches to prove the rack ANSWERS on this seat; the bytes are counted and compared, never stored"
  ".agent/repo=.this/role=any/skills/git.grove.auth.github.set.sh|1|MEMORY|:389 a reachability PROBE, redirected to /dev/null on the remote"
  ".agent/repo=.this/role=any/skills/git.grove.wake.sh|1|NAME|:232 AWS_PROFILE → exported for the aws cli"
  ".agent/repo=.this/role=any/skills/git.grove.stop.sh|1|NAME|:165 AWS_PROFILE → exported for the aws cli"
  ".agent/repo=.this/role=any/skills/git.grove.trust.gen.sh|1|NAME|:503 AWS_PROFILE → exported for the aws cli"
  ".agent/repo=.this/role=any/skills/aws.ec2.get.sh|1|NAME|:134 AWS_PROFILE → exported for the aws cli"
  ".agent/repo=.this/role=any/skills/aws.whoami.sh|1|NAME|:68 AWS_PROFILE → exported for the aws cli"
  ".agent/repo=.this/role=any/skills/aws.reach.set.sh|2|NAME|:551/:597 AWS_PROFILE → read to compare declared vs racked"
)

######################################################################
# .what = 2. THE COUNTER — proven to discriminate before it reads a real file
#
# 🛑 .why
#   - this repo documents its own call shapes in PROSE, beside the calls
#   - `git-credential-keyrack.sh` carries `rhx keyrack get` in a comment at :238 and inside an `echo` fix-text at :423, one screen from the live call at :404
#   - a naive counter reads 3 where the answer is 1
#   - this is m.8: the reader re-authors its subject, gains a second place to be wrong no pattern review would surface
######################################################################
_count_live() {
  local body="$1"
  # strip comments, then drop fix-text lines whose FIRST word emits prose
  sed 's/#.*$//' <<<"$body" \
    | grep -vE '^[[:space:]]*(echo|printf)[[:space:]]' \
    | grep -cE 'keyrack get'
}

FIX_LIVE='TOKEN="$(rhx keyrack get --key GITHUB_TOKEN --value)"'
FIX_COMMENT='#   printf ... | rhx keyrack get --value'
FIX_ECHO='  echo "      cd $REPO && rhx keyrack get --owner ehmpath \\" >&2'
FIX_TRAILING='AWS_PROFILE=$(rhx keyrack get --key AWS_PROFILE) # a trailing note'

SELFTEST=0
[[ "$(_count_live "$FIX_LIVE")"     == "1" ]] || SELFTEST=$((SELFTEST + 1))
[[ "$(_count_live "$FIX_COMMENT")"  == "0" ]] || SELFTEST=$((SELFTEST + 1))
[[ "$(_count_live "$FIX_ECHO")"     == "0" ]] || SELFTEST=$((SELFTEST + 1))
[[ "$(_count_live "$FIX_TRAILING")" == "1" ]] || SELFTEST=$((SELFTEST + 1))

if [[ "$SELFTEST" -gt 0 ]]; then
  echo "   └─ 💥 the counter fails its own fixtures ($SELFTEST of 4)" >&2
  echo "      · it cannot tell a live call from a documented one" >&2
  echo "      · every count below would be unfounded, so none is offered" >&2
  exit 2
fi
echo "   ├─ counter: ✔ discriminates (4/4 fixtures)"

######################################################################
# 3. DISCOVER every file that reaches the rack
######################################################################
mapfile -t RAW < <(git grep -l -E 'keyrack get' -- '*.sh' 2>/dev/null | sort -u)

# drop THIS file, and say so — an exclusion nobody can see is a hole
SELF_DROPPED=0
FOUND=()
for f in "${RAW[@]}"; do
  if [[ -n "$SELF_REL" && "$f" == "$SELF_REL" ]]; then
    SELF_DROPPED=1
    continue
  fi
  FOUND+=("$f")
done

if [[ "${#FOUND[@]}" -eq 0 ]]; then
  echo "   └─ 💥 no rack consumer found at all — the walk reached an empty set" >&2
  echo "      · a clean page about a set nobody reached is not a proof (m.12)" >&2
  exit 2
fi
echo "   ├─ files that name the rack: ${#FOUND[@]}"

# 🛑 .why the exclusion is REPORTED, never assumed
#    - if the self-drop breaks silently, this line goes quiet and the ✋ returns
#    - visible either way
if [[ "$SELF_DROPPED" -eq 1 ]]; then
  echo "   ├─ self: ✔ this reader dropped ITSELF from its own subject set"
  echo "   │        (its 'keyrack get' occurrences are patterns and fixtures)"
else
  echo "   ├─ self: 🌙 this reader could not name its own path, so it may"
  echo "   │        judge its own fixtures as consumers — read any ✋ below"
  echo "   │        against this file before you trust it"
fi
echo ""

######################################################################
# 4. JUDGE — three directions, because a stale row reads as coverage
######################################################################
FAIL=0
LIVE_FILES=()

for f in "${FOUND[@]}"; do
  [[ -f "$f" ]] || continue
  body="$(cat "$f" 2>/dev/null || echo "")"
  n="$(_count_live "$body")"

  # a file whose only mentions are prose is not a consumer at all
  if [[ "$n" -eq 0 ]]; then
    continue
  fi
  LIVE_FILES+=("$f")

  row=""
  for c in "${CENSUS[@]}"; do
    if [[ "${c%%|*}" == "$f" ]]; then row="$c"; break; fi
  done

  if [[ -z "$row" ]]; then
    echo "   ✋ UNDISPOSITIONED — $f"
    echo "      · $n live 'keyrack get' call(s), and no census row"
    echo "      · a new rack consumer is a security decision; record where its"
    echo "        value goes, then add its row"
    FAIL=$((FAIL + 1))
    continue
  fi

  IFS='|' read -r _p want class note <<<"$row"

  if [[ "$n" -ne "$want" ]]; then
    echo "   ✋ COUNT MOVED — $f"
    echo "      · census says $want live call(s); the tree holds $n"
    echo "      · a call added to a censused file inherits a verdict nobody"
    echo "        gave it — re-read the file, then update its row"
    FAIL=$((FAIL + 1))
    continue
  fi

  case "$class" in
    PERSISTS) echo "   🛑 $f — $class ($n)" ;;
    *)        echo "   ✔ $f — $class ($n)" ;;
  esac
  echo "      └─ $note"
done

######################################################################
# 5. the STALE direction — a census row whose file stopped calling
######################################################################
for c in "${CENSUS[@]}"; do
  p="${c%%|*}"
  hit=0
  for f in "${LIVE_FILES[@]}"; do [[ "$f" == "$p" ]] && hit=1 && break; done
  if [[ "$hit" -eq 0 ]]; then
    echo "   ✋ STALE ROW — $p"
    echo "      · the census claims a rack consumer here; the tree has none"
    echo "      · a row that resolves to no call reads as coverage. drop it"
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "   ├─ live consumers: ${#LIVE_FILES[@]}"

######################################################################
# .what = 6. the ONE open finding, restated on every run
#
# ⚠️ .why this is not a failure
#   - the row is KNOWN, RECORDED
#   - its fix is blocked on a from-scratch grove (`rule.require.one-command-provision`)
#   - a play that failed on it would be red on every run
#   - a check that is always red gets silenced, and takes the other twelve rows down with it (`gotcha.a-check-that-cries-wolf-gets-silenced`, the opening thesis)
#   - it must not go quiet
#   - the finding prints every run, as a standing 🛑 no one can mistake for a pass
######################################################################
PERSIST_N=0
for c in "${CENSUS[@]}"; do
  IFS='|' read -r _p _n class _note <<<"$c"
  [[ "$class" == "PERSISTS" ]] && PERSIST_N=$((PERSIST_N + 1))
done

# ⚠️ .why this is a PER-ROW loop and not one prose block
#   - it was one block, hardcoded to gh's remediation, and it was correct
#     while gh was the only PERSISTS row
#   - a second PERSISTS row made the SAME block print "2 consumer(s)" over
#     advice that names only gh — verdict right, subject wrong
#     (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.4)
#   - ⇒ the class already demands "every row carries its own justification";
#     now the reader enforces that rather than trust it
if [[ "$PERSIST_N" -gt 0 ]]; then
  echo "   └─ 🛑 $PERSIST_N consumer(s) WRITE a rack secret to disk"
  for c in "${CENSUS[@]}"; do
    IFS='|' read -r p _n class _note <<<"$c"
    [[ "$class" == "PERSISTS" ]] || continue
    echo "      ·"
    echo "      · $p"
    case "$p" in
      *5.4.gh/configure.upsert.sh)
        echo "        OPEN — this is the ✋ row in inventory.security-checks.md, and it stands"
        echo "        the delta is PERSISTENCE PAST REVOCATION, not initial access:"
        echo "        a seat that can read the copy could already read the rack"
        echo "        so 'rotate the credential' does NOT evict — the old pat must be"
        echo "        REVOKED at github.com/settings/tokens"
        echo "        fix at cause: gh reads GH_TOKEN from its ENV and persists none"
        echo "        of it. blocked on a from-scratch grove to prove"
        ;;
      *2.7.aliases/brains.auth.sh)
        echo "        ACCEPTED — the write IS the product, not a side effect of it:"
        echo "        'brains.auth use' exists to install a parked oauth token as the"
        echo "        live claude login, so a swap that wrote no file would perform"
        echo "        none of what a human asked for. there is no at-cause fix that"
        echo "        keeps the command"
        echo "        the bounds that make it acceptable, each read off the code:"
        echo "         - the sink is claude's OWN credential store, which claude"
        echo "           writes itself on every login — this adds no new secret file"
        echo "         - :1154 chmod 700 the auth dir; :1519 chmod 600 the temp BEFORE"
        echo "           the secret lands, then an atomic mv, so no window is 0644"
        echo "         - :1460 the PRIOR token is parked back to the rack rather than"
        echo "           left behind, so a swap moves one copy, never forks two"
        ;;
      *)
        echo "        ✋ no justification recorded"
        echo "        a PERSISTS row is a live security decision; record where the"
        echo "        value lands and why that is acceptable, then add its arm here"
        FAIL=$((FAIL + 1))
        ;;
    esac
  done
fi

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "   └─ ✋ $FAIL census defect(s)" >&2
  exit 1
fi

echo "   └─ ✔ every rack consumer is dispositioned, and every row is live"
exit 0
