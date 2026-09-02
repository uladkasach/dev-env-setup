#!/usr/bin/env bash
######################################################################
# .what = snapshot + assertion tests for the brains.auth.* render and
#         classification leaves in src/brains.auth.sh
#
# .why  = brains.auth.* is three commands a human drives directly, with dozens
#         of output variants, and a dotfiles repo has no test harness to catch
#         a drift in any of them. every defect this feature shipped — a lone
#         flag that spun forever, a fold that clobbered prior accounts, a jq
#         parse error that destroyed three live credentials — was found by eye,
#         late, or not at all. a reviewer cannot vibecheck output they never see.
#
#         so this covers the parts that need NO credentials and NO network:
#         the render, the fix-hint map, and the exit-code verdict are all pure
#         functions of their arguments. that is the whole point of how they
#         were decomposed, and it costs one command to check.
#
# usage:
#   rhx brains.auth.test              # run the checks
#   rhx brains.auth.test --resnap     # rewrite the .snap files
#
# .note = TZ is pinned to UTC so `_brains_auth_when` renders the same weekday
#   and clock on every machine. the countdown from `_brains_auth_until` is
#   measured against the real clock, so it can never be snapped literally —
#   it is normalized to `in <rel>` before the diff. all else is compared byte
#   for byte.
# .note = it lives beside the two other brains.auth skills rather than in src/,
#   because src/ holds files that are COPIED to ~/ by sync.devenv — a test does
#   not belong in a human's home dir. as a skill it is also runnable the same
#   way as every other command in this repo: `rhx <name>`.
# .note = tools it needs, beyond bash: jq, and the four below that the clamps
#   lean on — `timeout` + `setsid` (the hang guards and the no-tty probe),
#   `cmp` (the backup-integrity clamp), `stat` (the file-mode clamps). the
#   first three are util-linux/coreutils and are NOT guaranteed on a minimal
#   host, so the preflight below HALTS on an absent one by name. without it, an
#   absent `setsid` turned the whole notty.* section into a wall of
#   `command not found` reds that read as failures of the code under test —
#   the misattributed cause `rule.require.errors-name-the-fix` forbids.
######################################################################

set -uo pipefail

export TZ=UTC

# ⚠️ fail fast, and name the tool. one clear line beats N reds that blame the
#   wrong thing. see the dependency .note above for why each is needed.
for _tool in jq timeout setsid cmp stat; do
  command -v "$_tool" >/dev/null 2>&1 || {
    echo "💥 brains.auth.test needs '${_tool}', which is not on PATH" >&2
    echo "   the suite is hermetic (no network, no credentials) but it does lean on" >&2
    echo "   jq + coreutils + util-linux. install it, then re-run: rhx brains.auth.test" >&2
    exit 1
  }
done
unset _tool

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SNAPS="$SKILL_DIR/brains.auth.test.snap"

# locate + source src/brains.auth.sh, and strip the rhx `--skill` token into ${ARGS[@]}
#
# ⚠️ this file used to carry its OWN copy of that preamble, `--skill` hang-guard and all —
#   a THIRD copy of a guard the shared bootstrap exists to hold once, and its comment had
#   already shortened away from the original. the argument for the copy was that this file
#   takes a flag the proxies do not (`--resnap`), but that conflates two things: the SHARED
#   half is the hang guard, the UNIQUE half is one flag. the shared half is shared now, and
#   the unique half is read below from the args the bootstrap hands back.
#   the copy was worst here of all three: a hang in a test run reads as a slow suite.
# shellcheck disable=SC1091
source "$SKILL_DIR/brains.auth.bootstrap.sh"

ALIASES="$BRAINS_AUTH_SRC"

# the one flag the proxies do not take. read from ${ARGS[@]}, which the bootstrap already
# stripped the --skill token out of.
#
# ⚠️ an unrecognized flag is REFUSED, not ignored — and the prior version ignored it, which is
#   a defect of exactly the kind this file exists to catch. `--resnp` ran in verify mode in
#   silence, so on a seeded checkout the operator believes they re-pinned the baselines while
#   the suite merely re-read them; the baselines they meant to update stay stale and the run
#   looks green. an instrument that quietly drops its own input cannot be trusted to report a
#   dropped input anywhere else. this mirrors `_brains_auth_say_unknown_arg`, the discipline
#   the three production commands already carry (`rule.require.failfast`).
RESNAP=0
for _a in ${ARGS[@]+"${ARGS[@]}"}; do
  case "$_a" in
    --resnap) RESNAP=1 ;;
    *) echo "🐢 bummer dude — unknown arg: $_a (the only flag here is --resnap)" >&2; exit 2 ;;
  esac
done

mkdir -p "$SNAPS"

PASS=0
FAIL=0

# .what = strip the only value that cannot be snapped — the live countdown
# .why  = `in 2h14m` is measured from the real clock, so it differs on every run.
#   the reset INSTANT it counts toward is snapped (via `resets at mon 03:19`),
#   so the information stays pinned; only the volatile view of it is masked.
_normalize() { sed -E 's/in [0-9]+h[0-9]+m/in <rel>/g'; }

# .what = compare an actual output against a stored snapshot ($1=name, $2=actual)
# .why  = one shared assert so every case reports the same way, and a failure
#   prints the diff a human needs rather than merely "did not match"
_SNAP_ASKED=''
_snap() {
  local name="$1" actual="$2"
  # ⚠️ record the name at RUNTIME, not by a scan of this file's source. several callers build
  #   the name from a loop variable (`_snap "help.${_cmd}"`), so a source grep sees a literal
  #   that never appears on disk and reports three healthy baselines as orphans. the roster
  #   below is what the suite ACTUALLY asked for, which is the only honest answer to
  #   "does anyone read this file?". (this runs in the main shell — the PASS/FAIL counters
  #   below prove that, since their totals survive to the report.)
  _SNAP_ASKED="${_SNAP_ASKED}|${name}|"
  # ⚠️ `file` gets its OWN `local`. bash expands every argument of `local` before the
  #   builtin runs, so a `local name="$1" file="$SNAPS/$name.snap"` would expand `$name`
  #   while it is still unbound — which `set -u` turns into a hard exit.
  local file="$SNAPS/$name.snap"
  if (( RESNAP )); then
    printf '%s\n' "$actual" > "$file"
    echo "   ├─ 📸 ${name}"
    return 0
  fi
  if [[ ! -f "$file" ]]; then
    echo "   ├─ ✋ ${name}: no snapshot yet (run with --resnap)"
    (( FAIL++ ))
    return 1
  fi
  if diff -u "$file" <(printf '%s\n' "$actual") > /dev/null; then
    echo "   ├─ ✓ ${name}"
    (( PASS++ ))
    return 0
  fi
  echo "   ├─ 💥 ${name}"
  diff -u "$file" <(printf '%s\n' "$actual") | sed 's/^/   │  /'
  (( FAIL++ ))
  return 1
}

# .what = assert an exact exit code ($1=name, $2=expected, $3=actual)
# .why  = the exit code is a contract for cron/statusline callers that never
#   read the tree, so it is asserted directly rather than inferred from output
_code() {
  local name="$1" want="$2" got="$3"
  if [[ "$want" == "$got" ]]; then
    echo "   ├─ ✓ ${name} (exit ${got})"
    (( PASS++ ))
  else
    echo "   ├─ 💥 ${name}: expected exit ${want}, got ${got}"
    (( FAIL++ ))
  fi
}

echo ""
echo "🧪 brains.auth — render + classification"

# ---------------------------------------------------------------- fixtures
# fixed timestamps, so the rendered weekday + clock are identical everywhere.
FIXTURE_HEALTHY='{
  "surfer@ehmpath.com": {
    "five_hour": { "utilization": 58.0, "resets_at": "2026-06-15T09:00:00+00:00" },
    "seven_day": { "utilization": 31.0, "resets_at": "2026-06-19T17:00:00+00:00" }
  }
}'

FIXTURE_OPUS='{
  "surfer@ehmpath.com": {
    "five_hour": { "utilization": 91.0, "resets_at": "2026-06-15T09:00:00+00:00" },
    "seven_day": { "utilization": 64.0, "resets_at": "2026-06-19T17:00:00+00:00" },
    "seven_day_opus": { "utilization": 40.0, "resets_at": null }
  }
}'

FIXTURE_MIXED='{
  "kai@ehmpath.com": { "error": "refresh_rejected" },
  "surfer@ehmpath.com": {
    "five_hour": { "utilization": 3.0, "resets_at": "2026-06-15T09:00:00+00:00" },
    "seven_day": { "utilization": 9.0, "resets_at": "2026-06-19T17:00:00+00:00" }
  }
}'

FIXTURE_ALL_DEAD='{
  "kai@ehmpath.com": { "error": "refresh_rejected" },
  "moana@ehmpath.com": { "error": "no_token" }
}'

FIXTURE_ALL_BROKEN='{
  "kai@ehmpath.com": { "error": "refresh_rejected" },
  "moana@ehmpath.com": { "error": "rate_limited" }
}'

# ---------------------------------------------------------------- the render
_snap 'render.healthy' \
  "$(_brains_auth_render "$FIXTURE_HEALTHY" | _normalize)"

# the "← signed in" mark is a claim of fact, so which row carries it is snapped
_snap 'render.signed-in-mark' \
  "$(_brains_auth_render "$FIXTURE_HEALTHY" 'surfer@ehmpath.com' | _normalize)"

_snap 'render.opus-row' \
  "$(_brains_auth_render "$FIXTURE_OPUS" | _normalize)"

# a failed account must NOT abort the sweep — the healthy rows still render
_snap 'render.partial-failure' \
  "$(_brains_auth_render "$FIXTURE_MIXED" | _normalize)"

_snap 'render.all-failed' \
  "$(_brains_auth_render "$FIXTURE_ALL_DEAD" | _normalize)"

# ---------------------------------------------------------------- the hints
# every error code the code can emit gets its remediation snapped, so a new
# code added with no hint shows up as an unreviewed `💥 <raw_code>` line.
# ⚠️ the last two are the codes NO account node can ever carry — they are raised on the
#   orchestrator's own early returns, so no fold hands them to the table and the table's
#   clamp could not see them. `no_subscriptions` had no entry at all as a result, which meant
#   its documented exit 2 rested on a hand-typed `return 2` while the table would have said 1.
#   an error code the table cannot see is an exit code with two sources of truth.
_ERRORS=(
  no_token token_expired needs_reauth refresh_rejected refresh_server_error
  refresh_rate_limited
  no_access_token refresh_curl_failed api_key_not_oauth
  keyrack_absent keyrack_unreadable
  active_token_expired active_creds_unreadable active_identity_unknown
  active_identity_unverified curl_failed rate_limited unexpected_shape
  usage_server_error usage_rejected
  parse_failure some_code_we_never_declared
  no_subscriptions keyrack_list_failed
)
_hints=''
for e in "${_ERRORS[@]}"; do
  _hints+="${e} -> $(_brains_auth_fix_for_error "$e")"$'\n'
done
_snap 'hints.every-error-code' "${_hints%$'\n'}"


# ---------------------------------------------------------------- the verdict
_brains_auth_exit_for "$FIXTURE_HEALTHY"    >/dev/null; _code 'verdict.all-healthy'   0 "$?"
_brains_auth_exit_for "$FIXTURE_MIXED"      >/dev/null; _code 'verdict.partial'       0 "$?"
_brains_auth_exit_for "$FIXTURE_ALL_DEAD"   >/dev/null; _code 'verdict.all-caller'    2 "$?"
_brains_auth_exit_for "$FIXTURE_ALL_BROKEN" >/dev/null; _code 'verdict.any-our-fault' 1 "$?"
_brains_auth_exit_for 'not json at all'     >/dev/null; _code 'verdict.unreadable'    1 "$?"

# ---------------------------------------------------------------- the gauge
# the bar is utf-8 block glyphs; a byte-wise transform would corrupt them into
# `�`, so the exact glyph output is pinned at each boundary.
_bars=''
for p in 0 3 50 99 100 150; do
  _bars+="$(printf '%3s%% -> %s' "$p" "$(_brains_auth_bar "$p")")"$'\n'
done
_snap 'bar.boundaries' "${_bars%$'\n'}"

# ---------------------------------------------------------------- the identity split
# the wire format `<uuid>\t<email>` is known ONLY to these two accessors, so
# they are pinned: a change to the packed shape must break here, loudly.
_snap 'identity.accessors' \
  "uuid -> $(_brains_auth_uuid_of_who "abc-123"$'\t'"kai@ehmpath.com")
email -> $(_brains_auth_email_of_who "abc-123"$'\t'"kai@ehmpath.com")"

# ---------------------------------------------------------------- the reach shape
# one validator now serves all three commands, so its verdicts are pinned here.
# `@all` is NOT a reach — the callers that accept it test for it separately, and a
# validator that quietly blessed it would let `--reach @all` through on `use`, where
# a swap to "every account" names no account at all.
_reaches=''
for r in 'kai@ehmpath.com' 'a.b+c@sub.domain.co' '@all' 'kai' 'kai@ehmpath' \
         'kai @ehmpath.com' 'kai@@ehmpath.com' ''; do
  if _brains_auth_is_reach "$r"; then _reaches+="ok   '${r}'"$'\n'
  else _reaches+="no   '${r}'"$'\n'; fi
done
_snap 'reach.shape' "${_reaches%$'\n'}"

# ---------------------------------------------------------------- the swap path
# these are the highest-blast-radius leaves in the namespace — they overwrite the one file
# that backs every live claude session. they are also, happily, hermetic: the target path is
# read from `$_BRAINS_AUTH_LIVE_CREDS`, a variable, so the whole park/install pair can be
# pointed at a temp dir and never touches a real ~/.claude.
#
# ⚠️ the override MUST be in place before any of these run. a leak of the real path here
#   would rewrite the human's live credentials from a test — so the dir is made first, the
#   variable is pointed at it, and every case below builds its own fixture inside it.
_SWAPDIR="$(mktemp -d)"
trap 'rm -rf "$_SWAPDIR"' EXIT
# ⚠️ BOTH live-file paths are redirected here, together, before ANY case runs. they were once
#   redirected in two different places — creds here, profile 270 lines below, beside the first
#   case that read it — and the profile cases that ran in between wrote their fixtures to the
#   human's REAL ~/.claude.json, one of them the literal string `not json at all`. a redirect
#   parted from its twin is a redirect a later section can be added above.
_BRAINS_AUTH_LIVE_CREDS="$_SWAPDIR/.credentials.json"
_BRAINS_AUTH_LIVE_PROFILE="$_SWAPDIR/.claude.json"

# ⚠️ and the redirect is VERIFIED, not merely written. every case below writes fixtures — some
#   deliberately corrupt — through these two variables, so a path that still points into $HOME
#   destroys the human's live claude config. the comment above used to be the only guard, and a
#   comment cannot fail a run. this can.
for _p in "$_BRAINS_AUTH_LIVE_CREDS" "$_BRAINS_AUTH_LIVE_PROFILE"; do
  case "$_p" in
    "$_SWAPDIR"/*) ;;
    *) echo "💥 halt: '$_p' is not inside the temp dir — a case would clobber a real file" >&2
       exit 1 ;;
  esac
done

_ORT='sk-ant-ort01-parked-token-fixture'
_OAT='sk-ant-oat01-access-token-fixture'

# the identity wire format is `<uuid>\t<email>`, so a fixture that builds one needs a literal
# tab. it is named here because the `eval`-built overrides below cannot carry a `$'\t'` escape
# through the quoting intact.
_TAB=$'\t'

# .what = assert two strings match ($1=name, $2=expected, $3=actual)
# .why  = the swap cases assert small exact values (a token, a mode, a key), where a full
#   snapshot file would carry more ceremony than signal
_is() {
  local name="$1" want="$2" got="$3"
  if [[ "$want" == "$got" ]]; then
    echo "   ├─ ✓ ${name}"
    (( PASS++ ))
  else
    echo "   ├─ 💥 ${name}: expected '${want}', got '${got}'"
    (( FAIL++ ))
  fi
}

# an absent creds file is a KNOWN answer (nobody signed in), not a failed read
rm -f "$_BRAINS_AUTH_LIVE_CREDS"
_out="$(_brains_auth_park_read)"; _rc=$?
_is 'park.absent-file.rc'  '0'  "$_rc"
_is 'park.absent-file.out' ''   "$_out"

# a shape we do not recognize must FAIL LOUD. the caller is about to overwrite the only copy
# of this token, so a silent empty return here is how an account loses its last credential.
printf '%s' '{"claudeAiOauth":{"refreshToken":"'"$_OAT"'"}}' > "$_BRAINS_AUTH_LIVE_CREDS"
_brains_auth_park_read >/dev/null 2>&1
_is 'park.wrong-shape.rc' '1' "$?"

# the good path hands back the durable token, untouched
printf '%s' '{"claudeAiOauth":{"refreshToken":"'"$_ORT"'"},"someClaudeKey":"keep-me"}' \
  > "$_BRAINS_AUTH_LIVE_CREDS"
_is 'park.good.out' "$_ORT" "$(_brains_auth_park_read)"

# ---- the install half
# the prior file (above) is the one this swap replaces, so both invariants are observable:
# the foreign key must survive, and a .bak of the PRIOR content must be left behind.
rm -f "${_BRAINS_AUTH_LIVE_CREDS}.bak"
_brains_auth_install_creds 'kai@ehmpathy.com' "$_OAT" "$_ORT" 3600 'user:inference user:profile' 'max'
_is 'install.rc' '0' "$?"

# a key claude keeps beside .claudeAiOauth must survive the swap — we replace one block of
# that file, not the file
_is 'install.keeps-foreign-key' 'keep-me' \
  "$(jq -r '.someClaudeKey' < "$_BRAINS_AUTH_LIVE_CREDS")"

# the .bak is the restore point the failure messages promise; it must hold the PRIOR token
_is 'install.bak-holds-prior' "$_ORT" \
  "$(jq -r '.claudeAiOauth.refreshToken' < "${_BRAINS_AUTH_LIVE_CREDS}.bak")"

# the file is a secret at rest — the atomic rename must not widen it past the owner
_is 'install.mode-is-0600' '600' \
  "$(stat -c '%a' "$_BRAINS_AUTH_LIVE_CREDS")"

# the written block is pinned whole. `expiresAt` is now+ttl, so it is masked; every other
# field is compared byte for byte, because claude reads each one of them by name.
_snap 'install.payload' \
  "$(jq -S '.claudeAiOauth | .expiresAt = "<exp>"' < "$_BRAINS_AUTH_LIVE_CREDS")"

# an absent prior file is a valid start state (a first-ever login), not a hard failure
rm -f "$_BRAINS_AUTH_LIVE_CREDS" "${_BRAINS_AUTH_LIVE_CREDS}.bak"
_brains_auth_install_creds 'kai@ehmpathy.com' "$_OAT" "$_ORT" 3600 '' 'pro' >/dev/null 2>&1
_is 'install.from-absent.rc' '0' "$?"
# with no scopes supplied the default pair is written, never an empty list
_is 'install.default-scopes' 'user:inference user:profile' \
  "$(jq -r '.claudeAiOauth.scopes | join(" ")' < "$_BRAINS_AUTH_LIVE_CREDS")"

# ---- the token sniff used by `brains.auth.set`
# it must pick the DURABLE token out of a dir that also holds an access token
_AUTHDIR="$_SWAPDIR/isolated"
mkdir -p "$_AUTHDIR"
printf '%s' '{"claudeAiOauth":{"accessToken":"'"$_OAT"'","refreshToken":"'"$_ORT"'"}}' \
  > "$_AUTHDIR/.credentials.json"
_is 'extract.picks-refresh-not-access' "$_ORT" "$(_brains_auth_extract_refresh "$_AUTHDIR")"
_is 'extract.empty-dir' '' "$(_brains_auth_extract_refresh "$_SWAPDIR/nope")"

# ---------------------------------------------------------------- the fold
# ⚠️ this fold lost data once: one account's jq failure emitted empty stdout, and a straight
#   assign of that to `$combined` wiped every account gathered before it. the fix captures
#   into `$folded` first and re-folds a `parse_failure` into the INTACT prior object.
#   that fix had no clamp until now, which is the exact gap `rule.require.clamp-edge-cases`
#   names — and this is the one function in the namespace with a history of SILENT data loss,
#   so a regression here would not announce itself.
#
# the seam is a shell function, so the leaf is redefined rather than mocked at a boundary:
# `_brains_auth_node_for_reach` is what the fold calls, so a version that emits garbage for
# one reach reproduces the original defect precisely.
# ⚠️ the override is REQUIRED for hermeticity, not merely for the fixture. the real
#   `_brains_auth_node_for_reach` reaches the keyrack, so a fold case that skipped the
#   override would hit the human's live credential store from a test — which one draft of
#   this file did, and it announced itself as keyrack noise in the run output.
_fold_with_nodes() {
  # $1 = the reach whose node should be INVALID json (empty = every node valid)
  # $2 = the newline-delimited reach list to fold over
  local bad="$1" reaches="$2"
  # a subshell, so the override cannot leak into the cases that follow
  (
    eval "_brains_auth_node_for_reach() {
      [[ -n '$bad' ]] && [[ \"\$2\" == '$bad' ]] && { printf '%s' 'not json at all'; return; }
      printf '{\"five_hour\":{\"utilization\":10}}'
    }"
    _brains_auth_gather 'ua' "$reaches"
  )
}
# the middle account emits INVALID json — the shape that made jq fail and stdout empty
_fold_out="$(_fold_with_nodes 'moana@x.com' "$(printf 'kai@x.com\nmoana@x.com\nsurfer@x.com\n')")"

# the accounts BEFORE the bad node must survive it — that is the whole defect
_is 'fold.keeps-prior-accounts' '3' "$(jq -r 'length' <<< "$_fold_out" 2>/dev/null)"
_is 'fold.first-account-survives'  '10' "$(jq -r '."kai@x.com".five_hour.utilization' <<< "$_fold_out" 2>/dev/null)"
# and the accounts AFTER it must still be gathered — the fold continues, never aborts
_is 'fold.later-account-gathered' '10' "$(jq -r '."surfer@x.com".five_hour.utilization' <<< "$_fold_out" 2>/dev/null)"
# the bad one is reported as a failure, never silently dropped (rule.forbid.failhide)
_is 'fold.bad-node-is-named' 'parse_failure' "$(jq -r '."moana@x.com".error' <<< "$_fold_out" 2>/dev/null)"

# a blank line in the reach list is skipped, not folded as an empty-string account
_is 'fold.skips-blank-lines' '1' \
  "$(_fold_with_nodes '' "$(printf '\nkai@x.com\n\n')" | jq -r 'length' 2>/dev/null)"

# ---------------------------------------------------------------- the cold start
# a brand-new machine with no key stored yet is the most common first-run path, and both of
# its declared outcomes were dark. `_brains_auth_reaches` is a function, so it is the seam.
_usage_with_reaches() {
  # $1 = the body to give _brains_auth_reaches; $2... = args to _brains_auth_usage
  local body="$1"; shift
  (
    eval "_brains_auth_reaches() { $body; }"
    _brains_auth_usage "$@"
  )
}

_snap 'coldstart.no-subscriptions.tree'  "$(_usage_with_reaches 'return 0' 2>&1)"
_usage_with_reaches 'return 0' >/dev/null 2>&1
_code 'coldstart.no-subscriptions.exit' 2 "$?"

# the --json contract must hold on a GLOBAL failure too — a caller that pipes to jq must never
# be handed bare prose on the one path where it most needs a parseable answer
_snap 'coldstart.no-subscriptions.json' "$(_usage_with_reaches 'return 0' --json 2>&1)"

_snap 'coldstart.keyrack-failed.json' "$(_usage_with_reaches 'return 1' --json 2>&1)"
_usage_with_reaches 'return 1' --json >/dev/null 2>&1
_code 'coldstart.keyrack-failed.exit' 1 "$?"

# ---------------------------------------------------------------- the @all union
# a plain `claude /login` account that was never `brains.auth.set` still belongs in an @all
# sweep — it is exactly the account whose remaining budget you most want to see, and the
# keyrack enumeration alone omits it.
#
# `_brains_auth_has_reach` was unit-clamped in isolation and the coldstart cases cover the
# empty-stored/empty-active corner, but the COMPOSED promise was dark: no case ever put one
# stored reach beside a DIFFERENT live one and asserted two rows come back. that gap matters
# because its regression is silent — the account simply does not appear, with no error to
# read, so a human concludes the login is fine and it merely has no budget row.
_usage_union() {
  # $1 = the reach list _brains_auth_reaches emits; $2 = the live account; $3 = its arc
  # $4... = args to _brains_auth_usage. every node is stubbed, so no network, no keyrack.
  local stored="$1" live="$2" arc="$3"; shift 3
  (
    eval "_brains_auth_reaches()        { printf '%s' '$stored'; return 0; }"
    eval "_brains_auth_active_reach()   { printf '%s' '$live'; return $arc; }"
    eval "_brains_auth_node_for_reach() { jq -n '{five_hour:{utilization:1}}'; }"
    _brains_auth_usage "$@" 2>/dev/null
  )
}

# a stored account plus a DIFFERENT verified live account = two rows, not one
_is 'union.active-joins-all' 'kai@x.com moana@x.com' \
  "$(_usage_union 'kai@x.com' 'moana@x.com' 0 --json | jq -r 'keys | join(" ")' 2>/dev/null)"

# the live account already in the keyrack must not be unioned in twice — the membership test
# is exact-match, so a near-miss reach can neither absorb nor duplicate a stored one
_is 'union.no-duplicate-when-stored' 'kai@x.com' \
  "$(_usage_union 'kai@x.com' 'kai@x.com' 0 --json | jq -r 'keys | join(" ")' 2>/dev/null)"

# a NARROWED read is not a sweep: `--reach kai` asks about kai, so the live account is not
# invited in. a union here would answer a question the human did not ask.
_is 'union.narrowed-read-stays-narrow' 'kai@x.com' \
  "$(_usage_union 'kai@x.com' 'moana@x.com' 0 --json --reach kai@x.com \
     | jq -r 'keys | join(" ")' 2>/dev/null)"

# an UNVERIFIED live name may not be unioned in. it comes from a record that can lag the live
# token, so it would invent a row for an account that is not signed in — and this path is
# reachable when no creds file exists, where the up-front identity refusal does not fire.
_is 'union.unverified-stays-out' 'kai@x.com' \
  "$(rm -f "$_BRAINS_AUTH_LIVE_CREDS"; _usage_union 'kai@x.com' 'moana@x.com' 2 --json \
     | jq -r 'keys | join(" ")' 2>/dev/null)"

# ---- the sweep-count invariant: N reaches in -> N rows out, none silently dropped
# ⚠️ every mechanism below this promise is unit-covered — the fold keeps prior accounts, a bad
#   node is named rather than dropped, blank lines are skipped, the union adds at most one —
#   but the COMPOSED promise had no assertion of its own. that gap matters because a lost row
#   is this feature's signature silent failure: no error, one fewer line, and a human who
#   concludes an account has no budget stored and re-auths a token that was fine.
#   so this asserts the arithmetic end to end, at a size where an off-by-one cannot hide.
_five=$'a@x.com\nb@x.com\nc@x.com\nd@x.com\ne@x.com'
_is 'sweep.five-in-five-out' '5' \
  "$(_usage_union "$_five" 'a@x.com' 0 --json | jq -r 'length' 2>/dev/null)"

# and with a live account that is NOT among them, the count is N+1 — never N, never N+2
_is 'sweep.union-adds-exactly-one' '6' \
  "$(_usage_union "$_five" 'zz@x.com' 0 --json | jq -r 'length' 2>/dev/null)"

# every reach that went in comes back out under its OWN key. a count alone would pass if two
# accounts collided onto one key and a third was invented to make up the number.
_is 'sweep.every-reach-keyed' 'a@x.com b@x.com c@x.com d@x.com e@x.com' \
  "$(_usage_union "$_five" 'a@x.com' 0 --json | jq -r 'keys | join(" ")' 2>/dev/null)"

# ---- progress is for a watchful human, never for a contract
# ⚠️ the sweep is sequential and can take seconds, so it reports which account it is on. that
#   report must never reach a pipe: a `--json` consumer parses stdout, and a snapshot or a
#   cron log that captured stderr would gain a wall of `⏳` rows plus ansi escapes. the guard
#   is `[[ -t 2 ]]`, and this is what proves it — the suite itself runs with stderr captured,
#   so a regression that drops the tty test shows up here rather than in a human's log.
# .note = this uses its OWN seam rather than `_usage_union`, because that one discards stderr
#   INSIDE its subshell — so a `2>&1` at the call site would capture an empty string and the
#   case would pass no matter what. that is precisely the toothless-clamp shape
#   `rule.require.clamp-edge-cases` forbids, and the first draft of this case had it.
_prog_out="$(
  eval "_brains_auth_reaches()        { printf '%s' '$_five'; return 0; }"
  eval "_brains_auth_active_reach()   { printf '%s' 'a@x.com'; return 0; }"
  eval "_brains_auth_node_for_reach() { jq -n '{five_hour:{utilization:1}}'; }"
  _brains_auth_usage --json 2>&1
)"
case "$_prog_out" in
  *'⏳'*)   _is 'sweep.progress-off-a-pipe' 'quiet' 'progress leaked into a captured stream' ;;
  *$'\033'*) _is 'sweep.progress-off-a-pipe' 'quiet' 'ansi escapes leaked into a captured stream' ;;
  *)        _is 'sweep.progress-off-a-pipe' 'quiet' 'quiet' ;;
esac

# ---------------------------------------------------------------- the active-account branch
# the live account is read from ~/.claude and NEVER refreshed (the one-holder rule), so its
# two failure codes are reached only through that branch. the hint strings were pinned; the
# BRANCH SELECTION was not — so a rewire that sent the active account down the keyrack path
# would have gone unnoticed, and that path is the one that rotates a live token.
_active_node() {
  # $1 = the creds file body; emits the node for an account that IS the active one
  printf '%s' "$1" > "$_BRAINS_AUTH_LIVE_CREDS"
  _brains_auth_node_for_reach 'ua' 'kai@x.com' 'kai@x.com' 0
}

_is 'active.expired-token-is-named' 'active_token_expired' \
  "$(_active_node '{"claudeAiOauth":{"accessToken":"'"$_OAT"'","expiresAt":1}}' | jq -r '.error')"
_is 'active.unreadable-creds-is-named' 'active_creds_unreadable' \
  "$(_active_node '{"claudeAiOauth":{"expiresAt":99999999999999}}' | jq -r '.error')"
_is 'active.corrupt-creds-is-named' 'active_creds_unreadable' \
  "$(_active_node 'not json at all' | jq -r '.error')"

# ---- the active branch's SUCCESS node must have the same json shape as a parked one
# ⚠️ the two branches build their node by different routes — the parked one mints from the
#   keyrack, the active one reads `~/.claude/.credentials.json` and never refreshes (the
#   one-holder rule) — and only the parked shape was ever pinned. so `--json` had a whole
#   branch whose keys nobody checked. a consumer that reads
#   `.["me@x.com"].five_hour.utilization` breaks the day the signed-in account renders a
#   different shape, and it breaks for exactly one account: whichever one you are on.
#   the tree render already pins the `← signed in` MARK; this pins the DATA behind it.
_active_ok_node() {
  printf '%s' '{"claudeAiOauth":{"accessToken":"'"$_OAT"'","expiresAt":99999999999999}}' \
    > "$_BRAINS_AUTH_LIVE_CREDS"
  (
    eval "_brains_auth_node_via_access() { printf '%s' '$1'; }"
    _brains_auth_node_for_reach 'ua' 'kai@x.com' 'kai@x.com' 0
  )
}
_USAGE_BODY='{"five_hour":{"utilization":24,"resets_at":"2026-09-02T13:20:00Z"},"seven_day":{"utilization":48,"resets_at":"2026-09-03T12:00:00Z"}}'
# the keys a --json consumer reads, in sorted order, so an added or dropped key goes red
_is 'active.json-shape-matches-parked' 'five_hour seven_day' \
  "$(_active_ok_node "$_USAGE_BODY" | jq -r 'keys_unsorted | sort | join(" ")')"
# and the values must survive the branch untouched — a shape that matches while the numbers
# are lost would satisfy the check above and still render a wrong budget
_is 'active.json-carries-the-numbers' '24 48' \
  "$(_active_ok_node "$_USAGE_BODY" | jq -r '[.five_hour.utilization, .seven_day.utilization] | join(" ")')"
# a success node carries NO error key — the absence is what a consumer branches on
_is 'active.json-success-has-no-error' 'absent' \
  "$(_active_ok_node "$_USAGE_BODY" | jq -r 'if has("error") then "PRESENT" else "absent" end')"

# ---- the usage classifier must split 5xx from other-4xx, as its twin already does
# ⚠️ `_brains_auth_node_via_access` is called the twin of `_brains_auth_mint_access` by this
#   file's own comments, and the mint learned this lesson the hard way: it once folded every
#   non-401 into one code, so a 503 from anthropic rendered "refresh token dead (run:
#   brains.auth.set)" — a browser re-auth prescribed to a human to repair someone else's
#   outage. that was fixed on the mint and NOT here, so this leaf still folded every other 4xx
#   into a generic `http_<n>` that the severity table's default calls a MALFUNCTION (ours,
#   exit 1) — when a 403 (a token without the usage scope) is squarely the caller's.
#   the same defect, pointed the other way: there a server fault read as the human's; here a
#   human fault reads as ours, so a cron retries forever against a token that will never work.
_usage_node_for_http() {
  (
    eval "_brains_auth_usage_reply() { printf '%s\n%s' '{\"error\":{\"message\":\"nope\"}}' '$1'; }"
    _brains_auth_node_via_access 'ua' 'kai@x.com' 'tok'
  )
}
_is 'usage.http-401-is-token_expired'      'token_expired'      "$(_usage_node_for_http 401 | jq -r '.error')"
_is 'usage.http-429-is-rate_limited'       'rate_limited'       "$(_usage_node_for_http 429 | jq -r '.error')"
_is 'usage.http-403-is-usage_rejected'     'usage_rejected'     "$(_usage_node_for_http 403 | jq -r '.error')"
_is 'usage.http-404-is-usage_rejected'     'usage_rejected'     "$(_usage_node_for_http 404 | jq -r '.error')"
_is 'usage.http-500-is-usage_server_error' 'usage_server_error' "$(_usage_node_for_http 500 | jq -r '.error')"
_is 'usage.http-503-is-usage_server_error' 'usage_server_error' "$(_usage_node_for_http 503 | jq -r '.error')"
# the split is worthless unless the two land on OPPOSITE sides of the severity table — that is
# the whole reason the codes differ, and the half a rename could silently undo
_is 'usage.rejected-is-the-callers'  'constraint'  "$(_brains_auth_severity_for_error usage_rejected)"
_is 'usage.server-error-is-ours'     'malfunction' "$(_brains_auth_severity_for_error usage_server_error)"
# and a non-numeric code must keep the generic shape rather than be guessed into either bucket
_is 'usage.unparseable-code-stays-generic' 'http_weird' "$(_usage_node_for_http weird | jq -r '.error')"

# ⚠️ and the SUCCESS path must survive this leaf. every case above hands it a failing code, and
#   `_active_ok_node` stubs the whole function out — so the 200 branch had no coverage at all
#   inside `_brains_auth_node_via_access` itself. it cost a live regression to find that: a
#   restructure of the error map turned the `200)` no-op arm into a fall-through, so a healthy
#   account rendered `💥 http_200` — a failure node for a request that WORKED, on the one row
#   the human actually reads. these two pin the fence that makes that structurally impossible.
_usage_node_ok() {
  (
    eval "_brains_auth_usage_reply() { printf '%s\n200' '$_USAGE_BODY'; }"
    _brains_auth_node_via_access 'ua' 'kai@x.com' 'tok'
  )
}
_is 'usage.http-200-is-not-an-error' 'absent' \
  "$(_usage_node_ok | jq -r 'if has("error") then "PRESENT: \(.error)" else "absent" end')"
_is 'usage.http-200-carries-the-windows' '24 48' \
  "$(_usage_node_ok | jq -r '[.five_hour.utilization, .seven_day.utilization] | join(" ")')"

# ---- the 200-shape gate: a PRESENT-but-unreadable number must refuse, never read as zero
# ⚠️ this is the worst-direction failure this whole feature can have, so it earns its own block.
#   the gate once tested only that the windows were OBJECTS, which passes a body whose
#   `.utilization` is a string — and every step after that converts the string into a confident
#   zero rather than refuse it: jq's `// 0` fires on null/false only (a non-empty string is
#   truthy, so it flows through), then awk's `printf "%.0f"` coerces it to 0 silently. the human
#   reads `session ░░░░░░░░░░ 0% used` on an account whose real number was never read, and acts
#   on a full-budget all-clear. a refusal costs them a retry; this costs them the decision the
#   tool exists to inform.
_usage_node_body() {
  ( eval "_brains_auth_usage_reply() { printf '%s\n200' '$1'; }"
    _brains_auth_node_via_access 'ua' 'kai@x.com' 'tok' )
}
_shape_verdict() { _usage_node_body "$1" | jq -r '.error // "trusted"'; }
# a string utilization is the shape that produced the defect — it must be refused
_is 'shape.string-utilization-refuses' 'unexpected_shape' \
  "$(_shape_verdict '{"five_hour":{"utilization":"n/a"},"seven_day":{"utilization":48}}')"
# ⚠️ the two cases below split one claim in half on purpose, because a single case here would
#   overclaim. the coercion does NOT happen in the node — a node built from a string body still
#   carries the literal "n/a" — it happens two steps later in `_brains_auth_round`. so the first
#   case pins the COERCION (proving the danger is real and downstream), and the second pins that
#   the gate stops the body before it can ever reach it. a case named "never-reads-zero" that
#   only looked at the node would go green for the wrong reason and read as proof it is not
#   (`hazard.a-clamp-can-lie-the-same-way-code-can`).
# first: awk really does turn a non-numeric string into a confident 0. this is the mechanism.
_is 'shape.round-coerces-a-string-to-zero' '0' "$(_brains_auth_round 'n/a')"
# second: so the gate must refuse the body BEFORE the render can hand that string to round.
#   an error node has no `.five_hour` at all, which is what "refused" reads here.
_is 'shape.string-never-reaches-the-round' 'refused' \
  "$(case "$(_usage_node_body '{"five_hour":{"utilization":"n/a"},"seven_day":{"utilization":48}}' \
              | jq -r 'if has("error") then "refused" else (.five_hour.utilization|tostring) end')" in
       refused) echo 'refused' ;;
       *)       echo "REACHED THE RENDER" ;;
     esac)"
# the second window is checked too — a gate that only guarded the first would pass this
_is 'shape.string-in-second-window-refuses' 'unexpected_shape' \
  "$(_shape_verdict '{"five_hour":{"utilization":24},"seven_day":{"utilization":"high"}}')"
# an absent value must refuse rather than fall to `// 0` — `(null|type)` is "null", not "number"
_is 'shape.absent-utilization-refuses' 'unexpected_shape' \
  "$(_shape_verdict '{"five_hour":{},"seven_day":{"utilization":48}}')"
# an explicit null likewise: this is the one case `// 0` WOULD have caught, and it must still
# refuse rather than render a zero the endpoint never sent
_is 'shape.null-utilization-refuses' 'unexpected_shape' \
  "$(_shape_verdict '{"five_hour":{"utilization":null},"seven_day":{"utilization":48}}')"
# the ABSENT-window half the gate already closed must stay closed — this is the regression the
# narrowed test could plausibly break, since a window that is not an object has no `.utilization`
_is 'shape.absent-window-still-refuses' 'unexpected_shape' \
  "$(_shape_verdict '{"seven_day":{"utilization":48}}')"
_is 'shape.non-object-window-still-refuses' 'unexpected_shape' \
  "$(_shape_verdict '{"five_hour":"n/a","seven_day":{"utilization":48}}')"
# and a genuinely healthy body must still pass — a gate that refuses every body is not a gate.
# a float is deliberate: utilization is a percentage, and an int-only test would refuse a
# healthy endpoint that reports 24.5
_is 'shape.healthy-body-is-trusted' 'trusted' \
  "$(_shape_verdict '{"five_hour":{"utilization":24.5},"seven_day":{"utilization":48}}')"
_is 'shape.zero-is-a-real-number' 'trusted' \
  "$(_shape_verdict '{"five_hour":{"utilization":0},"seven_day":{"utilization":0}}')"

# ---- the shared pre-flight verdict on a stored token
# ⚠️ `use` and `usage` run the SAME two checks in the SAME order and diverge only in how they
#   present the answer. that was one fact told twice, and this file has already paid for the
#   shape: each check was hand-rolled at the swap site once, and each was wrong in the same
#   direction — an api key read as "your token is stale" (which loops the human back through
#   the same message), and a never-stored key read as "could not read" (which offers a retry
#   against a state only `brains.auth.set` can clear).
_is 'tokenerr.usable-token-is-quiet' ''                  "$(_brains_auth_token_err 0 "$_ORT")"
_is 'tokenerr.absent-key-is-named'   'keyrack_absent'    "$(_brains_auth_token_err 2 '')"
_is 'tokenerr.locked-rack-is-named'  'keyrack_unreadable' "$(_brains_auth_token_err 1 '')"
_is 'tokenerr.api-key-is-named'      'api_key_not_oauth' "$(_brains_auth_token_err 0 'sk-ant-api03-xyz')"
# ⚠️ the ORDER is the part a refactor would lose. on a FAILED read the token is empty, so the
#   shape check would also fire — and if shape ran first, a locked keyrack would render
#   "your token is stale" and send the human to a browser flow that cannot open a lock. the
#   keyrack verdict must outrank the shape verdict, and this pins it with both faults live.
_is 'tokenerr.keyrack-outranks-shape' 'keyrack_unreadable' \
  "$(_brains_auth_token_err 1 'sk-ant-api03-xyz')"

# ---- the empty-store render, as a leaf
# ⚠️ this branch used to be inlined while `_brains_auth_render_identity_blocked` sat right
#   beside it as an extracted leaf — so a reader of the pair could not tell whether "inline"
#   or "extracted" was the convention, and only one of the two was snappable without a driven
#   sweep. both are leaves now, and both are snapped here.
# ⚠️ this helper does the profile read the ORCHESTRATOR does, then hands the name to the
#   render — because the render is a pure leaf and no longer opens the file itself. the two
#   lines below are the caller's two lines, so this still covers profile-file → rendered text
#   end to end; what it no longer does is let a render reach for a global.
_render_no_subs_when() {
  printf '%s' "$1" > "$_BRAINS_AUTH_LIVE_PROFILE"
  _brains_auth_render_no_subscriptions \
    "$(_brains_auth_creds_field "$_BRAINS_AUTH_LIVE_PROFILE" '.oauthAccount.emailAddress')"
}
_snap 'coldstart.no-subs.names-the-live-account' \
  "$(_render_no_subs_when '{"oauthAccount":{"emailAddress":"kai@ehmpathy.com"}}')"
# and with no live login, the hint line must be ABSENT rather than render an empty name
_snap 'coldstart.no-subs.no-login-omits-the-hint' \
  "$(_render_no_subs_when '{}')"
# a torn profile must not invent a name either — it degrades to the same shape as no login
_is 'coldstart.no-subs.torn-profile-omits-the-hint' 'omitted' \
  "$(case "$(_render_no_subs_when 'not json' 2>/dev/null)" in
       *"profile names"*) echo 'INVENTED a name' ;;
       *)                 echo 'omitted' ;;
     esac)"
# ⚠️ the render must be a PURE function of its argument — it renders the name it is HANDED,
#   and never the one the profile file happens to hold. this is the clamp on that: the file on
#   disk says `moana@x.com`, the argument says `kai@x.com`, and the argument must win. the leaf
#   used to open the file itself, and under that shape this case reads `moana@x.com` — a leaf
#   that ignores its own input, which is the whole reason a pure-vs-i/o mixup is a defect and
#   not a style note. it also proves the file read moved OUT rather than merely got shadowed.
_is 'coldstart.no-subs.render-is-pure' 'kai@x.com' \
  "$( printf '%s' '{"oauthAccount":{"emailAddress":"moana@x.com"}}' > "$_BRAINS_AUTH_LIVE_PROFILE"
      _brains_auth_render_no_subscriptions 'kai@x.com' \
        | sed -n 's/.*profile names \([^ ]*\) .*/\1/p' )"

# ---------------------------------------------------------------- the profile sync
# this function once swallowed every failure silently, which made the one state it exists to
# prevent — ~/.claude.json left with the PRIOR account's name — undiagnosable. it was rewritten
# to fail loud and had no coverage of either half.
_sync_with_who() {
  # $1 = what _brains_auth_whoami should emit; $2 = its exit code
  (
    eval "_brains_auth_whoami() { printf '%s' '$1'; return $2; }"
    _brains_auth_sync_profile 'ua'
  )
}

printf '%s' '{"oauthAccount":{"accountUuid":"old","emailAddress":"moana@x.com"},"keepMe":1}' \
  > "$_BRAINS_AUTH_LIVE_PROFILE"
_sync_with_who "u-9${_TAB}kai@x.com" 0 >/dev/null 2>&1
_is 'sync.rc' '0' "$?"
_is 'sync.writes-new-uuid'  'u-9'       "$(jq -r '.oauthAccount.accountUuid'  < "$_BRAINS_AUTH_LIVE_PROFILE")"
_is 'sync.writes-new-email' 'kai@x.com' "$(jq -r '.oauthAccount.emailAddress' < "$_BRAINS_AUTH_LIVE_PROFILE")"
# the merge must preserve every other key claude keeps in that file
_is 'sync.keeps-foreign-key' '1' "$(jq -r '.keepMe' < "$_BRAINS_AUTH_LIVE_PROFILE")"

# ⚠️ a failed identity read must return 1 AND say so. a silent `return 0` here is the original
#   defect: the swap reports success while claude shows the wrong email.
_sync_out="$(_sync_with_who '' 1 2>&1)"
_sync_with_who '' 1 >/dev/null 2>&1
_is 'sync.unknown-identity.rc'    '1' "$?"
_is 'sync.unknown-identity.loud'  '1' "$([[ -n "$_sync_out" ]] && echo 1 || echo 0)"
# and it must NOT have touched the file it could not correct
_is 'sync.unknown-identity.no-write' 'kai@x.com' \
  "$(jq -r '.oauthAccount.emailAddress' < "$_BRAINS_AUTH_LIVE_PROFILE")"

# an unreadable profile file is the other loud path
printf '%s' 'not json at all' > "$_BRAINS_AUTH_LIVE_PROFILE"
_sync_out="$(_sync_with_who "u-9${_TAB}kai@x.com" 0 2>&1)"
_sync_with_who "u-9${_TAB}kai@x.com" 0 >/dev/null 2>&1
_is 'sync.corrupt-profile.rc'   '1' "$?"
_is 'sync.corrupt-profile.loud' '1' "$([[ -n "$_sync_out" ]] && echo 1 || echo 0)"

# ---------------------------------------------------------------- the severity table
# severity used to be recovered by a prefix-match on the hint's ✋/💥 glyph, which made a
# DISPLAY string decide the exit code automation reads. it is data now, and both surfaces read
# it — so this pins that they cannot disagree.
#
# the EXIT CODE column is snapped beside the severity for the same reason the glyph is: it was
# the last half of the contract still hand-typed at each call site, so the table and the codes
# it implies were two facts a reader had to reconcile. now they render side by side, and a
# severity that flips drags its code into the diff with it.
_sev=''
for e in "${_ERRORS[@]}"; do
  _sev+="$(printf '%-28s %-12s %s  exit %s' "$e" \
    "$(_brains_auth_severity_for_error "$e")" \
    "$(_brains_auth_glyph_for_severity "$(_brains_auth_severity_for_error "$e")")" \
    "$(_brains_auth_code_for_error "$e")")"$'\n'
done
_snap 'severity.every-error-code' "${_sev%$'\n'}"

# the glyph a hint WEARS must be the glyph its severity EARNS. a mismatch here is precisely
# the defect the table was extracted to make impossible, so it is asserted rather than snapped
# — a snapshot would record a drift; this refuses it.
_agree=1
for e in "${_ERRORS[@]}"; do
  [[ "$(_brains_auth_fix_for_error "$e")" == \
     "$(_brains_auth_glyph_for_severity "$(_brains_auth_severity_for_error "$e")")"* ]] || _agree=0
done
_is 'severity.hint-glyph-agrees' '1' "$_agree"

# an unlisted code must land on malfunction — an unanticipated failure is ours until proven
# otherwise, and to default to constraint would hand the human a fix they cannot apply
_is 'severity.unknown-code-is-malfunction' 'malfunction' \
  "$(_brains_auth_severity_for_error 'some_code_we_never_declared')"

# ---------------------------------------------------------------- the swap decision
# the whole authorization matrix for `use`, as a pure verb. this is the branch that stands
# between a read and a credential overwrite, and until it was factored out it could be
# exercised only by a live swap.
_decide=''
for _row in \
  'kai@x.com|kai@x.com|0' 'kai@x.com|moana@x.com|0' 'kai@x.com||0' \
  'kai@x.com|kai@x.com|1' 'kai@x.com|moana@x.com|1' 'kai@x.com||1' \
  'kai@x.com|kai@x.com|2' 'kai@x.com|moana@x.com|2' 'kai@x.com||2'
do
  IFS='|' read -r _r _a _c <<< "$_row"
  _decide+="$(printf 'reach=%-10s active=%-12s arc=%s -> %s' \
    "$_r" "${_a:-<none>}" "$_c" "$(_brains_auth_use_decide "$_r" "$_a" "$_c")")"$'\n'
done
_snap 'use.decision-matrix' "${_decide%$'\n'}"

# ⚠️ refuse comes BEFORE noop, and that order is pinned deliberately. the reverse reads kinder
#   — "you asked for the account you are already on, so let it pass" — and it lies: with the
#   identity unproven, `active` is a GUESS, so `reach == active` may be false in reality and
#   the noop would report "already signed in as kai@x" on a machine signed in as someone else.
_is 'use.refuse-outranks-noop' 'refuse_unverified' \
  "$(_brains_auth_use_decide 'kai@x.com' 'kai@x.com' 2)"

# ---------------------------------------------------------------- the identity branch
# this is the highest-blast-radius decision point in the namespace: it is what stands between
# a read and a token rotation that would log a live session out. it had no coverage, because
# it looked to need a network — and it does not.
#
# `_brains_auth_whoami` asks the api ONLY while the live access token is still valid. an
# expired one is not refreshed (that is the rotation hazard), so it falls straight through to
# claude's profile file. so the whole three-state ladder is reachable from FILE STATE alone:
#
#   no creds file                      -> 0 verified   (nobody signed in — a known answer)
#   expired access + a named profile   -> 2 unverified (a name that may LAG the live token)
#   expired access + an empty profile  -> 1 unknown    (a login exists but cannot be named)
#
# .note = the profile redirect used to sit HERE, beside its first reader. that is what made the
#   defect: two profile-sync sections were later added ABOVE this line, and they wrote their
#   fixtures to the real ~/.claude.json. the redirect now lives with the creds one at the top,
#   where no future section can be inserted before it.

# a creds file whose access token expired long ago — this is the state an idle terminal lands
# in within the hour, so it is the common case, not an exotic one
_expired_creds() {
  printf '%s' '{"claudeAiOauth":{"accessToken":"'"$_OAT"'","expiresAt":1,"refreshToken":"'"$_ORT"'"}}' \
    > "$_BRAINS_AUTH_LIVE_CREDS"
}

rm -f "$_BRAINS_AUTH_LIVE_CREDS" "$_BRAINS_AUTH_LIVE_PROFILE"
_out="$(_brains_auth_active_reach 'ua')"; _rc=$?
_is 'arc.no-creds.rc'  '0' "$_rc"
_is 'arc.no-creds.out' ''  "$_out"

_expired_creds
printf '%s' '{"oauthAccount":{"accountUuid":"u-1","emailAddress":"kai@ehmpathy.com"}}' \
  > "$_BRAINS_AUTH_LIVE_PROFILE"
_out="$(_brains_auth_active_reach 'ua')"; _rc=$?
_is 'arc.unverified.rc'  '2'                 "$_rc"
_is 'arc.unverified.out' 'kai@ehmpathy.com'  "$_out"

_expired_creds
printf '%s' '{}' > "$_BRAINS_AUTH_LIVE_PROFILE"
_out="$(_brains_auth_active_reach 'ua')"; _rc=$?
_is 'arc.unknown.rc'  '1' "$_rc"
_is 'arc.unknown.out' ''  "$_out"

# ---- what each command DOES with that verdict
# `--reach` is passed so the sweep never reaches the keyrack: with an explicit reach the
# enumeration is skipped, and the identity check short-circuits before any i/o. so these
# exercise the real orchestrators end to end, hermetically.
#
# ⚠️ the two commands are asymmetric ON PURPOSE and that asymmetry is pinned here, because it
#   is the kind a later reader would "tidy" into consistency and break: `use` with no args is
#   a DISPLAY, so an unverified name may label it (caveated). `usage` REFRESHES, and a refresh
#   against the account that is truly live rotates its token out from under an open session —
#   so an unverified name may never authorize it. display may guess; a mutation may not.
_expired_creds
printf '%s' '{"oauthAccount":{"accountUuid":"u-1","emailAddress":"kai@ehmpathy.com"}}' \
  > "$_BRAINS_AUTH_LIVE_PROFILE"

# .what = mask the per-run temp dir out of a message that quotes a file path
# .why  = `mktemp -d` names a fresh dir on every run, so a snapshot that captured it would
#   fail on the very next run — a clamp that cries wolf gets deleted, and a deleted clamp
#   guards no defect. the SHAPE of the message is what is pinned; the path is not.
_maskdir() { sed -E "s#${_SWAPDIR}#<tmp>#g"; }

_snap 'identity.usage-refuses-unverified.json' \
  "$(_brains_auth_usage --reach kai@ehmpathy.com --json 2>&1 | _maskdir)"
_brains_auth_usage --reach kai@ehmpathy.com --json >/dev/null 2>&1
_code 'identity.usage-refuses-unverified.exit' 2 "$?"

# ⚠️ the refusal a human reads is snapped BESIDE the display below on purpose. the two are
#   read back to back in this state, and the pair must tell ONE story — a reviewer who sees
#   them together can judge that at a glance; two separate snapshots could each read fine on
#   its own and still contradict each other.
_snap 'identity.usage-refuses-unverified.tree' \
  "$(_brains_auth_usage --reach kai@ehmpathy.com 2>&1 | _maskdir)"

# the DISPLAY still names the account — caveated, never silent
_snap 'identity.use-shows-unverified' "$(_brains_auth_use 2>&1 | _maskdir)"

_expired_creds
printf '%s' '{}' > "$_BRAINS_AUTH_LIVE_PROFILE"
_snap 'identity.usage-refuses-unknown' \
  "$(_brains_auth_usage --reach kai@ehmpathy.com --json 2>&1 | _maskdir)"
_brains_auth_usage --reach kai@ehmpathy.com --json >/dev/null 2>&1
_code 'identity.usage-refuses-unknown.exit' 2 "$?"

# a swap must refuse on BOTH non-verified codes — it is the mutation, so it is the strict one
_brains_auth_use --reach kai@ehmpathy.com >/dev/null 2>&1
_code 'identity.use-refuses-unknown.exit' 2 "$?"

# ---------------------------------------------------------------- the swap sequence
# every case above stops at a REFUSAL. past that gate lies the highest-blast-radius code in the
# namespace — mint → install → park-file → sync-profile, a credential overwrite with two
# distinct rollback narratives — and it was reachable only by a real mint against a real token,
# so it had no clamp that could fail before it shipped.
#
# the one network-bound step is the mint, so it is the seam. with it and the keyrack read
# overridden, the whole sequence runs hermetically and each failure branch can be FORCED.
# ⚠️ the overrides are required for hermeticity, not merely for the fixture: `_get_token`
#   reaches the human's keyrack and `_mint_access` rotates a real token server-side. a case
#   here that skipped either would spend a live credential to run a test.
_swap_with() {
  # $1 = the node _brains_auth_mint_access emits
  # $2 = rc of _brains_auth_install_creds   (the credential overwrite)
  # $3 = rc of _brains_auth_park_file       (files the account we swapped OFF of)
  # $4 = rc of _brains_auth_set_token       (the rotated-token write-back on install failure)
  local mint="$1" irc="${2:-0}" prc="${3:-0}" src="${4:-0}"
  (
    eval "_brains_auth_active_reach()  { printf '%s' 'moana@x.com'; return 0; }"
    eval "_brains_auth_get_token()     { printf '%s' '$_ORT'; return 0; }"
    eval "_brains_auth_park_read()     { printf '%s' '$_ORT'; return 0; }"
    # the compare-and-swap probe agrees with the park read, so these cases exercise the
    # branches BELOW the guard. left unstubbed it would read the shared temp creds file and
    # pass or fail on whatever a prior case happened to leave there — an accidental
    # dependency that would make every swap case below quietly order-dependent.
    eval "_brains_auth_live_ref()      { printf '%s' '$_ORT'; }"
    eval "_brains_auth_mint_access()   { printf '%s' '$mint'; }"
    eval "_brains_auth_install_creds() { return $irc; }"
    eval "_brains_auth_park_file()     { return $prc; }"
    eval "_brains_auth_set_token()     { return $src; }"
    eval "_brains_auth_sync_profile()  { return 0; }"
    _brains_auth_use --reach kai@x.com
  )
}

# ---- a swap must be as PRECISE about a stored token's shape as a read is
# ⚠️ `use` once hand-rolled its own verdict here — one "stored token is stale (expected
#   sk-ant-ort…)" for every shape it did not like. an API KEY stored where an oauth token
#   belongs took that same line, so the human was sent to re-auth a subscription when the real
#   fix was to store a different KIND of credential. meanwhile the read path had a precise
#   `api_key_not_oauth` hint for the identical token. one condition, two answers, and the swap
#   held the wrong one.
#   both the verdict and its remediation now come from the shared leaves, so a swap cannot be
#   less precise than a read about the same token. these clamp that they still route there —
#   which is what a re-inlined `case` would break while every table case stayed green.
_swap_with_stored() {
  ( eval "_brains_auth_active_reach() { printf '%s' 'moana@x.com'; return 0; }"
    eval "_brains_auth_get_token()    { printf '%s' '$1'; return 0; }"
    _brains_auth_use --reach kai@x.com 2>&1; echo "rc=$?" )
}
for _shape in "sk-ant-api03-a-real-api-key:api_key_not_oauth" \
              "not-a-token-at-all:needs_reauth" \
              ":no_token"; do
  _tok="${_shape%%:*}"; _err="${_shape##*:}"
  _got="$(_swap_with_stored "$_tok")"
  # the message must be the TABLE's, verbatim — not a lookalike typed at the call site
  case "$_got" in
    *"$(_brains_auth_fix_for_error "$_err")"*)
      _is "swap.shape-${_err}.uses-the-table" 'shared' 'shared' ;;
    *) _is "swap.shape-${_err}.uses-the-table" 'shared' "hand-rolled: ${_got}" ;;
  esac
  # and the exit code must be the table's too — all three are the caller's to fix
  case "$_got" in
    *"rc=$(_brains_auth_code_for_error "$_err")"*)
      _is "swap.shape-${_err}.uses-the-code" 'shared' 'shared' ;;
    *) _is "swap.shape-${_err}.uses-the-code" 'shared' "diverged: ${_got}" ;;
  esac
done

# ---- ...and as precise about the KEYRACK's two failures, which is the same defect on the
# other axis. `_brains_auth_get_token` declares them apart — rc 2 = never stored (a CONSTRAINT
# a sign-in fixes), rc 1 = the keyrack could not be read (a MALFUNCTION a sign-in cannot touch)
# — and the read path honored the split while the swap collapsed both into one hand-typed
# `return 1`. so a never-stored account was told "keyrack could not read" and exited 1: a retry
# offered against a state only `brains.auth.set` can clear, and the wrong severity handed to
# every `$?` consumer. these clamp both rows, message AND code, against the shared tables.
_swap_with_keyrack_rc() {
  ( eval "_brains_auth_active_reach() { printf '%s' 'moana@x.com'; return 0; }"
    eval "_brains_auth_get_token()    { return $1; }"
    _brains_auth_use --reach kai@x.com 2>&1; echo "rc=$?" )
}
for _kr in "2:keyrack_absent" "1:keyrack_unreadable"; do
  _rc="${_kr%%:*}"; _err="${_kr##*:}"
  _got="$(_swap_with_keyrack_rc "$_rc")"
  case "$_got" in
    *"$(_brains_auth_fix_for_error "$_err")"*)
      _is "swap.keyrack-${_err}.uses-the-table" 'shared' 'shared' ;;
    *) _is "swap.keyrack-${_err}.uses-the-table" 'shared' "hand-rolled: ${_got}" ;;
  esac
  case "$_got" in
    *"rc=$(_brains_auth_code_for_error "$_err")"*)
      _is "swap.keyrack-${_err}.uses-the-code" 'shared' 'shared' ;;
    *) _is "swap.keyrack-${_err}.uses-the-code" 'shared' "diverged: ${_got}" ;;
  esac
done
# the split is the whole point, so pin that the two rows genuinely DIFFER — a future edit that
# merged them back would otherwise satisfy both loops above with one shared answer
_is 'swap.keyrack-codes-stay-split' '2|1' \
  "$(_brains_auth_code_for_error keyrack_absent)|$(_brains_auth_code_for_error keyrack_unreadable)"

_MINT_GOOD='{"ok":true,"code":200,"access":"A","refresh":"R2","ttl":3600,"scopes":"","kind":"max"}'

# .what = drive _brains_auth_set to its mint-failure branch, hermetically
# .why  = `set` opens a browser sign-in, so the only way to reach the branch under test is to
#   stand in for the two i/o leaves ahead of it. the sign-in becomes a no-op and the captured
#   token becomes a fixture, so the case exercises the DECISION alone.
_store_with() {
  local mint="$1"
  (
    eval "_brains_auth_login_isolated()  { :; }"
    eval "_brains_auth_extract_refresh() { printf '%s' '$_ORT'; return 0; }"
    eval "_brains_auth_mint_access()     { printf '%s' '$mint'; }"
    _brains_auth_set
  )
}

# .what = drive _brains_auth_set to its FILING decision, and report the reach it filed under
# .why  = the precedence at the heart of the reach scheme — "the token names itself; a supplied
#   --reach never overrules it" — had no case at all. $1 = what the token reports (empty = the
#   token stays silent), $2.. = the args the human typed.
# .note = `_brains_auth_set_token` is stubbed to PRINT its reach rather than write a keyrack, so
#   the case observes the decision itself instead of a side effect two layers away.
# .note = the reach is emitted behind a `REACH:` marker and cut back out, because `set` also
#   prints its own sign-in banner to stdout. an unmarked capture would compare the decision
#   against four lines of prose and read as a failure while the code was correct — which is
#   exactly what the first draft of these three cases did.
_store_reach_when() {
  local says="$1" out; shift
  out="$(
    eval "_brains_auth_login_isolated()  { :; }"
    eval "_brains_auth_extract_refresh() { printf '%s' '$_ORT'; return 0; }"
    eval "_brains_auth_mint_access()     { printf '%s' '$_MINT_GOOD'; }"
    eval "_brains_auth_who_for_access()  { [[ -n '$says' ]] || return 1; printf 'uuid-1\t%s' '$says'; }"
    eval "_brains_auth_set_token()       { printf '\nREACH:%s\n' \"\$1\"; return 0; }"
    _brains_auth_set "$@" 2>/dev/null
  )"
  # an absent marker means the filing branch was never reached — say so, rather than let the
  # whole banner through and have it read as a mismatched reach
  case "$out" in
    *REACH:*) out="${out##*REACH:}"; printf '%s' "${out%%$'\n'*}" ;;
    *)        printf 'never-filed' ;;
  esac
}

# ---- the reach precedence: the TOKEN names the account, a flag never overrules it
# ⚠️ this is the property the whole reach scheme rests on, and it had zero coverage until now.
#   the vision retired the `--sub <slug>` handle precisely so that no human-typed name could
#   ever disagree with the token — "no handle is invented, so no handle can disagree with the
#   token or be typed wrong". the line `reach="$(_brains_auth_email_of_who "$who")"` is where
#   that promise is kept, and a regression that flipped the precedence would file a live token
#   under an account nobody will ever look it up by. it fails SILENTLY: `set` reports success,
#   and the loss surfaces rounds later as an unrelated `usage` miss.
_is 'set.token-identity-outranks-flag' 'kai@ehmpathy.com' \
  "$(_store_reach_when 'kai@ehmpathy.com' --reach 'wrong@example.com')"
# the same precedence with no flag at all — the common case, where the token is the only source
_is 'set.token-identity-with-no-flag' 'kai@ehmpathy.com' \
  "$(_store_reach_when 'kai@ehmpathy.com')"
# and the fallback the flag exists FOR: the token declines to say who it is, so the supplied
# name is all there is. a precedence fix must not cost us this one.
_is 'set.flag-is-the-fallback' 'named@example.com' \
  "$(_store_reach_when '' --reach 'named@example.com')"

# ---- the isolation boundary must not survive a failed mktemp
# ⚠️ `authdir="$(mktemp -d)"` used to go unchecked, and that ONE unread rc inverts the whole
#   promise of this command. a full tmpfs hands back an EMPTY string, and bash carries an empty
#   string forward as happily as a path: `chmod 700 ""` fails unread, the trap arms on an empty
#   path, and the login is invoked with `CLAUDE_CONFIG_DIR=""` — which does NOT aim claude at a
#   private dir. so the sign-in whose own banner says "isolated from your global claude" would
#   write a live, durable refresh token into `~/.claude`, the exact file the isolation exists to
#   protect, on the machine of a human who was told it never would.
#   the failure is invisible from the outside: the login succeeds, the token is stored, and the
#   only trace is a global credential file quietly overwritten. so these clamp BOTH halves —
#   that the failure is named, and that the login never runs.
_set_with_dead_mktemp() {
  (
    eval "mktemp() { return 1; }"
    # if the guard is absent, this marker proves the login was reached with an empty authdir
    eval "_brains_auth_login_isolated() { printf 'LOGIN-RAN-WITH:[%s]\n' \"\$1\"; }"
    eval "_brains_auth_extract_refresh() { printf ''; return 1; }"
    _brains_auth_set --reach 'kai@ehmpathy.com' 2>&1
  )
}
_MKT="$(_set_with_dead_mktemp)"
case "$_MKT" in
  *'could not open a private dir'*) _is 'set.dead-mktemp-is-named' 'named' 'named' ;;
  *)                                _is 'set.dead-mktemp-is-named' 'named' 'SILENT — no cause given' ;;
esac
# the half that actually protects the credential: the login must not have been invoked at all.
# a message alone would be cold comfort if the sign-in still ran against the global config.
case "$_MKT" in
  *LOGIN-RAN-WITH:*) _is 'set.dead-mktemp-skips-login' 'skipped' 'RAN — global login at risk' ;;
  *)                 _is 'set.dead-mktemp-skips-login' 'skipped' 'skipped' ;;
esac

# ---- the mint-failure exit code
# ⚠️ this branch returned a flat `1` for EVERY mint failure, `refresh_rejected` among them —
#   which the shared table calls a `constraint`, because the token is dead and only a human
#   re-auth fixes it. a caller that reads `$?` to choose "auto-retry" over "tell the human to
#   re-auth" would have retried forever against a token that can never mint again. so the code
#   is derived from the severity table, and the two severities are pinned apart here.
_swap_with '{"ok":false,"error":"refresh_rejected","code":401}' >/dev/null 2>&1
_code 'swap.mint-constraint-exits-2' 2 "$?"
_swap_with '{"ok":false,"error":"refresh_curl_failed","code":0}' >/dev/null 2>&1
_code 'swap.mint-malfunction-exits-1' 1 "$?"

# ⚠️ and `set` must agree with `use` about the SAME fault. `set`'s branch was a flat `return 1`,
#   so the two orchestrators gave OPPOSITE answers for one failure: `use` called a dead token a
#   constraint (2, "tell the human to re-auth"), `set` called it a malfunction (1, "retry"). a
#   caller that branches on `$?` could not trust either. both now read the shared table.
_store_with '{"ok":false,"error":"refresh_rejected","code":401}' >/dev/null 2>&1
_code 'store.mint-constraint-exits-2' 2 "$?"
_store_with '{"ok":false,"error":"refresh_curl_failed","code":0}' >/dev/null 2>&1
_code 'store.mint-malfunction-exits-1' 1 "$?"
# the LEAD line stays account-named even though the CODE and the HINT come from the shared
# table — a swap fails on one account, so it names it; a sweep renders many rows, so its
# table does not. the remediation below the lead is the table's, verbatim.
_snap 'swap.mint-rejected.says' \
  "$(_swap_with '{"ok":false,"error":"refresh_rejected","code":401}' 2>&1 | _maskdir)"

# ⚠️ the drift clamp. this branch used to hand-roll its OWN case over the same error codes,
#   with three named arms and a generic `*)` catch-all. so a code the shared table has a
#   precise hint for — `no_access_token`, "the oauth flow may have changed" — fell through
#   to "refresh was rejected", and the human was sent to re-auth a token that was fine.
#   the sweep and the swap now read the SAME hint for the same failure, and this is what
#   proves it: the expected text is built from the table, so a second copy cannot satisfy it.
_out="$(_swap_with '{"ok":false,"error":"no_access_token","code":200}' 2>&1)"
case "$_out" in
  *"$(_brains_auth_fix_for_error no_access_token)"*)
    _is 'swap.hint-comes-from-the-table' 'table' 'table' ;;
  *) _is 'swap.hint-comes-from-the-table' 'table' "hand-rolled: ${_out}" ;;
esac

# ---- the isolated sign-in dir holds a secret at rest, so its shred must cover every exit
# ⚠️ these two read the SOURCE, not a run, and that is deliberate rather than lazy. a signal
#   trap only fires when the signal arrives, so to exercise it a case would have to `kill` a
#   live interactive `claude` sign-in — an i/o leaf the suite stubs precisely because it
#   cannot be driven hermetically. what CAN be pinned without a run is the property the
#   defect was: which signals the trap names.
#
#   the defect: `_brains_auth_set` armed `trap 'rm -rf "$authdir"' INT` alone, while its
#   comment promised a wipe on "every way out". a SIGTERM — a killed terminal, a logout, a
#   reaped parent — left a LIVE, durable oauth refresh token on disk. RETURN is the wider
#   half of the fix: it shreds on EVERY early return, so a future branch added above the
#   eager `rm -rf` cannot strand the secret merely because its author did not think of it.
_arm="$(grep -n "trap 'rm -rf \"\$authdir\"'" "$ALIASES" | sed 's/.*authdir"'"'"'//')"
for _sig in INT TERM HUP RETURN; do
  case "$_arm" in
    *"$_sig"*) _is "trap.arms-${_sig}" 'armed' 'armed' ;;
    *)         _is "trap.arms-${_sig}" 'armed' "absent (arm reads:${_arm})" ;;
  esac
done
# and the disarm must name the SAME set. name a subset and the rest stay armed past the
# eager shred, so the two lines drift apart with no signal that they have.
# ⚠️ scoped to the arm's OWN signal list, not to a bare `trap - INT`. the file now holds a
#   second trap pair (`_brains_auth_write_secret`, below), so a file-wide scan would tally
#   both and report a mismatch about two lines that each match their own partner.
_disarm="$(grep -n "trap - $(printf '%s' "$_arm" | tr -s ' ' | sed 's/^ //')" "$ALIASES" | sed 's/.*trap - //' | head -1)"
_is 'trap.disarm-matches-arm' "$(printf '%s' "$_arm" | tr -s ' ' | sed 's/^ //')" \
                              "$(printf '%s' "$_disarm" | tr -s ' ' | sed 's/^ //')"

# ---- the shared secret-write leaf must cover the kill window too
# ⚠️ `_brains_auth_write_secret` is the one leaf EVERY credential write funnels through, and it
#   had no trap at all. its explicit `rm -f`s cover the error paths, but a signal takes none of
#   them: a ctrl-c or a reaped parent between the write and the rename strands a live oauth
#   token in a `.new.XXXXXX` file beside the real one — durable, and invisible, because no
#   recovery path looks for that name (the strand guard watches `.bak`, not `.new`).
#   read from the source for the same reason as the pair above: a signal trap cannot be fired
#   hermetically, but WHICH signals it names can be pinned exactly.
_wsarm="$(grep -n "trap \"rm -f '\\\$tmp'\"" "$ALIASES" | sed 's/.*\$tmp.//')"
for _sig in INT TERM HUP; do
  case "$_wsarm" in
    *"$_sig"*) _is "trap.write-secret-arms-${_sig}" 'armed' 'armed' ;;
    *)         _is "trap.write-secret-arms-${_sig}" 'armed' "absent (arm reads:${_wsarm})" ;;
  esac
done
# ⚠️ and it must NOT name RETURN. a RETURN trap set in a function OUTLIVES that function and
#   fires on unrelated returns elsewhere in the file — the first attempt at this trap did
#   exactly that and killed the suite with `tmp: unbound variable` from a function 70 lines
#   away. the authdir trap can afford RETURN because it is armed once in a command that owns
#   its whole stack; this leaf is called from inside other functions, so it cannot.
case "$_wsarm" in
  *RETURN*) _is 'trap.write-secret-omits-RETURN' 'omitted' 'PRESENT — it will follow us up the stack' ;;
  *)        _is 'trap.write-secret-omits-RETURN' 'omitted' 'omitted' ;;
esac
# the path must be baked in at arm time (double quotes), never left to expand at fire time —
# a `local` is torn down before the handler runs, so a late expansion meets `set -u` and dies
# inside the signal handler, which is the worst possible place to learn that.
case "$(grep -c "trap \"rm -f '\\\$tmp'\"" "$ALIASES")" in
  0) _is 'trap.write-secret-bakes-the-path' 'baked' 'LATE — expands at fire time' ;;
  *) _is 'trap.write-secret-bakes-the-path' 'baked' 'baked' ;;
esac

# ---- the beta opt-in header is single-source
# ⚠️ this value was hand-typed at all three call sites while the file's OWN constants
#   (`_BRAINS_AUTH_UA_PINNED`, `_BRAINS_AUTH_HTTP_TIMEOUT`) exist precisely because a value
#   typed at N sites is N places to drift. the endpoints are undocumented, so the day anthropic
#   retires this beta the fix must be ONE edit — and a PARTIAL edit is the worse failure: two
#   paths on the new value and one on the old reads as "the endpoint is flaky", which sends the
#   next reader to the network instead of to this line.
_is 'beta.header-declared-once' '1' \
  "$(grep -c "^_BRAINS_AUTH_ANTHROPIC_BETA='" "$ALIASES")"
# the literal may appear ONLY in that declaration — never again at a call site
_is 'beta.header-no-literal-at-call-sites' '0' \
  "$(grep -c -- '-H "anthropic-beta: oauth-' "$ALIASES")"
# and every oauth call must send it THROUGH the constant. three calls make one (mint, whoami,
# usage); a count below three means a path dropped the header and will 429 in a way that reads
# as rate limits rather than as an absent opt-in.
_is 'beta.header-sent-by-every-call' '3' \
  "$(grep -c 'anthropic-beta: ${_BRAINS_AUTH_ANTHROPIC_BETA}' "$ALIASES")"

# ---- the live-token freshness read is one leaf, and its four verdicts are distinct
# ⚠️ `_brains_auth_whoami` and `_brains_auth_node_for_reach`'s active branch ran this identical
#   sequence from two places ~1,380 lines apart with NO comment at either site that named the
#   other. that is the un-inherited-twin shape which already bit the usage classifier — caught
#   here BEFORE a divergence. the rc split is what lets the two callers keep their DIFFERENT
#   verdicts (whoami falls back to the profile; node_for_reach names `active_token_expired`)
#   off ONE read of the file.
# ⚠️ these probes MUTATE a fixture later cases read, so the prior content is saved HERE and
#   restored BELOW — after the last probe, in file order. the first draft of this block only
#   `rm -f`'d at the end, which left the file ABSENT for every case downstream and surfaced as
#   `cat: .../.credentials.json: No such file` plus a stray `jq: parse error` in an unrelated
#   later case. that is failure shape 3 in hazard.a-clamp-can-lie-the-same-way-code-can.md,
#   committed by the very round that wrote the brief.
_LC_SAVED=''
_LC_HAD=0
[[ -f "$_BRAINS_AUTH_LIVE_CREDS" ]] && { _LC_SAVED="$(cat "$_BRAINS_AUTH_LIVE_CREDS")"; _LC_HAD=1; }
_lc_probe() {  # $1 = file content, or '' for an absent file; echoes "<rc>|<stdout>"
  local out rc
  rm -f "$_BRAINS_AUTH_LIVE_CREDS"
  [[ -n "$1" ]] && printf '%s' "$1" > "$_BRAINS_AUTH_LIVE_CREDS"
  out="$(_brains_auth_access_for_live)"; rc=$?
  printf '%s|%s' "$rc" "$out"
}
_FUTURE_MS=$(( ($(date +%s) + 3600) * 1000 ))
_PAST_MS=$(( ($(date +%s) - 3600) * 1000 ))
_is 'live-access.fresh-yields-the-token' '0|sk-ant-oat01-live' \
  "$(_lc_probe "{\"claudeAiOauth\":{\"accessToken\":\"sk-ant-oat01-live\",\"expiresAt\":$_FUTURE_MS}}")"
_is 'live-access.torn-file-is-rc1' '1|' "$(_lc_probe 'not json at all')"
_is 'live-access.absent-file-is-rc2' '2|' "$(_lc_probe '')"
_is 'live-access.no-token-field-is-rc2' '2|' "$(_lc_probe '{"claudeAiOauth":{"expiresAt":1}}')"
_is 'live-access.expired-is-rc3' '3|' \
  "$(_lc_probe "{\"claudeAiOauth\":{\"accessToken\":\"sk-ant-oat01-old\",\"expiresAt\":$_PAST_MS}}")"
# ⚠️ rc 1 and rc 3 must NOT leak a token on stdout. a caller that reads stdout and ignores the
#   rc would otherwise send an EXPIRED token to the api, take a 401, and report a live account
#   as dead — the failure the rc exists to prevent, re-introduced by a sloppy read.
_is 'live-access.expired-withholds-the-token' '3|' \
  "$(_lc_probe "{\"claudeAiOauth\":{\"accessToken\":\"sk-ant-oat01-old\",\"expiresAt\":0}}")"
# an absent expiresAt defaults to 0, which is always past — fail CLOSED, never open
_is 'live-access.absent-expiry-fails-closed' '3|' \
  "$(_lc_probe '{"claudeAiOauth":{"accessToken":"sk-ant-oat01-live"}}')"
# and the freshness computation lives in exactly ONE place — the whole point of the leaf
_is 'live-access.freshness-test-is-single-source' '1' \
  "$(grep -c 'now_ms=\$(( \$(date +%s) \* 1000 ))' "$ALIASES")"
# the restore — after the last probe, in file order (see the warn above the probe)
rm -f "$_BRAINS_AUTH_LIVE_CREDS"
(( _LC_HAD == 1 )) && printf '%s' "$_LC_SAVED" > "$_BRAINS_AUTH_LIVE_CREDS"

# ---- the .bak rescue recipe is single-source, and both framings still render it whole
# ⚠️ these three steps are the ONLY path back for a token that exists nowhere else. two callers
#   walk a human through them — the park failure that CREATES the strand, and the pre-flight
#   refusal that later declines to overwrite it — and they had the steps spelled out twice.
#   a drift would hand one caller's human a recipe that no longer matches the file layout, and
#   they would learn that with the token already gone.
_is 'bakrescue.step1-is-single-source' '1' \
  "$(grep -c '1\. cp \${_BRAINS_AUTH_LIVE_CREDS}\.bak' "$ALIASES")"
_is 'bakrescue.step3-is-single-source' '1' \
  "$(grep -c '3\. rm -f \${_BRAINS_AUTH_LIVE_CREDS}\.bak' "$ALIASES")"
# and BOTH callers must still reach it — a shared leaf that one caller stopped calling is a
# silent loss of the whole recipe, which reads as "the message got shorter", not as a defect
_is 'bakrescue.both-callers-reach-it' '2' \
  "$(grep -c '_brains_auth_say_bak_rescue "' "$ALIASES")"
# each caller keeps its OWN step-2 purpose — that is the argument, and the reason it is one
_bakpurp="$(grep -o '_brains_auth_say_bak_rescue "[^"]*"' "$ALIASES" | sort -u | wc -l)"
_is 'bakrescue.callers-keep-distinct-purposes' '2' "$_bakpurp"

# ---- the active path may never mint, store, or read the keyrack
# ⚠️ this is the invariant the active/parked split exists to protect, and the reason the split
#   is not cosmetic. the ACTIVE account's refresh token is held by an open claude session; a
#   mint here rotates it server-side and logs that session out mid-flight
#   (hazard.claude-oauth-one-holder-per-token.md). while both paths lived under ONE name, a
#   change meant for the parked path could reach the live credentials by accident and no check
#   would object. now it is checkable: the active leaf's body must contain none of these verbs.
_active_body="$(sed -n '/^_brains_auth_node_for_active() {$/,/^}$/p' "$ALIASES")"
_is 'split.active-leaf-exists' 'found' \
  "$([[ -n "$_active_body" ]] && echo found || echo 'ABSENT — the scan below proves no such thing')"
for _verb in _brains_auth_mint_access _brains_auth_set_token _brains_auth_get_token _brains_auth_await_rotation; do
  case "$_active_body" in
    *"$_verb"*) _is "split.active-omits-${_verb}" 'omitted' "PRESENT — it can rotate the live token" ;;
    *)          _is "split.active-omits-${_verb}" 'omitted' 'omitted' ;;
  esac
done
# and the parked leaf DOES mint — otherwise the check above passes on a leaf that acts on none
_parked_body="$(sed -n '/^_brains_auth_node_for_parked() {$/,/^}$/p' "$ALIASES")"
case "$_parked_body" in
  *_brains_auth_mint_access*) _is 'split.parked-still-mints' 'mints' 'mints' ;;
  *)                          _is 'split.parked-still-mints' 'mints' 'ABSENT — the parked path lost its mint' ;;
esac
# the dispatcher reaches BOTH leaves — a split whose branch is unreachable is a silent revert
_disp="$(sed -n '/^_brains_auth_node_for_reach() {$/,/^}$/p' "$ALIASES")"
for _leaf in _brains_auth_node_for_active _brains_auth_node_for_parked; do
  case "$_disp" in
    *"$_leaf"*) _is "split.dispatch-reaches-${_leaf}" 'reached' 'reached' ;;
    *)          _is "split.dispatch-reaches-${_leaf}" 'reached' 'UNREACHABLE' ;;
  esac
done

# ---- install fails, and the rotated token is filed back
# ⚠️ the mint ROTATED the stored token server-side, so the copy still in the keyrack is already
#   dead and the only live value is in memory. to exit here with no write-back would strand
#   the account. this is the recovery narrative that clamps that.
_swap_out="$(_swap_with "$_MINT_GOOD" 1 0 0 2>&1 | _maskdir)"
_swap_with "$_MINT_GOOD" 1 0 0 >/dev/null 2>&1
_code 'swap.install-fails.exit' 1 "$?"
_snap 'swap.install-fails.files-back' "$_swap_out"

# and the worse half: the write-back ALSO fails, so the account really is stranded and the
# message must say so rather than imply a recovery that did not happen
_snap 'swap.install-fails.strands' \
  "$(_swap_with "$_MINT_GOOD" 1 0 1 2>&1 | _maskdir)"

# ---- park-file fails AFTER a successful install
# the swap STANDS here — the new login is live — so this must not exit non-zero. the prior
# account's token is recoverable from the .bak, so the fix is a retry, never a rollback.
_swap_with "$_MINT_GOOD" 0 1 0 >/dev/null 2>&1
_code 'swap.park-fails.exit-is-still-0' 0 "$?"
_snap 'swap.park-fails.warns' "$(_swap_with "$_MINT_GOOD" 0 1 0 2>&1 | _maskdir)"

# ---- the happy path, end to end
_snap 'swap.happy-path' "$(_swap_with "$_MINT_GOOD" 2>&1 | _maskdir)"

# ---- an unrecognized verdict must REFUSE, never fall through into the overwrite
# ⚠️ the authorization `case` had no `*)` arm, and a bash case with no default does not fail —
#   it does no work and falls through. so a verdict this command did not recognize would carry
#   straight on into the keyrack read, the mint, and `_brains_auth_install_creds`: a live
#   credential overwrite performed with NO authorization, on the one command whose entire job
#   is to decide whether an overwrite is safe. the decider emits four verbs today, so the gap
#   is latent — but if it ever stops being latent the cost is a destroyed token, and a latent
#   defect on the highest-blast-radius path is exactly what a clamp is for.
_swap_when_decider_says() {
  (
    eval "_brains_auth_use_decide() { printf '%s' '$1'; }"
    # if the guard is absent, this marker proves control reached the credential overwrite
    eval "_brains_auth_get_token() { printf 'REACHED-THE-MUTATION\n' >&2; printf '%s' '$_ORT'; }"
    eval "_brains_auth_active_reach() { printf '%s' 'moana@x.com'; return 0; }"
    eval "_brains_auth_live_ref()      { printf '%s' '$_ORT'; }"
    eval "_brains_auth_park_read()     { printf '%s' '$_ORT'; return 0; }"
    eval "_brains_auth_mint_access()   { printf '%s' '$_MINT_GOOD'; }"
    eval "_brains_auth_install_creds() { return 0; }"
    eval "_brains_auth_park_file()     { return 0; }"
    eval "_brains_auth_set_token()     { return 0; }"
    eval "_brains_auth_sync_profile()  { return 0; }"
    _brains_auth_use --reach kai@x.com 2>&1
  )
}
_UNK="$(_swap_when_decider_says 'a_verb_from_the_future')"
case "$_UNK" in
  *REACHED-THE-MUTATION*) _is 'swap.unknown-verdict-refuses' 'refused' 'FELL THROUGH to the overwrite' ;;
  *)                      _is 'swap.unknown-verdict-refuses' 'refused' 'refused' ;;
esac
# and it must be a malfunction, not a constraint — a verdict we do not know is OUR defect,
# so a caller must not be sent off to fix its own input
_swap_when_decider_says 'a_verb_from_the_future' >/dev/null 2>&1
_code 'swap.unknown-verdict-is-ours' 1 "$?"
# the guard must not cost us the one verb that DOES authorize the swap. a `*)` arm written
# against the wrong verb name would refuse every real swap — loudly, but universally.
case "$(_swap_when_decider_says 'proceed')" in
  *REACHED-THE-MUTATION*) _is 'swap.proceed-still-proceeds' 'proceeded' 'proceeded' ;;
  *)                      _is 'swap.proceed-still-proceeds' 'proceeded' 'BLOCKED the real swap' ;;
esac

# ---- a stale profile after a successful swap must not report a clean success
# ⚠️ the sync used to end in `|| true`, which threw its rc away: the command closed with a
#   clean tree and exit 0 while `~/.claude.json` still named the PRIOR account. that is not
#   cosmetic — `_brains_auth_whoami` falls back to that very profile whenever the live access
#   token has expired, and that identity gates every later read. so a discarded rc here makes
#   a later `brains.auth.usage` name the wrong account as signed-in, and the one signal that
#   would have warned a caller was the code we dropped.
_swap_with_stale_profile() {
  (
    eval "_brains_auth_active_reach()  { printf '%s' 'moana@x.com'; return 0; }"
    eval "_brains_auth_get_token()     { printf '%s' '$_ORT'; return 0; }"
    eval "_brains_auth_park_read()     { printf '%s' '$_ORT'; return 0; }"
    eval "_brains_auth_live_ref()      { printf '%s' '$_ORT'; }"
    eval "_brains_auth_mint_access()   { printf '%s' '$_MINT_GOOD'; }"
    eval "_brains_auth_install_creds() { return 0; }"
    eval "_brains_auth_park_file()     { return 0; }"
    eval "_brains_auth_set_token()     { return 0; }"
    eval "_brains_auth_sync_profile()  { return 1; }"
    _brains_auth_use --reach kai@x.com
  )
}
_swap_with_stale_profile >/dev/null 2>&1
_code 'swap.stale-profile-exits-nonzero' 1 "$?"
# and the tree must say the swap STILL LANDED — a bare non-zero would read as "swap failed",
# which is the opposite of true and would send a human to re-run a swap that already worked
_snap 'swap.stale-profile.says' "$(_swap_with_stale_profile 2>&1 | _maskdir)"

# ---- the compare-and-swap: ~/.claude changed while the mint was in flight
# ⚠️ this is the one mutation-path race, and its damage is TOTAL and SILENT.
#
#   the interleave: two swaps start while account A is live. the first mints X, installs it,
#   parks A, and shreds the .bak. the second still holds the picture it took at ITS start —
#   it also believes A is live — so when its own mint returns it installs Y straight over X.
#   but X's freshly-rotated token lived in ~/.claude and in no other place: the keyrack copy
#   its mint rotated past is dead, and the .bak the second swap cuts covers X only until that
#   swap's own park shreds it. X is then unreachable without a browser re-auth, and no step in
#   either swap reports a loss.
#
#   a plain `claude /login` in another terminal produces the identical shape, which is why the
#   guard compares the FILE rather than coordinate between our own processes — a lock we hold
#   cannot stop claude itself from touching that file.
_swap_when_live_becomes() {
  # $1 = what ~/.claude holds by the time the install is due ($_ORT = unchanged)
  # $2 = rc of the rotated-token write-back, so the stranded-recovery half is reachable too
  local live_now="$1" src="${2:-0}"
  (
    eval "_brains_auth_active_reach()  { printf '%s' 'moana@x.com'; return 0; }"
    eval "_brains_auth_get_token()     { printf '%s' '$_ORT'; return 0; }"
    eval "_brains_auth_park_read()     { printf '%s' '$_ORT'; return 0; }"
    eval "_brains_auth_live_ref()      { printf '%s' '$live_now'; }"
    eval "_brains_auth_mint_access()   { printf '%s' '$_MINT_GOOD'; }"
    # the observable is whether the overwrite happened AT ALL — a guard that fires but still
    # installs would look identical in the prose, and it is the install that destroys a token
    eval "_brains_auth_install_creds() { echo 'INSTALLED'; return 0; }"
    eval "_brains_auth_park_file()     { return 0; }"
    eval "_brains_auth_set_token()     { return $src; }"
    eval "_brains_auth_sync_profile()  { return 0; }"
    _brains_auth_use --reach kai@x.com
  )
}

# an UNCHANGED file installs — the guard must not fire on the ordinary path
case "$(_swap_when_live_becomes "$_ORT" 2>&1)" in
  *INSTALLED*) _is 'cas.unchanged-installs' 'installed' 'installed' ;;
  *)           _is 'cas.unchanged-installs' 'installed' 'the guard fired on a quiet file' ;;
esac

# a CHANGED file must NOT install. this is the assertion the whole guard exists for.
_cas_out="$(_swap_when_live_becomes 'sk-ant-ort01-somebody-elses-token' 2>&1)"
case "$_cas_out" in
  *INSTALLED*) _is 'cas.changed-refuses-install' 'refused' 'INSTALLED ANYWAY — a token was destroyed' ;;
  *)           _is 'cas.changed-refuses-install' 'refused' 'refused' ;;
esac

# ⚠️ and the abort owes the SAME rotation recovery the install-failure path owes. the mint
#   already rotated our target's token, so a bare `return` here would strand the very account
#   the human asked to swap to — the guard would trade one lost token for another.
case "$_cas_out" in
  *'filed back to the keyrack'*) _is 'cas.abort-refiles-rotation' 'refiled' 'refiled' ;;
  *)                             _is 'cas.abort-refiles-rotation' 'refiled' "stranded: ${_cas_out}" ;;
esac

# a refused swap is a malfunction (1), not a constraint (2): the human typed a valid request
# and did no wrong — the machine's state moved underneath it, and a retry is the fix
_swap_when_live_becomes 'sk-ant-ort01-somebody-elses-token' >/dev/null 2>&1
_code 'cas.changed-exits-1' 1 "$?"

# a login that vanished from where one stood is a change too. the mirror case matters because
# it compares a token against an empty string — the direction a guard written backwards would
# still pass — so this pins that an emptied file aborts as hard as a swapped one.
case "$(_swap_when_live_becomes '' 2>&1)" in
  *INSTALLED*) _is 'cas.vanished-refuses-install' 'refused' 'INSTALLED ANYWAY' ;;
  *)           _is 'cas.vanished-refuses-install' 'refused' 'refused' ;;
esac

# the worse half: the abort's write-back ALSO fails, so the target really is stranded and the
# message must say so rather than imply a recovery that did not happen
_snap 'cas.changed.says' \
  "$(_swap_when_live_becomes 'sk-ant-ort01-somebody-elses-token' 1 2>&1 | _maskdir)"

# ⚠️ .security = the .bak holds the prior account's DURABLE refresh token in the clear. it is
#   shredded the moment the keyrack copy is confirmed, and ONLY then — so a park failure must
#   KEEP it (it is the sole recovery copy) and a park success must REMOVE it. both directions
#   are clamped, because a regression either way is a silent security defect: a leaked secret
#   at rest, or a deleted last copy.
# ⚠️ the fixture is a REAL credentials shape that holds the same token as the live file, and
#   both halves of that matter. it was `printf 'x'` until the strand guard landed, and the
#   suite caught the drift itself: an unparseable `.bak` is now (correctly) treated as a
#   strand, so the swap refused and never reached the park these two cases are about. the
#   token must match the live one for the same reason — a DIFFERENT token is a strand, which
#   is the case the `strand.*` block below owns. here we want the redundant copy: the shape a
#   swap that died between the `cp` and the write leaves behind.
_bak_holds() { printf '{"claudeAiOauth":{"refreshToken":"%s"}}' "$1" > "${_BRAINS_AUTH_LIVE_CREDS}.bak"; }

_bak_holds "$_ORT"
_swap_with "$_MINT_GOOD" 0 0 0 >/dev/null 2>&1
_is 'swap.park-ok.shreds-bak' 'gone' \
  "$([[ -f "${_BRAINS_AUTH_LIVE_CREDS}.bak" ]] && echo 'present' || echo 'gone')"

_bak_holds "$_ORT"
_swap_with "$_MINT_GOOD" 0 1 0 >/dev/null 2>&1
_is 'swap.park-fails.keeps-bak' 'present' \
  "$([[ -f "${_BRAINS_AUTH_LIVE_CREDS}.bak" ]] && echo 'present' || echo 'gone')"
rm -f "${_BRAINS_AUTH_LIVE_CREDS}.bak"

# ---- the SECOND swap, after a park failure left an account in the .bak
# ⚠️ the pair above proves a failed park KEEPS the .bak. what no case proved is what the NEXT
#   swap does to it — and the answer was: destroy it. the install cuts its own .bak with a
#   plain `cp`, so swap #2 overwrote the sole remaining home of swap #1's stranded account,
#   printed a success tree, and reported no loss whatsoever.
#
#   the recovery text made it worse rather than better: it said "rerun to file it", and a rerun
#   walked straight into that `cp`. by then the live account was the one swapped IN, so the
#   rerun parked the wrong account and clobbered the stranded one on the way. the cure was the
#   disease. these clamp both halves of the fix — the refusal, and its precondition.
_bak_swap() {
  # $1 = the refresh token to plant in a leftover .bak
  ( printf '{"claudeAiOauth":{"refreshToken":"%s"}}' "$1" > "${_BRAINS_AUTH_LIVE_CREDS}.bak"
    eval "_brains_auth_active_reach()  { printf '%s' 'moana@x.com'; return 0; }"
    eval "_brains_auth_get_token()     { printf '%s' '$_ORT'; return 0; }"
    eval "_brains_auth_park_read()     { printf '%s' '$_ORT'; return 0; }"
    eval "_brains_auth_live_ref()      { printf '%s' '$_ORT'; }"
    eval "_brains_auth_mint_access()   { printf '%s' '$_MINT_GOOD'; }"
    eval "_brains_auth_install_creds() { echo 'INSTALLED'; return 0; }"
    eval "_brains_auth_park_file()     { return 0; }"
    eval "_brains_auth_sync_profile()  { return 0; }"
    _brains_auth_use --reach kai@x.com 2>&1
    echo "rc=$?" )
}

# a .bak holding a DIFFERENT token than the live one is a strand — refuse, and do not install
_bak_out="$(_bak_swap 'sk-ant-ort01-the-stranded-account')"
case "$_bak_out" in
  *INSTALLED*) _is 'strand.refuses-install' 'refused' 'INSTALLED ANYWAY — a token was destroyed' ;;
  *)           _is 'strand.refuses-install' 'refused' 'refused' ;;
esac
# it is the CALLER's to fix (restore + set), so it is a constraint, never a malfunction
case "$_bak_out" in *'rc=2'*) _is 'strand.exits-2' 2 2 ;; *) _is 'strand.exits-2' 2 "$_bak_out" ;; esac
# and the refusal must hand over a recipe that works — the old text named a rerun that destroyed
case "$_bak_out" in
  *'brains.auth.set'*) _is 'strand.names-the-rescue' 'named' 'named' ;;
  *)                   _is 'strand.names-the-rescue' 'named' "unnamed: ${_bak_out}" ;;
esac

# ⚠️ the precondition, and the half a guard written too broadly would break: a .bak whose token
#   EQUALS the live one is NOT a strand. it comes from a swap that died between the `cp` and the
#   write, so the prior login is still in ~/.claude and the copy is redundant. to refuse on it
#   would wedge every later swap behind a file that guards no token — a guard that bricks the
#   command it protects. this is the case that keeps the guard narrow.
case "$(_bak_swap "$_ORT")" in
  *INSTALLED*) _is 'strand.redundant-bak-still-installs' 'installed' 'installed' ;;
  *)           _is 'strand.redundant-bak-still-installs' 'installed' 'refused on a redundant copy' ;;
esac
rm -f "${_BRAINS_AUTH_LIVE_CREDS}.bak"

# ---- a CORRUPT credentials file must not read as an ABSENT one
# ⚠️ every reader of this file muted jq and returned the empty string, so a torn file gave the
#   identical answer to a file that was never written — and each reader had justified the mute
#   with the absent case alone. the corrupt case rode along underneath, and it pointed the
#   wrong way at both consumers:
#     · the CAS probe read empty, compared unequal, and blamed a concurrent writer for a
#       corruption the read had hidden — so the human hunts a second terminal that is not there.
#     · the strand check read empty, said "not a strand", and let the swap overwrite a `.bak`
#       that may hold a real account's last token — the hole the strand guard exists to close,
#       re-opened through another door.
#   the reader now separates them by RC, and these pin both halves.
_corrupt="${_BRAINS_AUTH_LIVE_CREDS}.corrupt.json"
printf '{"claudeAiOauth":{' > "$_corrupt"          # truncated mid-object: real, and unparseable
_is 'creds.corrupt-is-rc1' 1 "$(_brains_auth_creds_field "$_corrupt" '.claudeAiOauth.refreshToken'; echo $?)"
_is 'creds.absent-is-rc0'  0 "$(_brains_auth_creds_field "${_BRAINS_AUTH_LIVE_CREDS}.nope" '.x'; echo $?)"
# a VALID file that simply lacks the key is rc 0 too — that is an answer, not a failure
printf '{"other":1}' > "$_corrupt.ok"
_is 'creds.absent-key-is-rc0' 0 "$(_brains_auth_creds_field "$_corrupt.ok" '.claudeAiOauth.refreshToken'; echo $?)"
rm -f "$_corrupt.ok"

# and the consequence that matters: an unreadable `.bak` counts as a strand, so the swap
# REFUSES. the two mistakes are not symmetric — to call it redundant destroys a token we could
# not read; to call it a strand costs one refusal the human can clear by hand.
cp "$_corrupt" "${_BRAINS_AUTH_LIVE_CREDS}.bak"
case "$( ( eval "_brains_auth_live_ref() { printf '%s' '$_ORT'; }"
           _brains_auth_bak_strands && echo 'strand' || echo 'redundant' ) )" in
  strand) _is 'strand.unreadable-bak-refuses' 'strand' 'strand' ;;
  *)      _is 'strand.unreadable-bak-refuses' 'strand' 'called it redundant — would overwrite' ;;
esac
rm -f "${_BRAINS_AUTH_LIVE_CREDS}.bak" "$_corrupt"

# ---- and the two readers that DEGRADE rather than refuse must still SAY they degraded
# ⚠️ both of these pick a safe fallback and carry on, which is right — a torn file must not
#   brick a read or a swap. what makes them failhides is silence, and the silence is worse than
#   the fallback in each case:
#     · whoami falls through to the PROFILE file, which can name a different account than the
#       live token; the human reads a name with no way to know it came from the stale source.
#     · install_creds starts the new file EMPTY, so any key claude kept beside .claudeAiOauth is
#       minted away — a real loss, reported by no one.
#   these clamp the report, not its text: a reworded sentence still passes, a MUTED one does not.
_saved_creds="$(cat "$_BRAINS_AUTH_LIVE_CREDS")"
_saved_prof="$(cat "$_BRAINS_AUTH_LIVE_PROFILE")"
printf '{"claudeAiOauth":{' > "$_BRAINS_AUTH_LIVE_CREDS"   # truncated mid-object
# the profile is seeded rather than assumed — earlier cases in this file rewrite it, and a
# clamp whose verdict depends on what ran before it is a clamp that reports the wrong thing
printf '{"oauthAccount":{"accountUuid":"u-stale","emailAddress":"stale@ehmpathy.com"}}' \
  > "$_BRAINS_AUTH_LIVE_PROFILE"

case "$( ( curl() { return 7; }; _brains_auth_whoami 'ua/1' ) 2>&1 >/dev/null )" in
  *'could not be parsed'*) _is 'failhide.whoami-says-it-degraded' 'said' 'said' ;;
  *)                       _is 'failhide.whoami-says-it-degraded' 'said' 'MUTED — stale name, no signal' ;;
esac
# ...and it must still ANSWER (from the profile), by the UNVERIFIED door — a refusal here would
# leave `brains.auth.usage` unable to even label the active row on a torn file, while a
# VERIFIED answer would let that stale name authorize a swap
_is 'failhide.whoami-still-answers-unverified' '2' \
  "$( ( curl() { return 7; }; _brains_auth_whoami 'ua/1' >/dev/null 2>&1; echo $? ) )"

case "$( ( _brains_auth_install_creds 'kai@ehmpathy.com' 'acc' "$_ORT" 3600 '' 'max' ) 2>&1 >/dev/null )" in
  *'could not be parsed'*) _is 'failhide.install-says-keys-dropped' 'said' 'said' ;;
  *)                       _is 'failhide.install-says-keys-dropped' 'said' 'MUTED — foreign keys gone quietly' ;;
esac

# ---- the PROFILE read is the third of the family, and its mislabel is the subtlest
# a torn profile reads empty, so whoami returns 1 = "unknown identity" — which is what a
# machine that never signed in returns too. the outcome is fail-safe either way (an unknown
# identity authorizes no act), but the human is told no login was found while a login record
# sat right there, unreadable.
printf '{"oauthAccount":{' > "$_BRAINS_AUTH_LIVE_PROFILE"      # truncated mid-object
case "$( ( curl() { return 7; }; _brains_auth_whoami 'ua/1' ) 2>&1 >/dev/null )" in
  *"$_BRAINS_AUTH_LIVE_PROFILE"*'could not be parsed'*)
    _is 'failhide.profile-says-it-degraded' 'said' 'said' ;;
  *) _is 'failhide.profile-says-it-degraded' 'said' 'MUTED — reads as never signed in' ;;
esac
# and the verdict must still be UNKNOWN (rc 1), never a name — a torn profile has no answer
# to give, and an answer invented from it would be the failure the ladder exists to prevent
_is 'failhide.profile-torn-is-unknown' '1' \
  "$( ( curl() { return 7; }; _brains_auth_whoami 'ua/1' >/dev/null 2>&1; echo $? ) )"
printf '%s' "$_saved_creds" > "$_BRAINS_AUTH_LIVE_CREDS"
printf '%s' "$_saved_prof"  > "$_BRAINS_AUTH_LIVE_PROFILE"
rm -f "${_BRAINS_AUTH_LIVE_CREDS}.bak"

# ---------------------------------------------------------------- the help text
# `--help` is the one surface a human reads BEFORE they know how the command behaves, so a
# drift here misleads at the worst moment — and it is pure text, which means no other check
# in this suite would ever notice. both streams are captured, because a flag that migrated
# between stdout and stderr would break a `--help | grep` in a caller's own shell.
for _cmd in usage set use; do
  _snap "help.${_cmd}" "$("_brains_auth_${_cmd}" --help 2>&1)"
done

# ---------------------------------------------------------------- the mint accessor
# the mint node's shape is known to exactly one leaf that builds it and one that reads it.
# this pins the read half, because its two edge cases are both credential-loss shaped: an
# absent field that reads as the literal "null" would pass a `[[ -z ]]` test and be FILED to
# the keyrack as though it were a token, and a `false` flattened to empty would read as an
# absent verdict rather than a failed one.
_MINT_OK='{"ok":true,"error":null,"code":200,"access":"A","refresh":"R","ttl":3600,"scopes":"","kind":"max"}'
_MINT_BAD='{"ok":false,"error":"refresh_rejected","code":401}'

_is 'mint.reads-string'        'R'                 "$(_brains_auth_mint_field "$_MINT_OK" refresh)"
_is 'mint.reads-number'        '3600'              "$(_brains_auth_mint_field "$_MINT_OK" ttl)"
_is 'mint.null-is-empty'       ''                  "$(_brains_auth_mint_field "$_MINT_OK" error)"
_is 'mint.absent-is-empty'     ''                  "$(_brains_auth_mint_field "$_MINT_BAD" access)"
_is 'mint.keeps-false'         'false'             "$(_brains_auth_mint_field "$_MINT_BAD" ok)"
_is 'mint.reads-true'          'true'              "$(_brains_auth_mint_field "$_MINT_OK" ok)"
_is 'mint.reads-error'         'refresh_rejected'  "$(_brains_auth_mint_field "$_MINT_BAD" error)"
_is 'mint.unparseable-is-empty' ''                 "$(_brains_auth_mint_field 'not json' access)"

# ---- what a non-200 mint reply is CLASSIFIED as, and what `.code` is allowed to claim
# ⚠️ the 5xx row is the one that misdirected. every non-429 non-200 landed in
#   `refresh_rejected` — a CONSTRAINT whose hint is "refresh token dead (run: brains.auth.set)"
#   — so a transient anthropic outage told a human their credential was dead and sent them
#   through a browser re-auth to repair someone else's server, while a cron read a permanent
#   verdict for a fault that clears itself. a 4xx genuinely IS a dead token; a 5xx never is.
_mint_for_http() {
  ( eval "_brains_auth_refresh_reply() { printf '%s\n$1' '{}'; }"
    _brains_auth_mint_access 'ua/1' 'tok' )
}
for _hc in "401:refresh_rejected" "429:refresh_rate_limited" \
           "500:refresh_server_error" "503:refresh_server_error"; do
  _c="${_hc%%:*}"; _e="${_hc##*:}"
  _is "mint.http-${_c}-is-${_e}" "$_e" \
    "$(_brains_auth_mint_field "$(_mint_for_http "$_c")" error)"
done
# and the split must earn its keep at the SEVERITY table, which is where it reaches the human
_is 'mint.server-error-is-ours' 'malfunction|constraint' \
  "$(_brains_auth_severity_for_error refresh_server_error)|$(_brains_auth_severity_for_error refresh_rejected)"

# ⚠️ `.code` means "the http status of the exchange that produced this verdict", and a caller
#   may branch on it to split a dead token from a transient fault. the decode-failure fallback
#   used to claim `200` — a healthy exchange asserted over a body we could not read, which is
#   a lie in the one field that exists to be trusted. 0 is what "no status obtained" already
#   means here (`refresh_curl_failed` uses it), and it is the truth for a verdict about an
#   unreadable body.
_unreadable_mint="$( ( eval "_brains_auth_refresh_reply() { printf '%s\n200' 'NOT JSON {{'; }"
                       _brains_auth_mint_access 'ua/1' 'tok' ) )"
_is 'mint.unreadable-body-is-named' 'refresh_unreadable' \
  "$(_brains_auth_mint_field "$_unreadable_mint" error)"
_is 'mint.unreadable-body-claims-no-200' '0' \
  "$(_brains_auth_mint_field "$_unreadable_mint" code)"

# ---- the error-node writer, the accessor's other half
# eleven early returns emit a failure node, and one of them used to interpolate a variable
# into a hand-built JSON string. that was latent — the value only ever came from a fixed
# literal set — but the round trip is what makes the invariant checkable rather than argued,
# so it is pinned against a value that WOULD have broken the template.
_is 'errnode.round-trips' 'no_token' \
  "$(_brains_auth_get_error "$(_brains_auth_error_node 'no_token')")"
# ⚠️ a quote in the code must not escape the string. under the old template this emitted
#   `{"error":"a"b"}` — unparseable, so `_brains_auth_get_error` returned EMPTY, and an empty
#   error reads as a HEALTHY account. a malformed node did not look like a failure; it looked
#   like a success, which is the exact worst direction for a budget-warning tool.
_is 'errnode.escapes-quotes' 'a"b' \
  "$(_brains_auth_get_error "$(_brains_auth_error_node 'a"b')")"

# ---- the sign-in state reader, and the three causes it used to flatten into one
# `_brains_auth_extract_refresh` once muted BOTH streams, so three separate causes all read
# as "empty": no state file at all, a state file we cannot parse, and a state file that
# simply held no ort-shaped value. only the third is benign, yet the caller reported the same
# hint for all three — "did the browser approval complete?" — which sends a human back to redo
# a login that already succeeded. the exit code now names each cause; this pins that it does.
_XDIR="$(mktemp -d)"

# rc 1 = neither file was there. the sign-in wrote no state at all.
_out="$(_brains_auth_extract_refresh "$_XDIR")"; _rc=$?
_is 'extract.no-files.rc'   '1'  "$_rc"
_is 'extract.no-files.out'  ''   "$_out"

# rc 2 = a file IS there but does not parse. a DIFFERENT fix from rc 1, and the one the mute
# hid most expensively: the sign-in succeeded and persisted a shape we do not recognize, so
# the honest report is "unparseable", never "did you finish the browser flow?"
printf 'not json at all' | tee "$_XDIR/.claude.json" >/dev/null
_out="$(_brains_auth_extract_refresh "$_XDIR" 2>/dev/null)"; _rc=$?
_is 'extract.unparseable.rc'  '2'  "$_rc"
# ⚠️ and the cause must REACH the human, not merely set an exit code. the muted jq error was
#   the only evidence of what shape the sign-in actually wrote.
_err="$(_brains_auth_extract_refresh "$_XDIR" 2>&1 >/dev/null)"
case "$_err" in
  *'could not be parsed'*) _is 'extract.unparseable.says' 'said' 'said' ;;
  *)                       _is 'extract.unparseable.says' 'said' "silent: ${_err}" ;;
esac

# rc 0 = it parsed. the benign absence — valid state that holds no ort-shaped value — is the
# ONLY outcome a caller may report as "the approval may not have completed".
printf '{"other":"sk-ant-oat01-nope"}' | tee "$_XDIR/.claude.json" >/dev/null
_out="$(_brains_auth_extract_refresh "$_XDIR")"; _rc=$?
_is 'extract.parsed-no-token.rc'   '0'  "$_rc"
_is 'extract.parsed-no-token.out'  ''   "$_out"

# rc 0 WITH the value — the happy read, so the clamp discriminates rather than merely
# rejects every input it is handed.
printf '{"refreshToken":"sk-ant-ort01-yes"}' | tee "$_XDIR/.claude.json" >/dev/null
_out="$(_brains_auth_extract_refresh "$_XDIR")"; _rc=$?
_is 'extract.parsed-with-token.rc'   '0'                 "$_rc"
_is 'extract.parsed-with-token.out'  'sk-ant-ort01-yes'  "$_out"

rm -rf "$_XDIR"

# ---- the concurrency retry, and the two narratives it must tell apart
# a refresh ROTATES the stored token server-side, so two overlapped sweeps of one reach both
# mint from the same value and the loser's mint is rejected. with no retry, a perfectly
# healthy account rendered "refresh token dead (run: brains.auth.set)" and sent the human
# through a full browser re-auth to repair a race. the retry rests on EVIDENCE, never on a
# clock: re-read the keyrack, and a CHANGED stored value proves another holder rotated it.
_ROTATED='sk-ant-ort01-rotated-by-the-other-sweep'

# .what = drive _brains_auth_node_for_reach's mint path with a scripted token + mint sequence
# .why  = the race needs two DIFFERENT answers from two calls to each leaf, which a static
#   stub cannot give. a counter file makes the sequence explicit and inspectable.
_race_with() {
  local first_token="$1" second_token="$2" second_ok="$3" seq="$_SWAPDIR/race.seq"
  rm -f "$seq" "$seq.m"
  # ⚠️ the second mint node goes through a FILE, never through the eval string. it is json,
  #   so it carries double quotes, and an interpolation into a double-quoted `printf` inside
  #   an eval closes the quote early — which made both retry cases read `refresh_unreadable`
  #   (an empty mint node) rather than the answer under test.
  printf '%s' "$second_ok" > "$seq.node"
  (
    # the poll's WAIT is zeroed for the suite. these clamps pin how many times the evidence is
    # re-read, never how long the gaps are — a wall-clock assertion would make the suite slow
    # and flaky at once, and would pin a tunable constant as if it were a contract.
    _BRAINS_AUTH_RACE_WAIT=0
    eval "_brains_auth_identity_is_actionable() { return 0; }"
    # call 1 hands out the pre-race token; call 2 (the re-read) hands out the second one
    eval '_brains_auth_get_token() {
            local n; n="$(cat "'"$seq"'" 2>/dev/null || echo 0)"; echo $(( n + 1 )) > "'"$seq"'"
            (( n == 0 )) && { printf %s "'"$first_token"'"; return 0; }
            printf %s "'"$second_token"'"; return 0
          }'
    # the first mint always loses the race; the second reflects whether the retry succeeded
    eval '_brains_auth_mint_access() {
            local m; m="$(cat "'"$seq"'.m" 2>/dev/null || echo 0)"; echo $(( m + 1 )) > "'"$seq"'.m"
            (( m == 0 )) && { printf %s '"'"'{"ok":false,"error":"refresh_rejected","code":401}'"'"'; return; }
            cat "'"$seq"'.node"
          }'
    eval "_brains_auth_node_via_access() { printf '%s' '{\"five_hour\":{},\"seven_day\":{}}'; }"
    eval "_brains_auth_set_token()       { return 0; }"
    _brains_auth_node_for_reach 'UA' 'kai@x.com' '' 0
  )
}
_MINT_OK2='{"ok":true,"code":200,"access":"A2","refresh":"R3","ttl":3600,"scopes":"","kind":"max"}'

# narrative 1 — a CONCURRENT sweep rotated the token. the stored value changed, so the retry
# fires and the account reads healthy. that is the whole point: no human act was ever needed.
_is 'race.rotated-token-recovers' '' \
  "$(_brains_auth_get_error "$(_race_with "$_ORT" "$_ROTATED" "$_MINT_OK2")")"

# narrative 2 — the token is GENUINELY dead. the keyrack still holds the same value, so no
# retry fires and the human is correctly sent to re-auth.
# ⚠️ this is the half that makes the clamp discriminate. a retry that fired unconditionally
#   would also pass narrative 1, while it doubled every dead-token read and told the human
#   the same answer at twice the cost.
_is 'race.unchanged-token-stays-dead' 'refresh_rejected' \
  "$(_brains_auth_get_error "$(_race_with "$_ORT" "$_ORT" "$_MINT_OK2")")"

# narrative 3 — rotated AND the retry still fails. a rotation is not a free pass; if the new
# value is dead too, the failure must still surface rather than be swallowed by the retry.
_is 'race.retry-failure-still-surfaces' 'refresh_rejected' \
  "$(_brains_auth_get_error "$(_race_with "$_ORT" "$_ROTATED" \
     '{"ok":false,"error":"refresh_rejected","code":401}')")"

# narrative 4 — the winner's WRITE-BACK IS LATE. this is the window a single re-read could not
# see, and it condemns a live account:
#     t0  both sweeps read T          t1  the winner mints; the server rotates T -> T2
#     t2  the loser mints with T and is REJECTED (T is spent)
#     t3  the winner finally writes T2 to the keyrack
# a re-read taken at t2 lands in t2..t3 and still sees T — "no one raced me" — so the account
# renders "refresh token dead (run: brains.auth.set)" and a human is sent through a browser
# re-auth to repair a race. the fixture hands out T on the FIRST re-read and T2 only on the
# second, so it reproduces exactly that gap.
_race_with_late_writeback() {
  local seq="$_SWAPDIR/race.late"
  rm -f "$seq" "$seq.m"
  printf '%s' "$_MINT_OK2" > "$seq.node"
  (
    _BRAINS_AUTH_RACE_WAIT=0
    eval "_brains_auth_identity_is_actionable() { return 0; }"
    # call 1 = the pre-mint read; call 2 = the re-read that lands IN the gap (still old);
    # call 3 = the re-read after the winner's write-back finally lands
    eval '_brains_auth_get_token() {
            local n; n="$(cat "'"$seq"'" 2>/dev/null || echo 0)"; echo $(( n + 1 )) > "'"$seq"'"
            (( n <= 1 )) && { printf %s "'"$_ORT"'"; return 0; }
            printf %s "'"$_ROTATED"'"; return 0
          }'
    eval '_brains_auth_mint_access() {
            local m; m="$(cat "'"$seq"'.m" 2>/dev/null || echo 0)"; echo $(( m + 1 )) > "'"$seq"'.m"
            (( m == 0 )) && { printf %s '"'"'{"ok":false,"error":"refresh_rejected","code":401}'"'"'; return; }
            cat "'"$seq"'.node"
          }'
    eval "_brains_auth_node_via_access() { printf '%s' '{\"five_hour\":{},\"seven_day\":{}}'; }"
    eval "_brains_auth_set_token()       { return 0; }"
    _brains_auth_node_for_reach 'UA' 'kai@x.com' '' 0
  )
}
_is 'race.late-writeback-still-recovers' '' \
  "$(_brains_auth_get_error "$(_race_with_late_writeback)")"

# ---- the retry loop must not multiply keyrack subprocesses
# ⚠️ the unlock used to sit inside `_brains_auth_get_token`, and that call is NOT once per
#   account: the rotation-race recovery above re-reads the token up to `_BRAINS_AUTH_RACE_TRIES`
#   more times. so a `--reach @all` sweep over N dead accounts spawned up to 4N
#   `rhx keyrack unlock` subprocesses to read N secrets, and the extra 3N bought no information
#   at all — the unlock is idempotent and holds for the rest of the command.
#   that is not a tidiness point on this machine: a keyrack-daemon accumulation once filled
#   zram and drove the desktop into disk-swap thrash. and the multiplier peaks on DEAD
#   accounts — exactly the state a human re-reads over and over while they repair them.
#   this counts the REAL unlocks across a run that takes the retry path three times.
_unlocks_during_a_retried_read() {
  local tally="$_SWAPDIR/unlock.tally"
  rm -f "$tally"; printf '0' > "$tally"
  (
    _BRAINS_AUTH_RACE_WAIT=0
    _brains_auth_unlock_reset
    # count the calls that would have become `rhx keyrack unlock` subprocesses
    eval 'rhx() {
            [[ "$1" == keyrack && "$2" == unlock ]] && {
              local n; n="$(cat "'"$tally"'")"; echo $(( n + 1 )) > "'"$tally"'"
            }
            return 0
          }'
    # the read itself is stubbed at the leaf below the unlock, so only the unlock is measured
    eval "_brains_auth_creds_field() { printf ''; return 0; }"
    _brains_auth_get_token 'kai@x.com' >/dev/null 2>&1
    _brains_auth_get_token 'kai@x.com' >/dev/null 2>&1
    _brains_auth_get_token 'kai@x.com' >/dev/null 2>&1
    _brains_auth_get_token 'kai@x.com' >/dev/null 2>&1
  )
  cat "$tally"
}
_is 'unlock.retries-do-not-multiply' '1' "$(_unlocks_during_a_retried_read)"

# a SECOND account in the same sweep still gets its own unlock — the memo is per reach, not a
# blanket "already unlocked once". a memo that skipped account two would read a locked key and
# report `keyrack_unreadable` for an account that was never given its unlock.
_unlocks_across_two_reaches() {
  local tally="$_SWAPDIR/unlock.tally2"
  rm -f "$tally"; printf '0' > "$tally"
  (
    _brains_auth_unlock_reset
    eval 'rhx() {
            [[ "$1" == keyrack && "$2" == unlock ]] && {
              local n; n="$(cat "'"$tally"'")"; echo $(( n + 1 )) > "'"$tally"'"
            }
            return 0
          }'
    eval "_brains_auth_creds_field() { printf ''; return 0; }"
    _brains_auth_get_token 'kai@x.com'   >/dev/null 2>&1
    _brains_auth_get_token 'moana@x.com' >/dev/null 2>&1
    _brains_auth_get_token 'kai@x.com'   >/dev/null 2>&1
  )
  cat "$tally"
}
_is 'unlock.each-reach-gets-its-own' '2' "$(_unlocks_across_two_reaches)"

# and the memo must NOT outlive one command. an unlock has a ~9h TTL, so a memo that survived
# in a long-lived interactive shell would skip an unlock the keyrack has since re-locked — and
# the read would then fail as `keyrack_unreadable`, whose hint names the very unlock we chose
# to skip. a self-inflicted error with a hint that reads like a lie.
_unlocks_after_a_reset() {
  local tally="$_SWAPDIR/unlock.tally3"
  rm -f "$tally"; printf '0' > "$tally"
  (
    _brains_auth_unlock_reset
    eval 'rhx() {
            [[ "$1" == keyrack && "$2" == unlock ]] && {
              local n; n="$(cat "'"$tally"'")"; echo $(( n + 1 )) > "'"$tally"'"
            }
            return 0
          }'
    eval "_brains_auth_creds_field() { printf ''; return 0; }"
    _brains_auth_get_token 'kai@x.com' >/dev/null 2>&1
    _brains_auth_unlock_reset   # a new command begins
    _brains_auth_get_token 'kai@x.com' >/dev/null 2>&1
  )
  cat "$tally"
}
_is 'unlock.reset-restores-the-unlock' '2' "$(_unlocks_after_a_reset)"

# ---- the two keyrack failures, and why they must never share a node
# a keyrack read fails for two causes with OPPOSITE fixes: the key was never stored (a human
# runs `brains.auth.set`), or the keyrack could not be read at all — locked, no daemon, no host
# manifest (a sign-in is powerless; an unlock or a retry is the move). they used to share one
# `keyrack_failed` node, classified `constraint`, hinted "not stored yet (run: brains.auth.set)".
# so a locked keyrack sent the human through a browser flow that could not fix it, and an
# automated consumer read a transient fault as permanent and never retried.
_is 'keyrack.absent-is-the-callers'     'constraint'  "$(_brains_auth_severity_for_error keyrack_absent)"
_is 'keyrack.unreadable-is-ours'        'malfunction' "$(_brains_auth_severity_for_error keyrack_unreadable)"
# ⚠️ and the hint TEXTS must differ, not merely the severities. one text for both would send
#   the human to the wrong command while the exit code quietly said the right one.
# ⚠️ the glyph is STRIPPED before the compare, and that is the point. the first draft of this
#   clamp compared the whole hint and stayed GREEN under a deliberate collapse — because the
#   severities already differ, the two glyphs differ, so two identical texts still compared as
#   "different". a clamp that cannot go red is a guess; this one compares only the words.
# ⚠️ the strip is `${x#* }` (drop through the first space), NOT `cut -c3-`. the second draft
#   used cut and ALSO stayed green: cut counts BYTES, and ✋ is three bytes while 💥 is four, so
#   two identical texts still compared as different by their glyph remnants. two drafts of this
#   one clamp failed to bite for two different reasons — which is the whole argument for the
#   dogfood step rather than a reasoned "this looks right".
_kra_full="$(_brains_auth_fix_for_error keyrack_absent)";     _kra="${_kra_full#* }"
_kru_full="$(_brains_auth_fix_for_error keyrack_unreadable)"; _kru="${_kru_full#* }"
_is 'keyrack.hint-texts-differ' 'differ' \
  "$([[ "$_kra" != "$_kru" ]] && echo differ || echo same)"
# the unreadable hint must name the UNLOCK, since that is the move that can actually work
case "$(_brains_auth_fix_for_error keyrack_unreadable)" in
  *'keyrack unlock'*) _is 'keyrack.unreadable-names-the-unlock' 'named' 'named' ;;
  *) _is 'keyrack.unreadable-names-the-unlock' 'named' \
       "$(_brains_auth_fix_for_error keyrack_unreadable)" ;;
esac

# ---- and the classification that PRODUCES those two nodes, not merely the table that grades them
# ⚠️ the four cases above clamp the severity TABLE. they do not touch `_brains_auth_get_token`,
#   which is the code that decides WHICH of the two an account gets — so the table could stay
#   perfect while the decision that feeds it broke, and every case above would stay green. this
#   was proven: the classification was rewritten from a stderr-prose match to an exit-code read
#   and the whole suite passed unchanged, which is not a pass, it is an absence of coverage.
#
# .what it pins: keyrack's EXIT CODE decides the class. 2 = the key was never stored (the
#   caller's, fixed by a sign-in). anything else non-zero = the keyrack could not be read
#   (ours, fixed by an unlock or a retry).
# .why it must not read the prose: keyrack's wording is unversioned and lives in another repo.
#   a copy-edit there would silently flip an absent key into a malfunction, and the human would
#   be told to unlock a keyrack that is already open, for an account that was never stored.
#
# .note = the seam replaces `rhx` itself, so both the unlock and the get are stubbed. the stub
#   emits on stderr the same shape keyrack does, which lets the third case prove the
#   passthrough without a real keyrack.
_token_rc_when_keyrack_exits() {
  local code="$1"
  (
    eval "rhx() { [[ \$2 == unlock ]] && return 0; echo 'keyrack: the daemon is not up' >&2; return $code; }"
    _brains_auth_get_token 'kai@ehmpathy.com' >/dev/null 2>&1
  )
}
_token_rc_when_keyrack_exits 2; _is 'gettoken.exit2-is-absent'     '2' "$?"
_token_rc_when_keyrack_exits 1; _is 'gettoken.exit1-is-unreadable' '1' "$?"
# ⚠️ an exit code keyrack has never emitted must NOT read as "absent". an unknown fault is ours
#   until proven otherwise — the opposite default would hand the human a sign-in for a cause a
#   sign-in cannot touch, which is the exact defect the two-node split exists to end.
_token_rc_when_keyrack_exits 7; _is 'gettoken.unknown-exit-is-ours' '1' "$?"
# the malfunction path passes keyrack's OWN words through, because our hint for it is generic
# while keyrack knows which of daemon / lock / manifest failed. the absent path does not — our
# hint for that one is already exact, so a passthrough would be noise once per account.
_gt_says() {
  (
    eval "rhx() { [[ \$2 == unlock ]] && return 0; echo 'keyrack: the daemon is not up' >&2; return $1; }"
    _brains_auth_get_token 'kai@ehmpathy.com' 2>&1 >/dev/null
  )
}
case "$(_gt_says 1)" in
  *'daemon is not up'*) _is 'gettoken.unreadable-passes-cause-through' 'through' 'through' ;;
  *)                    _is 'gettoken.unreadable-passes-cause-through' 'through' "swallowed: $(_gt_says 1)" ;;
esac
_is 'gettoken.absent-stays-quiet' '' "$(_gt_says 2)"

# ---------------------------------------------------------------- the hang guard
# a `--flag` with no value made `shift 2` a NO-OP, and the loop spun forever in silence.
# every arg parser in the namespace carries a value guard against it; this clamps that the
# guard is real. `timeout` is what makes it a clamp rather than a hope — without it, a
# regression would HANG this suite instead of fail it.
# all SEVEN entry points are clamped, not a sample.
# ⚠️ these cases no longer clamp seven independent copies of the guard — they clamp that each
#   entry point still ROUTES to the one copy that owns it. the guard was hand-rolled at every
#   entry point when these cases were written; it is now two shared definitions:
#     the three orchestrators   -> `_brains_auth_reach_from_flag`   (src/brains.auth.sh)
#     the three proxies + this  -> `brains.auth.bootstrap.sh`       (this dir)
#   the per-entry-point case is still the right shape after that consolidation, because the
#   failure mode simply moved: a future edit that re-inlines a parse in ONE command restores
#   the hang in that one command alone, and only a per-command case would catch it.
timeout 5 bash -c "source '$ALIASES'; _brains_auth_usage --reach" >/dev/null 2>&1
_code 'guard.usage.reach-without-value' 2 "$?"
timeout 5 bash -c "source '$ALIASES'; _brains_auth_use --reach" >/dev/null 2>&1
_code 'guard.use.reach-without-value' 2 "$?"
timeout 5 bash -c "source '$ALIASES'; _brains_auth_set --reach" >/dev/null 2>&1
_code 'guard.set.reach-without-value' 2 "$?"

# ---------------------------------------------------------------- a MALFORMED --reach value
# ⚠️ the pair to the guard above, and the more likely of the two in real use: a flag with no
#   value is a fumble, but a mistyped email is a Tuesday. `_brains_auth_is_reach` had its own
#   snapshot (`reach.shape`) and all three commands DO validate — but no case ever drove a bad
#   value through an entry point, so the leaf was proven while the wiring was assumed.
#   that is the exact "leaf tested ⇒ wiring untested" gap this file caught and closed twice
#   already (`node_for_reach`, `access_for_live`); it had simply never been applied to itself.
# .note = a bare slug is the shape that matters most. under the retired `--sub` scheme it was
#   the CORRECT input, so it is what muscle memory still types — and with no shape check it
#   would sail past as a keyrack miss and report "never stored" for an account that is.
for _cmd in usage use set; do
  timeout 5 bash -c "source '$ALIASES'; _brains_auth_${_cmd} --reach vlad" >/dev/null 2>&1
  _code "reachshape.${_cmd}.bare-slug-exits-2" 2 "$?"
done
# and each refusal must NAME the shape it wants — a bare "invalid" leaves the human to guess
# whether the account, the spelling, or the flag is at fault
for _cmd in usage use set; do
  _out="$(timeout 5 bash -c "source '$ALIASES'; _brains_auth_${_cmd} --reach vlad" 2>&1 >/dev/null)"
  case "$_out" in
    *email*) _is "reachshape.${_cmd}.names-the-shape" 'named' 'named' ;;
    *)       _is "reachshape.${_cmd}.names-the-shape" 'named' "silent about email: ${_out}" ;;
  esac
done
# a value that merely LOOKS close must still be refused — the check is about shape, so an
# address with no dot in the domain is exactly the near-miss a typo produces
timeout 5 bash -c "source '$ALIASES'; _brains_auth_usage --reach vlad@ahbode" >/dev/null 2>&1
_code 'reachshape.usage.no-dot-exits-2' 2 "$?"
# ⚠️ and `@all` must SURVIVE the shape check on the one command that accepts it. a check
#   tightened without this case would refuse the default sweep — the most common invocation
#   in the namespace — and every clamp above would still pass.
timeout 5 bash -c "source '$ALIASES'; _brains_auth_usage --reach @all --help" >/dev/null 2>&1
_code 'reachshape.usage.at-all-is-not-refused' 0 "$?"

# ---------------------------------------------------------------- set with no tty
# ⚠️ every other `set` case STUBS `_brains_auth_login_isolated` out, so the one line that needs
#   a real terminal had never been executed by this suite at all. `</dev/tty` with no tty is a
#   bare redirection failure, and the empty result then read as "no refresh token captured (did
#   the browser approval complete?)" — a human sent to redo a sign-in that never started, with
#   a retry that cannot work, because the fault is the context.
# .note = `setsid` is what makes this a real clamp rather than a mock: it detaches the child
#   from its terminal, so the guard meets the true condition instead of a stand-in for it.
#   this is the ONE case that runs the leaf unstubbed.
_notty() {  # run $1 detached from any tty; echoes "<rc>|<stderr>"
  local out rc
  out="$(setsid timeout 5 bash -c "source '$ALIASES'; $1" 2>&1 >/dev/null)"; rc=$?
  printf '%s|%s' "$rc" "$out"
}
_nt="$(_notty '_brains_auth_login_isolated /tmp')"
_code 'notty.login-leaf-refuses-with-3' 3 "${_nt%%|*}"
case "${_nt#*|}" in
  *'needs a real terminal'*) _is 'notty.login-leaf-names-the-cause' 'named' 'named' ;;
  *) _is 'notty.login-leaf-names-the-cause' 'named' "wrong cause: ${_nt#*|}" ;;
esac
# ⚠️ and it must say the login did NOT start. that clause is the whole repair: without it a
#   human still reasonably reads the failure as "my sign-in did not take" and retries it.
case "${_nt#*|}" in
  *'was NOT started'*) _is 'notty.login-leaf-says-it-never-ran' 'said' 'said' ;;
  *) _is 'notty.login-leaf-says-it-never-ran' 'said' "silent — reads as a failed login" ;;
esac
# the caller must HONOR that rc rather than fall through to the extract's absent-token message.
# ⚠️ asserted POSITIVELY — "the tty cause reaches the surface" — not negatively as "the browser
#   message is absent". the first draft did the latter and stayed GREEN with the guard defeated,
#   because an absent string is also absent when the path never reaches that line at all. a
#   negative assertion cannot tell "the bug is fixed" from "the code never ran", which is the
#   failhide shape hazard.a-clamp-can-lie-the-same-way-code-can.md names.
_nts="$(_notty '_brains_auth_set')"
case "${_nts#*|}" in
  *'needs a real terminal'*) _is 'notty.set-surfaces-the-tty-cause' 'surfaced' 'surfaced' ;;
  *) _is 'notty.set-surfaces-the-tty-cause' 'surfaced' "lost the cause: ${_nts#*|}" ;;
esac
# and it must be a CONSTRAINT (2) — the caller fixes this by moving to a terminal; a 1 would
# tell an automated caller the fault was ours and invite a retry that can never succeed
_code 'notty.set-exits-constraint' 2 "${_nts%%|*}"

# the two skill wrappers carry the same guard against the `--skill` token that `rhx` prepends.
# they are separate processes with their own parsers, so they need their own clamps — and a
# lone trailing `--skill` is exactly the shape the wrapper receives when a flag is fumbled.
#
# ⚠️ THIS FILE is the third such consumer, and it is clamped alongside them rather than
#   trusted. it carried its own hand-rolled copy of that guard until it was pointed at the
#   bootstrap — a copy whose comment had already shortened away from the original, which is
#   how a guard becomes decoration. and it is the worst of the three places to lose: a
#   hung proxy looks like a hung command, but a hung SUITE just looks like a slow suite, so
#   the one signal that would report the loss is the signal it silences.
#   the self-reference is cheap: a valueless `--skill` exits before a single case runs.
for _w in usage set use test; do
  timeout 5 bash "$SKILL_DIR/brains.auth.${_w}.sh" --skill >/dev/null 2>&1
  _code "guard.skill-${_w}.flag-without-value" 2 "$?"
done

# ⚠️ and THIS harness must refuse an unknown flag rather than ignore it. it ignored them, which
#   is the defect it exists to catch, one level up: `--resnp` ran in verify mode in silence, so
#   an operator who meant to re-pin the baselines got a green run and stale baselines. the
#   refusal exits before a single case runs, so this self-invocation is cheap and cannot recurse.
timeout 5 bash "$SKILL_DIR/brains.auth.test.sh" --resnp >/dev/null 2>&1
_code 'guard.test.refuses-unknown-flag' 2 "$?"

# ---------------------------------------------------------------- one refusal, three commands
# ⚠️ the three commands each reject an unrecognized flag, and for 19 review rounds no case
#   compared the three sentences — so one of them drifted unseen: `use` said
#   "🐢 unknown arg: $1 (try --help)" where `set` and `usage` said
#   "🐢 bummer dude — unknown arg: $1 (see --help)". every case stayed green, because each one
#   only ever read ONE command's copy. a divergence between peers is invisible to a per-peer
#   test. so this clamps the RELATION, not the text: whatever the sentence becomes, all three
#   say it. that also means it survives a future reword, which a hardcoded-string case would not.
_unknown_says() { bash -c "source '$ALIASES'; _brains_auth_$1 --nope-not-a-flag" 2>&1 >/dev/null; }
_is 'unknownarg.use-matches-set'   "$(_unknown_says set)" "$(_unknown_says use)"
_is 'unknownarg.usage-matches-set' "$(_unknown_says set)" "$(_unknown_says usage)"
# and the shared sentence must still name the fix — a level-but-useless line is no win
case "$(_unknown_says use)" in
  *'--help'*) _is 'unknownarg.names-the-fix' 'named' 'named' ;;
  *)          _is 'unknownarg.names-the-fix' 'named' "unnamed: $(_unknown_says use)" ;;
esac

# ---------------------------------------------------------------- the section map
# ⚠️ the file header carries a `.map` line that lists §1..§N, and each region carries a
#   `# ══ §N` banner. a map is only worth reading while it is TRUE, and a stale one is worse
#   than an absent one: it sends a reader to a region that moved, or hides one that was added.
#   the drift is silent by nature — a new banner with no map entry breaks no behavior at all.
#   so this compares the two lists of section NUMBERS. numbers, not titles: the map abbreviates
#   ("§7 command: set" vs "§7. command: brains.auth.set — enroll an account"), and a title
#   match would fail on a reword that broke no navigation.
_map_ns="$(sed -n '/^#   §1 /,/^# ─/p' "$ALIASES" | grep -o '§[0-9]\+' | sort -u -V | tr '\n' ' ')"
_banner_ns="$(grep -o '^# ══ §[0-9]\+' "$ALIASES" | grep -o '§[0-9]\+' | sort -u -V | tr '\n' ' ')"
_is 'sectionmap.matches-the-banners' "$_banner_ns" "$_map_ns"
# and the banners must be greppable by the exact recipe the header advertises
_is 'sectionmap.recipe-finds-them' 'found' \
  "$(grep -q '^# ══' "$ALIASES" && echo found || echo absent)"

# ---------------------------------------------------------------- the two call leaves
# ⚠️ `_brains_auth_usage_reply` and `_brains_auth_refresh_reply` are the file's only two raw
#   endpoint calls, and each is a PURE call leaf: curl is the last command, so the function's
#   exit code IS curl's. their callers rely on that — both read `$?` right after the capture and
#   map a non-zero to `curl_failed` / `refresh_curl_failed`. append one line after the curl (a
#   trace, a `return 0`, a tidy-up) and `$?` becomes that line's, so a dead network starts to
#   read as a 200 with an empty body — which classifies as `unexpected_shape` and names the
#   wrong cause, or worse renders as a confident all-clear.
#   these clamp the property, not the text: a fake curl that fails must surface its code.
_curl_rc_of() {
  ( eval "curl() { return $2; }"; _brains_auth_$1 'ua/1' 'tok' >/dev/null 2>&1; echo $? )
}
_is 'callleaf.usage-passes-curl-rc'   '7' "$(_curl_rc_of usage_reply 7)"
_is 'callleaf.refresh-passes-curl-rc' '7' "$(_curl_rc_of refresh_reply 7)"
_is 'callleaf.usage-passes-curl-ok'   '0' "$(_curl_rc_of usage_reply 0)"
# ⚠️ the case above was FLAKY before the usage leaf got its own subshell, and the flake WAS the
#   defect. a stubbed curl that returns without a read of stdin makes `printf` take SIGPIPE
#   (141); with `pipefail` on in the caller's shell, the pipeline reports 141 instead of curl's
#   status — so a call that WORKED reads as `curl_failed` and the human is told the endpoint is
#   unreachable. whether it fired came down to which side of the pipe won the race, so the case
#   went red only sometimes, and only under a pipe.
#   the SIGPIPE itself cannot be forced — whether it fires depends on the pipe buffer absorbing
#   a ~60-byte write before the reader exits, and it usually does. so these clamp the CONTRACT
#   the SIGPIPE happened to violate, which is deterministic: with pipefail ON in the caller, an
#   upstream failure in the pipeline must NOT become the leaf's answer. curl's code must be.
#   a failed `printf` stands in for the SIGPIPE — same position in the pipeline, same effect
#   under pipefail, but it fires every time instead of by luck.
_curl_rc_under_pipefail() {
  ( set -o pipefail
    eval "curl() { return $2; }"
    printf() { return 3; }        # the upstream failure, forced
    _brains_auth_$1 'ua/1' 'tok' >/dev/null 2>&1
    echo $? )
}
_is 'callleaf.usage-ok-survives-caller-pipefail'   '0' "$(_curl_rc_under_pipefail usage_reply 0)"
# ⚠️ the honest note on the case below: it does NOT bite on the defect, and is not claimed to.
#   under pipefail bash reports the RIGHTMOST non-zero, so with curl at 7 the answer is 7 with
#   or without the containment. it guards the FIX instead — `set +o pipefail` is exactly the
#   kind of change that could mask a real curl failure, and this is what says it did not. a
#   clamp that guards a repair is worth keeping; a clamp that pretends to guard the defect
#   would not be (`hazard.a-clamp-can-lie-the-same-way-code-can`).
_is 'callleaf.usage-rc-survives-caller-pipefail'   '7' "$(_curl_rc_under_pipefail usage_reply 7)"
# ...and the containment must hold the other way too: the leaf sets an option, so it must not
# leak that change back to the caller. `set +o pipefail` in a bare function body would.
_is 'callleaf.usage-does-not-leak-pipefail' 'on' \
  "$( set -o pipefail
      _brains_auth_usage_reply 'ua/1' 'tok' >/dev/null 2>&1 || :
      case "$(set -o | grep '^pipefail')" in *on) echo 'on' ;; *) echo 'LEAKED off' ;; esac )"

# and the bearer must never reach curl's ARGV — `/proc/<pid>/cmdline` is world-readable, so a
# token passed as an argument is visible in `ps` to any local user for the life of the call.
# both leaves route it through stdin instead (`-K -` here, `--data @-` at the mint). this
# clamps that the secret is absent from the args curl actually receives.
_curl_argv_of() {
  ( eval "curl() { printf '%s\n' \"\$@\"; }"; _brains_auth_$1 'ua/1' 'sk-ant-SECRETVALUE' 2>/dev/null )
}
case "$(_curl_argv_of usage_reply)" in
  *SECRETVALUE*) _is 'callleaf.usage-keeps-token-off-argv' 'absent' 'LEAKED to argv' ;;
  *)             _is 'callleaf.usage-keeps-token-off-argv' 'absent' 'absent' ;;
esac
case "$(_curl_argv_of refresh_reply)" in
  *SECRETVALUE*) _is 'callleaf.refresh-keeps-token-off-argv' 'absent' 'LEAKED to argv' ;;
  *)             _is 'callleaf.refresh-keeps-token-off-argv' 'absent' 'absent' ;;
esac

# ⚠️ and the mint must NOT follow redirects. curl re-sends the method AND the body to a 3xx
#   `Location`, so a single redirect would re-POST the DURABLE refresh token to whatever host
#   the reply names — the same loss the argv clamp above prevents, over the wire instead of via
#   /proc. the endpoint is pinned and has no legitimate redirect, so the capability is pure
#   downside. this clamps the absence of `-L` / `--location` in the args curl receives. the
#   match is LINE-anchored on purpose: `_curl_argv_of` prints one arg per line, so a bare
#   `*-L*` would also fire on any header value that happened to hold a capital L, and a clamp
#   that cries wolf on an unrelated edit is one the next reader disables.
_refresh_follows_redirects() {
  local a
  while IFS= read -r a; do
    case "$a" in
      --location|--location-trusted) return 0 ;;
      -[!-]*L*)                      return 0 ;;   # -L, or L inside a short-flag cluster (-sSL)
    esac
  done <<< "$(_curl_argv_of refresh_reply)"
  return 1
}
if _refresh_follows_redirects; then
  _is 'callleaf.refresh-refuses-redirects' 'absent' 'FOLLOWS redirects'
else
  _is 'callleaf.refresh-refuses-redirects' 'absent' 'absent'
fi

# ⚠️ a mid-pipeline failure must not be masked into the WRONG error class. the mint's rc is read
#   by `_brains_auth_mint` to split `refresh_curl_failed` (malfunction, retryable) from the
#   http-code path. without pipefail the rc is curl's alone — so a jq that dies hands curl an
#   empty body, the endpoint answers a plain 400, and the human is told to re-auth an account
#   whose token was never rejected. this fails a jq while curl SUCCEEDS: the only arrangement
#   in which the mask is observable.
#   ⚠️ each probe runs `set +o pipefail` FIRST. this harness itself runs under `set -uo
#   pipefail` (line 33), and a subshell inherits it — so without the disable, the leaf would
#   look correct on the strength of the CALLER's option and these clamps would pass whether or
#   not the leaf sets its own. that is a clamp with no teeth, and it was caught only by a
#   dogfood run in which the defect stayed green.
_refresh_rc_with_dead_jq() {
  ( set +o pipefail
    jq() { return 5; }; curl() { return 0; }
    _brains_auth_refresh_reply 'ua/1' 'tok' >/dev/null 2>&1; echo $? )
}
case "$(_refresh_rc_with_dead_jq)" in
  0) _is 'callleaf.refresh-unmasks-mid-pipeline' 'nonzero' 'MASKED as 0 — reads as a live 400' ;;
  *) _is 'callleaf.refresh-unmasks-mid-pipeline' 'nonzero' 'nonzero' ;;
esac
# and pipefail must not cost the network contract: when curl itself fails, ITS rc still wins,
# because bash yields the RIGHTMOST non-zero. a SIGPIPE'd jq upstream must not shadow it.
_is 'callleaf.refresh-curl-rc-outranks-upstream' '7' \
  "$( ( set +o pipefail
       jq() { return 5; }; curl() { return 7; }
       _brains_auth_refresh_reply 'ua/1' 'tok' >/dev/null 2>&1; echo $? ) )"
# ...and pipefail must stay INSIDE the leaf's subshell. a leak would change how EVERY later
# pipeline in the caller's shell reports failure — a repo skill, or the human's interactive
# session, since these aliases are sourced into it.
_pipefail_after_refresh() {
  ( set +o pipefail
    curl() { return 0; }
    _brains_auth_refresh_reply 'ua/1' 'tok' >/dev/null 2>&1
    # $SHELLOPTS is a colon-list of the `set -o` options currently ON — bash-native, so this
    # clamp adds no dependency at all, on top of the five the header .note declares and the
    # preflight enforces (jq, timeout, setsid, cmp, stat).
    case ":${SHELLOPTS}:" in *:pipefail:*) echo 'LEAKED' ;; *) echo 'off' ;; esac )
}
_is 'callleaf.refresh-pipefail-stays-inside' 'off' "$(_pipefail_after_refresh)"

# -------------------------------------------------- the bootstrap finds the root by landmark
# ⚠️ the root used to be reached by a hop count — `$dir/../../../..`, four steps, chosen for
#   this exact layout. the count was right, but a reviewer read `role=any` as two directories
#   and filed it as a blocker, and that misread is the point: a positional count re-derives a
#   fact from a directory convention nobody promised to keep, so it is a claim every reader
#   must re-verify and one rename silently breaks. every entry point sources this file, so a
#   wrong root turns all four commands into loud non-functional surfaces at once.
#   these clamp the PROPERTY that replaced it: the walk stops at the directory that actually
#   holds `src/brains.auth.sh`, at whatever depth it sits.
_BOOT="$SKILL_DIR/brains.auth.bootstrap.sh"
_boot_finds_root() {   # $1 = how deep to bury a fake bootstrap below a fake root
  local root d i
  root="$(mktemp -d)"
  mkdir -p "$root/src"; printf ': # a stand-in source\n' > "$root/src/brains.auth.sh"
  d="$root"; for (( i = 0; i < $1; i++ )); do d="$d/lvl$i"; done
  mkdir -p "$d"; cp "$_BOOT" "$d/brains.auth.bootstrap.sh"
  ( source "$d/brains.auth.bootstrap.sh" >/dev/null 2>&1; printf '%s' "$BRAINS_AUTH_SRC" )
  rm -rf "$root"
}
# the real depth (4) must work — the behavior the hop count had
case "$(_boot_finds_root 4)" in
  */src/brains.auth.sh) _is 'boot.finds-root-at-depth-4' 'found' 'found' ;;
  *)                    _is 'boot.finds-root-at-depth-4' 'found' 'LOST the root' ;;
esac
# ...and so must a depth the hop count could never have reached. this is the whole delta: a
# rename or one more nested level no longer breaks every entry point at once.
case "$(_boot_finds_root 7)" in
  */src/brains.auth.sh) _is 'boot.finds-root-at-any-depth' 'found' 'found' ;;
  *)                    _is 'boot.finds-root-at-any-depth' 'found' 'LOST the root' ;;
esac
# and a bootstrap with NO such root above it must fail loud rather than hand back a path that
# does not exist — `[[ -f ]]` on a hop-count guess would have named a path, not a cause
_boot_orphaned() {
  local root d; root="$(mktemp -d)"; d="$root/a/b"
  mkdir -p "$d"; cp "$_BOOT" "$d/brains.auth.bootstrap.sh"
  # ⚠️ redirect order is load-bearing: `2>&1` must point stderr at the capture FIRST, then
  #   `>/dev/null` moves stdout away. the reverse (`>/dev/null 2>&1`) sends the very message
  #   we came to read into the void, and the case then reports 'silent' about a leaf that
  #   spoke — a false red that reads exactly like a real regression.
  ( source "$d/brains.auth.bootstrap.sh" 2>&1 >/dev/null )
  rm -rf "$root"
}
case "$(_boot_orphaned)" in
  *'no src/brains.auth.sh in any parent'*) _is 'boot.orphaned-fails-loud' 'named' 'named' ;;
  *)                                       _is 'boot.orphaned-fails-loud' 'named' 'silent or unnamed' ;;
esac
# ⚠️ a SOURCED file's top-level assignments land in the CALLER's namespace, where `local` is
#   unavailable to contain them. this preamble's header promises it leaves EXACTLY two names
#   behind, and that promise is only worth what a case can check — so this reads the caller's
#   namespace after the source and asserts the transient walk variables are gone. the failure
#   it clamps is quiet by nature: an incidental global cannot be seen in any output, and only
#   shows up as a collision with some later definition in the same shell, far from here.
_boot_leaks() {
  ( source "$_BOOT" --skill brains.auth.test >/dev/null 2>&1
    for _v in _BRAINS_AUTH_BOOTSTRAP_DIR _BRAINS_AUTH_WALK; do
      [[ -n "${!_v+set}" ]] && printf '%s ' "$_v"
    done )
}
_is 'boot.leaves-no-walk-globals' '' "$(_boot_leaks)"
# ...and the two documented outputs must still be there — a cleanup that swept too wide would
# pass the case above while it broke every proxy, so the positive half is asserted too.
# ⚠️ a real extra arg is passed on purpose. with ONLY `--skill <v>`, the `ARGS` left behind is
#   an empty array, and an emptiness test cannot tell that apart from an unset one — so the
#   case would have read as a broken output on a preamble that works. the arg doubles as the
#   proof that the `--skill` token is stripped and the rest forwarded verbatim.
_boot_outputs() {
  ( source "$_BOOT" --skill brains.auth.test --json >/dev/null 2>&1
    [[ -n "${BRAINS_AUTH_SRC:-}" ]] && printf 'src '
    printf '%s' "${ARGS[*]}" )
}
_is 'boot.keeps-its-two-outputs' 'src --json' "$(_boot_outputs)"

# -------------------------------------------------- the error roster must not drift
# ⚠️ `_ERRORS` (up at the hints snapshot) is hand-kept, so a code added to
#   `_brains_auth_fix_for_error` and forgotten there ships a hint AND a severity that no case
#   ever reads — invisible in the diff, and unpinned against a later reword. that is the same
#   "two sources of truth" defect the hints note describes, one level up: the ROSTER drifted
#   from the table it claims to cover. `refresh_server_error` was added this round and the whole
#   suite stayed green, which is exactly the silence this closes.
#   the declared set is DERIVED from the source, never re-typed — a clamp that restates the
#   list would drift alongside it, the way the roster did.
_declared_codes() {
  local line inside=0
  while IFS= read -r line; do
    case "$line" in
      _brains_auth_fix_for_error*) inside=1; continue ;;
    esac
    (( inside )) || continue
    case "$line" in
      *esac*) break ;;
      # a case arm: four spaces, an identifier, a close paren. `*)` is the default, not a code.
      '    '[a-z]*')'*) line="${line#"${line%%[![:space:]]*}"}"; printf '%s\n' "${line%%)*}" ;;
    esac
  done < "$ALIASES"
}
_missing=''
while IFS= read -r _c; do
  [[ -z "$_c" ]] && continue
  case " ${_ERRORS[*]} " in *" $_c "*) ;; *) _missing+="$_c " ;; esac
done <<< "$(_declared_codes)"
_is 'hints.roster-covers-every-declared-code' '' "$_missing"
# and the scan must actually FIND arms — a parse that silently yields an empty set would make
# the clamp above pass forever, which is the failhide shape it exists to prevent
case "$(_declared_codes)" in
  *keyrack_unreadable*) _is 'hints.roster-scan-reads-the-table' 'found' 'found' ;;
  *)                    _is 'hints.roster-scan-reads-the-table' 'found' 'SCANNED NO ARMS — clamp is blind' ;;
esac

# ---------------------------------------------------------------- the --sub deprecation
# ⚠️ `--sub` is the pre-reach name. it still parses everywhere — muscle memory must land — but
#   an alias that works in total silence is an alias nobody ever abandons, so it now announces
#   that it is superseded. these clamp the three properties that make the notice honest:
_out="$(_brains_auth_reach_from_flag --sub kai@ehmpathy.com 2>&1 >/dev/null)"
case "$_out" in
  *'--reach is the term now'*) _is 'deprecation.sub-says-so' 'noted' 'noted' ;;
  *)                           _is 'deprecation.sub-says-so' 'noted' "silent: ${_out}" ;;
esac
# it must still WORK — a deprecation that breaks the caller is a removal wearing a nicer word
_is 'deprecation.sub-still-parses' 'kai@ehmpathy.com' \
  "$(_brains_auth_reach_from_flag --sub kai@ehmpathy.com 2>/dev/null)"
# and the canonical name must stay QUIET — a notice on every `--reach` is noise that trains
# the eye to skip the one line that matters
_is 'deprecation.reach-is-quiet' '' \
  "$(_brains_auth_reach_from_flag --reach kai@ehmpathy.com 2>&1 >/dev/null)"
# the notice rides stderr, so a `--json` consumer's stdout is untouched by it
_is 'deprecation.notice-off-stdout' 'kai@ehmpathy.com' \
  "$(_brains_auth_reach_from_flag --sub kai@ehmpathy.com 2>/dev/null)"

# ---------------------------------------------------------------- active verdict (read mode)
# ⚠️ the no-arg READ of `brains.auth.use` used to test `(( arc == 1 ))` / `(( arc == 2 ))` at
#   the call site, so the one surface that REPORTS the tri-state to a human decoded it by hand.
#   the verdict is a pure verb now; these pin all four outcomes and the order between them.
_is 'verdict.unknown'    'unknown'    "$(_brains_auth_active_verdict 'kai@x.com' 1)"
_is 'verdict.absent'     'absent'     "$(_brains_auth_active_verdict '' 0)"
_is 'verdict.unverified' 'unverified' "$(_brains_auth_active_verdict 'kai@x.com' 2)"
_is 'verdict.verified'   'verified'   "$(_brains_auth_active_verdict 'kai@x.com' 0)"
# ⚠️ THE ORDER CASE. an unnamed login is not an empty one. were the empty test to run first, a
#   machine that IS signed in but whose token could not be read would report "no account is
#   signed in" — the one confusion this command exists to prevent. so arc=1 with an empty
#   `active` must still read `unknown`, never `absent`.
_is 'verdict.unknown-outranks-absent' 'unknown' "$(_brains_auth_active_verdict '' 1)"
# a default-absent arc is treated as unknown, never as verified — an unsupplied quality is the
# least trustworthy one, not the most.
_is 'verdict.absent-arc-defaults-unknown' 'unknown' "$(_brains_auth_active_verdict 'kai@x.com')"
# and it composes the two extant leaves rather than restate either — a fourth outcome added to
# the ladder must land in ONE place. proven by body scan, since a value test cannot see through
# to which leaf produced it.
_verdict_body="$(sed -n '/^_brains_auth_active_verdict() {$/,/^}$/p' "$ALIASES")"
_is 'verdict.reads-through-actionable' '1' \
  "$(printf '%s' "$_verdict_body" | grep -c '_brains_auth_identity_is_actionable')"
_is 'verdict.reads-through-ident-err' '1' \
  "$(printf '%s' "$_verdict_body" | grep -c '_brains_auth_ident_err_for_arc')"

# ---------------------------------------------------------------- the arc map has one owner
# ⚠️ `_brains_auth_node_for_reach` used to pick the unverified node with a bare `== 2` and fall
#   through to a literal, re-implementing a named transformer's output inside an orchestrator.
#   the sibling read path (`_brains_auth_usage`) already went through the leaf, so the two
#   would have disagreed about what an unverified identity is CALLED the moment either moved.
# ⚠️ comments are stripped before the scan. the body carries a ⚠️ that NAMES the leaf and
#   names the literals it replaced, so a scan of the raw body counts prose as code and reads
#   green off a comment. that is the inherited-state shape of
#   hazard.a-clamp-can-lie-the-same-way-code-can.md — a clamp that measures the wrong text.
_nfr_body="$(sed -n '/^_brains_auth_node_for_reach() {$/,/^}$/p' "$ALIASES" | grep -v '^[[:space:]]*#')"
_is 'archmap.node-for-reach-has-no-literal' '0' \
  "$(printf '%s' "$_nfr_body" | grep -c "active_identity_unverified'")"
_is 'archmap.node-for-reach-reads-the-leaf' '1' \
  "$(printf '%s' "$_nfr_body" | grep -c '_brains_auth_ident_err_for_arc')"
# and the leaf it reads still answers what the deleted literals said, for both arcs
_is 'archmap.leaf-2-is-unverified' 'active_identity_unverified' "$(_brains_auth_ident_err_for_arc 2)"
_is 'archmap.leaf-1-is-unknown'    'active_identity_unknown'    "$(_brains_auth_ident_err_for_arc 1)"

# ---------------------------------------------------------------- the @all union predicate
# ⚠️ the sweep decided this with a three-clause boolean chained under one `if`, so the DECISION
#   had no name even though each clause did. each clause is a veto; each is pinned alone here,
#   because a conjunction with one clause silently dropped still passes every happy-path case.
_union_list=$'a@x.com\nb@x.com'
_ok()  { _brains_auth_should_union_active "$@" && echo yes || echo no; }
_is 'union.verified-all-new'      'yes' "$(_ok 0 '@all' 'c@x.com' "$_union_list")"
_is 'union.veto-unverified-arc'   'no'  "$(_ok 2 '@all' 'c@x.com' "$_union_list")"
_is 'union.veto-unknown-arc'      'no'  "$(_ok 1 '@all' 'c@x.com' "$_union_list")"
_is 'union.veto-narrowed-read'    'no'  "$(_ok 0 'a@x.com' 'c@x.com' "$_union_list")"
_is 'union.veto-empty-active'     'no'  "$(_ok 0 '@all' '' "$_union_list")"
_is 'union.veto-already-listed'   'no'  "$(_ok 0 '@all' 'a@x.com' "$_union_list")"
# ⚠️ a whole-line, literal membership test — not a substring one. `a@x.com` must not be read as
#   already present because `aa@x.com` is. this is the -x/-F pair the leaf below it carries.
_is 'union.partial-match-is-not-a-match' 'yes' "$(_ok 0 '@all' 'a@x.co' "$_union_list")"

# ---------------------------------------------------------------- the .bak is verified, not assumed
# ⚠️ existence is not integrity. the backup copy's exit status used to be discarded, so a copy
#   that died partway — a full disk is the plausible one, since a secret write follows at once —
#   left a `.bak` that PASSES `[[ -f ]]`. every downstream rescue promise tests only for the
#   file, so a human would have been sent to restore from a truncated one.
_bak_probe() {  # $1 = 'short' to simulate a copy that came out wrong
  local d rc out
  d="$(mktemp -d)"
  printf '{"claudeAiOauth":{"refreshToken":"sk-ant-ort01-PRIOR"}}' > "$d/.credentials.json"
  out="$(
    _BRAINS_AUTH_LIVE_CREDS="$d/.credentials.json"
    [[ "$1" == 'short' ]] && cmp() { return 1; }
    _brains_auth_install_creds 'kai@x.com' 'sk-ant-oat01-A' 'sk-ant-ort01-B' 3600 '' 'max' 2>&1 >/dev/null
  )"; rc=$?
  # report the rc, whether the prior token survived, and whether a .bak was left behind
  printf '%s|%s|%s' "$rc" \
    "$(grep -qF 'PRIOR' "$d/.credentials.json" && echo kept || echo LOST)" \
    "$([[ -f "$d/.credentials.json.bak" ]] && echo bak || echo none)"
  rm -rf "$d"
}
# the happy path still installs, and still leaves the restore point behind
_is 'bakverify.good-copy-installs' '0|LOST|bak' "$(_bak_probe good)"
# ⚠️ THE CASE. a short copy REFUSES, and refusal is the safe direction: the prior credentials
#   are still in place at that point, so the cost is one aborted swap, never one destroyed
#   login. and the corrupt `.bak` is removed rather than left to be promised as a rescue.
_is 'bakverify.short-copy-refuses' '1|kept|none' "$(_bak_probe short)"
_is 'bakverify.short-copy-names-the-cause' 'named' \
  "$(_bak_probe_msg="$(
      d="$(mktemp -d)"
      printf '{"claudeAiOauth":{}}' > "$d/.credentials.json"
      (
        _BRAINS_AUTH_LIVE_CREDS="$d/.credentials.json"
        cmp() { return 1; }
        _brains_auth_install_creds 'kai@x.com' 'a' 'b' 3600 '' 'max' 2>&1 >/dev/null
      )
      rm -rf "$d"
    )"
    case "$_bak_probe_msg" in
      *'restore point'*'untouched'*) echo named ;;
      *) echo "MISATTRIBUTED: ${_bak_probe_msg}" ;;
    esac)"

# ---------------------------------------------------------------- the dependency preflight
# ⚠️ the harness leans on five tools beyond bash, and its own comment used to claim "bash + jq".
#   an absent `setsid` turned the entire notty.* section into a wall of `command not found`
#   reds that read as failures of the CODE, not of the host — the misattributed cause
#   `rule.require.errors-name-the-fix` forbids. the preflight names the tool instead.
_SELF="$SKILL_DIR/brains.auth.test.sh"
_is 'preflight.declares-five-tools' 'jq timeout setsid cmp stat' \
  "$(sed -n 's/^for _tool in \(.*\); do$/\1/p' "$_SELF" | head -1)"
# every declared tool is genuinely on this host, so no clamp below is silently skipped
_is 'preflight.every-tool-present' '' \
  "$(for _t in jq timeout setsid cmp stat; do command -v "$_t" >/dev/null 2>&1 || printf '%s ' "$_t"; done)"
# and the pipefail clamp's comment names the whole set rather than a subset of it.
# ⚠️ SCOPED TO THAT FUNCTION'S BODY, not to the file. a whole-file scan counts the clamp's own
#   search string as a second hit, because the clamp has to spell out the very text it looks
#   for. two self-reference traps in a row here, in opposite directions: the negative form
#   ("the stale claim is absent") can never reach zero, and the positive form can never reach
#   one. a scoped read is what escapes both.
_pf_body="$(sed -n '/^_pipefail_after_refresh() {$/,/^}$/p' "$_SELF")"
_is 'preflight.pipefail-comment-names-the-set' '1' \
  "$(printf '%s' "$_pf_body" | grep -c 'jq, timeout, setsid, cmp, stat')"

# ---------------------------------------------------------------- no orphaned baselines
# ⚠️ a `.snap` file with no case that reads it is a baseline nobody checks. it costs a reviewer
#   real attention — they read it as pinned output while it pins none — and it survives every
#   run, because the suite only ever asks "does the baseline MATCH?", never "does anyone ASK?".
#   this bit for real: `identity.usage-refuses-unverified.snap` was orphaned when its case split
#   into `.json` and `.tree` variants, a review closed the finding, and the file stayed on disk
#   for another round until an outside reviewer re-found it. the record said fixed; the disk
#   disagreed. so the check is mechanical now rather than a promise.
# .note = this runs LAST on purpose. it reads the roster of names the suite actually invoked,
#   so it must run after every `_snap` call has had its chance to register one.
_orphans=''
for _f in "$SNAPS"/*.snap; do
  [[ -e "$_f" ]] || continue
  _n="$(basename "$_f" .snap)"
  case "$_SNAP_ASKED" in
    *"|${_n}|"*) : ;;
    *) _orphans="${_orphans}${_n} " ;;
  esac
done
_is 'snap.no-orphaned-baselines' '' "$_orphans"
# and the roster must be NON-EMPTY — an empty one would report every baseline as an orphan,
# and an empty snap dir would report none at all. both are the failhide shape this section
# exists to prevent, so each end is pinned rather than assumed.
_is 'snap.orphan-scan-found-baselines' 'found' \
  "$(compgen -G "$SNAPS/*.snap" >/dev/null && echo found || echo 'NO BASELINES — the check above is blind')"
_is 'snap.orphan-roster-is-populated' 'found' \
  "$([[ -n "$_SNAP_ASKED" ]] && echo found || echo 'EMPTY ROSTER — every baseline would read as an orphan')"

# ---------------------------------------------------------------- the header count cannot lie
# ⚠️ `src/brains.auth.sh`'s own preamble advertises this suite's size, and it drifted to ~100
#   cases wrong before a reviewer caught it by eye. a doc pointer a reader trusts for a sense
#   of coverage is worse than none once it is stale. so the number is no longer maintained by
#   discipline — it is asserted, and any case added without a touch of that header turns this
#   red with both numbers on screen.
# .note = it must run LAST, and it counts ITSELF: PASS+FAIL is read before `_is` increments,
#   so the header's figure is that total plus this one case. that self-inclusion is why the
#   `+ 1` is here rather than a bug — remove it and the header would have to under-report by
#   exactly one forever.
_is 'header.count-matches-the-suite' "$(( PASS + FAIL + 1 ))" \
  "$(sed -n 's/^# tests:.*(\([0-9]\+\) cases,.*/\1/p' "$ALIASES" | head -1)"

# ---------------------------------------------------------------- report
echo "   └─ ${PASS} passed, ${FAIL} failed"
echo ""
(( FAIL == 0 )) || exit 1
echo "🐢 shell yeah — brains.auth output is pinned"
