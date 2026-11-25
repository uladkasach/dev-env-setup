#!/usr/bin/env bash
######################################################################
# .what = prove 5.26.commitorgs allows each org a cloud grove's token can push to,
#         in the org commit meter, exactly as the commit gate reads it — and keeps
#         every block, every other key, and every damaged meter as is
#
# .why  = a verdict here that disagreed with `check_org_blocker` would be a ✔ over a
#         crew the gate refuses. so every read and every write is graded against the
#         upstream gate itself, on the same bytes, never against a table this play
#         wrote (`hazard.a-clamp-can-lie-the-same-way-code-can`)
#
# .the rows
#   1. the classifier vs `check_org_blocker`, one fixture per meter shape
#   2. the token read: push filter · user repos dropped · dedupe · github→keyrack map · a failed read
#   3. configure.upsert on a cloud crew seat: absent · re-run · a block kept · @all blocked ·
#      damaged · token unread · token with no org · a write that fails · a write that lands
#      naught · a read that fails · jq absent · a directory at the meter path
#   4. configure.verify: granted · unset · blocked · @all · damaged · token unread · no org ·
#      crews · only orgless crews · jq absent · a directory at the path; then provision.verify
#      + upsert: jq present · absent · broken · installed · failed
#   5. declines: a local grove · a ci runner · the admin seat — no phase writes a meter there
#   6. the public entry, `grove.provision --what 5.26.commitorgs`: plan · apply · apply, then
#      each refusal, each decline, and an extant seat with one token org unset
#   8. parity: the bundle's writer vs the real `git.commit.uses` writer and read verb; its
#      crew-org read vs the gate's `get_org_from_keyrack`; the 5.4.gh-first dispatch
#   7. the rendered transcript matches its snapshot (run last, after row 8)
#
# .the stand-ins, each in the .mock / .why / .real form
#   - .mock = `gh` — it answers `gh api user/repos` from a fixture repo list, and runs the
#             bundle's own `--jq` filter over it with the real jq
#     .why  = the shapes a live token will not produce on demand: a user repo, a duplicate,
#             a no-push org, a 401
#     .real = `prove.commitorgs-token-read-meets-real-github` reads the live api with the
#             bundle's own call; the hetzner crew seat answered three orgs, as this does
#   - .mock = `pkg_install` (PKG_STUB) — answers a jq install, ok or failed
#     .why  = a real apt install needs root and the network, and would change the box
#     .real = the same `pkg_install` (src/grove.pkg.sh) every bundle installs through; a fresh
#             grove's provision runs it. the public entry (row 6) runs with jq present, so it
#             installs naught, and no capture here proves the jq install itself
#   - .mock = a `jq` that exits 3 (JQ_BROKEN_DIR) — a half-installed or shadowed jq
#     .why  = no healthy box holds one
#     .real = the healthy jq every other row reads with
#   - .mock = `get_org_from_keyrack`, inside `gate_verdict` — names the org the gate checks
#     .why  = the gate reads it from a crew tree's keyrack; row 1 grades the meter, not that read
#     .real = row 8d grades the bundle's crew-org read against the real `get_org_from_keyrack`
#             on seven manifest shapes
#   - .mock = `hostname` and `whoami`, inside `phase()` — answer `box-7` and the row's seat
#     .why  = `grove_env_seat_is_admin` reads `whoami` to pick the decline arm (rows 5a–5c), and
#             a fixed host keeps the laptop's name out of the snapshot
#     .real = the public entry (row 6) runs the real `hostname` and `whoami`, masked in its snaps
#   - fault seams, not remote stand-ins: WRITE_FAIL, WRITE_NOOP, READ_FAIL, JQ_MODE=absent swap one
#     bundle operation for one that returns 1, to reach its failure arm; BLOCK_MIDWRITE wraps the
#     real unchanged-check with a write, so the real check is what refuses
#
# .what it does to the box
#   - none: every read and write lands under a throwaway dir, removed on exit
#
# usage:
#   rhx play.run --play prove.commitorgs-reads-the-meter-as-the-gate
#
# exit:
#   0 = every claim held · 1 = a claim failed · 2 = the subject is unreadable
######################################################################

set -uo pipefail

echo "🔎 prove.commitorgs-reads-the-meter-as-the-gate"
echo "   └─ subject: 5.26.commitorgs, against rhachet-roles-ehmpathy check_org_blocker"
echo ""

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
[[ -n "$ROOT" ]] || { echo "   └─ ✋ ConstraintError: not inside a git checkout" >&2; exit 2; }
BUNDLE="$ROOT/src/grove.provision/5.devtools/5.26.commitorgs"
[[ -f "$BUNDLE/_.sh" ]] || { echo "   └─ ✋ ConstraintError: the subject is absent: $BUNDLE" >&2; exit 2; }
UPSTREAM="$ROOT/node_modules/rhachet-roles-ehmpathy/dist/domain.roles/mechanic/skills/git.commit/git.commit.operations.sh"
if [[ ! -f "$UPSTREAM" ]]; then
  echo "   └─ ✋ ConstraintError: the upstream gate is absent: $UPSTREAM" >&2
  echo "      ⇒ without it, every row grades against naught; this is no pass" >&2
  echo "      fix: pnpm install" >&2
  exit 2
fi
command -v jq >/dev/null 2>&1 || { echo "   └─ ✋ ConstraintError: jq is absent; the stub gh and the gate both need it" >&2; exit 2; }

# .what = run one check; tally it.  args: the label, then the command
failed=0; passed=0
claim() {
  local label="$1"; shift
  if "$@"; then echo "   ✔ $label"; passed=$((passed + 1)); return 0; fi
  echo "   💥 MalfunctionError: $label" >&2; failed=$((failed + 1))
}

FIX="$(mktemp -d)" || { echo "   └─ 💥 MalfunctionError: could not build a fixture dir" >&2; exit 1; }
trap 'rm -rf "$FIX"' EXIT

# .what = add one rendered output to the transcript snapshot.  args: label, then the text
# .why  = per-run values (the fixture dir, the checkout, the login, the host) are masked,
#         so the public transcript carries none of them
TRANSCRIPT="$FIX/transcript"; : > "$TRANSCRIPT"
SNAP_HOST="$(hostname 2>/dev/null)"
FIXTURE_SEATS=(camper ground human runner)
snap() {
  local text="${2//$FIX/<fix>}" i
  text="${text//$ROOT/<root>}"
  # a fixture seat (`<seat>@box-7`) is a fixed string: shield it behind its index, so a real
  # login that shares its name (a grove's `camper`) is never masked inside it
  for i in "${!FIXTURE_SEATS[@]}"; do text="${text//${FIXTURE_SEATS[$i]}@box-7/<fixture-seat-$i>}"; done
  text="${text//$(whoami)/<login>}"
  for i in "${!FIXTURE_SEATS[@]}"; do text="${text//<fixture-seat-$i>/${FIXTURE_SEATS[$i]}@box-7}"; done
  [[ -n "$SNAP_HOST" ]] && text="${text//$SNAP_HOST/<host>}"
  printf '## %s\n%s\n\n' "$1" "$text" >> "$TRANSCRIPT"
}

METER_REL=".rhachet/storage/repo=ehmpathy/role=mechanic/.meter/git.commit.uses.org.jsonc"

# .what = put a meter fixture under a HOME.  args: home= kind=absent|dir|bytes bytes=
meter_put() {
  local home='' kind='' bytes='' arg
  for arg in "$@"; do
    case "$arg" in home=*) home="${arg#home=}" ;; kind=*) kind="${arg#kind=}" ;; bytes=*) bytes="${arg#bytes=}" ;; esac
  done
  mkdir -p "$home/$(dirname "$METER_REL")"
  case "$kind" in
    absent) ;;
    dir)    mkdir -p "$home/$METER_REL" ;;
    bytes)  printf '%s' "$bytes" > "$home/$METER_REL" ;;
  esac
}

# .what = the upstream gate's verdict for one org: allow | refuse | corrupt.  args: home= org=
gate_verdict() {
  local home='' org='' arg
  for arg in "$@"; do case "$arg" in home=*) home="${arg#home=}" ;; org=*) org="${arg#org=}" ;; esac; done
  ( export HOME="$home"
    # an upstream that did not load answers `unloaded`, which no verdict equals
    # shellcheck disable=SC1090
    source "$UPSTREAM" >/dev/null 2>&1 || { echo unloaded; exit 0; }
    declare -F check_org_blocker >/dev/null || { echo unloaded; exit 0; }
    get_org_from_keyrack() { ORG_VALUE="$org"; return 0; }
    check_org_blocker >/dev/null 2>&1; rc=$?
    [[ $rc -eq 0 ]] && { echo allow; exit 0; }
    [[ "$ORG_BLOCK_CORRUPT" == true ]] && { echo corrupt; exit 0; }
    echo refuse )
}

# .what = the gate's verdicts for a list of orgs, as `org=verdict` words.  args: home= orgs=
gate_verdicts() {
  local home='' orgs='' arg org out=''
  for arg in "$@"; do case "$arg" in home=*) home="${arg#home=}" ;; orgs=*) orgs="${arg#orgs=}" ;; esac; done
  for org in $orgs; do out="${out:+$out }$org=$(gate_verdict home="$home" org="$org")"; done
  printf '%s' "$out"
}

# .what = the bundle's verdict for one org, collapsed to the gate's three.  args: home= org=
ours_verdict() {
  local home='' org='' arg
  for arg in "$@"; do case "$arg" in home=*) home="${arg#home=}" ;; org=*) org="${arg#org=}" ;; esac; done
  ( export HOME="$home"
    # shellcheck disable=SC1090
    source "$BUNDLE/_.sh"
    presence="$(grove_provision_5_26_commitorgs_meter_presence)"
    bytes=''; [[ "$presence" == present ]] && bytes="$(cat "$HOME/$METER_REL")"
    case "$(grove_provision_5_26_commitorgs_state_of org="$org" presence="$presence" bytes="$bytes")" in
      allowed|allowed@all) echo allow ;;
      blocked|blocked@all|unset) echo refuse ;;
      *) echo corrupt ;;
    esac )
}

######################################################################
# row 1 — the classifier agrees with the gate on every shape
######################################################################
i=0
while IFS='|' read -r label kind bytes; do
  [[ -n "$label" ]] || continue
  for org in ahbode ehmpathy; do
    i=$((i + 1)); H="$FIX/c$i"; mkdir -p "$H"
    meter_put home="$H" kind="$kind" bytes="$bytes"
    g="$(gate_verdict home="$H" org="$org")"; o="$(ours_verdict home="$H" org="$org")"
    claim "1.  $label, org $org: gate=$g, bundle=$o" [ "$g" == "$o" ]
  done
done <<'CASES'
absent file|absent|
a directory at the path|dir|
a 0-byte file|bytes|
an empty object|bytes|{}
an empty orgs|bytes|{"orgs":{}}
ahbode allowed|bytes|{"orgs":{"ahbode":"allowed"}}
ahbode blocked, @all allowed|bytes|{"orgs":{"ahbode":"blocked","@all":"allowed"}}
@all allowed|bytes|{"orgs":{"@all":"allowed"}}
@all blocked|bytes|{"orgs":{"@all":"blocked"}}
a top-level array|bytes|[]
orgs as a string|bytes|{"orgs":"x"}
a leaf as an array|bytes|{"orgs":{"ahbode":["allowed"]}}
@all as an unknown word|bytes|{"orgs":{"@all":"yes"}}
unparseable bytes|bytes|{"orgs":
CASES

######################################################################
# the stub `gh`: runs the caller's own `--jq` over a fixture repo list, with the real jq
######################################################################
STUB="$FIX/bin"; mkdir -p "$STUB"
cat > "$FIX/repos.orgs.json" <<'JSON'
[
  {"owner": {"login": "ahbode", "type": "Organization"}, "permissions": {"push": true}},
  {"owner": {"login": "ahbode", "type": "Organization"}, "permissions": {"push": true}},
  {"owner": {"login": "ehmpathy", "type": "Organization"}, "permissions": {"push": true}},
  {"owner": {"login": "acme", "type": "Organization"}, "permissions": {"push": true}},
  {"owner": {"login": "otherorg", "type": "Organization"}, "permissions": {"push": false}},
  {"owner": {"login": "some-human", "type": "User"}, "permissions": {"push": true}}
]
JSON
# a github org whose name differs from its keyrack org: placeholder names, mapped by the
# row-2d override of `GROVE_ORG_GHORGS` (this public repo names no org past ahbode and ehmpathy)
cat > "$FIX/repos.mapped.json" <<'JSON'
[
  {"owner": {"login": "ahbode", "type": "Organization"}, "permissions": {"push": true}},
  {"owner": {"login": "acme-labs", "type": "Organization"}, "permissions": {"push": true}}
]
JSON
cat > "$FIX/repos.none.json" <<'JSON'
[
  {"owner": {"login": "otherorg", "type": "Organization"}, "permissions": {"push": false}}
]
JSON
cat > "$STUB/gh" <<STUBGH
#!/usr/bin/env bash
mode="\${GH_STUB_MODE:-orgs}"
[[ "\$mode" == fail ]] && { echo "gh: HTTP 401: Bad credentials (https://api.github.com/user/repos)" >&2; exit 1; }
expr=''
while [[ \$# -gt 0 ]]; do
  [[ "\$1" == --jq ]] && { expr="\$2"; shift; }
  shift
done
jq -r "\$expr" "$FIX/repos.\$mode.json"
STUBGH
chmod +x "$STUB/gh"

# a jq that is present and parses no json: the shape a half-installed or shadowed jq takes
JQ_BROKEN_DIR="$FIX/jq-broken"; mkdir -p "$JQ_BROKEN_DIR"
printf '#!/usr/bin/env bash\necho "jq: error: not a json parser" >&2\nexit 3\n' > "$JQ_BROKEN_DIR/jq"
chmod +x "$JQ_BROKEN_DIR/jq"
export JQ_BROKEN_DIR

# .what = run one phase of the bundle as a seat, under a HOME, with the stub gh first on PATH
#         args: home= server= seat= phase=<configure_upsert|configure_verify|provision_verify>
#         env:  GH_STUB_MODE=orgs|none|fail · WRITE_FAIL=1 (the meter writer fails)
#               WRITE_NOOP=1 (the meter writer answers 0 and writes naught)
#               BLOCK_MIDWRITE=1 (a block lands between the read and the rename)
#               READ_FAIL=1 (a present meter's read fails) · JQ_MODE=absent|broken
#               PKG_STUB=ok|fail (the package install answers, with no apt run)
# .note = the hostname is pinned to `box-7` and the login to the seat, so a row reads the
#         same on any box
phase() {
  local home='' server='' seat='' fn='' arg
  for arg in "$@"; do
    case "$arg" in
      home=*) home="${arg#home=}" ;; server=*) server="${arg#server=}" ;;
      seat=*) seat="${arg#seat=}" ;; phase=*)  fn="${arg#phase=}" ;;
    esac
  done
  ( export HOME="$home" GROVE_ENV_SERVER="$server" GROVE_ENV_SEAT="$seat" PATH="$STUB:$PATH"
    hostname() { echo box-7; }
    _seat="$seat"; whoami() { echo "$_seat"; }
    # shellcheck disable=SC1091
    source "$ROOT/src/grove.env.sh" >/dev/null 2>&1 && declare -F grove_env_seat_is_admin >/dev/null \
      || { echo "💥 src/grove.env.sh did not load"; echo "rc=99"; exit 0; }
    # shellcheck disable=SC1091
    source "$ROOT/src/grove.org.sh" || { echo "💥 src/grove.org.sh did not load"; echo "rc=99"; exit 0; }
    for f in _.sh "${fn%_*}.${fn#*_}.sh"; do
      # shellcheck disable=SC1090
      source "$BUNDLE/$f" || { echo "💥 $f did not load"; echo "rc=99"; exit 0; }
    done
    [[ -n "${WRITE_FAIL:-}" ]] && grove_provision_5_26_commitorgs_meter_allow() { return 1; }
    [[ -n "${WRITE_NOOP:-}" ]] && grove_provision_5_26_commitorgs_meter_allow() { return 0; }
    # a human's block lands between the read and the rename; the real check then runs
    if [[ -n "${BLOCK_MIDWRITE:-}" ]]; then
      eval "$(declare -f grove_provision_5_26_commitorgs_meter_unchanged | sed '1s/^grove_provision_5_26_commitorgs_meter_unchanged/__real_meter_unchanged/')"
      grove_provision_5_26_commitorgs_meter_unchanged() {
        printf '%s' '{"orgs":{"ehmpathy":"blocked"}}' > "$(grove_provision_5_26_commitorgs_meter_path)"
        __real_meter_unchanged "$@"
      }
    fi
    [[ -n "${READ_FAIL:-}" ]] && grove_provision_5_26_commitorgs_meter_bytes() { return 1; }
    [[ "${JQ_MODE:-}" == absent ]] && grove_provision_5_26_commitorgs_has_jq() { return 1; }
    [[ "${JQ_MODE:-}" == broken ]] && export PATH="$JQ_BROKEN_DIR:$PATH"
    # the stub logs each call to a file, so no harness line reaches the snapshot
    [[ "${PKG_STUB:-}" == ok ]] && pkg_install() { echo "pkg_install $*" >> "$FIX/pkg.calls"; return 0; }
    [[ "${PKG_STUB:-}" == fail ]] && pkg_install() { echo "pkg_install $* (failed)" >> "$FIX/pkg.calls"; return 1; }
    "grove_provision_5_26_commitorgs_${fn}"; echo "rc=$?"
  ) 2>&1
}

# .what = lay one crew tree.  args: home= owner=<github owner dir> tree= org=<keyrack org>
crew_tree() {
  local home='' owner='' tree='' org='' arg dir
  for arg in "$@"; do
    case "$arg" in
      home=*) home="${arg#home=}" ;; owner=*) owner="${arg#owner=}" ;;
      tree=*) tree="${arg#tree=}" ;; org=*)   org="${arg#org=}" ;;
    esac
  done
  dir="$home/git/$owner/_worktrees/$tree/.agent"
  mkdir -p "$dir"
  printf 'org: %s\n' "${org:-$owner}" > "$dir/keyrack.yml"
}

HZ=cloud@hetzner.hetzbot
ORGS3="acme ahbode ehmpathy"

######################################################################
# row 2 — the token read
######################################################################
token_orgs() {
  ( export PATH="$STUB:$PATH"
    # shellcheck disable=SC1091
    source "$ROOT/src/grove.org.sh"
    [[ -n "${GHORGS_OVERRIDE:-}" ]] && GROVE_ORG_GHORGS="$GHORGS_OVERRIDE"
    # shellcheck disable=SC1090
    source "$BUNDLE/_.sh"
    grove_provision_5_26_commitorgs_token_orgs; echo " rc=$?" )
}
out="$(token_orgs)"
claim "2a. the token read: push orgs only, user repos dropped, deduped" [ "$out" == "$ORGS3 rc=0" ]
out="$(GH_STUB_MODE=mapped GHORGS_OVERRIDE='acme:acme-labs' token_orgs)"
claim "2d. a github org named apart from its keyrack org reads as the keyrack org (acme-labs → acme)" [ "$out" == "acme ahbode rc=0" ]
out="$(GH_STUB_MODE=none token_orgs)"
claim "2b. a token that can push to no org: an empty set, rc=0" [ "$out" == " rc=0" ]
out="$(GH_STUB_MODE=fail token_orgs)"
claim "2c. a failed read: rc=1, never an empty set that reads as 'no org'" [ "$out" == " rc=1" ]

######################################################################
# row 3 — configure.upsert on a cloud crew seat
######################################################################
H="$FIX/u-absent"; mkdir -p "$H"
out="$(phase home="$H" server="$HZ" seat=camper phase=configure_upsert)"; snap "upsert · hetzner, no meter yet" "$out"
claim "3a. no meter: allows each token org, names them, rc=0" bash -c '[[ "$1" == *"allowed orgs '"'"'acme'"'"', '"'"'ahbode'"'"', '"'"'ehmpathy'"'"' on camper@box-7"* && "$1" == *"rc=0"* ]]' _ "$out"
claim "3b. and the real gate now allows each one" [ "$(gate_verdicts home="$H" orgs="$ORGS3")" == "acme=allow ahbode=allow ehmpathy=allow" ]
claim "3c. and an org the token cannot push to stays refused" [ "$(gate_verdict home="$H" org=otherorg)" == refuse ]
before="$(cat "$H/$METER_REL")"; stamp="$(stat -c %Y.%N "$H/$METER_REL" 2>/dev/null)"
sleep 1
out="$(phase home="$H" server="$HZ" seat=camper phase=configure_upsert)"; snap "upsert · hetzner, re-run on a granted meter" "$out"
claim "3d. a re-run: says no write is owed, rc=0, the meter's bytes and mtime unchanged" bash -c '[[ -f "$3" && -n "$2" && "$1" == *"every token org already reads allowed on camper@box-7 — no write owed"* && "$1" == *"rc=0" && "$1" != *"allowed orgs"* && "$2" == "$(cat "$3")" && "$4" == "$(stat -c %Y.%N "$3")" ]]' _ "$out" "$before" "$H/$METER_REL" "$stamp"

H="$FIX/u-block"; mkdir -p "$H"
meter_put home="$H" kind=bytes bytes='{"orgs":{"ehmpathy":"blocked","otherorg":"allowed"},"note":"kept"}'
out="$(phase home="$H" server="$HZ" seat=camper phase=configure_upsert)"; snap "upsert · hetzner, ehmpathy blocked by the human" "$out"
claim "3e. a block: the other two allowed, the block said and kept, every other key kept" bash -c '[[ "$1" == *"allowed orgs '"'"'acme'"'"', '"'"'ahbode'"'"'"* && "$1" == *"🌙 left org '"'"'ehmpathy'"'"' as is"*"refused here until the human lifts it"* && "$1" == *"rc=0"* && "$(jq -c . "$2")" == "{\"orgs\":{\"ehmpathy\":\"blocked\",\"otherorg\":\"allowed\",\"acme\":\"allowed\",\"ahbode\":\"allowed\"},\"note\":\"kept\"}" ]]' _ "$out" "$H/$METER_REL"
claim "3f. and the real gate refuses the blocked org, allows the rest" [ "$(gate_verdicts home="$H" orgs="$ORGS3")" == "acme=allow ahbode=allow ehmpathy=refuse" ]

H="$FIX/u-allblock"; mkdir -p "$H"
meter_put home="$H" kind=bytes bytes='{"orgs":{"@all":"blocked"}}'
out="$(phase home="$H" server="$HZ" seat=camper phase=configure_upsert)"; snap "upsert · hetzner, @all blocked by the human" "$out"
claim "3g. an @all block: a 🌙 per org, no write, rc=0 — the human's block reaches every org" bash -c '[[ "$1" == *"🌙 left org '"'"'acme'"'"' as is"* && "$1" == *"🌙 left org '"'"'ehmpathy'"'"' as is"* && "$1" != *"allowed orgs"* && "$1" != *"no write owed"* && "$1" == *"rc=0" && "$(cat "$2")" == "{\"orgs\":{\"@all\":\"blocked\"}}" ]]' _ "$out" "$H/$METER_REL"

H="$FIX/u-damaged"; mkdir -p "$H"
meter_put home="$H" kind=bytes bytes='{"orgs":'
out="$(phase home="$H" server="$HZ" seat=camper phase=configure_upsert)"; snap "upsert · hetzner, a damaged meter" "$out"
claim "3h. a damaged meter: rc=1, never written over, names the read, the clear, the apply, the re-block, each its own step" bash -c '[[ "$1" == *"is damaged, so no grant is written over it"* && "$1" == *"1. read it first"*"cat "* && "$1" == *"2. then clear it"*"rm "* && "$1" == *"3. then apply: rhx grove.provision --what 5.26.commitorgs --mode apply"* && "$1" == *"4. then set each block"*"--org <org> block"* && "$1" != *"allowed orgs"* && "$1" == *"rc=1"* && "$(cat "$2")" == "{\"orgs\":" ]]' _ "$out" "$H/$METER_REL"

H="$FIX/u-unread"; mkdir -p "$H"
out="$(GH_STUB_MODE=fail phase home="$H" server="$HZ" seat=camper phase=configure_upsert)"; snap "upsert · hetzner, the token cannot be read" "$out"
claim "3i. an unread token: rc=1, names 5.4.gh as the fix, writes no meter" bash -c '[[ "$1" == *"could not be read"* && "$1" == *"--what 5.4.gh --mode apply"* && "$1" == *"rc=1"* && ! -e "$2/$3" ]]' _ "$out" "$H" "$METER_REL"

H="$FIX/u-none"; mkdir -p "$H"
out="$(GH_STUB_MODE=none phase home="$H" server="$HZ" seat=camper phase=configure_upsert)"; snap "upsert · hetzner, a token that can push to no org" "$out"
claim "3j. a token with no push org: a 🌙, rc=0, writes no meter" bash -c '[[ "$1" == *"🌙 the token on camper@box-7 can push to no org"* && "$1" == *"rc=0"* && ! -e "$2/$3" ]]' _ "$out" "$H" "$METER_REL"

H="$FIX/u-wfail"; mkdir -p "$H"
out="$(WRITE_FAIL=1 phase home="$H" server="$HZ" seat=camper phase=configure_upsert)"; snap "upsert · hetzner, a write that fails" "$out"
claim "3k. a write that fails: rc=1, said with its fix, never a claim of a grant" bash -c '[[ "$1" == *"could not be written"* && "$1" == *"└─ fix: once the dir is writable"*"--what 5.26.commitorgs --mode apply"* && "$1" == *"rc=1"* && "$1" != *"allowed orgs"* ]]' _ "$out"

H="$FIX/u-allallow"; mkdir -p "$H"
meter_put home="$H" kind=bytes bytes='{"orgs":{"@all":"allowed"}}'
out="$(phase home="$H" server="$HZ" seat=camper phase=configure_upsert)"; snap "upsert · hetzner, @all allowed by the human" "$out"
claim "3l. an @all allow: no write owed, said, rc=0, the meter as the human left it" bash -c '[[ "$1" == *"no write owed"* && "$1" == *"rc=0" && "$(cat "$2")" == "{\"orgs\":{\"@all\":\"allowed\"}}" ]]' _ "$out" "$H/$METER_REL"

H="$FIX/u-rfail"; mkdir -p "$H"
meter_put home="$H" kind=bytes bytes='{"orgs":{"ahbode":"allowed"}}'
out="$(READ_FAIL=1 phase home="$H" server="$HZ" seat=camper phase=configure_upsert)"; snap "upsert · hetzner, a present meter whose read fails" "$out"
claim "3m. a present meter whose read fails: 💥 with ls -l, rc=1, no write" bash -c '[[ "$1" == *"💥 MalfunctionError"*"could not be read"* && "$1" == *"read why: ls -l "* && "$1" != *"allowed orgs"* && "$1" == *"rc=1"* && "$(cat "$2")" == "{\"orgs\":{\"ahbode\":\"allowed\"}}" ]]' _ "$out" "$H/$METER_REL"

H="$FIX/u-nojq"; mkdir -p "$H"
meter_put home="$H" kind=bytes bytes='{"orgs":{"ehmpathy":"blocked"}}'
out="$(JQ_MODE=absent phase home="$H" server="$HZ" seat=camper phase=configure_upsert)"; snap "upsert · hetzner, jq absent" "$out"
claim "3n. jq absent: names the absent tool and its apply, never a damaged meter, rc=1, the meter untouched" bash -c '[[ "$1" == *"jq is absent on camper@box-7"* && "$1" == *"--what 5.26.commitorgs --mode apply"* && "$1" != *"damaged"* && "$1" != *"rm "* && "$1" == *"rc=1"* && "$(cat "$2")" == "{\"orgs\":{\"ehmpathy\":\"blocked\"}}" ]]' _ "$out" "$H/$METER_REL"

H="$FIX/u-wnoop"; mkdir -p "$H"
out="$(WRITE_NOOP=1 phase home="$H" server="$HZ" seat=camper phase=configure_upsert)"; snap "upsert · hetzner, a write that answers 0 and lands naught" "$out"
claim "3o. a write that lands naught: the re-read catches it, ✋ names each org still unset, rc=1, never a claim of a grant" bash -c '[[ "$1" == *"was written, and it still reads no grant for orgs '"'"'acme'"'"', '"'"'ahbode'"'"', '"'"'ehmpathy'"'"'"* && "$1" == *"└─ fix: re-run"*"rhx git.commit.uses get --org"* && "$1" != *"• allowed orgs"* && "$1" == *"rc=1"* ]]' _ "$out"

H="$FIX/u-midwrite"; mkdir -p "$H/$(dirname "$METER_REL")"
out="$(BLOCK_MIDWRITE=1 phase home="$H" server="$HZ" seat=camper phase=configure_upsert)"; snap "upsert · hetzner, a human's block lands while the apply writes" "$out"
claim "3q. a block set mid-write: the apply refuses, the block survives, rc=1, never a claim of a grant" bash -c '[[ "$1" == *"changed while this apply ran, so no grant is written over it"* && "$1" == *"--what 5.26.commitorgs --mode apply"* && "$1" != *"• allowed orgs"* && "$1" == *"rc=1"* && "$(cat "$2")" == "{\"orgs\":{\"ehmpathy\":\"blocked\"}}" && -z "$(ls "$(dirname "$2")" | grep "\.tmp\.")" ]]' _ "$out" "$H/$METER_REL"

H="$FIX/u-dir"; mkdir -p "$H"
meter_put home="$H" kind=dir
out="$(phase home="$H" server="$HZ" seat=camper phase=configure_upsert)"; snap "upsert · hetzner, a directory at the meter path" "$out"
claim "3p. a directory at the meter path: ✋ names ls -ld, never the cat/rm fix, rc=1, the path untouched" bash -c '[[ "$1" == *"holds no readable file"* && "$1" == *"read why: ls -ld "* && "$1" != *"rm "* && "$1" == *"rc=1"* && -d "$2" ]]' _ "$out" "$H/$METER_REL"

######################################################################
# row 4 — configure.verify
######################################################################
out="$(phase home="$FIX/u-absent" server="$HZ" seat=camper phase=configure_verify)"; snap "verify · hetzner, every token org allowed, no crew yet" "$out"
claim "4a. granted: names the token's orgs, ✔ each, no crew yet, rc=0" bash -c '[[ "$1" == *"can push to orgs '"'"'acme'"'"', '"'"'ahbode'"'"', '"'"'ehmpathy'"'"'"* && "$1" == *"allows org '"'"'acme'"'"'"* && "$1" == *"allows org '"'"'ehmpathy'"'"'"* && "$1" == *"no crew tree lives on camper@box-7 yet"* && "$1" != *"belongs to an org"* && "$1" == *"rc=0"* ]]' _ "$out"

H="$FIX/v-absent"; mkdir -p "$H"
out="$(phase home="$H" server="$HZ" seat=camper phase=configure_verify)"; snap "verify · hetzner, no meter yet" "$out"
claim "4b. unset: one ✋ ConstraintError names each org on its seat and the apply that allows it, never a grant, rc=1, writes no meter" bash -c '[[ "$1" == *"✋ ConstraintError: the commit gate finds no grant for orgs '"'"'acme'"'"', '"'"'ahbode'"'"', '"'"'ehmpathy'"'"' on camper@box-7"* && "$(grep -c ConstraintError <<< "$1")" -eq 1 && "$1" == *"fix: rhx grove.provision --what 5.26.commitorgs --mode apply"* && "$1" != *"git.commit.uses --org"* && "$1" == *"rc=1"* && ! -e "$2/$3" ]]' _ "$out" "$H" "$METER_REL"

out="$(phase home="$FIX/u-block" server="$HZ" seat=camper phase=configure_verify)"; snap "verify · hetzner, ehmpathy blocked by the human" "$out"
claim "4c. a block: a 🌙 that keeps it, the rest ✔, rc=0" bash -c '[[ "$1" == *"🌙 org '"'"'ehmpathy'"'"' is blocked"* && "$1" == *"allows org '"'"'ahbode'"'"'"* && "$1" == *"rc=0"* ]]' _ "$out"

out="$(phase home="$FIX/u-damaged" server="$HZ" seat=camper phase=configure_verify)"; snap "verify · hetzner, a damaged meter" "$out"
claim "4d. a damaged meter: ✋ with the read, the clear, the apply, the re-block, never an unset verdict, rc=1" bash -c '[[ "$1" == *"is damaged, so the commit gate refuses orgs '"'"'acme'"'"', '"'"'ahbode'"'"', '"'"'ehmpathy'"'"'"* && "$1" == *"1. read it first"* && "$1" == *"2. then clear it"*"rm "* && "$1" == *"4. then set each block"* && "$1" != *"finds no grant"* && "$1" == *"rc=1"* ]]' _ "$out"

# one damaged leaf in a meter that parses: the gate refuses that org alone, so the verdict names it alone
H="$FIX/v-leaf"; mkdir -p "$H"
meter_put home="$H" kind=bytes bytes='{"orgs":{"acme":"allowed","ahbode":["allowed"],"ehmpathy":"allowed"}}'
out="$(phase home="$H" server="$HZ" seat=camper phase=configure_verify)"; snap "verify · hetzner, one damaged leaf" "$out"
claim "4w. one damaged leaf: the ✋ names that org alone, the rest ✔, rc=1" bash -c '[[ "$1" == *"is damaged, so the commit gate refuses org '"'"'ahbode'"'"'"* && "$1" != *"refuses orgs"* &&"$1" == *"allows org '"'"'acme'"'"'"* && "$1" == *"allows org '"'"'ehmpathy'"'"'"* && "$1" == *"rc=1"* ]]' _ "$out"
gv="$(gate_verdicts home="$H" orgs="$ORGS3")"
claim "4w. and the real gate agrees: acme and ehmpathy allowed, ahbode alone corrupt" [ "$gv" == "acme=allow ahbode=corrupt ehmpathy=allow" ]

out="$(GH_STUB_MODE=fail phase home="$FIX/u-absent" server="$HZ" seat=camper phase=configure_verify)"; snap "verify · hetzner, the token cannot be read" "$out"
claim "4e. an unread token: ✋ names 5.4.gh, rc=1" bash -c '[[ "$1" == *"could not be read"* && "$1" == *"--what 5.4.gh"* && "$1" == *"rc=1"* ]]' _ "$out"

out="$(GH_STUB_MODE=none phase home="$FIX/u-absent" server="$HZ" seat=camper phase=configure_verify)"; snap "verify · hetzner, a token that can push to no org" "$out"
claim "4f. a token with no push org: ✋ names where the scope is set, rc=1" bash -c '[[ "$1" == *"can push to no org, so no crew here can ship"* && "$1" == *"git.grove.auth.github.set"* && "$1" == *"rc=1"* ]]' _ "$out"

H="$FIX/v-crews"; mkdir -p "$H"; cp -r "$FIX/u-absent/.rhachet" "$H/"
crew_tree home="$H" owner=ahbode tree=svc-a
crew_tree home="$H" owner=acme tree=svc-x org=acme
crew_tree home="$H" owner=otherorg tree=svc-w
out="$(phase home="$H" server="$HZ" seat=camper phase=configure_verify)"; snap "verify · hetzner, a crew of an org the token cannot push to" "$out"
claim "4g. a crew outside the token's reach: one ✋ names the org and its tree, rc=1; acme's crew passes" bash -c '[[ "$1" == *"crews of org '"'"'otherorg'"'"' live on camper@box-7, and the token cannot push to them"* && "$1" == *"otherorg: svc-w"* && "$1" != *"acme: svc-x"* && "$(grep -c ConstraintError <<< "$1")" -eq 1 && "$1" == *"rc=1"* ]]' _ "$out"

# the gate keys on the MANIFEST's org, never the owner dir: two trees whose dir and org disagree
HM="$FIX/v-manifest"; mkdir -p "$HM"; cp -r "$FIX/u-absent/.rhachet" "$HM/"
crew_tree home="$HM" owner=ahbode tree=svc-m org=otherorg
crew_tree home="$HM" owner=otherorg tree=svc-n org=ahbode
out="$(phase home="$HM" server="$HZ" seat=camper phase=configure_verify)"; snap "verify · hetzner, crew trees whose dir and manifest name different orgs" "$out"
claim "4v. the manifest's org decides, never the owner dir: the tree under ahbode/ that names otherorg is flagged, the one under otherorg/ that names ahbode passes" bash -c '[[ "$1" == *"crews of org '"'"'otherorg'"'"' live on"* && "$1" == *"otherorg: svc-m"* && "$1" != *"svc-n"* && "$1" == *"rc=1"* ]]' _ "$out"
rm -rf "$H/git/otherorg"
out="$(phase home="$H" server="$HZ" seat=camper phase=configure_verify)"; snap "verify · hetzner, every crew within the token's reach" "$out"
claim "4h. every crew within reach: ✔, rc=0" bash -c '[[ "$1" == *"belongs to an org the token can push to ✔"* && "$1" == *"rc=0"* ]]' _ "$out"
mkdir -p "$H/git/ahbode/_worktrees/svc-bare/.agent"; printf 'env.prep:\n  - KEY\n' > "$H/git/ahbode/_worktrees/svc-bare/.agent/keyrack.yml"
out="$(phase home="$H" server="$HZ" seat=camper phase=configure_verify)"; snap "verify · hetzner, a crew tree whose keyrack names no org" "$out"
claim "4i. a tree whose keyrack names no org: a 🌙 names it and why no grant helps, never ✋; the ✔ counts only trees with an org, rc=0" bash -c '[[ "$1" == *"🌙 crew trees on camper@box-7 whose keyrack names no org, so no meter grant helps them: svc-bare"* && "$1" == *"every crew tree with an org on camper@box-7 belongs to an org the token can push to ✔"* && "$1" != *"ConstraintError"* && "$1" == *"rc=0"* ]]' _ "$out"
H="$FIX/v-orgless"; mkdir -p "$H/git/ahbode/_worktrees/svc-bare/.agent"; cp -r "$FIX/u-absent/.rhachet" "$H/"
printf 'env.prep:\n  - KEY\n' > "$H/git/ahbode/_worktrees/svc-bare/.agent/keyrack.yml"
out="$(phase home="$H" server="$HZ" seat=camper phase=configure_verify)"; snap "verify · hetzner, only crew trees whose keyrack names no org" "$out"
claim "4t. only orgless trees: a 🌙 names them, and no ✔ over zero graded trees, rc=0" bash -c '[[ "$1" == *"svc-bare"* && "$1" == *"no crew tree on camper@box-7 names an org — none to grade"* && "$1" != *"belongs to an org the token can push to ✔"* && "$1" == *"rc=0"* ]]' _ "$out"

H="$FIX/v-nojq"; mkdir -p "$H"; cp -r "$FIX/u-absent/.rhachet" "$H/"
out="$(JQ_MODE=absent phase home="$H" server="$HZ" seat=camper phase=configure_verify)"; snap "verify · hetzner, jq absent, a healthy meter" "$out"
claim "4s. jq absent over a healthy meter: names the absent tool, never a damaged meter, rc=1" bash -c '[[ "$1" == *"jq is absent on camper@box-7"* && "$1" == *"--what 5.26.commitorgs --mode apply"* && "$1" != *"damaged"* && "$1" != *"rm "* && "$1" == *"rc=1"* ]]' _ "$out"

out="$(phase home="$FIX/u-dir" server="$HZ" seat=camper phase=configure_verify)"; snap "verify · hetzner, a directory at the meter path" "$out"
claim "4u. a directory at the meter path: ✋ names ls -ld, never the cat/rm fix, rc=1" bash -c '[[ "$1" == *"holds no readable file"* && "$1" == *"read why: ls -ld "* && "$1" != *"rm "* && "$1" == *"rc=1"* ]]' _ "$out"

out="$(phase home="$FIX/u-allallow" server="$HZ" seat=camper phase=configure_verify)"; snap "verify · hetzner, @all allowed by the human" "$out"
claim "4j. an @all allow: ✔ each org, said (via @all), rc=0" bash -c '[[ "$1" == *"allows org '"'"'ahbode'"'"' on camper@box-7 ✔ (via @all)"* && "$1" == *"rc=0"* ]]' _ "$out"

out="$(READ_FAIL=1 phase home="$FIX/u-rfail" server="$HZ" seat=camper phase=configure_verify)"; snap "verify · hetzner, a present meter whose read fails" "$out"
claim "4k. a present meter whose read fails: 💥 with ls -l, no verdict drawn from the failed read, rc=1" bash -c '[[ "$1" == *"💥 MalfunctionError"*"could not be read"* && "$1" == *"read why: ls -l "* && "$1" != *"allows org"* && "$1" != *"finds no grant"* && "$1" != *"damaged"* && "$1" == *"rc=1"* ]]' _ "$out"

out="$(phase home="$FIX/u-allblock" server="$HZ" seat=camper phase=configure_verify)"; snap "verify · hetzner, @all blocked by the human" "$out"
claim "4o. an @all block: a 🌙 per org, said (via @all), no ✋, rc=0" bash -c '[[ "$1" == *"🌙 org '"'"'ahbode'"'"' is blocked on camper@box-7 by the human'"'"'s own word (via @all)"* && "$1" != *"ConstraintError"* && "$1" == *"rc=0"* ]]' _ "$out"

######################################################################
# row 4b — provision.verify: jq is present and parses
######################################################################
H="$FIX/p-jq"; mkdir -p "$H"
out="$(phase home="$H" server="$HZ" seat=camper phase=provision_verify)"; snap "provision verify · hetzner, jq present and parses" "$out"
claim "4l. jq present and parses: ✔, rc=0" bash -c '[[ "$1" == *"jq parses json on this seat ✔"* && "$1" == *"rc=0"* ]]' _ "$out"
out="$(JQ_MODE=absent phase home="$H" server="$HZ" seat=camper phase=provision_verify)"; snap "provision verify · hetzner, jq absent" "$out"
claim "4m. jq absent: ✋ names the apply that installs it, never a damaged meter, rc=1" bash -c '[[ "$1" == *"jq is absent"* && "$1" == *"--what 5.26.commitorgs --mode apply"* && "$1" != *"damaged"* && "$1" == *"rc=1"* ]]' _ "$out"
out="$(JQ_MODE=broken phase home="$H" server="$HZ" seat=camper phase=provision_verify)"; snap "provision verify · hetzner, a jq that parses no json" "$out"
claim "4n. a jq that parses no json: ✋ names the one found and the apply, never 'absent', rc=1" bash -c '[[ "$1" == *"does not parse a json object"* && "$1" == *"found: $2/jq"* && "$1" == *"--what 5.26.commitorgs --mode apply"* && "$1" != *"jq is absent"* && "$1" == *"rc=1"* ]]' _ "$out" "$JQ_BROKEN_DIR"
: > "$FIX/pkg.calls"
out="$(JQ_MODE=absent PKG_STUB=ok phase home="$H" server="$HZ" seat=camper phase=provision_upsert)"; snap "provision upsert · hetzner, jq absent, installed" "$out"
claim "4p. jq absent: the upsert installs it and says so, rc=0" bash -c '[[ "$(cat "$2")" == "pkg_install jq" && "$1" == *"jq installed"* && "$1" == *"rc=0"* ]]' _ "$out" "$FIX/pkg.calls"
: > "$FIX/pkg.calls"
out="$(JQ_MODE=absent PKG_STUB=fail phase home="$H" server="$HZ" seat=camper phase=provision_upsert)"; snap "provision upsert · hetzner, jq absent, its install fails" "$out"
claim "4q. jq absent and its install fails: ✋ names the re-run, rc=1, never a claim it was installed" bash -c '[[ "$(cat "$2")" == "pkg_install jq (failed)" && "$1" == *"jq could not be installed"* && "$1" == *"--what 5.26.commitorgs --mode apply"* && "$1" != *"jq installed"* && "$1" == *"rc=1"* ]]' _ "$out" "$FIX/pkg.calls"
out="$(phase home="$H" server="$HZ" seat=camper phase=provision_upsert)"
claim "4r. jq present: the upsert is silent, rc=0" [ "$out" == "rc=0" ]

######################################################################
# row 5 — declines: no phase acts, and no meter is written
######################################################################
for row in "5a|local@unix|human|a local grove" "5b|local@cicd|runner|a ci runner" "5c|$HZ|ground|the admin seat"; do
  IFS='|' read -r tag server seat label <<< "$row"
  H="$FIX/d-$tag"; mkdir -p "$H"
  up="$(phase home="$H" server="$server" seat="$seat" phase=configure_upsert)"
  ve="$(phase home="$H" server="$server" seat="$seat" phase=configure_verify)"
  pv="$(phase home="$H" server="$server" seat="$seat" phase=provision_verify)"
  : > "$FIX/pkg.calls"
  pu="$(JQ_MODE=absent PKG_STUB=ok phase home="$H" server="$server" seat="$seat" phase=provision_upsert)"
  snap "declines · $label" "$ve"
  claim "$tag. $label: all four phases decline, rc=0, no meter written, no install even with jq absent" bash -c '[[ "$1" == *"🌙 declined"* && "$1" != *"git.commit.uses --org"* && "$1" == *"rc=0"* && "$2" == "rc=0" && "$3" == "rc=0" && "$6" == "rc=0" && ! -s "$7" && ! -e "$4/$5" ]]' _ "$ve" "$up" "$pv" "$H" "$METER_REL" "$pu" "$FIX/pkg.calls"
done

######################################################################
# row 6 — the public entry, blackbox: plan · apply · apply, under a clean env and a fixture HOME
#
# 🛑 rows 2–5 drive the phase functions. this row enters where a human does, so a break in the
#    dispatch (the configure.upsert this bundle adds), the slug, or the env derivation reddens
#    here even where every phase function still answers
######################################################################
# .what = the entry's output plus `rc=<n>`.  args: home= mode=
#         server= and seat= default to the cloud crew seat, where the bundle acts
entry() {
  local home='' mode='' server="$HZ" seat=camper arg
  for arg in "$@"; do
    case "$arg" in
      home=*) home="${arg#home=}" ;; mode=*) mode="${arg#mode=}" ;;
      server=*) server="${arg#server=}" ;; seat=*) seat="${arg#seat=}" ;;
    esac
  done
  # .carve-out = the driver by path, not `rhx grove.provision`. trigger: `env -i` with a PATH of
  #   the stub dir + /usr/bin + /bin holds no `rhx`, and only that clean env pins the fixture HOME,
  #   the cloud server, the seat, and the gh stub — the outer skill would read the laptop's own
  env -i HOME="$home" PATH="$STUB:/usr/bin:/bin" GROVE_ENV_SERVER="$server" GROVE_ENV_SEAT="$seat" \
    GH_STUB_MODE="${GH_STUB_MODE:-orgs}" \
    timeout -k 5 300 bash "$ROOT/src/grove.provision._.sh" --what 5.26.commitorgs --mode "$mode" --org ahbode </dev/null 2>&1
  echo "rc=$?"
}
# .what = snap one entry render, its checkout's commit masked.  args: label, then the text
entry_snap() {
  snap "$1" "$(printf '%s\n' "$2" | sed -E 's/· commit [^ ]+/· commit <commit>/')"
}
H="$FIX/entry"; mkdir -p "$H"
out="$(entry home="$H" mode=plan)"; entry_snap "public entry · plan, a fresh seat" "$out"
claim "6a. plan, a fresh seat: names the three orgs owed and the apply, rc=1, writes no meter" bash -c '[[ "$1" == *"5.26.commitorgs.configure.verify"* && "$1" == *"finds no grant for orgs '"'"'acme'"'"', '"'"'ahbode'"'"', '"'"'ehmpathy'"'"'"* && "$1" == *"rc=1"* && ! -e "$2/$3" ]]' _ "$out" "$H" "$METER_REL"
out="$(entry home="$H" mode=apply)"; entry_snap "public entry · apply, a fresh seat" "$out"
claim "6b. apply: allows the three, rc=0, and the real gate agrees" bash -c '[[ "$1" == *"allowed orgs '"'"'acme'"'"', '"'"'ahbode'"'"', '"'"'ehmpathy'"'"'"* && "$1" == *"rc=0"* && "$2" == "acme=allow ahbode=allow ehmpathy=allow" ]]' _ "$out" "$(gate_verdicts home="$H" orgs="$ORGS3")"
before="$(cat "$H/$METER_REL")"
out="$(entry home="$H" mode=apply)"; entry_snap "public entry · apply again, converged" "$out"
claim "6c. apply again: converged, no write, rc=0" bash -c '[[ "$1" != *"allowed orgs"* && "$1" == *"rc=0"* && "$2" == "$(cat "$3")" ]]' _ "$out" "$before" "$H/$METER_REL"
out="$(entry home="$H" mode=plan)"; entry_snap "public entry · plan, a granted seat" "$out"
claim "6f. plan on a granted seat: ✔ each org, rc=0, no write" bash -c '[[ "$1" == *"allows org '"'"'acme'"'"'"* && "$1" != *"ConstraintError"* && "$1" == *"rc=0"* && "$2" == "$(cat "$3")" ]]' _ "$out" "$before" "$H/$METER_REL"

for row in "6g|local@unix|human|a local grove" "6h|$HZ|ground|the admin seat"; do
  IFS='|' read -r tag server seat label <<< "$row"
  H="$FIX/entry-$tag"; mkdir -p "$H"
  out="$(entry home="$H" mode=apply server="$server" seat="$seat")"; entry_snap "public entry · apply, $label" "$out"
  claim "$tag. apply on $label: the bundle declines, rc=0, no meter written, and prints no grant a clone could paste" bash -c '[[ "$1" == *"🌙 declined"* && "$1" == *"rc=0"* && "$1" != *"git.commit.uses --org"* && ! -e "$2/$3" ]]' _ "$out" "$H" "$METER_REL"
done

H="$FIX/entry-block"; mkdir -p "$H"
meter_put home="$H" kind=bytes bytes='{"orgs":{"ehmpathy":"blocked"}}'
out="$(entry home="$H" mode=apply)"; entry_snap "public entry · apply, ehmpathy blocked by the human" "$out"
claim "6d. apply over a block: the other two allowed, a 🌙 keeps the block, rc=0" bash -c '[[ "$1" == *"allowed orgs '"'"'acme'"'"', '"'"'ahbode'"'"'"* && "$1" == *"🌙 org '"'"'ehmpathy'"'"' is blocked"* && "$1" == *"rc=0"* && "$(jq -r .orgs.ehmpathy "$2")" == blocked ]]' _ "$out" "$H/$METER_REL"

H="$FIX/entry-damaged"; mkdir -p "$H"
meter_put home="$H" kind=bytes bytes='{"orgs":'
out="$(entry home="$H" mode=apply)"; entry_snap "public entry · apply, a damaged meter" "$out"
claim "6e. apply over a damaged meter: ✋ names the read, the clear, the apply, rc=1, never written over" bash -c '[[ "$1" == *"is damaged, so no grant is written over it"* && "$1" == *"rc=1"* && "$(cat "$2")" == "{\"orgs\":" ]]' _ "$out" "$H/$METER_REL"

H="$FIX/entry-unread"; mkdir -p "$H"
out="$(GH_STUB_MODE=fail entry home="$H" mode=apply)"; entry_snap "public entry · apply, the token cannot be read" "$out"
claim "6i. apply with an unread token: ✋ could not be read, the verify skipped, rc=1, no meter written" bash -c '[[ "$1" == *"could not be read"* && "$1" == *"configure.verify — skipped"* && "$1" == *"rc=1"* && ! -e "$2/$3" ]]' _ "$out" "$H" "$METER_REL"

H="$FIX/entry-nopush"; mkdir -p "$H"
out="$(GH_STUB_MODE=none entry home="$H" mode=apply)"; entry_snap "public entry · apply, a token that can push to no org" "$out"
claim "6j. apply with a token that can push to no org: a 🌙 at the upsert, ✋ at the verify, rc=1, no meter written" bash -c '[[ "$1" == *"🌙"* && "$1" == *"can push to no org"* && "$1" == *"rc=1"* && ! -e "$2/$3" ]]' _ "$out" "$H" "$METER_REL"

H="$FIX/entry-crew"; mkdir -p "$H"
crew_tree home="$H" owner=otherorg tree=svc-w
out="$(entry home="$H" mode=apply)"; entry_snap "public entry · apply, a crew of an org the token cannot push to" "$out"
claim "6k. apply with a crew outside the token's reach: the three allowed, ✋ names the crew's org and tree, rc=1" bash -c '[[ "$1" == *"allowed orgs '"'"'acme'"'"', '"'"'ahbode'"'"', '"'"'ehmpathy'"'"'"* && "$1" == *"crews of org '"'"'otherorg'"'"' live on"* && "$1" == *"otherorg: svc-w"* && "$1" == *"rc=1"* ]]' _ "$out"

# the extant grove's shape: two token orgs already allowed by hand, one unset, a hand-typed key
H="$FIX/entry-extant"; mkdir -p "$H"
meter_put home="$H" kind=bytes bytes='{"orgs":{"ahbode":"allowed","ehmpathy":"allowed","ehmpahty":"allowed"}}'
out="$(entry home="$H" mode=plan)"; entry_snap "public entry · plan, an extant seat with one token org unset" "$out"
claim "6l. plan on an extant seat: ✔ the two allowed, ✋ names the one unset org, rc=1, no write" bash -c '[[ "$1" == *"allows org '"'"'ahbode'"'"'"* && "$1" == *"finds no grant for org '"'"'acme'"'"' on"* && "$1" == *"rc=1"* && "$(jq -c . "$2")" == "{\"orgs\":{\"ahbode\":\"allowed\",\"ehmpathy\":\"allowed\",\"ehmpahty\":\"allowed\"}}" ]]' _ "$out" "$H/$METER_REL"
out="$(entry home="$H" mode=apply)"; entry_snap "public entry · apply, an extant seat with one token org unset" "$out"
claim "6m. apply on an extant seat: allows the one org, every prior key kept, rc=0" bash -c '[[ "$1" == *"• allowed org '"'"'acme'"'"' on"* && "$1" == *"rc=0"* && "$(jq -c . "$2")" == "{\"orgs\":{\"ahbode\":\"allowed\",\"ehmpathy\":\"allowed\",\"ehmpahty\":\"allowed\",\"acme\":\"allowed\"}}" ]]' _ "$out" "$H/$METER_REL"

######################################################################
# row 8 — parity with the real upstream writer, read verb, and org reader
#
# 🛑 rows 1–6 grade the bundle's meter against the real gate. this row grades the bundle's
#    own writer against the pinned `git.commit.uses.sh` that a human's `rhx git.commit.uses`
#    reaches, and the bundle's crew-org read against the gate's `get_org_from_keyrack`, so an
#    upstream shape change reddens here
#
# ⚠️ `__I_AM_HUMAN=true` is the upstream's own door for integration tests (its tty guard names
#    it). every write lands in a throwaway HOME: the writer's contract under test, never a grant
######################################################################
WRITER="${UPSTREAM%/*}/git.commit.uses.sh"
[[ -f "$WRITER" ]] || { echo "   └─ ✋ ConstraintError: the upstream writer is absent: $WRITER" >&2; exit 2; }

# .what = run the real writer as a human would, under a HOME, from a git repo.  args: home= then its args
real_write() {
  local home="${1#home=}"; shift
  mkdir -p "$home/repo"; git -C "$home/repo" init -q 2>/dev/null
  ( cd "$home/repo" && HOME="$home" __I_AM_HUMAN=true timeout -k 5 60 bash "$WRITER" "$@" ) </dev/null >>"$home/write.log" 2>&1
}
# .what = the real read verb's answer under a HOME, plus `rc=<n>`.  args: home=
real_get() {
  local home="${1#home=}"
  mkdir -p "$home/repo"; git -C "$home/repo" init -q 2>/dev/null
  ( cd "$home/repo" && HOME="$home" timeout -k 5 60 bash "$WRITER" get --org ) </dev/null 2>&1
  echo "rc=$?"
}

H_REAL="$FIX/p-real"; mkdir -p "$H_REAL"
for org in $ORGS3; do real_write home="$H_REAL" --org "$org" allow; done
H_OURS="$FIX/p-ours"; mkdir -p "$H_OURS"
phase home="$H_OURS" server="$HZ" seat=camper phase=configure_upsert >/dev/null
claim "8a. the bundle's writer and the real writer, granted the same orgs, write the same meter" \
  bash -c '[[ -f "$1" && -f "$2" && "$(jq -S -c . "$1")" == "$(jq -S -c . "$2")" ]]' _ "$H_REAL/$METER_REL" "$H_OURS/$METER_REL"
[[ "$(jq -S -c . "$H_REAL/$METER_REL" 2>/dev/null)" == "$(jq -S -c . "$H_OURS/$METER_REL" 2>/dev/null)" ]] \
  || { echo "      real: $(cat "$H_REAL/$METER_REL" 2>/dev/null)"; echo "      ours: $(cat "$H_OURS/$METER_REL" 2>/dev/null)"; echo "      the writer said: $(cat "$H_REAL/write.log" 2>/dev/null)"; }

out="$(real_get home="$H_OURS")"; snap "real read verb · a meter the bundle wrote" "$out"
claim "8b. the real read verb reads the bundle's meter: rc=0, names each org" bash -c '[[ "$1" == *"rc=0" && "$1" == *acme* && "$1" == *ahbode* && "$1" == *ehmpathy* ]]' _ "$out"

real_write home="$H_OURS" --org ehmpathy block; rc_b=$?
out="$(phase home="$H_OURS" server="$HZ" seat=camper phase=configure_upsert)"
claim "8c. a block the real writer set over the bundle's meter: the bundle keeps it, the gate refuses it" bash -c '[[ "$1" -eq 0 && "$2" == *"🌙 left org '"'"'ehmpathy'"'"' as is"* && "$2" == *"rc=0" && "$(jq -r .orgs.ehmpathy "$3")" == blocked && "$4" == refuse ]]' _ "$rc_b" "$out" "$H_OURS/$METER_REL" "$(gate_verdict home="$H_OURS" org=ehmpathy)"

# .what = the gate's own org read of one manifest: `org=<value>`, or `org=` where it names none
gate_org_of() {
  local manifest="$1" repo
  repo="$FIX/orgread.$RANDOM$RANDOM"; mkdir -p "$repo/.agent"; git -C "$repo" init -q 2>/dev/null
  cp "$manifest" "$repo/.agent/keyrack.yml"
  ( cd "$repo" || exit 0
    # shellcheck disable=SC1090
    source "$UPSTREAM" >/dev/null 2>&1 || { echo unloaded; exit 0; }
    get_org_from_keyrack >/dev/null 2>&1
    echo "org=$ORG_VALUE" )
}
# .what = the bundle's org read of one manifest, in the same form
ours_org_of() {
  ( # shellcheck disable=SC1091
    source "$ROOT/src/grove.org.sh" >/dev/null 2>&1
    echo "org=$(grove_org_of_manifest "$1")" )
}
j=0
while IFS='|' read -r label body; do
  [[ -n "$label" ]] || continue
  j=$((j + 1)); m="$FIX/manifest.$j.yml"; printf '%b' "$body" > "$m"
  g="$(gate_org_of "$m")"; o="$(ours_org_of "$m")"
  claim "8d. manifest, $label: gate $g, bundle $o" [ "$g" == "$o" ]
done <<'MANIFESTS'
a plain org line|org: ahbode\nenv.prep:\n  - KEY\n
no space after the colon|org:ahbode\n
blanks after the org|org: ahbode   \n
a blank inside the org|org: ah bode\n
an empty first org line, a second below|org:\norg: ahbode\n
no org line|env.prep:\n  - KEY\n
an indented org line|  org: ahbode\n
MANIFESTS

claim "8e. 5.devtools dispatches 5.4.gh before 5.26.commitorgs, so gh is wired before the token read" \
  bash -c 'a="$(grep -n "bundle.upgrade 5.4.gh$" "$1" | cut -d: -f1)"; b="$(grep -n "bundle.upgrade 5.26.commitorgs$" "$1" | cut -d: -f1)"; [[ -n "$a" && -n "$b" && "$a" -lt "$b" ]]' _ "$ROOT/src/grove.provision/5.devtools/_.sh"

######################################################################
# row 7 — every byte a human reads, as one reviewed artifact
######################################################################
# shellcheck source=/dev/null
source "$ROOT/.play/permanent/play.snap.operations.sh"
claim "7.  the rendered transcript matches its snapshot" \
  play_snap_verify dir="$ROOT/.play/permanent/prove.commitorgs-reads-the-meter-as-the-gate.snap" name=transcript actual="$(cat "$TRANSCRIPT")"

echo ""
echo "🌊 $passed held · $failed failed"
[[ "$failed" -eq 0 ]] || exit 1
exit 0
