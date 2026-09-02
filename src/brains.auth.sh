#!/usr/bin/env bash
######################################################################
# .what = brains.auth.* — see, store, and swap claude subscription accounts
#
# .why it is its own file, and not inline in bash_aliases.sh:
#   1. it is a self-contained namespace — ~1,700 lines, 60+ functions, its own
#      `_BRAINS_AUTH_` prefix, its own vars — with zero references out to the
#      general-purpose aliases around it. a self-contained unit inside a
#      4,300-line grab-bag is a placement accident, not a design.
#   2. HERMETICITY, which is the half that carries real weight. the test suite
#      and the two skill proxies must `source` this namespace under
#      `set -uo pipefail`. while it lived inline, that meant a source of the whole
#      monolith — so an unset variable or a parse defect ANYWHERE in an unrelated
#      alias would hard-abort the clamp on the riskiest credential code in the
#      repo, for a cause unrelated to brains.auth. a clamp made fragile by edits
#      it does not cover is a clamp that will rot.
#      `hazard.bash-aliases-parse-silently.md` records the parse half of this.
#
# .how it loads: the same paved pattern as `src/ductwork.sh` and `src/termwork.sh` —
#   `src/X.sh` is copied to `~/.bash_aliases.X.sh` by `sync.devenv.bashaliases`, and
#   sourced from the head of `~/.bash_aliases`. add one, and you must add all three:
#   the file, the source line, and the cp in the sync alias.
#
# vision: .behavior/v2026_07_28.brain-budget-utilization/1.vision.yield.md
# tests:  rhx brains.auth.test   (301 cases, hermetic, no network, no real ~/.claude)
#         ⚠️ this number is ASSERTED, not maintained by hand — `header.count-matches-the-suite`
#           reads it back out of this very line and compares it to the suite's own total. it
#           drifted ~100 cases wrong once, when it was only a promise. now a case added
#           without a touch of this line turns the suite red, with both figures on screen.
######################################################################

# ─────────────────────────────────────────────────────────────────────────────
# brains.auth — see + store claude subscription budget usage by token
#
# tokens live in the GLOBAL keyrack (reachable from any repo) as ONE key cut at a
# REACH per account — the account's own email:
#   BRAINS_AUTH__OF__CLAUDE_CODE_OAUTH_TOKEN  --reach casey@ahction.com
#
# .why the reach, not a name suffix: an account's email is a fact the token itself
#   reports, so it needs no invented handle to be filed under. the prior scheme minted
#   one key per account with a mangled suffix (`…__FOR__caseyatahction`), which meant a
#   name to choose, a mangle to reproduce, and a lookup table to map back. the reach
#   removes all three: the account IS its email, everywhere.
#
# keyrack's own words for the parts (do NOT overload them):
#   slug    = @all.prep.BRAINS_AUTH__OF__CLAUDE_CODE_OAUTH_TOKEN   (reachless)
#   reach   = casey@ahction.com                                    (who it is cut for)
#   address = slug@reach                                           (the manifest map key)
# an address is NEVER split back on `@` — a reach may legally hold one, and an email
# always does. read the `slug` + `reach.exid` fields the manifest already records.
#
# vision: .behavior/v2026_07_28.brain-budget-utilization/1.vision.yield.md
#
# .map = this file stays ONE file on purpose — it runs under `set -uo pipefail` when a proxy
#   sources it, and a split would put that guarantee at the mercy of source order. what a split
#   would have bought is navigability, so the regions are marked instead. to list them:
#       grep '^# ══' src/brains.auth.sh
#   §1 constants · §2 trace · §3 token mint · §4 identity ladder · §5 render leaves
#   §6 keyrack i/o · §7 command: set · §8 credential-file i/o · §9 command: use
#   §10 usage fetch + sweep · §11 error tables · §12 render · §13 command: usage
# ─────────────────────────────────────────────────────────────────────────────

# ══ §1. constants ════════════════════════════════════════════════════════════
_BRAINS_AUTH_KEY='BRAINS_AUTH__OF__CLAUDE_CODE_OAUTH_TOKEN'

# .what = the keyrack coordinates every read and write in this file uses
# .why  = these two were hand-typed at five call sites, and the slug below baked the env in a
#   SIXTH time as a literal — so one bucket change was six edits with no signal if one was
#   missed. and a partial edit produces this namespace's worst-shaped failure rather than an
#   error: the write lands under one owner/env while `keyrack list` filters by another, so the
#   token is stored, unlisted, and reads back as "never stored".
#   the file already had this instinct — `_BRAINS_AUTH_HTTP_TIMEOUT` exists because "a timeout
#   applied at two of the three is the exact failure this constant exists to prevent" — it was
#   simply never carried to the pair that names WHERE the credentials live.
# .note = the slug is COMPOSED from them, so the env cannot be declared here and spelled
#   differently one line down.
_BRAINS_AUTH_KEYRACK_OWNER='ehmpath'
_BRAINS_AUTH_KEYRACK_ENV='prep'
_BRAINS_AUTH_SLUG="@all.${_BRAINS_AUTH_KEYRACK_ENV}.${_BRAINS_AUTH_KEY}"
_BRAINS_AUTH_USAGE_URL='https://api.anthropic.com/api/oauth/usage'
# the usage endpoint rejects the long-lived token; it accepts only a short-lived access
# token, minted fresh from the stored oauth refresh token at read time. these two feed
# that mint (see hazard.claude-oauth-refresh-rotation.md for why + the rotation caveat).
_BRAINS_AUTH_REFRESH_URL='https://platform.claude.com/v1/oauth/token'
_BRAINS_AUTH_CLIENT_ID='9d1c250a-e61b-44d9-88ed-5944d1962f5e'

# .what = the claude-code User-Agent header the oauth endpoints expect
# .why  = the UA is LOAD-BEARING: the refresh + usage endpoints bucket an unrecognized
#   UA into an aggressively rate-limited path that returns persistent 429s (proven — a
#   live refresh with claude-code/2.0.1 returned 200, while the machine-derived
#   claude-code/2.1.87 returned a persistent 429 that did not clear across a full day).
#   so we PIN a UA value known to be accepted, rather than derive it from `claude
#   --version` (which drifts to a value the endpoint may not accept).
#   override with BRAINS_AUTH_UA if a future claude-code version is required.
_BRAINS_AUTH_UA_PINNED='claude-code/2.0.1'
_brains_auth_ua() {
  echo "${BRAINS_AUTH_UA:-$_BRAINS_AUTH_UA_PINNED}"
}

# .what = where the global claude cli keeps the credentials of whichever account is signed in
# .why  = brains.auth.use swaps that account by a rewrite of this one file, so the path is
#   declared once here rather than repeated at each site (a drift between two copies would
#   swap the token into a file claude never reads, and look like a silent success)
_BRAINS_AUTH_LIVE_CREDS="${HOME}/.claude/.credentials.json"

# .what = the wall-clock bound on every oauth http call this namespace makes, in seconds
# .why  = curl waits FOREVER by default. an @all sweep is one call per account in sequence, so
#   a single stalled connection does not slow the sweep — it stops it, with no output and no
#   way to tell a hung read from a slow one. a bound turns that hang into a named failure the
#   caller already knows how to render.
# .note = declared ONCE, here, and passed at every call site. three sites make the same call
#   shape, and a timeout applied at two of the three is the exact failure this constant exists
#   to prevent: the path that forgot it is the path that hangs, and it hangs only under the
#   network conditions no one tests.
_BRAINS_AUTH_HTTP_TIMEOUT=15

# .what = the oauth beta opt-in header value every anthropic call in this namespace sends
# .why  = same argument the timeout above makes, and the same three call sites. the endpoints
#   are undocumented, so this value is a reverse-engineered constant that anthropic may retire;
#   the day it does, the fix is ONE edit here, not a hunt through three hand-typed copies.
#   a partial edit is worse than no edit: two paths on the new value and one on the old reads
#   as "the endpoint is flaky", which sends the next reader to the network rather than here.
# .note = the vision's open-questions section called this value "single-source today". it never
#   was — it was typed three times. it is single-source NOW, so that claim is true rather than
#   aspirational, and the vision's "confirm this is current" question is a one-line check.
_BRAINS_AUTH_ANTHROPIC_BETA='oauth-2025-04-20'

# .what = how hard a rejected mint looks for evidence that a CONCURRENT sweep rotated the token
# .why  = a refresh rotates server-side, so two overlapped reads of one account both mint from
#   one stored value and the loser's token is already spent. the loser tells "raced" from
#   "genuinely dead" by evidence — it re-reads the keyrack and asks whether the stored value
#   CHANGED. but the winner writes its rotated value back only AFTER its own mint returns, so
#   for a moment the loser's re-read sees the OLD value and reads "no one raced me — the token
#   is dead". a healthy account then renders "refresh token dead (run: brains.auth.set)" and a
#   human is sent through a browser re-auth to repair a race.
#   the fix is to let the evidence ARRIVE: the re-read is polled a few times rather than taken
#   once, so the loser outlasts the winner's write-back. a lock would close the window outright,
#   and was still declined — a stale lockfile wedges every later read of that account, which
#   trades a rare wrong message for a permanent dead command. this poll cannot wedge: it is
#   bounded, and it runs ONLY on a path that was already about to fail.
# .note = the first read happens with NO wait, so the fast path is unchanged and the whole cost
#   falls on a genuinely-dead token (~0.8s before its verdict).
_BRAINS_AUTH_RACE_TRIES="${BRAINS_AUTH_RACE_TRIES:-3}"
_BRAINS_AUTH_RACE_WAIT="${BRAINS_AUTH_RACE_WAIT:-0.4}"

# .what = the endpoint that names the account a token belongs to
# .why  = THE authoritative answer to "who is signed in". we never record that ourselves: you
#   may run `claude /login` at any moment and swap the account without telling us, so any
#   marker file we keep is a lie in waiting. this endpoint derives the answer from the TOKEN,
#   so it is correct by construction no matter who did the swap or when.
_BRAINS_AUTH_PROFILE_URL='https://api.anthropic.com/api/oauth/profile'

# .what = where the claude cli keeps the profile of the account it is signed in as
# .why  = the fallback identity read, for when the live access token has expired and the api
#   cannot be asked. claude refreshes this block on its own logins, so it is accurate for a
#   hand-made `/login`; our own swap writes it too, so it never lags behind us either.
_BRAINS_AUTH_LIVE_PROFILE="${HOME}/.claude.json"

# ══ §2. trace ════════════════════════════════════════════════════════════════
# .what = emit one stage trace to stderr when BRAINS_AUTH_DEBUG is set ($*=the stage line)
# .why  = a silent death must never hide — each stage announces itself and its result, so a
#   run that ends with no output still leaves a trail that says how far it got.
# .note = top-level ON PURPOSE. bash does not scope a nested function definition, so a
#   `_brains_auth_debug() { ... }` written inside an orchestrator body redefines a GLOBAL on every
#   single call — and a trace helper is precisely what must not be reshadowed at the moment
#   it is needed. declared once, here, it also gives the whole namespace ONE trace format,
#   rather than the four ad-hoc shapes that had drifted apart.
_brains_auth_debug() {
  [[ -n "${BRAINS_AUTH_DEBUG:-}" ]] && echo "🔎 brains.auth: $*" >&2
  return 0
}

# ══ §3. token mint — refresh token -> short-lived access token ═══════════════
# .what = mint an access token from a refresh token; emit `<body>\n<http code>` ($1=ua, $2=refresh)
# .why  = every path that reads a PARKED account starts here — the usage endpoint rejects the
#   durable refresh token, so each read mints a short-lived access token from it. one leaf for
#   the call, because callers classify the reply differently (a tree line vs a json node) but
#   must never differ on HOW it is asked: the UA header, the beta header, and above all the
#   token routed so that it reaches NO process argv.
# .note = this ROTATES the refresh token server-side. whatever calls this owns the write-back
#   of the new one, or the next read fails (hazard.claude-oauth-refresh-rotation.md).
# ⚠️ .security = the token must not be handed to `jq --arg`, however natural that reads. jq is
#   an external binary, so an --arg value lands in `/proc/<pid>/cmdline` and ANY local user can
#   read it out of `ps` for as long as that jq runs. the refresh token is the DURABLE
#   credential — an access token expires in an hour, this one does not — and this leaf sits on
#   the path of every read, every store, and every swap, so an argv leak here exposes it
#   constantly. so it rides jq's STDIN (`-R`, the raw line becomes `.`), the same discipline
#   the bearer headers use with curl's `-K -` and the body uses with `--data @-`.
# ⚠️ .security = NO `-L` here, deliberately. curl re-sends the method AND the body to a 3xx
#   `Location`, so one redirect would re-POST the durable refresh token to whatever host the
#   reply names. every other guard in this leaf keeps that token out of argv and inside the
#   process; a blind redirect-follow hands it to a third party over the wire, which is the same
#   loss through a different door. the mint endpoint is pinned and has no legitimate redirect,
#   so the capability buys no reach we need and costs the credential.
# .note = the pipeline runs under `pipefail` in a SUBSHELL, so the option cannot leak into a
#   caller's shell. without it this function's rc is curl's alone: a jq that dies mid-pipeline
#   hands curl an empty body, the endpoint answers a plain 400, and that classifies as
#   `refresh_rejected` — a CONSTRAINT that tells the human to re-auth an account whose token was
#   never actually rejected. with it, curl's rc still wins whenever curl itself fails (bash
#   yields the RIGHTMOST non-zero), so the network-failure contract the clamps pin is unchanged;
#   only the silent upstream failure stops passing as a 200.
_brains_auth_refresh_reply() {
  local ua="$1" token="$2"
  (
    set -o pipefail
    printf '%s' "$token" \
      | jq -Rc --arg c "$_BRAINS_AUTH_CLIENT_ID" \
          '{grant_type:"refresh_token", refresh_token:., client_id:$c}' \
      | curl -sS -m "$_BRAINS_AUTH_HTTP_TIMEOUT" -w $'\n%{http_code}' "$_BRAINS_AUTH_REFRESH_URL" \
          -H "Content-Type: application/json" \
          -H "anthropic-beta: ${_BRAINS_AUTH_ANTHROPIC_BETA}" \
          -H "User-Agent: ${ua}" \
          --data @-
  )
}

# .what = mint an access token and DECODE the reply into one json node ($1=ua, $2=refresh)
#   emits `{ok:true, access, refresh, ttl, scopes, kind}` or `{ok:false, error, code}`
# .why  = three callers each need the same four fields out of the same wire reply. when each
#   decoded it inline — split `<body>\n<code>` by hand, then jq every field — the wire format
#   was known in three places, so a drift in one could rotate a token and file the wrong value.
#   the decode lives here once; callers read named fields and own only their write-back.
# .note = still ROTATES the refresh token server-side. the CALLER owns the write-back of
#   `.refresh`, or the next read fails (hazard.claude-oauth-refresh-rotation.md).
_brains_auth_mint_access() {
  local ua="$1" token="$2" resp rc code body
  resp="$(_brains_auth_refresh_reply "$ua" "$token")"
  rc=$?
  code="${resp##*$'\n'}"
  body="${resp%$'\n'*}"

  (( rc != 0 )) && { jq -nc '{ok:false, error:"refresh_curl_failed", code:0}'; return 0; }
  if [[ "$code" != 200 ]]; then
    [[ -n "${BRAINS_AUTH_DEBUG:-}" ]] && printf '🔎 refresh http_%s: %s\n' "$code" "$body" >&2
    # ⚠️ THREE outcomes, not two, and the third was the one that misdirected. a 4xx means the
    #   stored token is genuinely dead, so `refresh_rejected` is a constraint that names the
    #   browser re-auth. a 429 is transient. but a 5xx is ANTHROPIC's fault, not the token's —
    #   and it used to land in the `refresh_rejected` bucket, which told the human "refresh
    #   token dead — run brains.auth.set" and exited 2 for a perfectly healthy account. that
    #   sends a person through a full browser flow to fix someone else's outage, and hands a
    #   cron a PERMANENT verdict for a fault that clears itself on retry.
    jq -nc --argjson c "${code:-0}" \
      '{ok:false,
        error:(if   $c == 429 then "refresh_rate_limited"
               elif $c >= 500 then "refresh_server_error"
               else                "refresh_rejected" end),
        code:$c}'
    return 0
  fi

  # an absent rotated token means the endpoint did not rotate, so the token we sent is still
  # live — carry it through as `.refresh` so every caller files a usable value either way.
  #
  # ⚠️ every value here is fully parenthesized. in jq's object-construction grammar a bare
  #   operator (`a != b`) is a PARSE error, and a parse error at this exact spot is the most
  #   expensive failure in the file: the refresh already succeeded, so the token has ALREADY
  #   rotated server-side, and a failure to decode drops the rotated value we were handed —
  #   stranding the account with a dead token in the keyrack and no live copy anywhere.
  # ⚠️ .security = the sent token rides the ENVIRONMENT, not argv. a `--arg sent "$token"`
  #   would place the durable refresh token in `/proc/<pid>/cmdline`, which any local user
  #   reads out of `ps`. stdin is already taken here by `$body`, so a scoped env assignment
  #   is the route — `/proc/<pid>/environ` is 0400 to the owner (hazard.secrets-in-argv.md).
  # .note = the decode-failure fallback carries `code: 0`, NOT 200. `.code` means "the http
  #   status of the exchange that produced this verdict", and every other failure node in this
  #   function carries the real one (401, 429, …). a 200 on a body we could not decode asserts
  #   a healthy exchange to any caller that branches on `.code` to split a dead token from a
  #   transient fault — a small lie in the one field that exists to be trusted. 0 is the value
  #   `refresh_curl_failed` already uses for "no http status was obtained", which is the truth
  #   here too: the exchange returned 200, but the verdict is about a body we could not read.
  _BA_SENT="$token" jq -c \
    '{ok: ((.access_token // "") != ""),
      error: (if (.access_token // "") == "" then "no_access_token" else null end),
      code: 200,
      access: (.access_token // ""),
      refresh: (if (.refresh_token // "") == "" then $ENV._BA_SENT else .refresh_token end),
      ttl: (.expires_in // 3600),
      scopes: (.scope // ""),
      kind: (.subscription_type // "")}' <<< "$body" \
    || jq -nc '{ok:false, error:"refresh_unreadable", code:0}'
}

# .what = read one named field out of a `_brains_auth_mint_access` node ($1=node, $2=field)
# .why  = three callers need fields off that node, and each took it apart with its own raw
#   `jq -r`. that put the node's shape in FOUR places — the leaf that builds it, plus three
#   that read it — so a rename of one field would break the three in silence, at the worst
#   possible moment: after the refresh has ALREADY rotated the token server-side. an empty read
#   there files the wrong value and strands the account with no live copy anywhere.
#   this is the same move `_brains_auth_email_of_who` already makes for the 2-field `who`
#   tuple; the 5-field mint node is well past rule-of-three and had never been given it.
# .note = an absent or null field reads as the EMPTY STRING, never the literal "null". callers
#   test emptiness (`[[ -z ]]`), and the four-character string "null" passes that test — it
#   would be filed to the keyrack as if it were a token. `false` survives as "false", so a
#   boolean field is not flattened into the absent case.
_brains_auth_mint_field() {
  local node="$1" field="$2"
  jq -r --arg f "$field" \
    'if (has($f) and .[$f] != null) then (.[$f] | tostring) else "" end' \
    <<< "$node" 2>/dev/null
}

# .what = decide which plan kind to stamp into the new credentials ($1 = the mint node)
# .why  = three sources answer one question, in a fixed order of trust, and that order is the
#   whole content of the decision — so it belongs behind a name rather than inline in the
#   swap, where a reader had to simulate which source wins under which emptiness.
#   1. the mint reply, when it carries one — the freshest truth the server just told us
#   2. the file we are about to overwrite — the prior login's own kind, carried rather than
#      guessed, because a swap should not silently downgrade an account's plan
#   3. `max` — the last resort, and a guess; it is a label, not an entitlement, so a wrong
#      one mislabels a row rather than grants extra budget
# .note = the file read allowlists ONE case: no live credentials file yet (a first swap on a
#   fresh machine). that is the expected absence, and an empty read just falls to the guess.
# ⚠️ a file that is THERE but unparseable is NOT that case, and it used to be muted into it —
#   a torn file and a genuinely `max` account both stamped `max`, with no signal. the guess is
#   still taken (a wrong kind mislabels a row; it grants no budget, so it must not halt a
#   swap), but it now says so, because a silent guess about a file we could not read is the
#   shape that teaches a reader to trust the label (`rule.forbid.failhide`).
_brains_auth_kind_for_mint() {
  local kind rc
  kind="$(_brains_auth_mint_field "$1" kind)"
  [[ -n "$kind" ]] && { printf '%s' "$kind"; return; }
  kind="$(_brains_auth_creds_field "$_BRAINS_AUTH_LIVE_CREDS" '.claudeAiOauth.subscriptionType')"
  rc=$?
  [[ -n "$kind" ]] && { printf '%s' "$kind"; return; }
  (( rc != 0 )) \
    && echo "🐢 heads up — could not read the prior plan kind from ${_BRAINS_AUTH_LIVE_CREDS}; stamped 'max'" >&2
  printf 'max'
}

# ══ §4. identity ladder — who does a token belong to, and how sure are we? ═══
# .what = is $1 already one of the newline-separated reaches on stdin?
# .why  = names the membership test the sweep's union needs. `grep -qxF "$x" <<< "$list"` had
#   to be decoded to see it asks "is this reach already in the list?" — and the -x/-F pair
#   carries the weight (whole-line, literal), so a reader also had to know that a partial or
#   regex match would union a reach that merely LOOKS like one already there.
_brains_auth_has_reach() {
  grep -qxF "$1"
}

# .what = does the signed-in account belong in this sweep? ($1=arc, $2=the --reach asked for,
#   $3=the reach signed in now, $4=the newline-separated reaches already enumerated)
#   0 = union it in, 1 = leave it out
# .why  = the sweep asked this as a three-clause predicate chained under one `if`, so a reader
#   had to hold all three clauses and their interaction to know when the live account joins —
#   the compound-boolean class `rule.forbid.inline-decode-friction` names. each clause was
#   individually a named read, but the CONJUNCTION had no name, and the conjunction is the
#   decision. named here, the orchestrator line reads as intent.
# .note = the three clauses, and why each is a veto:
#   - actionable arc — an unverified name comes from a file that can lag the live token, so it
#     would invent a row for an account that is not signed in
#   - `@all` — a narrowed read asked for one account; the live one is not it unless named
#   - not already enumerated — the keyrack copy and the live login are the same subscription
#     when both are present, and a duplicate row reads as two accounts
_brains_auth_should_union_active() {
  local arc="$1" sub="$2" active="$3" reaches="$4"
  _brains_auth_identity_is_actionable "$arc"    || return 1
  [[ "$sub" == "@all" && -n "$active" ]]        || return 1
  _brains_auth_has_reach "$active" <<< "$reaches" && return 1
  return 0
}

# .what = ask which account an access token belongs to; emit `<uuid>\t<email>` ($1=ua, $2=access)
# .why  = the token is the only honest source of its own identity. under the reach scheme the
#   email it reports IS the name the account's key is filed under, so this one call answers
#   both "who is signed in?" and "where does this token belong?" — the reads that let a swap
#   made behind our back be noticed, and a new account be filed with no name to invent.
# .note = the EXIT CODE carries what stdout cannot: 0 = a read that completed (stdout holds the
#   identity, or is empty because there genuinely is none), 1 = the read FAILED and the identity
#   is UNKNOWN. callers must not treat those alike — "no account signed in" invites an overwrite,
#   "could not tell" must refuse one (rule.forbid.failhide).
_brains_auth_who_for_access() {
  local ua="$1" access="$2" resp code body uuid email
  [[ -z "$access" ]] && return 0
  # the access token rides curl's stdin config (-K -), never argv, so it stays out of /proc
  resp="$(printf 'header = "Authorization: Bearer %s"\n' "$access" \
    | curl -sS -m "$_BRAINS_AUTH_HTTP_TIMEOUT" -w $'\n%{http_code}' "$_BRAINS_AUTH_PROFILE_URL" \
        -H "anthropic-beta: ${_BRAINS_AUTH_ANTHROPIC_BETA}" \
        -H "User-Agent: ${ua}" \
        -H "Content-Type: application/json" \
        -K -)"
  code="${resp##*$'\n'}"
  body="${resp%$'\n'*}"
  # a non-200 is an UNREAD identity, never an absent one — say so via the exit code
  [[ "$code" == 200 ]] || {
    [[ -n "${BRAINS_AUTH_DEBUG:-}" ]] && printf '🔎 profile http_%s: %s\n' "$code" "$body" >&2
    return 1
  }
  uuid="$(jq -r '.account.uuid // empty' <<< "$body" 2>/dev/null)"
  email="$(jq -r '.account.email // empty' <<< "$body" 2>/dev/null)"
  # a 200 whose body we cannot parse is also an unread identity, not an absent one
  [[ -z "$uuid" ]] && {
    [[ -n "${BRAINS_AUTH_DEBUG:-}" ]] && printf '🔎 profile 200 but no account.uuid: %s\n' "$body" >&2
    return 1
  }
  printf '%s\t%s' "$uuid" "$email"
  return 0
}

# .what = is $1 shaped like the email a key is cut at? (0 = yes)
# .why  = a reach IS an email, so the shape check is the same in all three commands. it was
#   hand-rolled verbatim in each, which is three places for one rule to drift — and the drift
#   is silent: a key cut at a typo'd reach STORES fine, then reads back only for someone who
#   repeats the typo. so the check is a prevention (`rule.prefer.prevent-over-correct`), and
#   a prevention kept in three copies is one edit away from a prevention in two.
# .note = deliberately loose. this refuses a typo of SHAPE (a bare slug, a stray space, an
#   absent dot) — it does not adjudicate what is a deliverable address. the authority on
#   whether an account exists is the api, and it already answers that on every read.
_brains_auth_is_reach() {
  [[ "${1:-}" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]
}

# .what = is $1 a durable subscription REFRESH token? (0 = yes)
# .why  = the same reason `_brains_auth_is_reach` exists, applied to the other shape this
#   namespace decides on. `[[ "$x" == sk-ant-ort* ]]` was spelled at four sites — the store
#   guard, the park read, the swap guard, and the sweep's classifier — which is the rule of
#   three crossed on a check that decides whether a credential is usable at all.
#   ⚠️ the four sites do not merely repeat a prefix, they encode a FACT about anthropic's
#   token namespace, and that namespace is not ours to version. the day a new prefix appears,
#   a named predicate is one edit; four bare globs are four edits and a silent miss on the one
#   that gets forgotten — read as "your token is stale", sending a human to re-auth a token
#   that was fine.
_brains_auth_is_refresh_token() {
  [[ "${1:-}" == sk-ant-ort* ]]
}

# .what = is $1 a pay-per-use api key rather than a subscription token? (0 = yes)
# .why  = the near-miss the sweep must name precisely. an `sk-ant-api…` key authenticates
#   fine and has no subscription budget at all, so it earns its own error code
#   (`api_key_not_oauth`) rather than the generic "stale token" — the two send a human to
#   two different fixes. one site today; it is named beside its sibling so the pair reads as
#   one decision about one namespace, rather than a predicate and a loose glob.
_brains_auth_is_api_key() {
  [[ "${1:-}" == sk-ant-api* ]]
}

# .what = the error code a stored token's SHAPE earns ($1=token); empty when the shape is fine
# .why  = the read path and the swap path were each asked "is this stored value usable?" and
#   each answered on its own. the read path told the two failures apart — an `sk-ant-api…` key
#   is `api_key_not_oauth` ("that is a pay-per-use key, it has no subscription budget"), while
#   any other wrong shape is `needs_reauth`. the swap path collapsed both into one sentence,
#   "your stored token is stale", so the human who had stored an api key by mistake was told
#   to re-auth — which stores another token of whatever kind they reach for next, and can
#   loop them straight back to the same message.
#   one classifier now answers for both, so the swap cannot be less precise than the read.
# .note = it returns a CODE, not a sentence, so each caller renders it through the shared hint
#   table. the classification and the text it earns stay one fact with one home.
_brains_auth_err_for_token_shape() {
  [[ -z "${1:-}" ]]                  && { printf 'no_token';          return; }
  _brains_auth_is_api_key "$1"       && { printf 'api_key_not_oauth'; return; }
  _brains_auth_is_refresh_token "$1" || { printf 'needs_reauth';      return; }
  printf ''
}

# .what = the error code a keyrack read's EXIT CODE earns ($1=rc); empty when the read worked
# .why  = the twin of the shape classifier above, and it exists for the same defect found on
#   the other axis. `_brains_auth_get_token` declares two distinct failures — rc 2 = the key was
#   never stored (a CONSTRAINT a sign-in fixes), rc 1 = the keyrack itself could not be read (a
#   MALFUNCTION a sign-in is powerless against). the READ path honored that split; the SWAP path
#   collapsed both into one hand-typed `return 1`, so a never-stored account was reported as
#   "keyrack could not read" and exited 1. that hands the human a retry for a state only
#   `brains.auth.set` can clear, and hands a `$?` consumer the wrong severity — the exact
#   contract this file declares two functions away, broken by the command with the most to lose.
#   both paths now ask the same leaf, so a swap cannot be less precise than a read about the
#   same stored key.
# .note = a CODE, not a sentence — the hint and the exit code are rendered by the shared tables.
_brains_auth_err_for_keyrack_rc() {
  (( ${1:-0} == 0 )) && { printf '';                   return; }
  (( ${1:-0} == 2 )) && { printf 'keyrack_absent';     return; }
  printf 'keyrack_unreadable'
}

# .what = read the email out of a `<uuid>\t<email>` identity ($1=who)
# .why  = the email IS the reach a key is filed under, so this is the single most-read field
#   in the namespace. `${who#*$'\t'}` is a positional-format extraction: to know what it
#   yields, a reader must first know the emitter packs uuid-then-email and then simulate the
#   substring removal. named once, every caller reads the intent instead of the mechanics.
# .note = the tab-packed shape is an implementation detail of _brains_auth_who_for_access.
#   these two accessors are the ONLY places that know it, so the format can change here
#   alone — with three hand-rolled splits it could not.
_brains_auth_email_of_who() { printf '%s' "${1#*$'\t'}"; }

# .what = read the account uuid out of a `<uuid>\t<email>` identity ($1=who)
# .why  = the pair to _brains_auth_email_of_who; same reason, other field.
_brains_auth_uuid_of_who() { printf '%s' "${1%%$'\t'*}"; }

# .what = the live access token, but ONLY while it is still valid; the rc names why not
# .why  = two callers ran this identical sequence — read `.claudeAiOauth.accessToken`, read
#   `.claudeAiOauth.expiresAt`, compute `now_ms`, compare — from two places ~1,380 lines apart,
#   with no comment at either site that the other existed. that is the SAME defect shape the
#   usage classifier carried (a hazard fixed on one path, un-inherited by its twin), caught
#   here BEFORE a divergence rather than after: the next edit to this rule — say an expiry
#   grace window, or a clock-skew allowance — would have landed on one site and left the other
#   on the old rule, and the two sites disagree about a CREDENTIAL's validity.
# .note = this leaf deliberately does NOT decide what to do about a stale token, because its
#   two callers legitimately disagree: `whoami` falls back to claude's profile file (a name
#   that can LAG, but is usable), while `node_for_reach` emits `active_token_expired` (a named
#   refusal). the shared part is the READ and the FRESHNESS TEST; the verdict is the caller's.
#   to have pulled the branch in too would have fused two behaviors that differ on purpose.
# .note = an expired live token is never ours to renew — claude renews it on its own next call,
#   and a refresh here would rotate the token out from under an open session
#   (hazard.claude-oauth-one-holder-per-token.md). hence a rc, never a repair.
#   rc 0 = FRESH, stdout holds the token   rc 1 = file present but UNPARSEABLE
#   rc 2 = no token (absent file or field) rc 3 = present but EXPIRED
_brains_auth_access_for_live() {
  local access exp_ms now_ms crc
  access="$(_brains_auth_creds_field "$_BRAINS_AUTH_LIVE_CREDS" '.claudeAiOauth.accessToken')"
  crc=$?
  (( crc != 0 )) && return 1
  [[ -z "$access" ]] && return 2
  exp_ms="$(_brains_auth_creds_field "$_BRAINS_AUTH_LIVE_CREDS" '.claudeAiOauth.expiresAt')"
  [[ -z "$exp_ms" ]] && exp_ms=0
  now_ms=$(( $(date +%s) * 1000 ))
  (( exp_ms <= now_ms )) && return 3
  printf '%s' "$access"
  return 0
}

# .what = ask who the live token belongs to; emit `<uuid>\t<email>` or empty ($1=ua)
# .why  = the one read that under-the-hood swaps cannot fool. it prefers the api (authoritative
#   for the token in hand) and falls back to claude's own profile file when the access token
#   has expired and the api would only answer 401.
# .note = an identity read has THREE outcomes, and the exit code names which one you hold:
#     0 = VERIFIED — the api answered for the token in hand; authoritative
#     2 = UNVERIFIED — only claude's profile file answered; it may be STALE and WRONG
#     1 = UNKNOWN — every source failed
#   ⚠️ 2 is the outcome that bites. ~/.claude.json can name a DIFFERENT account than the one
#   the live token belongs to — the two files are written at different moments and no mechanism
#   keeps them in step, so the profile LAGS reality with no signal that it does. a caller that
#   tests only "did the read succeed?" accepts that stale answer as truth.
#   so: an unverified identity may LABEL a display value, and must never AUTHORIZE a mutation.
# ⚠️ a CORRUPT live credentials file is the third input this must not confuse with the other
#   two. it reads as "no access token", which skips the api branch and drops through to the
#   profile file — the LAGGING source, which may name a different account entirely. so the
#   outcome is right (it leaves by the unverified door, and `identity_is_actionable` refuses a
#   mutation on it) but SILENT: the human is handed a name with no hint that the file holding
#   the live token could not be read. the read now carries its cause, and the degradation says
#   so once (`rule.forbid.failhide`).
_brains_auth_whoami() {
  local ua="$1" access who wrc uuid email crc prc

  # the read + freshness test are shared with node_for_reach's active branch; the VERDICT is
  # not. rc 1 is the only one this caller acts on — a torn file must still say so.
  access="$(_brains_auth_access_for_live)"
  crc=$?
  # one warn for the file, not one per field — the fields share a cause
  (( crc == 1 )) && _brains_auth_say_unparsed "$_BRAINS_AUTH_LIVE_CREDS" \
    "so the account name below comes from ${_BRAINS_AUTH_LIVE_PROFILE}, which can LAG the live token"

  # ask the api only while the live access token is still valid — an expired one yields a 401
  # that says no more about identity, and we must NOT refresh it (that would rotate the token
  # out from under an open claude session; hazard.claude-oauth-one-holder-per-token.md)
  if (( crc == 0 )); then
    who="$(_brains_auth_who_for_access "$ua" "$access")"
    wrc=$?
    (( wrc == 0 )) && [[ -n "$who" ]] && { printf '%s' "$who"; return 0; }
  fi

  # fallback: claude's own record of the account it signed in as — a LAGGING record, so it
  # leaves by the unverified door (2), never the verified one (0)
  # ⚠️ the profile read carries its cause too. a TORN profile reads empty, so the function
  #   returns 1 — "unknown identity" — which is indistinguishable from a machine that never
  #   signed in. the outcome is fail-safe either way (an unknown identity authorizes no act),
  #   but the CAUSE is mislabeled: a human is told no login was found when a login record was
  #   right there and could not be parsed. same family, same leaf, same one-warn-per-file rule.
  uuid="$(_brains_auth_creds_field "$_BRAINS_AUTH_LIVE_PROFILE" '.oauthAccount.accountUuid')"
  prc=$?
  email="$(_brains_auth_creds_field "$_BRAINS_AUTH_LIVE_PROFILE" '.oauthAccount.emailAddress')"
  (( prc != 0 )) && _brains_auth_say_unparsed "$_BRAINS_AUTH_LIVE_PROFILE" \
    "so no account name could be read from it — the identity reads as UNKNOWN, not as absent"
  # both sources dry = the identity is UNKNOWN, and the exit code must say so
  [[ -z "$uuid" ]] && return 1
  printf '%s\t%s' "$uuid" "$email"
  return 2
}

# .what = may an identity read of this quality authorize an act? ($1=arc) 0 = yes, 1 = refuse
# .why  = three sites asked the same question of the same two magic numbers, each with its own
#   `(( arc == 1 ))` / `(( arc == 2 ))` pair and its own comment. self-aware duplication is
#   still duplication: a fourth caller, or a fourth outcome added to the ladder, would have
#   three places to update in lockstep with only prose to hold them together — and the thing
#   that drifts apart is the check that stands between a read and a token rotation.
#   so the question is asked once, here, and its answer is what the call sites branch on.
# .note = this decides only WHETHER to act. it deliberately does not name the FIX, because the
#   two refused codes need different ones (unknown wants a session; unverified wants a renewed
#   token) — that split stays with `_brains_auth_fix_for_error`, which already owns remediation.
_brains_auth_identity_is_actionable() {
  (( ${1:-1} == 0 ))
}

# .what = what a swap should DO, given the target and the live identity — a pure verb
#   ($1=reach, $2=the reach signed in now, $3=how well $2 is known: 0|1|2)
#   emits one of: noop | refuse_unknown | refuse_unverified | proceed
# .why  = the swap's authorization matrix was fused with the `echo` calls that report it, so
#   the one decision that gates a credential overwrite could be exercised only by a live run.
#   the leaves around it (park, install) are clamped; the branch that decides whether to reach
#   them at all was not. as a pure verb it snapshots with no network, the same shape that
#   already serves `_brains_auth_fix_for_error` and `_brains_auth_render`.
# .note = the order is load-bearing, and it is refuse-BEFORE-noop. the reverse looks kinder —
#   "you asked for the account you are already on, so there is no token to rotate, so let it
#   pass" — and it lies. when the identity is unproven, `$active` is a GUESS, so `reach ==
#   active` may simply be false in reality. a `noop` would then report "already signed in as
#   kai@x" while the machine is on someone else, and the human proceeds on that answer. an
#   unproven identity cannot authorize a claim about who is signed in any more than it can
#   authorize a swap.
_brains_auth_use_decide() {
  local reach="$1" active="$2" arc="${3:-1}"
  if ! _brains_auth_identity_is_actionable "$arc"; then
    (( arc == 2 )) && { printf 'refuse_unverified'; return; }
    printf 'refuse_unknown'; return
  fi
  [[ -n "$active" ]] && [[ "$reach" == "$active" ]] && { printf 'noop'; return; }
  printf 'proceed'
}

# .what = what a no-arg READ of the live login should report ($1=the reach signed in now,
#   $2=how well it is known: 0|1|2) — a pure verb. emits one of:
#   unknown | absent | unverified | verified
# .why  = the read branch of `_brains_auth_use` tested `(( arc == 1 ))` and `(( arc == 2 ))`
#   with the raw codes at the call site, so a reader had to already hold the tri-state
#   contract to know what either line produced — the positional-code decode
#   `rule.forbid.inline-decode-friction` names. it was also the site that REPORTS that
#   contract to a human, which is the worst one to leave as bare arithmetic.
#   as a pure verb the four outcomes carry names, snapshot with no network, and let the
#   orchestrator read as a case over words rather than over numbers.
# .note = it re-derives no part of the tri-state itself. `_brains_auth_identity_is_actionable`
#   still owns "may this authorize an act", and `_brains_auth_ident_err_for_arc` still owns the
#   unverified-vs-unknown split — this leaf composes those two rather than restate either, so
#   a fourth outcome added to the ladder lands in one place, not three.
# .note = the order carries weight, and it is refuse-BEFORE-absent. an unnamed login is NOT
#   an empty one: were `[[ -z "$active" ]]` tested first, a machine that is signed in but whose
#   token could not be read would be reported as "no account is signed in" — the exact
#   confusion this command exists to prevent.
_brains_auth_active_verdict() {
  local active="$1" arc="${2:-1}"
  if ! _brains_auth_identity_is_actionable "$arc"; then
    case "$(_brains_auth_ident_err_for_arc "$arc")" in
      active_identity_unverified) printf 'unverified' ;;
      *)                          printf 'unknown'    ;;
    esac
    return
  fi
  [[ -z "$active" ]] && { printf 'absent'; return; }
  printf 'verified'
}

# .what = the reach the global claude is signed in as right now, or empty if unknown ($1=ua)
# .why  = the read half of the one-holder rule, re-derived from the live token on EVERY call —
#   never cached, never recorded. that is what lets a swap made behind our back (a plain
#   `claude /login`) be picked up correctly, with no record to keep and none to correct.
# .note = under the reach scheme this is a straight read: an account's email IS its reach, so
#   the answer the token gives us is already the name its key is filed under. no join table
#   sits between our name and theirs, so no middle record can go stale.
# .note = the exit code carries what stdout cannot, and callers MUST branch on it:
#     0 + a reach  = VERIFIED by the api — safe to act on, a mutation included
#     2 + a reach  = UNVERIFIED (it came from the profile file, which lags) — safe to DISPLAY,
#                    never to authorize a park, an overwrite, or a refresh decision
#     0 + empty    = genuinely no live login (no creds file) — safe to overwrite
#     1 + empty    = a login EXISTS but could not be named — refuse to touch it
#   collapse 1 into 0 and "unknown" becomes "absent"; collapse 2 into 0 and a STALE name
#   becomes truth. either collapse ends the same way: the token of the account you actively
#   use gets rotated out from under you.
_brains_auth_active_reach() {
  local ua="${1:-$(_brains_auth_ua)}" who wrc uuid email
  # no creds file = genuinely no one signed in; that is a known answer, not a failed read
  [[ -f "$_BRAINS_AUTH_LIVE_CREDS" ]] || return 0

  who="$(_brains_auth_whoami "$ua")"
  wrc=$?
  (( wrc == 1 )) && return 1
  uuid="$(_brains_auth_uuid_of_who "$who")"
  email="$(_brains_auth_email_of_who "$who")"
  # an identity with no email is unusable as a reach — unknown, never a guess
  [[ -z "$uuid" || -z "$email" ]] && return 1
  printf '%s' "$email"
  # carry the verified/unverified distinction through untouched — this function narrows the
  # identity to a reach, and must not launder an unverified one into a verified answer
  return "$wrc"
}

# ══ §5. render leaves — bars, clocks, error nodes ════════════════════════════
# .what = round a percent to a whole number ($1=percent)
# .why  = name the awk round so the render reads as intent, not decode
_brains_auth_round() {
  awk -v u="${1:-0}" 'BEGIN{printf "%.0f", u}'
}

# .what = draw a bar filled to the percent you pass ($1=percent, $2=width=10)
# .why  = one shared gauge glyph for the session + week windows
_brains_auth_bar() {
  local pct="${1%%.*}" w="${2:-10}" filled i out=''
  [[ -z "$pct" ]] && pct=0
  filled=$(( pct * w / 100 ))
  (( filled > w )) && filled=$w
  (( filled < 0 )) && filled=0
  # append the glyphs directly — NOT via `tr`, which maps bytes: a 3-byte utf-8
  # block (█ = e2 96 88) would collapse to one invalid byte and render as �.
  for (( i = 0; i < filled; i++ )); do out+='█'; done
  for (( i = filled; i < w; i++ )); do out+='░'; done
  printf '%s' "$out"
}

# .what = format an iso timestamp as a countdown "2h14m" from now ($1=iso)
# .why  = the vision shows the session reset as a time-until countdown
_brains_auth_until() {
  local iso="$1" target now diff h m
  [[ -z "$iso" ]] && { printf '?'; return; }
  target="$(date -d "$iso" +%s 2>/dev/null)" || { printf '%s' "$iso"; return; }
  now="$(date +%s)"
  diff=$(( target - now ))
  (( diff < 0 )) && diff=0
  h=$(( diff / 3600 )); m=$(( (diff % 3600) / 60 ))
  printf '%dh%02dm' "$h" "$m"
}

# .what = format an iso timestamp as a weekday + clock "fri 09:00" ($1=iso)
# .why  = the vision shows the week reset as a day+time, not a countdown
_brains_auth_when() {
  local iso="$1" out
  [[ -z "$iso" ]] && { printf '?'; return; }
  out="$(date -d "$iso" '+%a %H:%M' 2>/dev/null)" || { printf '%s' "$iso"; return; }
  printf '%s' "$out" | tr '[:upper:]' '[:lower:]'
}

# .what = extract the error code from a slug node, or empty if none ($1=node json)
# .why  = keep the shape-test out of the render, so the render reads as intent
_brains_auth_get_error() {
  jq -r 'if type=="object" and has("error") then .error else "" end' <<< "$1"
}

# .what = build a failure node for one account ($1=error code)
# .why  = the WRITER half of the accessor above, so the node shape is owned in one place
#   rather than hand-spelled at each of the eleven early returns that emit one.
# .note = it goes through `jq --arg` rather than a printf template, so the value is escaped
#   by construction. one site used to interpolate a variable straight into a hand-built JSON
#   string; that was latent (the value only ever came from a fixed literal set), but it was
#   the one seam in the namespace where a quote in an error code would emit a node that
#   `_brains_auth_get_error` could not parse — and an unparseable node reads as a MISSING
#   account, which is the silent-loss shape this namespace has been bitten by before.
_brains_auth_error_node() {
  jq -nc --arg e "$1" '{error:$e}'
}

# .what = write a top-level error node to stdout for a --json caller ($1=err)
# .why  = the BUILD above is compact because its nodes get folded into a bigger object that
#   the sweep pretty-prints once at the end (`jq . <<< "$combined"`). a top-level error takes
#   no such pass, so to emit the built node raw would hand `--json` two different layouts for
#   one flag — pretty on the success path, compact on every failure. so the emit adds the same
#   pass the success path applies, and the two agree.
# .note = the three top-level sites used to hand-roll `jq -n '{error:"…"}'` instead of reaching
#   for the builder at all, and had ALREADY drifted from it (`-n` vs `-nc`) — which is what
#   proves a second spelling of one shape does not stay a second spelling for long. build in
#   one place, emit in one place, and neither can drift from the other.
_brains_auth_emit_error() {
  jq . <<< "$(_brains_auth_error_node "$1")"
}

# ══ §6. keyrack i/o — the durable home for every parked refresh token ════════
# .what = list the reaches our one subscription key is cut for, in the global keyrack
# .why  = --reach @all sweeps every stored account, so the orchestrator needs the list
# .note = the manifest is keyed by ADDRESS (`slug@reach`), and a reach is an email that
#   itself holds an `@` — so an address must never be split back on `@` to recover the two
#   halves. keyrack already records them as separate FIELDS (`slug`, `reach.exid`), so we
#   read those instead.
_brains_auth_reaches() {
  local raw list
  # let keyrack's own error surface (do not hide it); fail loud on non-zero.
  # ⚠️ the absent `--org @all` here is deliberate, and it is NOT an asymmetry with the get/set
  #   leaves. `rhx keyrack list --help` accepts exactly five options — `--owner`, `--for`,
  #   `--prikey`, `--json`, `-h` — and no `--org` or `--env` among them, so it cannot be
  #   scoped: it lists every key on the host, global ones included. the slug match below is
  #   what narrows that to our subscription key.
  #   this is pinned rather than merely asserted because the shape it would fail into is the
  #   silent one — were `list` in fact org-scoped and defaulted to @this, a `--reach @all`
  #   sweep would omit every globally stored account and read back as "no subscriptions",
  #   which looks identical to a keyrack that was never filled. re-verified against a live
  #   `keyrack list --help` at i029; re-verify there, not from this comment, before you
  #   change it.
  raw="$(rhx keyrack list --owner "$_BRAINS_AUTH_KEYRACK_OWNER" --json)" || {
    echo "🐢 bummer dude — keyrack list failed (is it unlocked?)" >&2
    return 1
  }
  # parse as a checked step: a malformed json must surface here, never get swallowed
  # mid-pipeline into a silent empty list (which would misread as "no subscriptions")
  list="$(jq -r --arg s "$_BRAINS_AUTH_SLUG" \
    '.[] | select(.slug == $s) | .reach.exid // empty' <<< "$raw")" || {
    echo "🐢 bummer dude — keyrack json was malformed (could not read the reaches)" >&2
    return 1
  }
  [[ -n "$list" ]] && printf '%s\n' "$list"
  return 0
}

# .what = write one account's refresh token into the global keyrack at its reach
#   ($1=reach, $2=token)
# .why  = every write goes through one place, so the address a token lands at cannot drift
#   between the paths that write it (first store, swap-time stow, rotation write-back,
#   migration). a drift there is the worst kind: the write reports success and the read looks
#   in another spot, so the account reads as "not stored" while its only token sits elsewhere.
# .note = the value rides stdin, never argv, so the token stays out of the process list.
_brains_auth_set_token() {
  local reach="$1" token="$2"
  [[ -z "$reach" || -z "$token" ]] && return 1
  printf '%s' "$token" | rhx keyrack set \
    --owner "$_BRAINS_AUTH_KEYRACK_OWNER" --org @all --env "$_BRAINS_AUTH_KEYRACK_ENV" \
    --key "$_BRAINS_AUTH_KEY" --reach "$reach" \
    --vault os.secure --mech PERMANENT_VIA_REPLICA >/dev/null
}

# .what = read one account's refresh token back out of the global keyrack ($1=reach)
# .why  = the read twin of _brains_auth_set_token, and the same anti-drift reason. it also carries
#   the unlock: `keyrack get` reads the daemon, not the vault, so a key nobody has unlocked
#   this session is invisible — an unlock-less read would report "not stored" for a key that
#   is plainly there. unlock's stdout tree is dropped (callers emit json); its stderr stays.
# .note = the EXIT CODE separates two causes a single non-zero once flattened into one:
#     0 = the token was read (stdout holds it)
#     1 = the keyrack could not be READ — the daemon is down, the key is locked, the host
#         manifest is absent. OURS to fix, and a retry may fix it.
#     2 = the key is genuinely ABSENT from the manifest — this account was never stored.
#         the CALLER's to fix, by a `brains.auth.set`.
#   both used to be `return 1` and both rendered "not stored yet (run: brains.auth.set)" — so a
#   locked keyrack sent the human through a browser sign-in that cannot possibly fix a lock,
#   and an exit-code consumer read a transient fault as a permanent one and never retried.
#   the split is read from keyrack's own exit code, which carries the same two senses — see
#   the note on the branch below for why its prose must never be matched instead.
# .what = the set of reaches already unlocked by THIS command; reset per invocation
# .why  = see `_brains_auth_unlock_once` below.
# .note = a plain delimited string, not an assoc array, on purpose: this file is sourced by
#   both bash and zsh, and `declare -A` index syntax differs between them. a string with `|`
#   fences is portable, and a reach is an email so it can never hold a `|`.
_BRAINS_AUTH_UNLOCKED=''

# .what = clear the per-invocation unlock memo
# .why  = the memo must NOT outlive one command. an unlock has a TTL (~9h), so a memo that
#   survived in a long-lived interactive shell would skip an unlock the keyrack has since
#   re-locked, and the read would fail as `keyrack_unreadable` — a self-inflicted error whose
#   hint tells the human to run the very unlock we decided to skip. so every entry point
#   resets it, and the memo's whole life is one command.
_brains_auth_unlock_reset() { _BRAINS_AUTH_UNLOCKED=''; }

# .what = unlock one reach's key, at most once per command ($1=reach)
# .why  = the unlock used to run on EVERY `_brains_auth_get_token` call, and that call is not
#   once per account: `_brains_auth_await_rotation` re-reads the token up to
#   `_BRAINS_AUTH_RACE_TRIES` (3) more times when a mint is rejected. so a `--reach @all` sweep
#   over N accounts with dead tokens issued up to 4N `rhx keyrack unlock` subprocesses to read
#   N secrets — and the extra 3N buy exactly no information, because the unlock is idempotent
#   and its effect persists for the rest of the command.
#
# ⚠️ this is not a micro-optimization. on this machine a keyrack-daemon accumulation once
#   filled zram and drove the desktop into disk-swap thrash, so a command that multiplies
#   keyrack subprocesses by the number of DEAD accounts — precisely the case a human runs
#   repeatedly while they try to fix those accounts — is a footgun aimed at the worst moment.
#   the sweep now issues at most one unlock per account, whatever the retry count.
_brains_auth_unlock_once() {
  local reach="$1"
  case "$_BRAINS_AUTH_UNLOCKED" in
    *"|${reach}|"*) _brains_auth_debug "unlock reach=${reach} SKIPPED (already this run)"; return 0 ;;
  esac
  _brains_auth_debug "unlock reach=${reach}"
  rhx keyrack unlock --owner "$_BRAINS_AUTH_KEYRACK_OWNER" --env "$_BRAINS_AUTH_KEYRACK_ENV" \
    --key "$_BRAINS_AUTH_KEY" --reach "$reach" >/dev/null
  # recorded even on a failed unlock, deliberately: a second attempt in the same command would
  # fail the same way, and the read below already turns that into a named `keyrack_unreadable`
  # whose hint is the unlock command itself. a retry loop here would only multiply the cost
  # this leaf exists to bound.
  _BRAINS_AUTH_UNLOCKED="${_BRAINS_AUTH_UNLOCKED}|${reach}|"
}

# .what = the pre-flight verdict on a stored token — an error code, or empty if it is usable
#   ($1=the keyrack rc, $2=the token read)
# .why  = both commands that read a stored token run the SAME two checks in the SAME order —
#   classify the keyrack rc, then classify the token's shape — and diverge only in how they
#   present the answer (`use` prints a sentence and exits; `usage` folds an error node). that
#   is one fact told twice, and this file has already paid for that shape: each check was
#   hand-rolled at the swap site once, and each was wrong in the same direction — an api key
#   read as "your token is stale" (which loops the human back through the same message), and a
#   never-stored key read as "could not read" (which offers a retry against a state only
#   `brains.auth.set` can clear).
#   the ORDER also matters and is now decided once: the keyrack verdict outranks the shape
#   verdict, because on a failed read `$token` is empty and every shape check would then
#   report a second, misleading fault about a value that was never fetched.
# .note = presentation stays with the caller, deliberately. the two say very different things
#   about the same code, and a message from here would either duplicate or contradict them.
_brains_auth_token_err() {
  local krc="$1" token="$2" err
  err="$(_brains_auth_err_for_keyrack_rc "$krc")"
  [[ -n "$err" ]] && { printf '%s' "$err"; return; }
  _brains_auth_err_for_token_shape "$token"
}

_brains_auth_get_token() {
  local reach="$1" token gerr errfile grc
  [[ -z "$reach" ]] && return 1
  _brains_auth_unlock_once "$reach"
  errfile="$(mktemp)" || return 1
  token="$(rhx keyrack get \
    --owner "$_BRAINS_AUTH_KEYRACK_OWNER" --org @all --env "$_BRAINS_AUTH_KEYRACK_ENV" \
    --key "$_BRAINS_AUTH_KEY" --reach "$reach" --value 2>"$errfile")"
  grc=$?
  gerr="$(cat "$errfile" 2>/dev/null)"
  rm -f "$errfile"

  if (( grc != 0 )); then
    # ⚠️ keyrack's EXIT CODE decides the class, never its prose. keyrack is an ehmpathy tool
    #   and speaks the same dialect this namespace does (rule.require.exit-code-semantics):
    #   2 = the caller must fix it, 1 = it broke. verified against a live absent key, which
    #   answers `status: absent 🫧` and exits 2.
    #   this used to match on keyrack's stderr words — `*'not found'*|*'not in manifest'*` —
    #   which coupled a security-relevant branch to another tool's UNVERSIONED wording. a
    #   copy-edit there, in a repo we do not control, would silently reclassify an absent key
    #   as a malfunction: the human would be told "could not read the keyrack — unlock it" for
    #   an account that was simply never stored, and no unlock could ever fix it. an exit code
    #   is a contract; a sentence is not.
    if (( grc == 2 )); then
      return 2
    fi
    # a malfunction gets keyrack's OWN words through, because our hint for it is necessarily
    # generic ("could not read the keyrack") while keyrack knows which of daemon / lock / host
    # manifest actually failed. an absent key needs no such passthrough — our hint for THAT is
    # already exact ("not stored yet — run: brains.auth.set"), so keyrack's tree would be noise
    # repeated once per account on an @all sweep.
    [[ -n "$gerr" ]] && printf '%s\n' "$gerr" >&2
    return 1
  fi

  printf '%s' "$token" | tr -d '[:space:]'
}

# .what = wait for evidence that another holder rotated a token ($1=reach, $2=the token we used)
#   rc 0 = it changed, and the NEW value is on stdout. rc 1 = it never changed.
# .why  = the whole verdict "your refresh token is dead" rests on this answer, and a single
#   re-read gets it wrong in one direction only — the direction that costs a human a browser
#   re-auth for a healthy account.
#   the sequence that produces the wrong answer:
#     t0  two sweeps read the same stored token T
#     t1  the winner mints; the server rotates T -> T2 and hands T2 to the winner
#     t2  the loser mints with T and is REJECTED, because T is now spent
#     t3  the winner writes T2 back to the keyrack
#   a re-read taken at t2 lands before t3 and sees T unchanged — "no one raced me" — so a
#   perfectly live account renders `refresh_rejected`. the gap t2..t3 is a keyrack write, and
#   it is short, which is exactly why a bounded WAIT closes it while a single read cannot.
# .note = no lock, deliberately, and the reason has not changed: a stale lockfile wedges every
#   later read of that account, which trades a rare wrong message for a permanently dead
#   command. this poll cannot wedge — it is bounded by construction, and it runs ONLY after a
#   mint has already failed, so a healthy read pays none of it.
# .note = the FIRST read takes no wait, so a rotation that already landed is caught instantly.
#   only a genuinely dead token pays the full wait, once, before its verdict.
_brains_auth_await_rotation() {
  local reach="$1" was="$2" now n=0
  while (( n < _BRAINS_AUTH_RACE_TRIES )); do
    now="$(_brains_auth_get_token "$reach")"
    [[ -n "$now" && "$now" != "$was" ]] && { printf '%s' "$now"; return 0; }
    n=$(( n + 1 ))
    (( n < _BRAINS_AUTH_RACE_TRIES )) && sleep "$_BRAINS_AUTH_RACE_WAIT"
  done
  return 1
}

# .what = run an interactive claude sign-in whose whole state lands in $1=authdir
# .why  = the one i/o boundary of the store path, kept apart from the logic around it. it runs
#   an interactive `/login` — NOT `claude setup-token`, which only mints a long-lived token
#   anthropic now rejects on the usage endpoint and persists no refresh token at all (verified
#   live: its isolated dir held .claude.json and no credentials). `/login` writes
#   .credentials.json with the oauth refresh token, the durable secret we actually want.
# .note = the three arguments are each load-bearing:
#   - CLAUDE_CONFIG_DIR aims claude's ENTIRE state at the temp dir, so this sign-in never
#     touches — or logs out — the global ~/.claude session. this is what "isolated" means.
#   - `script(1)` grants a pty, without which claude's tui and browser hand-off do not run
#   - `</dev/tty` hands over the real keyboard even under the rhx proxy skill, whose stdio
#     is piped; with no tty the human could never complete the sign-in
#   output stays visible (logfile /dev/null) so the human can drive the flow. that leaks no
#   secret: `/login` SAVES the token to a file, it never prints it.
# ⚠️ the tty is CHECKED before it is redirected, and the check is the whole point of this
#   guard. `</dev/tty` with no controlling terminal fails as a bare redirection error, and the
#   caller then reads the empty result as "no refresh token captured (did the browser approval
#   complete?)" — which names the wrong cause entirely. it sends a human to redo a sign-in that
#   NEVER STARTED, and the retry cannot succeed, because the fault is the context and not the
#   login. that is a failhide with a helpful voice (`rule.forbid.failhide`), and this file
#   already refuses that shape three times over in `_brains_auth_extract_refresh`'s rc split.
#   rc 3 is distinct from claude's own exit codes so the caller can name this cause alone.
_brains_auth_login_isolated() {
  local authdir="$1"
  [[ -e /dev/tty ]] && : </dev/tty 2>/dev/null || {
    echo "🐢 hold up — brains.auth.set needs a real terminal" >&2
    echo "   it opens an interactive claude sign-in, so it cannot run from cron, CI, or a" >&2
    echo "   piped context with no controlling tty. the login was NOT started." >&2
    echo "   fix: run it yourself in a terminal — brains.auth.set" >&2
    return 3
  }
  CLAUDE_CONFIG_DIR="$authdir" script -q -c "claude" /dev/null </dev/tty
}

# .what = lift the oauth refresh token out of an isolated sign-in dir ($1=authdir)
# .why  = a shape-based find, deliberately, rather than a hardcoded json path. the sign-in
#   writes its oauth state somewhere under CLAUDE_CONFIG_DIR, but WHICH file and how deeply
#   nested both vary by claude version (.credentials.json vs .claude.json). so we slurp every
#   json in the dir and take the first value SHAPED like a refresh token (sk-ant-ort…) via
#   recursive descent — that survives a path change across versions, where a fixed path
#   silently returns empty and reads as "the human abandoned the login".
# .note = emits the token on stdout, or empty. a caller that gets empty must fail loud.
# .note = the exit code separates three outcomes a single "empty" once flattened into one:
#     0 = the state parsed cleanly (stdout = the token, or empty if it held no ort-shaped value)
#     1 = neither file was readable — the sign-in wrote no state at all
#     2 = the state is unparseable — a shape we do not recognize
#     3 = we could not make a temp file to read it — OURS to fix, and it says so itself
#   each earns a DIFFERENT fix, and the prior version reported "did the browser approval
#   complete?" for all three (rule.forbid.failhide).
_brains_auth_extract_refresh() {
  local authdir="$1" blob found jerr jrc errfile
  # ⚠️ this is the ONE muted stream, and it is an allowlist rather than a blanket: claude writes
  #   ONE of these two files depending on version, so "no such file" for the other is the
  #   EXPECTED case, not a failure. an empty read means NEITHER was there, which is a real and
  #   separately-nameable cause — so it is returned as one.
  blob="$(cat "$authdir"/.credentials.json "$authdir"/.claude.json 2>/dev/null)"
  [[ -z "$blob" ]] && return 1

  # ⚠️ jq's stderr is CAPTURED, never discarded. a parse error here means the sign-in persisted a
  #   shape we cannot read — a completely different fix from "the human abandoned the browser
  #   flow" — and a muted version reports the latter for both, sending the human to redo a login
  #   that already succeeded.
  # ⚠️ a mktemp failure is OUR fault (a full /tmp), never a shape we could not read — so it
  #   must not borrow rc 2, which the contract above reserves for "the state is unparseable".
  #   it did, and the caller then said "the sign-in state could not be parsed", which sends the
  #   human back through a browser flow that already succeeded to fix a disk that is full.
  #   it says its own cause and takes rc 3.
  errfile="$(mktemp)" || {
    echo "🐢 bummer dude — could not make a temp file to read the sign-in state" >&2
    echo "   check free space in \${TMPDIR:-/tmp}, then rerun" >&2
    return 3
  }
  found="$(jq -rs '[.[]? | .. | strings | select(startswith("sk-ant-ort"))] | first // empty' \
    <<< "$blob" 2>"$errfile")"
  jrc=$?
  jerr="$(cat "$errfile" 2>/dev/null)"
  rm -f "$errfile"

  if (( jrc != 0 )) || [[ -n "$jerr" ]]; then
    echo "🐢 bummer dude — the sign-in state in ${authdir} could not be parsed" >&2
    echo "   jq: ${jerr:-exit ${jrc}}" >&2
    return 2
  fi

  printf '%s' "$found"
  return 0
}

# ══ §7. command: brains.auth.set — enroll an account ═════════════════════════
# .what = read the value of a --reach/--sub flag; prints it, or fails 2 with the fix
# .why  = all three orchestrators accept the same account flag, and each once carried its own
#   copy of the same three duties: guard the value, accept the pre-reach `--sub` name, and say
#   so. three copies of one contract is three places for it to drift — and it already had
#   drifted in one: `--sub` parsed everywhere but appeared in only two of the three --help
#   texts, so on `set` it was a flag that worked and did not exist.
#
# .note = the value guard is the half that carries weight. a lone `--reach` at the end of the
#   argv makes `shift 2` a bash NO-OP, so the caller's while-loop spins forever in silence.
#   this returns 2 instead, and the suite clamps it with a `timeout` so a regression FAILS
#   rather than hangs.
#
# .note = `--sub` now says it is superseded, every time it is used. it still WORKS — muscle
#   memory must land — but a silent alias is an alias nobody ever abandons, so the notice is
#   what makes the eventual retirement fair rather than a surprise. it goes to stderr, so a
#   `--json` consumer's stdout stays clean.
#
# usage: reach="$(_brains_auth_reach_from_flag "$@")" || return 2 ; shift 2
_brains_auth_reach_from_flag() {
  local flag="$1"
  if [[ $# -lt 2 ]]; then
    echo "🐢 ${flag} needs a value (e.g. --reach you@example.com)" >&2
    return 2
  fi
  [[ "$flag" == '--sub' ]] && \
    echo "🐢 heads up — --sub is the old name; --reach is the term now (both still work)" >&2
  printf '%s' "$2"
}

# .what = store a subscription's oauth token into the global keyrack
# .why  = one-time setup so brains.auth.usage can read the token from anywhere
_brains_auth_set() {
  local reach=''
  _brains_auth_unlock_reset   # the memo lives for exactly one command — see the leaf's .why
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --reach|--sub)
        reach="$(_brains_auth_reach_from_flag "$@")" || return 2
        shift 2 ;;
      -h|--help)
        echo "🐢 brains.auth.set — store a claude subscription oauth token in the global keyrack"
        echo ""
        echo "  usage: brains.auth.set [--reach <email>]"
        echo ""
        echo "  opens an isolated browser sign-in (never your global claude), reads that"
        echo "  session's oauth refresh token, and stores it as"
        echo "  ${_BRAINS_AUTH_KEY} cut at that account's email, in the"
        echo "  global (--org @all) keyrack — so it is reachable from any repo."
        echo ""
        echo "    --reach <email>  only if the account cannot be asked (rare) — the"
        echo "                     email is read from the token itself by default."
        echo "                     alias: --sub (the old name, superseded)"
        echo ""
        echo "  exit codes, for a caller that reads only \$?:"
        echo "    0  the account was stored"
        echo "    1  it broke on our side — retry may help (no private dir, keyrack write)"
        echo "    2  it needs you — a dead token, a bad flag, or a sign-in you did not finish"
        echo ""
        echo "  example: brains.auth.set"
        return 0 ;;
      *) _brains_auth_say_unknown_arg "$1"; return $? ;;
    esac
  done

  # a supplied reach must look like the email it files the key under. reject a bad shape up
  # front (prevent, not correct): a key cut at a typo'd reach stores fine and then reads back
  # only for someone who repeats the typo.
  if [[ -n "$reach" ]] && ! _brains_auth_is_reach "$reach"; then
    echo "🐢 --reach must be an email address — got: $reach" >&2
    return 2
  fi

  # authenticate this subscription in an ISOLATED claude config dir, so the flow never
  # touches your global login. CLAUDE_CONFIG_DIR relocates claude's whole state —
  # credentials, settings, session — into a dir we control. we point it at a fresh temp
  # dir: an empty dir carries no session, so the setup-token flow forces a real browser
  # sign-in and you pick the account for THIS slug (not whatever the cli holds globally).
  # the login persists a session file in that dir; we read the refresh token from it, then
  # delete the dir. your global ~/.claude login stays intact — you are never logged out,
  # and each slug is its own account.
  #
  # .why the REFRESH token (not the printed setup-token): anthropic rejects the long-lived
  #   setup-token on the usage endpoint since ~2026-02. only a short-lived access token,
  #   minted fresh from the refresh token at read time, is accepted — so brains.auth.usage
  #   mints one per read. the refresh token is the durable secret we persist here.
  local authdir refresh
  # ⚠️ an UNCHECKED mktemp here is the one failure that inverts this function's promise. a full
  #   tmpfs or an unwritable TMPDIR leaves `authdir` EMPTY, and every step downstream still
  #   runs: `chmod 700 ""` fails unread, the trap arms on an empty path, and the login is
  #   handed `CLAUDE_CONFIG_DIR=""` — which does NOT aim claude at a private dir, so the
  #   sign-in this header promises "never touches your global login" writes a live refresh
  #   token straight into `~/.claude`, the exact file the isolation exists to protect. an
  #   empty string is a silent default that reads as success, so it is refused here.
  authdir="$(mktemp -d)" || authdir=''
  [[ -n "$authdir" && -d "$authdir" ]] || {
    echo "🐢 bummer dude — could not open a private dir for the sign-in" >&2
    echo "   so the login was NOT started; it would have fallen back to your global claude" >&2
    echo "   fix: free space in \${TMPDIR:-/tmp}, or point TMPDIR at a writable disk" >&2
    return 1
  }
  # the dir holds the isolated session credentials (a secret at rest) — keep it private, and
  # wipe it on EVERY way out of this function, not merely the one we thought of.
  # ⚠️ this used to trap INT alone while the comment claimed "even on a ctrl-c", which read as
  #   a broad guarantee and delivered a narrow one. a SIGTERM (a killed terminal, a logout, a
  #   parent process reaped) left a LIVE, durable oauth refresh token on disk, world-readable
  #   the moment the 0700 dir's parent is walked by a backup or a temp sweeper. so the trap
  #   covers TERM and HUP too, and — the part that actually closes the gap — RETURN, so every
  #   early exit below shreds the dir whether or not its author remembered to.
  chmod 700 "$authdir"
  trap 'rm -rf "$authdir"' INT TERM HUP RETURN

  echo "🐢 paddle out — a claude sign-in opens"
  echo "   ├─ isolated from your global claude — pick any account"
  echo "   ├─ if it does not prompt to log in, type: /login"
  echo "   └─ once you are signed in, type /exit (or ctrl-c) to finish"

  # claude drops into its repl once signed in, so the human ends the session themselves
  # (/exit); when it returns, the login has persisted the token we came for.
  # ⚠️ rc 3 means the login never STARTED (no controlling tty), which is a different fact from
  #   "the login ran and produced no token". to fall through here would hand that context
  #   failure to the extract leaf, which can only report an absent token — and the human would
  #   be told to redo a browser approval that was never opened. the leaf has already said the
  #   true cause; we only need to stop rather than overwrite it with a friendlier wrong one.
  local lrc=0
  _brains_auth_login_isolated "$authdir" || lrc=$?
  # rc 3 is the no-tty refusal and ONLY that; every other rc is claude's own, and those still
  # fall through to the extract below, which reports what the sign-in did or did not leave.
  (( lrc == 3 )) && return 2
  local xrc
  refresh="$(_brains_auth_extract_refresh "$authdir")"; xrc=$?

  # debug: when absent, list the isolated dir so a silent miss cannot hide (no secret shown)
  if [[ -z "$refresh" && -n "${BRAINS_AUTH_DEBUG:-}" ]]; then
    echo "🔎 brains.auth.set: no sk-ant-ort refresh token in ${authdir} (files: $(ls -a "$authdir" 2>/dev/null | tr '\n' ' '))" >&2
  fi

  # shred the isolated credentials the moment the refresh token is lifted. the RETURN trap
  # would also shred them, but this eager shred narrows the window the secret sits on disk
  # from "until the function ends" to "until we hold it in memory". the trap is the backstop
  # for the paths that never reach this line — never a licence to leave the file at rest on
  # the paths that do.
  # ⚠️ the disarm must name EVERY signal the arm named. disarm a subset and the rest stay
  #   armed past this point, so the two lines drift apart with no signal that they have.
  rm -rf "$authdir"
  trap - INT TERM HUP RETURN

  # ⚠️ the three causes each earn their OWN hint, because each earns a different next move.
  #   this branch used to be a single `[[ -z "$refresh" ]]`, so an unparseable state file and
  #   an abandoned browser flow both told the human to redo a login — which, for the former,
  #   is a login they already completed (rule.forbid.failhide).
  #   rc 2 already said its piece on stderr (the jq error), so it is not re-worded here.
  (( xrc == 2 )) && return 1
  if (( xrc == 1 )); then
    echo "🐢 bummer dude — the sign-in left no state behind in the isolated dir" >&2
    echo "   that means the claude session wrote no credentials at all" >&2
    echo "   re-run: brains.auth.set" >&2
    return 1
  fi

  if [[ -z "$refresh" ]]; then
    echo "🐢 bummer dude — no refresh token captured (did the browser approval complete?)" >&2
    echo "   re-run: brains.auth.set" >&2
    return 1
  fi

  # validate the shape at the boundary where bad data enters (pit-of-success): the session
  # refresh token is sk-ant-ort…; an sk-ant-api… value is a pay-per-use api key (no
  # subscription budget). reject anything else loud + at the cause, not later at read time.
  if ! _brains_auth_is_refresh_token "$refresh"; then
    echo "🐢 bummer dude — that is not a subscription refresh token (expected sk-ant-ort…)" >&2
    echo "   brains.auth reads subscription budget via the oauth refresh token" >&2
    return 2
  fi

  # ask the token which account it belongs to — that email is the reach the key is cut at.
  # .why do this now rather than take a name from you: the answer is a fact the token already
  #   carries, so an invented handle could only ever disagree with it. the mint also proves
  #   the captured token actually works, before it is filed as if it did.
  local ua mint mok merr mcode access newref who wrc
  ua="$(_brains_auth_ua)"
  mint="$(_brains_auth_mint_access "$ua" "$refresh")"
  mok="$(_brains_auth_mint_field   "$mint" ok)"
  merr="$(_brains_auth_mint_field  "$mint" error)"
  mcode="$(_brains_auth_mint_field "$mint" code)"
  mcode="${mcode:-?}"

  # ⚠️ a failed mint halts the store, even when --reach named the account for us.
  #   the mint is the ONLY proof the captured token can actually be refreshed, and a refresh
  #   is what every later read does. to file a token the mint just rejected is to store a
  #   value we have already watched fail — the error simply reappears at the next read,
  #   detached from the sign-in that caused it (rule.require.failfast).
  if [[ "$mok" != true ]]; then
    echo "🐢 bummer dude — that sign-in's token could not be refreshed (${merr}, http ${mcode})" >&2
    echo "   it is NOT stored, because the same failure would return on every read" >&2
    echo "   $(_brains_auth_fix_for_error "$merr")" >&2
    # ⚠️ the exit code comes from the SHARED severity table, exactly as `use`'s does. this used
    #   to be a flat `return 1`, so the two store/swap orchestrators disagreed with each other
    #   AND with the table for the same failure: `use` called a dead token a constraint (2)
    #   while `set` called it a malfunction (1). a caller that branches on `$?` to choose
    #   "auto-retry" over "tell the human to re-auth" got opposite answers from two commands
    #   about one fault.
    [[ "$(_brains_auth_severity_for_error "$merr")" == constraint ]] && return 2
    return 1
  fi

  # the mint rotated the stored secret — the rotated one is now the live token, so it is
  # what must be filed. the leaf carries the sent token through when no rotation happened.
  access="$(_brains_auth_mint_field "$mint" access)"
  newref="$(_brains_auth_mint_field "$mint" refresh)"
  [[ -n "$newref" ]] && refresh="$newref"

  who="$(_brains_auth_who_for_access "$ua" "$access")"
  wrc=$?
  # ⚠️ the token's answer OVERWRITES a supplied --reach, and the order is the whole point of
  #   the reach scheme. the vision retired the `--sub <slug>` handle so that no human-typed
  #   name could ever disagree with the token; a `[[ -z "$reach" ]]` guard here would restore
  #   exactly that disagreement, and it would file a live token under an account nobody will
  #   look it up by — silently, while `set` reports success.
  #   `--reach` is a FALLBACK for a token that declines to say who it is, never an override.
  #   clamped by `set.token-identity-outranks-flag` + `set.flag-is-the-fallback`.
  (( wrc == 0 )) && [[ -n "$who" ]] && reach="$(_brains_auth_email_of_who "$who")"

  # with no answer from the token and none supplied, we have no address to file it at. say so
  # plainly: a re-run is a fresh sign-in, so the captured token is not a loss worth a guess.
  if [[ -z "$reach" ]]; then
    echo "🐢 bummer dude — could not read which account that sign-in was for" >&2
    echo "   retry: brains.auth.set" >&2
    echo "   or name it yourself: brains.auth.set --reach you@example.com" >&2
    return 1
  fi

  # store into the global keyrack, repo-independent, cut at the account's own email.
  # note: the write needs your ssh identity to decrypt the host manifest at run time.
  _brains_auth_set_token "$reach" "$refresh" || {
    echo "🐢 bummer dude — keyrack set failed for ${reach}" >&2
    return 1
  }

  echo "🐢 shell yeah — stored ${reach} in the global keyrack"
}
alias brains.auth.set='_brains_auth_set'

# ══ §8. credential-file i/o — ~/.claude, the one live-token holder ═══════════
# .what = whatever refresh token ~/.claude holds RIGHT NOW, or empty when no login is there
# .why  = the compare-and-swap probe. a swap reads who is live at its start, then spends
#   seconds on a network mint before it overwrites that file — and the file is writable by
#   anyone else in that gap: a second `brains.auth.use`, or a plain `claude /login` in another
#   terminal. whoever writes it second destroys the token the first put there.
#
#   that loss is TOTAL, and no step reports it. the account swapped in a moment ago holds its
#   freshly-rotated token in ~/.claude and in no other place — the keyrack copy the mint
#   rotated past is already dead, and the `.bak` covers the account we swapped OFF of, never
#   the one we swapped ON to. so the overwrite is the only copy's last moment.
#
#   so this reads the file again just before the overwrite, and the caller compares. the field
#   compared is the refresh token itself rather than a digest of the file, because the token
#   IS the thing whose loss is the harm — a digest would also fire on an unrelated key claude
#   happened to touch, and would not fire at all if the token moved within an equal-length
#   rewrite. compare what you are about to destroy.
# .note = an unreadable or reshaped file yields empty, which compares UNEQUAL to any token we
#   parked — so a file that turned corrupt mid-flight aborts too, which is right: we cannot
#   park what we cannot read, and to overwrite it anyway would discard it silently.
# .what = read one field out of a claude credentials file ($1=path, $2=jq path)
#   emits the value on stdout; rc 0 = read it (empty when the file or the key is absent),
#   rc 1 = the file is THERE but could not be parsed
# .why  = four readers want one field out of this file — the CAS probe, the park read, the
#   strand check, and the plan-kind carry — and each had spelled its own jq. the path is a
#   claim about a format we do not own, so four spellings is four places to be wrong when it
#   moves.
#
# ⚠️ the RC is the half that carries weight, and its absence was a live defect. every copy
#   muted jq and returned the empty string, so a **corrupt** file answered identically to an
#   **absent** one — and each caller had justified the mute with the absent case alone while
#   the corrupt case rode along under it. the consequences were quiet and each pointed the
#   wrong way:
#     · the CAS probe read empty, compared UNEQUAL, and aborted with "the signed-in account
#       changed while this swap was mid-flight" — it blamed a concurrent writer for a
#       corruption the read had hidden.
#     · the strand check read empty, concluded "not a strand", and let the swap overwrite a
#       `.bak` that may hold a real account's last token — the exact hole the strand guard was
#       built to close, re-opened through a different door.
#   only `_brains_auth_park_read` survived, and by luck: it re-validates the shape afterward.
#   so the two answers are told apart here, once, and each caller decides what a corrupt file
#   means for it (`rule.forbid.failhide`).
# .note = an absent file stays rc 0 with an empty value. every caller means "what is in
#   there?", and "no file" is a legitimate answer (a machine that has never signed in).
_brains_auth_creds_field() {
  local out
  [[ -f "$1" ]] || return 0
  out="$(jq -r "$2 // empty" < "$1" 2>/dev/null)" || return 1
  printf '%s' "$out"
  return 0
}

# .what = announce that a credential-bearing file is present but unparseable ($1=path, $2=consequence)
# .why  = four callers now treat rc 1 as "carry on, but degraded" — they each pick a safe
#   fallback and continue, which is the right call (a torn file must not brick a read). but a
#   degraded path that says so in ONE sentence and a degraded path that says so in four is the
#   same drift `_brains_auth_say_unknown_arg` was extracted to close. the CONSEQUENCE differs
#   per caller, so it stays an argument; the diagnosis does not, so it lives here.
_brains_auth_say_unparsed() {
  echo "🐢 heads up — ${1} is there but could not be parsed" >&2
  echo "   ${2}" >&2
}

_brains_auth_ref_in() {
  _brains_auth_creds_field "$1" '.claudeAiOauth.refreshToken'
}

_brains_auth_live_ref() {
  _brains_auth_ref_in "$_BRAINS_AUTH_LIVE_CREDS"
}

# .what = read the live account's refresh token out of ~/.claude, with no write anywhere
# .why  = the prior account's ONLY live token sits in ~/.claude, and a swap overwrites that
#   file. the keyrack copy is stale by construction (claude rotated past it), so an overwrite
#   with no park orphans the account — its budget goes unreadable and it needs a full browser
#   re-auth. this is the READ half of that park.
# .note = the park is split in two — READ here, FILE later — so the keyrack stays untouched
#   until the new credentials are installed. the order matters and is argued in full at
#   `_brains_auth_park_file`; read it there before you move either half.
_brains_auth_park_read() {
  local live
  [[ -f "$_BRAINS_AUTH_LIVE_CREDS" ]] || return 0
  live="$(_brains_auth_ref_in "$_BRAINS_AUTH_LIVE_CREDS")"
  # a shape we do not recognize is not silently dropped — fail loud, because the caller is
  # about to overwrite the only copy of it
  _brains_auth_is_refresh_token "$live" || return 1
  printf '%s' "$live"
  return 0
}

# .what = does a leftover `.bak` hold the ONLY copy of some account's token? (0=yes)
# .why  = a `.bak` is shredded the instant its park is confirmed, so a `.bak` that is still
#   there means the prior swap's park FAILED — and that file is then the last home of a real
#   account's durable token. the next swap cuts its own `.bak` with a plain `cp`, which would
#   overwrite it and end that account with no error printed and no way back.
#
#   ⚠️ the advertised recovery WAS the destroyer. the park-failure message says "rerun to file
#   it" — but a rerun of `brains.auth.use` reaches this same `cp` first, and by then the live
#   account is the one already swapped in, so the rerun parks the WRONG account and clobbers
#   the stranded one on its way. to follow the hint destroyed the token the hint promised.
#
# .note = a `.bak` whose token EQUALS the live one is NOT a strand. that shape comes from a
#   swap that died between the `cp` and the write — the prior login is still in ~/.claude, so
#   the copy is redundant rather than sole, and to refuse on it would wedge every later swap
#   behind a file that guards no token at all.
_brains_auth_bak_strands() {
  local bakref rc
  bakref="$(_brains_auth_ref_in "${_BRAINS_AUTH_LIVE_CREDS}.bak")"; rc=$?
  # ⚠️ a `.bak` we cannot PARSE counts as a strand. we cannot prove it redundant, and the two
  #   mistakes are not symmetric: to call it redundant destroys a token we could not read,
  #   while to call it a strand costs one refusal and a rescue the human can complete by hand.
  #   an unreadable file used to answer identically to an absent one, so this fell the other
  #   way in silence — see `_brains_auth_creds_field` for the read that now tells them apart.
  (( rc != 0 )) && return 0
  [[ -z "$bakref" ]] && return 1
  [[ "$bakref" == "$(_brains_auth_live_ref)" ]] && return 1
  return 0
}

# .what = file a previously-read live token into the keyrack under its reach ($1=reach, $2=token)
# .why  = the WRITE half of the park, run only AFTER the new credentials are installed.
#
#   ⚠️ the order is the whole point. park-then-install looks natural and is wrong: between the
#   two steps the SAME refresh token sits in both ~/.claude and the keyrack. that is the
#   two-holder state hazard.claude-oauth-one-holder-per-token.md exists to forbid — whichever
#   copy is read next rotates the value and silently kills the other. an install failure in
#   that window leaves the pair standing indefinitely, with no step that undoes it.
#
#   install-then-park closes the window by construction: the keyrack is written only once
#   ~/.claude no longer holds that account, so the token has exactly one holder at every
#   instant. an install failure now writes no keyrack entry at all — the prior login is
#   simply left intact, which is the outcome a failed swap should have.
_brains_auth_park_file() {
  local reach="$1" live="$2"
  [[ -z "$reach" || -z "$live" ]] && return 0
  _brains_auth_set_token "$reach" "$live" 2>/dev/null || return 1
  return 0
}

# .what = the three steps that rescue a token stranded in the `.bak` ($1=what step 2 achieves)
# .why  = two callers walk a human through this same recovery for the same state (an orphaned
#   `.bak` that holds an account's ONLY refresh token): the park-failure message that CREATES
#   the strand, and the pre-flight refusal that later REFUSES to overwrite it. they had the
#   steps spelled out twice, and diverged only in how each framed them — the exact shape
#   `_brains_auth_say_unverified_because` was extracted to fix, one surface later.
# .note = the steps are the RECOVERY, which is identical. the lead-in and the last line are how
#   each caller frames it, which is not (one says "rescue it", the other "rescue it first, then
#   rerun"), so those stay with the caller. only step 2's purpose differs, hence the argument.
# ⚠️ these steps are the only path back for a token that exists nowhere else. a drift between
#   two copies would leave one caller's human with a recipe that no longer matches the file
#   layout — and they would learn that with the token already gone.
_brains_auth_say_bak_rescue() {
  echo "     1. cp ${_BRAINS_AUTH_LIVE_CREDS}.bak ${_BRAINS_AUTH_LIVE_CREDS}" >&2
  echo "     2. brains.auth.set          # ${1}" >&2
  echo "     3. rm -f ${_BRAINS_AUTH_LIVE_CREDS}.bak" >&2
}

# .what = park the account we swapped off of, and say what to do if that park fails
#   ($1=the account swapped off, $2=its token, $3=the account swapped on to)
# .why  = the two outcomes read at very different volumes — the success is two lines of the
#   ordinary flow, the failure is an urgent multi-step rescue — and they had been written as
#   an `if/else` nested inside a second `if`, on the riskiest write surface in the namespace.
#   a reader then held two branches plus an outer condition to learn what became of the prior
#   account's only token. as its own leaf it is guards-then-straight-line: two early exits,
#   then the ordinary path, with no `else` anywhere (`rule.forbid.else-branches`).
# .note = the caller must NOT return on a failure here. the swap itself already stands (the
#   new login is live), so the profile sync and the closing lines below it are still owed —
#   which is exactly why this is a function rather than a guard clause in the orchestrator.
_brains_auth_park_or_strand() {
  local active="$1" parked="$2" reach="$3"
  [[ -z "$active" || -z "$parked" ]] && return 0

  _brains_auth_park_file "$active" "$parked" || {
    echo "🐢 heads up — swapped in ${reach}, but could not stow ${active} into the keyrack" >&2
    echo "   its ONLY token is now ${_BRAINS_AUTH_LIVE_CREDS}.bak. rescue it:" >&2
    _brains_auth_say_bak_rescue "files ${active} back into the keyrack"
    echo "     4. brains.auth.use --reach ${reach}   # swap back to where you meant to be" >&2
    echo "   ⚠️ that file holds a live token in the clear; it is kept ONLY because the keyrack" >&2
    echo "      copy failed. until it is rescued, every swap REFUSES rather than overwrite it." >&2
    return 1
  }

  echo "   ├─ stowed ${active}"
  # ⚠️ .security = the .bak holds the prior account's DURABLE refresh token in the clear. it
  #   exists for exactly one purpose — to be the recovery copy while that token has no other
  #   home. the park just gave it one, so the .bak is now a redundant secret at rest that would
  #   otherwise outlive the swap forever, ride into every ~ backup, and sit there until the
  #   NEXT swap overwrote it. so it is shredded the moment, and only the moment, the keyrack
  #   copy is confirmed.
  rm -f "${_BRAINS_AUTH_LIVE_CREDS}.bak"
  return 0
}

# .what = write a secret payload to a path, atomically and privately ($1=path, $2=payload)
# .why  = the two files this namespace rewrites both hold credentials, and both need the same
#   four steps in the same order: a temp file BESIDE the target (so the rename stays within one
#   filesystem and is therefore atomic), `chmod 600` BEFORE the secret lands in it, the write,
#   then the rename. claude only ever observes the old file or the complete new one — never a
#   torn middle, which would log every account out at once.
#
#   ⚠️ the order of the first two steps is the security-relevant part, and it is exactly the
#   step a copy-paste drops. `mktemp` is already 0600 on gnu coreutils, so a write-then-chmod
#   ordering LOOKS identical on this machine and is not — the mode is a property of the
#   template on some platforms and of the umask on others. to hoist the sequence here makes
#   the ordering one decision rather than one-per-site, so a third write site cannot get a
#   quieter version of it.
# .note = the caller owns the message. this leaf returns 1 in silence, because its two callers
#   say very different things about the same failure (one aborts a swap, the other warns and
#   carries on) and a message from here would either duplicate or contradict them.
_brains_auth_write_secret() {
  local path="$1" payload="$2" tmp
  tmp="$(mktemp "${path}.new.XXXXXX")" || return 1
  # ⚠️ every explicit failure path below already removes the temp, but a SIGNAL takes none of
  #   them. a ctrl-c or a reaped parent between the write and the rename leaves a live oauth
  #   token in a `.new.XXXXXX` file beside the real one — durable, and invisible: no recovery
  #   path looks for that name, so the strand guard that watches `.bak` never sees it, and a
  #   temp sweeper may later hand it to whoever walks the directory.
  #   `_brains_auth_set`'s authdir learned this exact lesson (INT alone was widened to
  #   TERM/HUP/RETURN after a review); this leaf is the one every credential write funnels
  #   through, so it is the last place that should have been left without the same cover.
  #
  # ⚠️ two details of this trap are load-bearing, and both were learned the hard way here:
  #   1. the path is baked in NOW (double quotes), not read at fire time. a `local` is torn
  #      down before a RETURN trap runs, so a `$tmp` left to expand later hits `set -u` and
  #      dies with "unbound variable" — inside a signal handler, which is the worst place to
  #      discover it.
  #   2. there is no RETURN arm. a RETURN trap set here OUTLIVES this function and fires on
  #      unrelated returns elsewhere in the file. so the signal arms cover the kill window,
  #      the explicit `rm -f`s below cover the error paths, and the trap is cleared on every
  #      way out so it can never follow us up the stack.
  trap "rm -f '$tmp'" INT TERM HUP
  chmod 600 "$tmp"                  || { trap - INT TERM HUP; rm -f "$tmp"; return 1; }
  printf '%s\n' "$payload" > "$tmp" || { trap - INT TERM HUP; rm -f "$tmp"; return 1; }
  mv -f "$tmp" "$path"              || { trap - INT TERM HUP; rm -f "$tmp"; return 1; }
  trap - INT TERM HUP
  return 0
}

# .what = write one subscription's oauth pair into the live claude credentials, atomically
#   ($1=reach, $2=access token, $3=refresh token, $4=seconds until the access token expires,
#    $5=space-delimited scopes, $6=subscription kind)
# .why  = the swap must be all-or-none: a half-written credentials file logs you out of every
#   account at once. we build the whole json first, write it beside the target, then rename
#   (an atomic op within one filesystem), so claude only ever observes the old file or the
#   complete new one — never a torn middle.
_brains_auth_install_creds() {
  local reach="$1" access="$2" refresh="$3" ttl_s="$4" scopes="$5" kind="$6"
  local base payload now_s brc

  # start from the extant file so any key claude keeps beside .claudeAiOauth survives the swap.
  # ⚠️ absent and corrupt both fall back to an empty object, and that is deliberate — a torn
  #   file must not brick a swap, and the `.bak` cut below preserves the original either way.
  #   but only ONE of the two is harmless: an absent file has no keys to lose, while a corrupt
  #   one may hold keys claude needs that this mints away. so the fallback is the same and the
  #   REPORT is not (`rule.forbid.failhide`).
  base="$(_brains_auth_creds_field "$_BRAINS_AUTH_LIVE_CREDS" '.')"
  brc=$?
  (( brc != 0 )) && _brains_auth_say_unparsed "$_BRAINS_AUTH_LIVE_CREDS" \
    "so the new file starts EMPTY — any key claude kept beside .claudeAiOauth is dropped (the prior file survives as ${_BRAINS_AUTH_LIVE_CREDS}.bak)"
  [[ -z "$base" ]] && base='{}'

  now_s="$(date +%s)"
  # ⚠️ .security = the two TOKENS ride the environment, not argv. a `jq --arg a "$access"`
  #   puts the secret in `/proc/<pid>/cmdline`, which is world-readable — any local user can
  #   lift it out of `ps` while jq runs. `/proc/<pid>/environ` is 0400 to the owner alone, and
  #   the assignment is scoped to this one command, so the values leave with it.
  #   the non-secrets ($sc, $kd, $exp) stay on argv where they read clearer.
  payload="$(_BA_ACCESS="$access" _BA_REFRESH="$refresh" jq -c \
      --argjson exp "$(( (now_s + ttl_s) * 1000 ))" \
      --arg sc "$scopes" \
      --arg kd "$kind" \
      '.claudeAiOauth = {
          accessToken: $ENV._BA_ACCESS,
          refreshToken: $ENV._BA_REFRESH,
          expiresAt: $exp,
          scopes: ($sc | if . == "" then ["user:inference","user:profile"] else split(" ") end),
          subscriptionType: $kd
        }' <<< "$base")" || {
    echo "🐢 bummer dude — could not build the new credentials json" >&2
    return 1
  }

  # keep a restore point of the prior file before it is replaced.
  # ⚠️ every failure BELOW this line has a .bak; every failure ABOVE it does not. the caller
  #   must not promise a restore point it cannot see — so it tests for the file rather than
  #   assume this ran (a promise of a safety net that was never created is its own defect).
  # ⚠️ EXISTENCE IS NOT INTEGRITY. the copy's exit status used to be discarded, so a copy that
  #   died partway — a full disk is the plausible one, since a secret write follows immediately
  #   — left a .bak that PASSES `[[ -f ]]`. every downstream rescue promise ("your prior login
  #   is intact, a copy is at .bak") tests only for the file, so a human would have been sent
  #   to restore from a truncated one. that is the same failhide shape
  #   `_brains_auth_creds_field` was split to close: a corrupt read must not answer like a
  #   clean one.
  #   so the copy is verified byte-identical to its source, and a failure REFUSES the install.
  #   refusal is the safe direction: the prior credentials are still in place at this point,
  #   untouched, so the cost is one aborted swap rather than one destroyed login.
  #   (byte-identity rather than a parse check on purpose — it makes no claim about the shape
  #   of the file it is protecting, so it cannot reject a live file this namespace does not
  #   happen to recognize.)
  if [[ -f "$_BRAINS_AUTH_LIVE_CREDS" ]]; then
    cp -p "$_BRAINS_AUTH_LIVE_CREDS" "${_BRAINS_AUTH_LIVE_CREDS}.bak" \
      && cmp -s "$_BRAINS_AUTH_LIVE_CREDS" "${_BRAINS_AUTH_LIVE_CREDS}.bak" || {
      rm -f "${_BRAINS_AUTH_LIVE_CREDS}.bak"
      echo "🐢 bummer dude — could not take a restore point of your current login" >&2
      echo "   the copy to ${_BRAINS_AUTH_LIVE_CREDS}.bak failed or came out short," >&2
      echo "   so the swap was refused rather than overwrite the only copy you have." >&2
      echo "   your current login is untouched. check free disk space, then retry." >&2
      return 1
    }
  fi

  _brains_auth_write_secret "$_BRAINS_AUTH_LIVE_CREDS" "$payload" || {
    echo "🐢 bummer dude — could not write the new credentials into ${_BRAINS_AUTH_LIVE_CREDS}" >&2
    return 1
  }
  return 0
}

# .what = file a just-rotated refresh token back under its own account ($1=reach, $2=token)
# .why  = a mint ROTATES server-side, so the moment it returns, the account's stored copy is
#   dead and the live value exists only in memory. any swap that gives up AFTER the mint but
#   BEFORE the install therefore holds an account's last token in a variable about to go out
#   of scope — to simply `return` there strands it, and only a browser re-auth recovers it
#   (hazard.claude-oauth-refresh-rotation.md).
#
#   ⚠️ this opens no two-holder window, and that is why it is safe to call only on the abort
#   paths: each of them is a path where ~/.claude never received a copy. do NOT reach for it
#   after a successful install — there the file IS the holder, and a keyrack write would put
#   the same token in two places, which is the state the whole ordering exists to forbid.
# .note = extracted because there are two such paths (a refused compare-and-swap, and a failed
#   install) and they must recover identically. two hand-written copies of one recovery is how
#   the second one silently loses a step — the same drift `_brains_auth_reach_from_flag` and
#   the shared skill bootstrap were extracted to stop.
_brains_auth_refile_rotated() {
  local reach="$1" newref="$2"
  if [[ -n "$newref" ]] && _brains_auth_set_token "$reach" "$newref" 2>/dev/null; then
    echo "   ${reach}'s rotated token was filed back to the keyrack — it is not stranded" >&2
    return 0
  fi
  echo "🐢 bummer dude — ${reach}'s token rotated but could NOT be filed back" >&2
  echo "   its stored copy is dead, so re-auth it: brains.auth.set" >&2
  return 1
}

# .what = point claude's own profile block at the account behind the live token ($1=ua)
# .why  = ~/.claude.json holds the profile, .credentials.json holds the tokens. a swap that
#   writes only the tokens leaves the profile naming the PRIOR account — claude would show the
#   wrong email until it next refreshes, and our own expired-token fallback would read a lie.
#   so we re-ask the api who the new token belongs to and write that through, which keeps the
#   fallback identity read honest for as long as the live access token is expired.
# .note = every failure branch below is LOUD and returns 1. it used to `return 0` silently on
#   all five, which made the one state this function exists to prevent — ~/.claude.json naming
#   the PRIOR account — undiagnosable: the swap reported success while claude showed the wrong
#   email, and our own expired-token fallback then read that stale name as truth. a failure here
#   does not undo the swap (the tokens are already correct), so the caller warns and carries on;
#   what it must never do is stay quiet (rule.forbid.failhide).
_brains_auth_sync_profile() {
  local ua="$1" who wrc uuid email base merged
  who="$(_brains_auth_whoami "$ua")"
  wrc=$?
  uuid="$(_brains_auth_uuid_of_who "$who")"
  email="$(_brains_auth_email_of_who "$who")"
  (( wrc != 0 )) || [[ -z "$uuid" ]] && {
    echo "🐢 heads up — could not read who the new token belongs to, so ${_BRAINS_AUTH_LIVE_PROFILE} still names the prior account" >&2
    return 1
  }

  base="$(jq -c '.' < "$_BRAINS_AUTH_LIVE_PROFILE" 2>/dev/null)"
  [[ -z "$base" ]] && {
    echo "🐢 heads up — could not read ${_BRAINS_AUTH_LIVE_PROFILE}, so its profile still names the prior account" >&2
    return 1
  }
  merged="$(jq -c --arg u "$uuid" --arg e "$email" \
    '.oauthAccount = ((.oauthAccount // {}) + {accountUuid:$u, emailAddress:$e})' \
    <<< "$base" 2>/dev/null)" || {
    echo "🐢 heads up — could not merge the new account into ${_BRAINS_AUTH_LIVE_PROFILE}" >&2
    return 1
  }
  _brains_auth_write_secret "$_BRAINS_AUTH_LIVE_PROFILE" "$merged" || {
    echo "🐢 heads up — could not write ${_BRAINS_AUTH_LIVE_PROFILE}; it still names the prior account" >&2
    return 1
  }
  return 0
}

# ══ §9. command: brains.auth.use — swap the live login ═══════════════════════
# .what = hot-swap the global claude login to a stored subscription; the command a human runs
# .why  = the subscriptions already live in the keyrack for budget reads, so the same
#   credentials can drive the cli itself — swap accounts without a browser round-trip.
#   the swap is an INSTALL-then-park pair, in that order, and the order is load-bearing.
#   a refresh token is single-use with server-side rotation, so it may have exactly ONE
#   holder at every instant. park first and the same token sits in ~/.claude AND the keyrack
#   between the two steps — the two-holder state hazard.claude-oauth-one-holder-per-token.md
#   exists to forbid, and it persists indefinitely if the install then fails.
#   ⚠️ do NOT "fix" this into park-then-install. the full argument lives on
#   `_brains_auth_park_file`; this note exists because the header here once claimed the
#   opposite ordering, which is a maintenance trap on the riskiest command in the file.
_brains_auth_use() {
  local reach='' ua token krc active arc parked=''
  local mint access newref ttl scopes kind
  _brains_auth_unlock_reset   # the memo lives for exactly one command — see the leaf's .why

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --reach|--sub)
        reach="$(_brains_auth_reach_from_flag "$@")" || return 2
        shift 2 ;;
      -h|--help)
        echo "🐢 brains.auth.use — point the global claude cli at a stored subscription"
        echo ""
        echo "  usage: brains.auth.use [--reach <email>]"
        echo ""
        echo "    --reach <email>  the account to sign in as"
        echo "                     alias: --sub (the old name, superseded)"
        echo "    (no args)        show which account is signed in now"
        echo ""
        echo "  example: brains.auth.use --reach casey@ahction.com"
        echo ""
        echo "  whichever account you are on now is detected and stowed automatically —"
        echo "  even one you signed into by hand — so you can swap back with no browser."
        echo "  open claude sessions keep the OLD token in memory — restart them after."
        echo ""
        echo "  exit codes with --reach (a SWAP), for a caller that reads only \$?:"
        echo "    0  the swap landed, cleanly"
        echo "    1  it broke on our side — OR the swap landed but claude's own profile"
        echo "       view is stale (the tree says which; your credentials are intact)"
        echo "    2  it needs you — a dead token, a bad flag, or an identity we could not"
        echo "       verify (a swap is refused rather than risk the live account's token)"
        echo ""
        echo "  exit codes with no args (a READ) — these differ, and a non-zero here"
        echo "  means the ANSWER is doubtful, never that a credential moved:"
        echo "    0  the answer is trustworthy — a verified name, or a confirmed"
        echo "       absence of any login"
        echo "    1  a login is present but could not be named — a FAILED read, kept"
        echo "       apart from 'no login' on purpose"
        echo "    2  a name was found but not verified — do not act on it unchecked."
        echo "       an idle terminal whose access token has expired reads this way,"
        echo "       so treat it as 'renew, then re-ask', not as an error"
        return 0 ;;
      *) _brains_auth_say_unknown_arg "$1"; return $? ;;
    esac
  done

  ua="$(_brains_auth_ua)"
  # ask who is live RIGHT NOW rather than trust any record of our own — you may have run
  # `claude /login` since the last swap, and this is the read that notices.
  # arc separates "no one is signed in" (0) from "a login exists but is unnamed" (1).
  active="$(_brains_auth_active_reach "$ua")"
  arc=$?

  # no account asked for = report the current holder (a read, never a swap). a read MAY show
  # an unverified name, so long as it says so — the caller can then judge it themselves.
  #
  # the exit codes keep the three outcomes apart for a caller who reads only `$?`:
  #   0 = the answer is trustworthy (a verified name, or a confirmed absence of any login)
  #   1 = a login is present but we could not name it — a FAILED read, not an empty one.
  #       to return 0 here would make "unknown" indistinguishable from "no login", which is
  #       the one confusion this command exists to prevent.
  #   2 = a name was found but not verified — the caller must not act on it unchecked.
  if [[ -z "$reach" ]]; then
    case "$(_brains_auth_active_verdict "$active" "$arc")" in
      unknown)
        echo "🐢 a login is present, but could not tell which account it is" >&2
        echo "   run any claude command to renew its session, then retry" >&2
        return 1 ;;
      absent)
        echo "🐢 no account is signed in"
        return 0 ;;
      unverified)
        echo "🐢 the global claude appears to be signed in as: ${active}"
        echo "   (unverified — $(_brains_auth_say_unverified_because))"
        return 2 ;;
      *)
        echo "🐢 the global claude is signed in as: ${active}"
        return 0 ;;
    esac
  fi

  # an account is named by its email — the same reach its key is cut at. reject a bad shape
  # here rather than let it become a keyrack miss that reads as "never stored".
  _brains_auth_is_reach "$reach" || {
    echo "🐢 bummer dude — '${reach}' is not an email address" >&2
    echo "   accounts are named by their email: brains.auth.use --reach you@example.com" >&2
    return 2
  }

  # a swap is a MUTATION, so it needs a VERIFIED identity — an unverified name (arc=2) is
  # refused just as hard as an unknown one (arc=1). the reason they are equally unsafe:
  # to park under a stale name files the live token under the WRONG account and leaves the
  # right one with no copy at all — two accounts corrupted by one wrong answer, and the
  # wrong answer arrives with no signal that it is wrong.
  # this sits BEFORE the keyrack read so the refusal is the first thing a human sees.
  # the verdict is computed by a pure leaf, so the whole authorization matrix is snapshot-
  # testable with no network; what remains here is only how each verdict is SAID.
  case "$(_brains_auth_use_decide "$reach" "$active" "$arc")" in
    refuse_unknown)
      echo "🐢 hold up — could not tell which account is signed in, so it cannot be stowed" >&2
      echo "   a swap would overwrite its only token with no way back." >&2
      echo "   run any claude command to refresh its session, then retry." >&2
      return 2 ;;
    refuse_unverified)
      echo "🐢 hold up — the signed-in account could not be verified against the live token" >&2
      echo "   its name was $(_brains_auth_say_unverified_because)." >&2
      echo "   to stow it under a stale name would misfile it AND orphan the real one." >&2
      echo "   run any claude command to renew the session, then retry." >&2
      return 2 ;;
    # already there = a clean no-op, so a repeat call is safe (idempotent)
    noop)
      echo "🐢 turtally — already signed in as ${reach}"
      return 0 ;;
    # `proceed` is the fourth verb, the one that authorizes the swap — it falls through by design
    proceed) : ;;
    # ⚠️ and everything else must REFUSE. this arm was absent, and its absence was the single
    #   most dangerous line in the namespace: a bash case with no default does not fail — it
    #   does no work and falls through, so an unrecognized verdict carried straight on into
    #   the keyrack read, the mint, and `_brains_auth_install_creds` — a live-credential
    #   overwrite performed with NO authorization, on the one command whose whole job is to
    #   decide whether an overwrite is safe. that is not a theory: with this arm removed,
    #   `swap.unknown-verdict-refuses` reports "FELL THROUGH to the overwrite".
    #   the decider emits only four verbs today, so the gap is latent; but the rest of this
    #   file already defaults unanticipated codes to malfunction rather than to silence.
    *)
      echo "💥 the swap decider returned a verdict this command does not know" >&2
      echo "   refused, rather than proceed into an unauthorized credential overwrite" >&2
      echo "   fix: this is our defect — report it; your credentials were NOT touched" >&2
      return 1 ;;
  esac

  # ⚠️ refuse at once if a prior swap left an account stranded in the `.bak`. the install below
  #   cuts a fresh `.bak` with a plain `cp`, so a swap run now would destroy that account's last
  #   token — silently, and while it printed a success tree.
  #
  #   this guard sits BEFORE the keyrack read and the mint on purpose. every path further down
  #   rotates ${reach}'s token server-side, so a refusal after that point owes a write-back and
  #   leaves the account one failed write from stranded itself. refused here, no token moves.
  if _brains_auth_bak_strands; then
    echo "🐢 hold up — a prior swap left an account's only token in a leftover file" >&2
    echo "   ${_BRAINS_AUTH_LIVE_CREDS}.bak holds a refresh token that reached no keyrack," >&2
    echo "   and this swap would overwrite it. rescue it first:" >&2
    _brains_auth_say_bak_rescue "enrolls whoever that file signs you in as"
    echo "   then rerun this swap." >&2
    return 2
  fi

  # read the next subscription's token BEFORE we disturb the prior one, so an account that was
  # never stored fails while the current login is still fully intact
  token="$(_brains_auth_get_token "$reach")"
  krc=$?
  # ⚠️ BOTH pre-flight verdicts — the keyrack rc and the token shape — come from shared leaves,
  #   and both render through the shared hint + exit-code tables. so a swap can never be less
  #   precise about a stored key than a read is about the same one. each was hand-rolled here
  #   once, and each was wrong in the same direction: the shape check said "your token is
  #   stale" for an api key (which loops the human back through the same message), and the
  #   keyrack check said "could not read" for a key that was simply never stored (which offers
  #   a retry against a state only `brains.auth.set` can clear) and exited 1 for a constraint.
  local terr
  terr="$(_brains_auth_token_err "$krc" "$token")"
  [[ -n "$terr" ]] && {
    echo "🐢 bummer dude — cannot swap to ${reach}" >&2
    echo "   $(_brains_auth_fix_for_error "$terr")" >&2
    return "$(_brains_auth_code_for_error "$terr")"
  }

  echo "🐢 paddle out — swap to ${reach}"

  # READ whoever is live, with no write yet. the keyrack stays untouched until the new
  # credentials are installed, so the old token has exactly one holder the whole way
  # through (see _brains_auth_park_file for why the order is load-bearing).
  if [[ -n "$active" ]]; then
    parked="$(_brains_auth_park_read)" || {
      echo "🐢 bummer dude — no refresh token in ${_BRAINS_AUTH_LIVE_CREDS} to stow for ${active}" >&2
      echo "   the swap is halted so ${active} is not orphaned" >&2
      return 1
    }
  fi

  # mint the next access token from the stored refresh token (this rotates it, which is
  # fine: the rotated pair is what we hand to claude, and claude becomes its sole holder)
  mint="$(_brains_auth_mint_access "$ua" "$token")"
  if [[ "$(_brains_auth_mint_field "$mint" ok)" != true ]]; then
    local mint_code mint_err
    mint_code="$(_brains_auth_mint_field "$mint" code)"
    mint_err="$(_brains_auth_mint_field "$mint" error)"
    # the LEAD line is account-named on purpose — a swap failed on ONE account and can say so,
    # while the shared table stays account-agnostic because a sweep renders many rows at once.
    # that is the only part this branch is entitled to author.
    echo "🐢 bummer dude — could not swap to ${reach} (http ${mint_code:-?})" >&2
    # ⚠️ the REMEDIATION comes from the shared table, never a second hand-rolled case. this
    #   branch used to carry its own `case` over the same error codes, and two copies of one
    #   mapping drift the moment a code is added: the sweep would render the precise hint while
    #   the swap fell through to a generic "rejected", for the identical failure. proven — with
    #   the copy restored, a `no_access_token` reads as "refresh was rejected (http 200)", which
    #   sends the human to re-auth a token that was never the problem.
    echo "   $(_brains_auth_fix_for_error "$mint_err")" >&2
    # ⚠️ the CODE is not account-named, so it comes from the shared severity table — a flat
    #   `return 1` here would call a dead token a malfunction, and a caller that branches on
    #   `$?` to choose "auto-retry" over "tell the human to re-auth" would retry forever
    #   against a token that will never mint again.
    [[ "$(_brains_auth_severity_for_error "$mint_err")" == constraint ]] && return 2
    return 1
  fi
  access="$(_brains_auth_mint_field "$mint" access)"
  newref="$(_brains_auth_mint_field "$mint" refresh)"
  ttl="$(_brains_auth_mint_field    "$mint" ttl)"
  scopes="$(_brains_auth_mint_field "$mint" scopes)"
  kind="$(_brains_auth_kind_for_mint "$mint")"

  # install FIRST. a failure here has written no keyrack entry, so the prior login is simply
  # left intact — and the restore-point claim is made only if the file is actually there.
  #
  # ⚠️ from the mint above until this install lands, the rotated token for ${reach} exists
  #   ONLY in $newref, in memory. the server rotated it, so the copy still in the keyrack is
  #   already dead. to `return 1` here without a write-back would drop the only live value
  #   and strand ${reach} — a dropped rotation is how an account loses its last live token
  #   (hazard.claude-oauth-refresh-rotation.md). so the failure path files it before it exits.
  # ⚠️ the compare-and-swap. everything above decided WHAT to do from a picture of ~/.claude
  #   taken before a network mint that costs seconds — and that file is writable by anyone
  #   else meanwhile. so the picture is checked against reality one last time, here, in the
  #   instant before it is overwritten.
  #
  #   what a mismatch means: some other writer — a second `brains.auth.use`, or a plain
  #   `claude /login` — put a DIFFERENT account in that file while we were at the mint. its
  #   token is that account's only live copy (the keyrack copy it rotated past is dead, and
  #   the `.bak` we are about to cut covers the account we swapped OFF of, never the one
  #   already there). to install over it destroys it with no error and no recovery.
  #
  #   the answer is to ABORT, not to re-park the newcomer and carry on. the whole
  #   authorization above — the refuse_unknown / refuse_unverified matrix — was decided
  #   against `$active`, and a file that changed mid-flight has just proven that verdict void.
  #   to proceed on a re-read would be to re-authorize a credential mutation from facts that
  #   demonstrated their own instability. a retry re-derives the identity honestly.
  local live_now live_rc
  live_now="$(_brains_auth_live_ref)"; live_rc=$?
  # ⚠️ an UNREADABLE live file is its own verdict, and it used to borrow the one below. a
  #   corrupt read returned empty, which compares unequal, so the swap aborted while it told
  #   the human "the signed-in account changed mid-flight" — it named a concurrent writer for a
  #   torn file, and sent them to look for a second terminal that was never there. the abort is
  #   still right (we cannot prove what that file holds, so we must not overwrite it); only the
  #   cause was wrong. the rotation recovery is owed either way.
  if (( live_rc != 0 )); then
    echo "🐢 hold up — ${_BRAINS_AUTH_LIVE_CREDS} is there but could not be parsed" >&2
    echo "   the install was stopped: we cannot tell whose token that file holds, so an" >&2
    echo "   overwrite might destroy an account's only live copy." >&2
    echo "   inspect it (jq . ${_BRAINS_AUTH_LIVE_CREDS}), or re-auth with: brains.auth.set" >&2
    _brains_auth_refile_rotated "$reach" "$newref"
    return 1
  fi
  if [[ "$live_now" != "$parked" ]]; then
    echo "🐢 hold up — the signed-in account changed while this swap was mid-flight" >&2
    echo "   ~/.claude no longer holds what it held when this started, so the install was" >&2
    echo "   stopped: it would have overwritten another account's only live token." >&2
    echo "   likely another 'brains.auth.use', or a 'claude /login' in another terminal." >&2
    echo "   rerun when the other swap has settled." >&2
    # ⚠️ the rotation status is said LAST on purpose. when the write-back fails it ends with
    #   "re-auth it", and that is the more urgent of the two actions — a stranded account is
    #   fixed by a browser sign-in, never by the rerun advised above. to print it above the
    #   rerun line would leave "rerun" as the closing word for a case a rerun cannot fix.
    _brains_auth_refile_rotated "$reach" "$newref"
    return 1
  fi

  _brains_auth_install_creds "$reach" "$access" "$newref" "$ttl" "$scopes" "$kind" || {
    # put the rotated token back where a parked account's token belongs. this opens no
    # two-holder window: the install FAILED, so ~/.claude never received a copy.
    _brains_auth_refile_rotated "$reach" "$newref"
    [[ -f "${_BRAINS_AUTH_LIVE_CREDS}.bak" ]] \
      && echo "   your prior login is intact, and a copy is at ${_BRAINS_AUTH_LIVE_CREDS}.bak" >&2 \
      || echo "   your prior login is untouched — the swap stopped before it was replaced" >&2
    return 1
  }

  # NOW file the old account, once ~/.claude no longer holds it. a failure here is loud but
  # does not undo the swap: the new login is already live, and the old token is recoverable
  # from the .bak beside it, so the fix is a retry rather than a rollback.
  _brains_auth_park_or_strand "$active" "$parked" "$reach"

  # point claude's profile block at the new account too, so its own view agrees with ours.
  # ⚠️ this used to end in `|| true`, which threw the rc away and let the command close with a
  #   clean tree and exit 0 while `~/.claude.json` still named the PRIOR account. that is not a
  #   cosmetic lag: `_brains_auth_whoami` falls back to this very profile whenever the live
  #   access token has expired, and that identity is what gates every later read. so a stale
  #   profile makes a later `brains.auth.usage` name the wrong account as signed-in — and the
  #   one signal that would have warned a caller was the code we discarded.
  #   the swap ITSELF stands (the credentials are installed and live), so this is a degraded
  #   success, not a failure — the tree says exactly that, and the rc stops being a lie.
  local src_rc=0
  _brains_auth_sync_profile "$ua" || src_rc=$?

  (( src_rc != 0 )) && {
    echo "   └─ signed in as ${reach} 🧠 — but claude's own profile view is STALE"
    echo ""
    echo "🐢 heads up — the swap landed; ${_BRAINS_AUTH_LIVE_PROFILE} still names the prior account"
    echo "   fix: re-run brains.auth.use --reach ${reach} once the file is writable"
    echo "🐢 heads up — claude sessions already open still hold the old token; restart them"
    return 1
  }

  echo "   └─ signed in as ${reach} 🧠"
  echo ""
  echo "🐢 heads up — claude sessions already open still hold the old token; restart them"
}
alias brains.auth.use='_brains_auth_use'

# ══ §10. usage fetch + sweep — one node per account, folded ══════════════════
# .what = one usage node for the account claude is signed in as RIGHT NOW ($1=ua, $2=reach)
# .why  = the ACTIVE account is read from ~/.claude, never from the keyrack — the one-holder
#   rule. the global claude cli rotates its own refresh token as you use it, so the keyrack
#   copy of the active account is stale by design. worse, a refresh here would rotate the token
#   server-side and log your open claude session out mid-flight. so we take the access token
#   claude already holds and issue ZERO refreshes for the active account.
# .note = this path issues NO mint, keeps NO retry, and performs NO write-back. that is the
#   whole reason it is its own leaf: it shares only a tail call with its parked peer, while its
#   risk profile is the opposite one. fused, a reader had to hold both to reason about either,
#   and a change meant for the parked path could reach the live credentials by accident.
_brains_auth_node_for_active() {
  local ua="$1" reach="$2" live_access live_rc
  # every reader of the live credentials tells "absent" from "unparseable" the same way, and
  # the freshness test is shared with `_brains_auth_whoami` — one rule, one place.
  live_access="$(_brains_auth_access_for_live)"
  live_rc=$?
  # an expired live token is NOT ours to renew — claude renews it on its own next call.
  # name that as its own fix rather than refresh it and risk the lockout we just avoided.
  # rc 1 (torn) and rc 2 (absent) both mean "no usable token here", and the extant code
  # already collapsed them under one empty read — so the verdict is unchanged, deliberately.
  (( live_rc == 1 || live_rc == 2 )) && { _brains_auth_error_node 'active_creds_unreadable'; return; }
  (( live_rc == 3 )) && { _brains_auth_error_node 'active_token_expired'; return; }
  _brains_auth_node_via_access "$ua" "$reach" "$live_access"
}

# .what = one usage node for an account PARKED in the keyrack ($1=ua, $2=reach)
# .why  = the peer of `_brains_auth_node_for_active`, and everything the active path refuses to
#   do: read the keyrack, mint from the durable token, retry a rejection that a concurrent
#   sweep may have caused, and write the rotated token back. four steps that each mutate or
#   depend on server-side state, none of which the active path may ever take.
# ⚠️ every path below here rotates ${reach}'s refresh token server-side. that is safe ONLY
#   because the dispatcher proved this reach is not the live account first.
_brains_auth_node_for_parked() {
  local ua="$1" reach="$2" token krc mint access newref

  # read the token from the global keyrack (the fetch leaf carries the unlock); let its error
  # surface, and check the exit code so a real keyrack failure is not masked as "no token"
  token="$(_brains_auth_get_token "$reach")"
  krc=$?

  # early-return each pre-request failure as its own error node (no else-branches)
  # ⚠️ the two keyrack failures are NOT one. rc 2 says the key was never stored (a sign-in
  #   fixes it); rc 1 says the keyrack itself could not be read (a sign-in cannot). they used
  #   to share one node, so a locked keyrack sent the human to a browser flow that was
  #   powerless against it — and, since the shared node is a `constraint`, an automated
  #   consumer treated a transient fault as permanent and never retried.
  # the whole pre-flight verdict comes from the shared classifier, which the SWAP path reads
  # too — so both commands name the same fault the same way, in the same order, for the same
  # stored value. a non-refresh token is stale data from the pre-refresh design (a setup or
  # access token the usage endpoint now rejects); an sk-ant-api… key is a different fault with
  # a different fix; a keyrack miss is a third. this leaf decides which; we only render it.
  local terr
  terr="$(_brains_auth_token_err "$krc" "$token")"
  [[ -n "$terr" ]] && { _brains_auth_error_node "$terr"; return; }

  # mint a short-lived access token from the stored refresh token — the usage endpoint
  # rejects the durable token, so we refresh at read time. the refresh ROTATES the refresh
  # token server-side, so we write the new one back below or the next read fails (see
  # hazard.claude-oauth-refresh-rotation.md).
  # the mint leaf owns the wire decode AND the failure classification (a 429 is transient,
  # a 4xx means the stored token is genuinely dead) — we read named fields only
  mint="$(_brains_auth_mint_access "$ua" "$token")"
  if [[ "$(_brains_auth_mint_field "$mint" ok)" != true ]]; then
    local merr token2
    merr="$(_brains_auth_mint_field "$mint" error)"

    # ⚠️ ONE retry, and only for a rejection, because a rejection has TWO causes that look
    #   identical on the wire and need opposite answers from the human:
    #     a) the stored token is genuinely dead         -> re-auth in a browser
    #     b) a CONCURRENT sweep rotated it a moment ago -> just read again; no human act
    #   (b) is real: a refresh rotates server-side, so an overlapped cron tick and manual
    #   check both mint from one stored value and the loser's token is already spent. with no
    #   retry, a perfectly healthy account renders "refresh token dead (run: brains.auth.set)"
    #   and sends the human through a full browser re-auth to repair a race.
    #
    #   the two are told apart with NO lock and NO guesswork: re-read the keyrack. if the
    #   stored value CHANGED since we read it, another holder rotated it — that is (b), by
    #   evidence rather than by timing. if it is byte-identical, no one raced us and the
    #   token really is dead — that is (a), and it falls through to the same node as before.
    #   a lock was rejected as its own failure domain (a stale lockfile wedges every later
    #   read); this costs one keyrack read on a path that was about to fail anyway.
    #
    # ⚠️ the re-read is POLLED, not taken once, and that is the half that closes the race. the
    #   winner writes its rotated value back only AFTER its own mint returns, so a single
    #   re-read taken the instant our mint fails can land in the gap and still see the OLD
    #   value — which reads as "no one raced me" and condemns a healthy account.
    #   `_await_rotation` waits that evidence out, bounded.
    if [[ "$merr" == refresh_rejected ]]; then
      token2="$(_brains_auth_await_rotation "$reach" "$token")" && {
        _brains_auth_debug "reach=${reach} token rotated under us — one retry"
        token="$token2"
        mint="$(_brains_auth_mint_access "$ua" "$token")"
        merr="$(_brains_auth_mint_field "$mint" error)"
      }
    fi

    if [[ "$(_brains_auth_mint_field "$mint" ok)" != true ]]; then
      _brains_auth_error_node "${merr:-refresh_unreadable}"
      return
    fi
  fi
  access="$(_brains_auth_mint_field "$mint" access)"
  newref="$(_brains_auth_mint_field "$mint" refresh)"

  # write the rotated refresh token back so the next read holds a live token. best-effort:
  # a write-back failure is loud on stderr but does not fail THIS read (we already hold a
  # valid access token); stdout stays clean json.
  if [[ -n "$newref" && "$newref" != "$token" ]]; then
    _brains_auth_set_token "$reach" "$newref" 2>/dev/null \
      || echo "🐢 heads up — could not store the rotated token for ${reach}; the next read may need brains.auth.set" >&2
  fi

  _brains_auth_node_via_access "$ua" "$reach" "$access"
}

# .what = one account's usage node; pick the path its account is on
#   ($1=ua, $2=reach, $3=the reach signed in right now, $4=how well $3 is known: 0|1|2)
# .why  = the one decision that must happen before either leaf runs, kept as its own thin
#   grain. this used to be one function that fused the decision with BOTH paths — a shape three
#   review rounds flagged and three deferred on the ground that credential fixes were landing
#   on it. those fixes are in, so the reason has expired; to defer a fourth time would be
#   avoidance, not order-of-work.
# .note = the split is not cosmetic. the two paths share only their tail call and have opposite
#   risk profiles: `for_active` issues no mint and touches no stored state, while `for_parked`
#   rotates a server-side token on every call. one name over both meant the reader carried the
#   riskier path's rules while reading the safer one.
_brains_auth_node_for_reach() {
  local ua="$1" reach="$2" active="${3:-}" active_rc="${4:-0}"

  # ⚠️ an active identity that is not VERIFIED + a live login present = we refuse to touch
  #   this account at all. the parked leaf MINTS from the keyrack copy, which rotates the
  #   token server-side. if this reach happens to BE the live account, that rotation logs an
  #   open claude session out mid-flight — the exact lockout that
  #   hazard.claude-oauth-one-holder-per-token.md forbids.
  #
  #   both non-verified outcomes are refused, and for the SAME reason — neither can rule that
  #   out. unverified is not the safer half of the pair: a stale name is worse than no name,
  #   because it fails in two directions at once. we would skip the reach it names (and render
  #   the LIVE account's numbers under that wrong label), while the account that is truly
  #   signed in falls through to the parked leaf and gets its live token rotated out from
  #   under the session. so the safe read is no read — for 1 AND for 2.
  #
  #   they part only in the FIX, which is why the code is carried here rather than flattened
  #   to a boolean: an unknown identity needs the session refreshed; an unverified one needs
  #   the live token renewed so the api can answer for it.
  #   (`brains.auth.use` refuses on both codes too; this is the read path matched to it.)
  #   the 2-vs-else split itself is NOT re-derived here — `_brains_auth_ident_err_for_arc`
  #   owns that map, and this branch reads through it. an inline copy of the same two literals
  #   would drift the moment a code is added to the ladder, and the sibling that already read
  #   through the leaf (`_brains_auth_usage`) would then disagree with this one about what an
  #   unverified identity is called.
  if ! _brains_auth_identity_is_actionable "$active_rc" && [[ -f "$_BRAINS_AUTH_LIVE_CREDS" ]]; then
    _brains_auth_error_node "$(_brains_auth_ident_err_for_arc "$active_rc")"
    return
  fi

  # (`active` arrives as an argument, detected ONCE by the caller — detection costs an api
  # call, so a per-account re-detect would multiply it by the number of subscriptions.)
  if [[ -n "$active" && "$reach" == "$active" && -f "$_BRAINS_AUTH_LIVE_CREDS" ]]; then
    _brains_auth_node_for_active "$ua" "$reach"
    return
  fi

  _brains_auth_node_for_parked "$ua" "$reach"
}

# .what = ask the usage endpoint; emit `<body>\n<http code>` ($1=ua, $2=access token)
# .why  = the twin of `_brains_auth_refresh_reply`, and split for the same reason. both are
#   "call an oauth endpoint, then classify the reply", and the mint pair had already been split
#   while this one stayed fused — so the file carried two depths for one shape, and a reader who
#   learned the pattern at the mint had to re-derive it here. the peers now match: a pure call
#   leaf that owns HOW the endpoint is asked, and a classifier above it that owns what the
#   answer means.
# ⚠️ .security = the bearer rides curl's stdin config (`-K -`), never argv, so the access token
#   stays out of `/proc/<pid>/cmdline` where any local user could read it from `ps`. that is the
#   same discipline the refresh leaf uses, and one home for it keeps the two in step.
# .note = the UA header is load-bearing — without a real claude-code UA the endpoint drops the
#   request into an aggressively rate-limited bucket and answers 429.
# .note = `-sS` lets curl's own error reach stderr, and curl is the last command, so this
#   function's exit code IS curl's — a network failure is still catchable by the caller.
_brains_auth_usage_reply() {
  local ua="$1" access="$2"
  printf 'header = "Authorization: Bearer %s"\n' "$access" \
    | curl -sS -m "$_BRAINS_AUTH_HTTP_TIMEOUT" -w $'\n%{http_code}' "$_BRAINS_AUTH_USAGE_URL" \
      -H "anthropic-beta: ${_BRAINS_AUTH_ANTHROPIC_BETA}" \
      -H "User-Agent: ${ua}" \
      -H "Content-Type: application/json" \
      -K -
}

# .what = classify a usage reply into one usage node ($1=ua, $2=reach, $3=access token)
# .why  = both token sources converge here — a PARKED account mints its access token from the
#   keyrack, the ACTIVE one reads a token straight out of ~/.claude — but the query + the error
#   classification are identical either way. one leaf, so a fix to the shape-check or the
#   error map cannot land on only one of the two paths.
_brains_auth_node_via_access() {
  local ua="$1" reach="$2" access="$3" resp ccode code body

  resp="$(_brains_auth_usage_reply "$ua" "$access")"
  ccode=$?
  code="${resp##*$'\n'}"
  body="${resp%$'\n'*}"

  (( ccode != 0 )) && { _brains_auth_error_node 'curl_failed'; return; }

  # under the debug flag, surface the raw non-200 body to stderr — the endpoint often
  # explains a 401/403 (e.g. "token expired", "oauth token required") in the body,
  # which the classified error node below deliberately hides from the rendered tree
  [[ "$code" != 200 && -n "${BRAINS_AUTH_DEBUG:-}" ]] \
    && printf '🔎 %s http_%s: %s\n' "$reach" "$code" "$body" >&2

  # pull the endpoint's own explanation out of the body so each error node carries it —
  # the body is not the secret (it is the api's error message), and a bare code hides the
  # cause. anthropic errors nest as {"error":{"message":"..."}}; fall back to the raw body.
  local detail
  detail="$(jq -r '(.error.message // .error // .) | if type=="string" then . else tojson end' <<< "$body" 2>/dev/null)"
  [[ -z "$detail" || "$detail" == null ]] && detail="$body"

  # a non-200 maps to its own error node (with the endpoint's detail); 200 falls through
  #
  # ⚠️ the 5xx / other-4xx split below is NOT cosmetic, and this leaf is the second place it
  #   had to be learned. its twin `_brains_auth_mint_access` once collapsed every non-401 into
  #   one code, so a 503 from anthropic rendered "refresh token dead (run: brains.auth.set)" —
  #   a browser re-auth prescribed to a human to repair someone else's outage. that was fixed
  #   there and NOT here, so this leaf still folded every other 4xx into a generic `http_<n>`
  #   that the severity table's default calls a `malfunction` — ours to fix, exit 1 — when a
  #   403 (a token without the scope) is squarely the caller's. same defect, opposite
  #   direction: there a server fault read as the human's, here a human fault reads as ours.
  #   a comment two functions up already called these two "twins"; the twin now matches.
  # ⚠️ the whole error map is fenced behind ONE `!= 200` test, and that fence is the part a
  #   refactor breaks. this block used to be a single `case` whose `200)` arm was a no-op that
  #   fell out the bottom into the shape check below. split into stages without a fence, a 200
  #   walks past every arm and lands on the generic node at the end — so the SUCCESS path
  #   renders `💥 http_200`, which is precisely the defect that reached a live run here once.
  #   the fence makes the success path structurally unable to reach an error node.
  if [[ "$code" != 200 ]]; then
    # ⚠️ the 5xx / other-4xx split below is NOT cosmetic, and this leaf is the second place it
    #   had to be learned. its twin `_brains_auth_mint_access` once collapsed every non-401
    #   into one code, so a 503 from anthropic rendered "refresh token dead (run:
    #   brains.auth.set)" — a browser re-auth prescribed to a human to repair someone else's
    #   outage. that was fixed there and NOT here, so this leaf still folded every other 4xx
    #   into a generic `http_<n>` that the severity table's default calls a `malfunction` —
    #   ours to fix, exit 1 — when a 403 (a token without the scope) is squarely the caller's.
    #   same defect, opposite direction: there a server fault read as the human's, here a
    #   human fault reads as ours. a comment two functions up already called these two
    #   "twins"; the twin now matches.
    case "$code" in
      401) jq -nc --arg d "$detail" '{error:"token_expired", detail:$d}';  return ;;
      429) jq -nc --arg d "$detail" '{error:"rate_limited",  detail:$d}';  return ;;
    esac
    # ⚠️ the digit test is a guard, not decoration. under `set -u`, `(( code >= 500 ))` on a
    #   NON-numeric code treats the word as a variable name, finds it unset, and kills the
    #   function outright — so a garbled or absent status line would take down the read with
    #   an "unbound variable" instead of the honest `http_<n>` node this branch owes.
    case "$code" in
      ''|*[!0-9]*) : ;;   # not a plain number — fall through to the generic node below
      *)
        # anthropic broke, not you — retryable, and no re-auth is prescribed
        (( code >= 500 )) && {
          jq -nc --arg d "$detail" '{error:"usage_server_error", detail:$d}'; return
        }
        # any other 4xx is about THIS token or THIS request, so it is the caller's to fix
        (( code >= 400 )) && {
          jq -nc --arg c "$code" --arg d "$detail" '{error:"usage_rejected", code:$c, detail:$d}'; return
        }
        ;;
    esac
    # a non-numeric or otherwise unclassifiable code keeps the generic shape rather than a guess
    jq -nc --arg c "${code:-unknown}" --arg d "$detail" '{error:("http_"+$c), detail:$d}'; return
  fi

  # trust a 200 only if the expected windows are actually present — a drifted endpoint
  # shape must fail loud, never render a confidently-wrong "0% used, all clear" (the
  # worst-direction failure for a budget-warning tool)
  if ! jq -e '(.five_hour|type)=="object" and (.seven_day|type)=="object"' <<< "$body" >/dev/null 2>&1; then
    _brains_auth_error_node 'unexpected_shape'
    return
  fi
  printf '%s' "$body"
}

# .what = merge one account's node into the combined object ($1=combined, $2=reach, $3=node)
# .why  = the fold step, named — so the gather below reads as composition rather than a jq
#   expression a reader must simulate to learn that it keys the node under the reach.
# .note = the guarantee it owns: a bad node NEVER clobbers the accounts already gathered.
#   an unparseable node makes jq exit non-zero with EMPTY stdout, and a straight assign of
#   that empty string would wipe every prior account from the sweep — a silent, total loss
#   rendered as an empty tree. so the merge is captured first, and an empty capture re-folds
#   a `parse_failure` entry into the INTACT prior object instead.
_brains_auth_fold_node() {
  local combined="$1" reach="$2" node="$3" folded
  folded="$(jq --arg s "$reach" --argjson n "$node" '. + {($s): $n}' <<< "$combined" 2>/dev/null)"
  [[ -n "$folded" ]] && { printf '%s' "$folded"; return; }
  jq --arg s "$reach" '. + {($s): {error:"parse_failure"}}' <<< "$combined"
}

# .what = tell a watchful human which account the sweep is on ($1=reach, $2=n, $3=of)
# .why  = the sweep is SEQUENTIAL by design — the accounts share one rate-limited endpoint, and
#   each fetch is a refresh round-trip — so a human with several subscriptions on a slow link
#   waits multiple seconds at a blank cursor. silence there is ambiguous in the worst way: it
#   reads the same as a hang, so the honest response is to kill it and retry, which spends more
#   of the rate limit that made it slow (`rule.require.status-feedback`).
# .note = it writes to stderr and ONLY when stderr is a terminal. that is what keeps it out of
#   `--json` pipelines, out of every snapshot, and out of any log a cron keeps — progress is
#   for a human who watches, never part of the contract. the line is erased as it goes (`\r`
#   plus a clear), so the finished render is not preceded by a wall of dead rows.
_brains_auth_say_progress() {
  [[ -t 2 ]] || return 0
  printf '\r\033[K   ⏳ %s (%s/%s)' "$1" "$2" "$3" >&2
}

# .what = how many accounts a newline-separated reach list holds ($1=reaches)
# .why  = `printf '%s\n' "$x" | grep -c '[^[:space:]]'` is decode-friction: a reader must
#   simulate the grep to learn it counts NON-BLANK lines, and the blank-skip is the whole
#   point — one empty line at the end would otherwise inflate the denominator of the progress
#   line the human watches ("3 of 5" when there are four). the name states the intent; the body
#   keeps the mechanism (`rule.require.named-transformers`).
_brains_auth_count_reaches() {
  printf '%s\n' "$1" | grep -c '[^[:space:]]'
}

# .what = a newline-separated reach list rendered on ONE line, comma-joined ($1=reaches)
# .why  = the debug trace wants the whole list inline; `${x//$'\n'/,}` requires the reader to
#   know `//` substitutes EVERY match (not the first) before the line reads as "the reaches,
#   comma-joined". the same intent, named.
_brains_auth_reaches_oneline() {
  printf '%s' "${1//$'\n'/,}"
}

# .what = fetch usage json per account into one object keyed by reach ($1=ua, $2=reaches)
# .why  = compose the per-account leaf into one combined object (a thin fold, no i/o here)
_brains_auth_gather() {
  local ua="$1" reaches="$2" active="${3:-}" active_rc="${4:-0}" combined='{}'
  local reach node n=0 total
  total="$(_brains_auth_count_reaches "$reaches")"
  while IFS= read -r reach; do
    [[ -z "$reach" ]] && continue
    n=$(( n + 1 ))
    _brains_auth_say_progress "$reach" "$n" "$total"
    node="$(_brains_auth_node_for_reach "$ua" "$reach" "$active" "$active_rc")"
    combined="$(_brains_auth_fold_node "$combined" "$reach" "$node")"
  done <<< "$reaches"
  # erase the progress line so the render opens on a clean row
  [[ -t 2 ]] && printf '\r\033[K' >&2
  printf '%s' "$combined"
}

# ══ §11. error tables — severity, exit code, glyph, hint (one row per code) ══
# .what = who must fix an error code — `constraint` (the caller) or `malfunction` ($1=err)
# .why  = severity and remediation are two questions about one error, and they had been fused
#   into one channel: the exit code was recovered by a prefix-match on the ✋/💥 glyph of the
#   rendered HINT. that made a display string load-bearing for automation — a new case added
#   with the wrong glyph, or a copy-paste that dropped it, would break the exit-code contract
#   with no signal but a snapshot diff a reviewer had to catch by eye.
#   so severity is declared HERE as data. the hint renders its glyph from this answer, and the
#   verdict reads this answer directly, so the two agree by construction rather than by prose.
# .note = the default is `malfunction` on purpose. an error code with no entry is one we did
#   not anticipate, and an unanticipated failure is ours until proven otherwise — to default to
#   `constraint` would hand the human a fix for a fault they cannot fix (rule.forbid.failhide).
_brains_auth_severity_for_error() {
  case "$1" in
    no_token|token_expired|needs_reauth|refresh_rejected|api_key_not_oauth|keyrack_absent \
    |active_token_expired|active_identity_unknown|active_identity_unverified \
    |no_subscriptions|usage_rejected)
      printf 'constraint' ;;
    # ⚠️ `usage_rejected` is a constraint and `usage_server_error` is not, and that pair is the
    #   whole point of the 4xx/5xx split in `_brains_auth_node_via_access`: a 403 is about the
    #   caller's token, a 503 is about anthropic's day. collapse them and one of the two
    #   audiences is sent to repair what they do not own.
    # ⚠️ keyrack_unreadable is deliberately NOT listed above. a locked or absent keyrack is a
    #   fault on OUR side of the line — no browser sign-in fixes it, and a retry might — so it
    #   falls to `malfunction` and exits 1, which is what tells a caller to retry.
    #   keyrack_list_failed falls the same way, for the same reason.
    #
    # ⚠️ `no_subscriptions` and the two `active_identity_*` codes are here for a reason worth
    #   naming: they are raised on the orchestrator's OWN early returns, never on an account
    #   node, so no fold ever hands them to this table on its own. that made them invisible to
    #   it — `no_subscriptions` had no entry at all, so a branch routed through here would have
    #   fallen to the default `malfunction` and flipped a documented exit 2 into a 1, silently,
    #   for every cron and statusline that reads `$?`. they are entries now, and those branches
    #   derive their codes from here rather than hand-spell them.
    *) printf 'malfunction' ;;
  esac
}

# .what = the process exit code a severity earns ($1=constraint|malfunction)
# .why  = the LAST hand-spelled half of the contract. severity was already single-sourced, but
#   every caller then re-typed `return 2` beside it — so the table and the code it implies were
#   still two facts a reader had to check against each other. now they are one:
#   `return "$(_brains_auth_code_for_error "$e")"` cannot disagree with the table it reads.
# .note = the mapping is rule.require.exit-code-semantics, verbatim: 2 = the caller must fix
#   it, 1 = it broke and a retry may help.
_brains_auth_code_for_error() {
  [[ "$(_brains_auth_severity_for_error "$1")" == constraint ]] && { printf '2'; return; }
  printf '1'
}

# .what = the glyph that opens a hint, given its severity ($1=constraint|malfunction)
# .why  = one place decides which mark a severity wears, so the two are never typed apart
_brains_auth_glyph_for_severity() {
  [[ "$1" == constraint ]] && { printf '✋'; return; }
  printf '💥'
}

# .what = map an error code to a human remediation hint ($1=err)
# .why  = "what the human should do about error X" is a domain concern, not tree-layout —
#   keep it out of the render so a future consumer could reuse the same hint text
# .note = the fixes name no account: `brains.auth.set` reads the account off the token it
#   captures, so there is no handle to pass it. one command, whichever account is at fault.
# .note = the opening glyph is NOT typed into each line. it is rendered from the severity table
#   above, so a hint cannot wear a mark that disagrees with the exit code it earns.
_brains_auth_fix_for_error() {
  local err="$1" mark
  mark="$(_brains_auth_glyph_for_severity "$(_brains_auth_severity_for_error "$err")")"
  case "$err" in
    no_token)            printf '%s no token (run: brains.auth.set)' "$mark" ;;
    token_expired)       printf '%s token expired (run: brains.auth.set)' "$mark" ;;
    needs_reauth)        printf '%s stored token is stale — re-auth (run: brains.auth.set)' "$mark" ;;
    refresh_rejected)    printf '%s refresh token dead (run: brains.auth.set)' "$mark" ;;
    # a 5xx is ANTHROPIC's fault, never the token's, so the hint must not name a re-auth — the
    # one action that costs the human a browser flow and cannot touch the cause
    refresh_server_error) printf '%s anthropic returned a server error — your token is fine; retry shortly' "$mark" ;;
    # same two causes as `rate_limited` below — the mint is UA-gated identically
    refresh_rate_limited) printf '%s rate-limited on token refresh — retry in a bit; if it never clears, the pinned user-agent (%s) may be stale — override with BRAINS_AUTH_UA' \
                            "$mark" "$_BRAINS_AUTH_UA_PINNED" ;;
    no_access_token)     printf '%s refresh gave no access token — the oauth flow may have changed' "$mark" ;;
    refresh_curl_failed) printf '%s network error on token refresh — retry shortly' "$mark" ;;
    api_key_not_oauth)   printf '%s that is an api key, not a subscription oauth token' "$mark" ;;
    keyrack_absent)      printf '%s not stored yet (run: brains.auth.set)' "$mark" ;;
    # a sign-in cannot open a locked keyrack, so this hint names the unlock, not the sign-in
    keyrack_unreadable)  printf '%s could not read the keyrack (run: rhx keyrack unlock --owner %s --env %s)' \
                           "$mark" "$_BRAINS_AUTH_KEYRACK_OWNER" "$_BRAINS_AUTH_KEYRACK_ENV" ;;
    # the active account is read from ~/.claude, so its two failures name claude, not keyrack
    active_token_expired) printf '%s live token expired — run any claude command to renew it' "$mark" ;;
    active_creds_unreadable) printf '%s could not read the live claude credentials' "$mark" ;;
    # a refusal to read is the SAFE outcome for both: a live login we cannot name for certain
    # might be this very account, and a refresh would rotate its token out from under an open
    # claude session. they differ only in the fix, so they get one hint each.
    active_identity_unknown) printf '%s a login is present but unnamed — run any claude command, then retry' "$mark" ;;
    active_identity_unverified) printf '%s a login is present but its name could not be verified — run any claude command to renew it, then retry' "$mark" ;;
    curl_failed)         printf '%s network error (see above) — retry shortly' "$mark" ;;
    # ⚠️ a 429 has TWO causes here and the endpoint does not tell them apart, so the hint names
    #   both. the second is the one a retry can never clear: the UA is PINNED
    #   (`_BRAINS_AUTH_UA_PINNED`), and an unrecognized claude-code UA is bucketed into an
    #   aggressively throttled path that answers 429 forever. that is the documented failure
    #   which produced the pin in the first place, so a stale pin reproduces it exactly — and a
    #   bare "retry shortly" would then loop a human against a fault no retry fixes
    #   (`rule.require.errors-name-the-fix`).
    rate_limited)        printf '%s rate-limited — retry shortly; if it never clears, the pinned user-agent (%s) may be stale — override with BRAINS_AUTH_UA' \
                           "$mark" "$_BRAINS_AUTH_UA_PINNED" ;;
    # the 4xx/5xx pair from the usage endpoint. they read as opposites on purpose: one says
    # "your token is fine, wait", the other says "this token cannot read usage".
    usage_server_error)  printf '%s anthropic returned a server error — your token is fine; retry shortly' "$mark" ;;
    usage_rejected)      printf '%s the endpoint refused this token — it may lack the usage scope (re-run: brains.auth.set)' "$mark" ;;
    unexpected_shape)    printf '%s endpoint returned an unexpected shape — the api may have changed' "$mark" ;;
    parse_failure)       printf '%s could not read the endpoint response' "$mark" ;;
    # ⚠️ the two ORCHESTRATOR-only codes. no account node carries them, so they reach this
    #   table only if a future caller routes them here — and until now they would have fallen
    #   to the generic `<mark> <raw_code>` arm and rendered as "✋ no_subscriptions". that is a
    #   latent break of the one-hint-per-code invariant this table exists to hold, in exactly
    #   the two codes the severity table was also missing (for the same reason: no fold ever
    #   hands them over). both tables now know both codes.
    no_subscriptions)    printf '%s no subscriptions stored yet — add one: brains.auth.set' "$mark" ;;
    keyrack_list_failed) printf '%s could not list the keyrack — unlock it: rhx keyrack unlock --owner %s' "$mark" "$_BRAINS_AUTH_KEYRACK_OWNER" ;;
    *)                   printf '%s %s' "$mark" "$err" ;;
  esac
}

# .what = the exit code a combined-usage object earns ($1=combined json)
# .why  = a statusline or a cron reads `$?`; it never reads the tree. so the code must carry
#   the same verdict the tree shows, or automation reports "all clear" over a screen of
#   errors — the worst possible direction for a tool whose whole job is to warn.
# .note = the split is NOT re-derived here, and it is no longer recovered from the hint's
#   glyph either. both this verdict and that glyph read `_brains_auth_severity_for_error`, so
#   the classification lives in one table and reaches each surface as data. a second list would
#   be a second place to drift, and a drifted exit code is invisible until it lies.
_brains_auth_exit_for() {
  local combined="$1" total nerr err
  total="$(jq -r 'length' <<< "$combined" 2>/dev/null)"
  nerr="$(jq -r '[.[] | select(.error)] | length' <<< "$combined" 2>/dev/null)"
  # an unreadable combined is itself a malfunction — never silently a success
  [[ "$total" =~ ^[0-9]+$ && "$nerr" =~ ^[0-9]+$ ]] || return 1

  # a sweep that read real numbers for at least one account did its job. the failed accounts
  # are named in the tree, so the caller already has both the data AND the bad news — an
  # error code on a partial would cost the good numbers their consumer.
  (( nerr == 0 || nerr < total )) && return 0

  # every account failed, so no budget was read at all. classify by who must fix it:
  # any malfunction means at least one failure is ours or the network's -> 1.
  # all constraint means every failure is the caller's to fix (a dead or absent token) -> 2.
  while IFS= read -r err; do
    [[ -z "$err" ]] && continue
    [[ "$(_brains_auth_severity_for_error "$err")" == malfunction ]] && return 1
  done <<< "$(jq -r '.[] | select(.error) | .error' <<< "$combined" 2>/dev/null)"
  return 2
}

# ══ §12. render — the tree a human reads ═════════════════════════════════════
# .what = render the combined usage json as a turtle-headed tree ($1=combined json)
# .why  = keep the display logic out of the i/o + orchestration layers
_brains_auth_render() {
  local combined="$1" active="${2:-}"
  local reach node err s_used w_used o_used s_reset w_reset s_pct w_pct
  local mark
  # `active` is detected once by the caller and passed in — every account line flags whether
  # it is the one claude is signed in as, the most useful fact when you juggle accounts
  #
  # .why 🧠 and not the 🐢 the --help banners use: the two speak for different things, and the
  #   split is deliberate. 🐢 is the mechanic persona ADDRESSING you — help text, errors,
  #   advice. 🧠 labels the artifact being shown: a brain's budget. so the header of the
  #   budget itself is 🧠 (the wisher asked for it by name), while every line that talks TO
  #   the human stays 🐢.
  # .why no "— across all subscriptions" suffix: the same render serves `--reach <one>`, and
  #   there the suffix would be a plain lie. one header that is always true beats one that
  #   is true only in the default case.
  echo ""
  echo "🧠 claude budget"
  while IFS= read -r reach; do
    [[ -z "$reach" ]] && continue
    node="$(jq -c --arg s "$reach" '.[$s]' <<< "$combined")"
    err="$(_brains_auth_get_error "$node")"
    mark=''
    [[ -n "$active" && "$reach" == "$active" ]] && mark='  ← signed in'

    # an account with an error: show a named fix (hint text lives in its own map)
    if [[ -n "$err" ]]; then
      echo "   ├─ ${reach}${mark}: $(_brains_auth_fix_for_error "$err")"
      continue
    fi

    # pull the confirmed fields — utilization = percent used (91% = nearly spent, 3% = fresh)
    s_used="$(jq -r '.five_hour.utilization // 0' <<< "$node")"
    w_used="$(jq -r '.seven_day.utilization // 0' <<< "$node")"
    o_used="$(jq -r '.seven_day_opus.utilization // empty' <<< "$node")"
    s_reset="$(jq -r '.five_hour.resets_at // empty' <<< "$node")"
    w_reset="$(jq -r '.seven_day.resets_at // empty' <<< "$node")"
    s_pct="$(_brains_auth_round "$s_used")"
    w_pct="$(_brains_auth_round "$w_used")"

    # one block per account: a header line for the reach, then session + week each on
    # its OWN line — bar + percent + that window's reset together, so each window reads as
    # one thought. each reset shows BOTH the absolute time ("at fri 09:00") and the
    # countdown ("in 2h14m"), so a human reads the clock or the wait without a re-check.
    # .why no "nearly spent" badge: the bar already carries it. a full bar beside a 100%
    #   reads as spent at a glance, so a badge restates what is already plain — and a
    #   redundant alarm trains the eye to skip alarms.
    # .why the word "used" is spelled out on every row: the number alone is ambiguous, and
    #   this is the headline a go/no-go rests on. "58%" could be read as budget spent or
    #   budget left, and the two are opposites — a human who reads it backwards throttles
    #   when they had room, or charges ahead when they had none. the bar direction hints at
    #   it, but a hint is not a label. "used" is what the endpoint reports (`utilization`),
    #   so the word matches the source and no conversion sits between them to invert.
    printf '   ├─ %s%s\n' "$reach" "$mark"
    printf '   │  ├─ session  %s %3d%% used  ·  resets at %s, in %s\n' \
      "$(_brains_auth_bar "$s_pct")" "$s_pct" \
      "$(_brains_auth_when "$s_reset")" "$(_brains_auth_until "$s_reset")"
    # opus rides just after session (same 5h window) only when the account has one
    [[ -n "$o_used" ]] && printf '   │  ├─ opus     %s %3d%% used\n' \
      "$(_brains_auth_bar "$(_brains_auth_round "$o_used")")" "$(_brains_auth_round "$o_used")"
    printf '   │  └─ week     %s %3d%% used  ·  resets at %s, in %s\n' \
      "$(_brains_auth_bar "$w_pct")" "$w_pct" \
      "$(_brains_auth_when "$w_reset")" "$(_brains_auth_until "$w_reset")"
  done < <(jq -r 'keys[]' <<< "$combined")
  echo "   └─"
  echo ""
}

# .what = why an unverified name cannot be trusted — the shared diagnosis line
# .why  = three surfaces speak about one condition: `use` with no args (a caveated display),
#   `use --reach` (a refusal to MUTATE), and `usage` (a refusal to READ). they had each
#   hand-written the same underlying fact — that the name came from a record which can lag the
#   live token — so a future correction to that explanation would land in one place and drift
#   from two.
#   ⚠️ only the DIAGNOSIS is shared, deliberately. the three verdicts stay local and must:
#   a display may show a caveated guess, a read refuses because a refresh would sign the live
#   session out, and a swap refuses because a park under a stale name misfiles one account and
#   orphans another. those are three different consequences of one fact. to unify the verdicts
#   too would flatten a distinction the whole identity ladder exists to keep —
#   what they must share is the story, not the answer.
# .note = the fragment carries NO subject, so each caller supplies its own grammar around it
#   ("(unverified — …)", "its name was …", "that name was …"). a fragment that named its own
#   subject read wrong at two of the three sites the moment it was shared, which is a small but
#   real lesson: what is common here is the FACT, not the sentence.
_brains_auth_say_unverified_because() {
  printf 'read from %s, which can lag the live token' "$_BRAINS_AUTH_LIVE_PROFILE"
}

# .what = reject one unrecognized flag, the same way at every command ($1=the arg)
# .why  = all three commands ended a bad flag with the same sentence, typed three times — and
#   one copy had already drifted: `use` said "unknown arg: $1 (try --help)" where its two peers
#   said "bummer dude — unknown arg: $1 (see --help)". a human who learns one wording and then
#   meets another on the next command has to re-read to be sure it is the same refusal and not
#   a new class of failure. one copy holds all three level.
# .note = the three parse loops themselves stay separate on purpose — each binds different
#   locals for different flags, so a shared loop would take a callback per flag and read worse
#   than the three plain loops do. what repeated here was the SENTENCE, so the sentence is what
#   is shared (`rule.prefer.wet-over-dry` — extract only what actually repeated).
_brains_auth_say_unknown_arg() {
  echo "🐢 bummer dude — unknown arg: $1 (see --help)" >&2
  return 2
}

# .what = the error code an unresolved identity earns ($1=arc; 2=unverified, else unknown)
# .why  = the two arcs name two different fixes, and the orchestrator used to pick between
#   them inline. as a leaf the choice is readable on its own and reusable by the render.
_brains_auth_ident_err_for_arc() {
  (( $1 == 2 )) && { printf 'active_identity_unverified'; return; }
  printf 'active_identity_unknown'
}

# .what = say that the keyrack holds no subscription yet, and name the account at hand
# .why  = the same convention `_brains_auth_render_identity_blocked` was extracted for: output
#   is a pure leaf here, so it can be snapped directly rather than only through a driven sweep.
#   those two branches sit side by side in the orchestrator and only one had been pulled out,
#   which is exactly the drift that lets a convention quietly become a one-off — a reader of
#   the pair could not tell whether "inline" or "extracted" was the rule.
# .note = the profile read is the LOCAL file claude keeps, never a network call. that is the
#   whole reason this hint can exist here at all: the empty-store branch runs before the
#   identity read, because that read mints against the api and would cost a 15s timeout to
#   answer a question already in hand. see the caller's ⚠️ for the measurement.
# .note = it emits, and does NOT return the code — the caller derives that from the shared
#   severity table, so a render is never the place an exit code is decided.
_brains_auth_render_no_subscriptions() {
  local seen
  echo "🐢 no claude subscriptions in the global keyrack yet"
  seen="$(_brains_auth_creds_field "$_BRAINS_AUTH_LIVE_PROFILE" '.oauthAccount.emailAddress')"
  # attributed to claude on purpose: this name can lag the live token, so the sentence says
  # whose view it is rather than assert it as fact
  [[ -n "$seen" ]] \
    && echo "   claude's own profile names ${seen} — that is the account set would store"
  echo "   add one with:"
  echo "   └─ brains.auth.set"
}

# .what = say why no budget could be read at all ($1=err, $2=the candidate name, $3=as_json)
# .why  = extracted for the same reason `_brains_auth_render` and `_brains_auth_use_decide`
#   were: this file's convention is that output and decisions are pure leaves, so they can be
#   snapshot-tested directly instead of only through the orchestrator that calls them. this
#   ~20-line branch was the last one still written inline, so it was the only surface here
#   reachable exclusively when the whole sweep is driven — the shape that makes a case
#   expensive to write and therefore easy to skip.
# .note = it emits, and does NOT return the code. the caller derives that from the shared
#   severity table, so a render can never be the place an exit code is decided.
_brains_auth_render_identity_blocked() {
  local err="$1" active="$2" as_json="$3"

  [[ "$as_json" == 1 ]] && { _brains_auth_emit_error "$err"; return; }

  echo "🧠 claude budget" >&2
  echo "   └─ $(_brains_auth_fix_for_error "$err")" >&2
  echo "" >&2
  # ⚠️ name the candidate when there is one. `brains.auth.use` with no args SHOWS this same
  #   name (caveated), so to withhold it here would read as two unrelated faults rather than
  #   one condition seen from two commands — the human would take "who am i? kai@x" and
  #   "usage? no rows" as separate problems and chase both.
  #   the asymmetry in what the two commands DO is deliberate and stays: `use` with no args
  #   is a display, and a display may carry a caveated guess. this reads budget by REFRESH,
  #   and a refresh against the account that is truly live rotates its token out from under
  #   an open session — so the same guess may not authorize it. what they must share is the
  #   story, not the verdict.
  [[ -n "$active" ]] && echo "   the login here looks like ${active} — a guess, not a fact:" >&2
  [[ -n "$active" ]] && echo "   that name was $(_brains_auth_say_unverified_because)." >&2
  [[ -n "$active" ]] && echo "" >&2
  echo "   no account was read. a budget read REFRESHES each stored token, and a refresh" >&2
  echo "   against whichever account is truly live would sign your open session out. with" >&2
  echo "   the live one unproven, every account is a candidate, so none can be read." >&2
  return 0
}

# ══ §13. command: brains.auth.usage — read the budget ════════════════════════
# .what = show claude subscription budget usage; the command a human runs
# .why  = orchestrate the leaf operations (slugs -> gather -> render/json)
_brains_auth_usage() {
  local sub='@all' as_json=0
  _brains_auth_unlock_reset   # the memo lives for exactly one command — see the leaf's .why
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --reach|--sub)
        sub="$(_brains_auth_reach_from_flag "$@")" || return 2
        shift 2 ;;
      --json) as_json=1; shift ;;
      -h|--help)
        echo "🐢 brains.auth.usage — see your claude subscription budget (% used per window)"
        echo ""
        echo "  usage: brains.auth.usage [--reach <email>|@all] [--json]"
        echo ""
        echo "  reads each account's oauth token from the global keyrack and queries"
        echo "  the usage endpoint, then renders one block per account."
        echo ""
        echo "  --reach <email>  one account only (default: @all)"
        echo "                   alias: --sub (the old name, superseded)"
        echo "  --json           raw endpoint json per account (for automation)"
        echo ""
        echo "  each percent is budget USED, so a full bar means the window is spent."
        echo ""
        echo "  ⚠️ this read WRITES. anthropic rotates a refresh token every time it is spent,"
        echo "     so each account read mints once and stores the rotated token back into the"
        echo "     keyrack — one keyrack write per account, per call. that is what keeps the"
        echo "     next read working; it is not incidental."
        echo ""
        echo "     so poll no faster than once every 5 minutes. a tighter loop churns the"
        echo "     credential store for numbers that only move on the hour, and a write-back"
        echo "     that fails mid-churn leaves that account needing brains.auth.set."
        echo ""
        echo "     each account also costs one 'keyrack unlock' subprocess per call — one,"
        echo "     not one per retry — so an @all sweep scales with your account count."
        echo ""
        echo "  exit codes, for a cron or statusline that reads only \$?:"
        echo "    0  at least one account was read"
        echo "    1  every account failed, and at least one failure is ours to fix"
        echo "    2  every account failed, and every failure is yours to fix"
        echo ""
        echo "  example: brains.auth.usage --reach casey@ahction.com"
        return 0 ;;
      *) _brains_auth_say_unknown_arg "$1"; return $? ;;
    esac
  done

  # an account is named by its email — the reach its key is cut at. reject a bad shape here
  # rather than let it become a keyrack miss that reads as "never stored".
  if [[ "$sub" != "@all" ]] && ! _brains_auth_is_reach "$sub"; then
    echo "🐢 --reach must be @all or an email address — got: $sub" >&2
    return 2
  fi

  # gather the target reaches; a keyrack failure surfaces + aborts, not a false "empty"
  local reaches rc
  _brains_auth_debug "stage=reaches sub=${sub}"
  # an explicit reach is its own list of one — take it and skip the enumeration entirely,
  # so a named read never touches the keyrack manifest (rule.forbid.else-branches)
  reaches="$sub"
  if [[ "$sub" == "@all" ]]; then
    reaches="$(_brains_auth_reaches)"; rc=$?
    if (( rc != 0 )); then
      _brains_auth_debug "reaches FAILED rc=${rc}"
      # honor the --json contract on a global failure too: a valid json error
      # object to stdout, so `brains.auth.usage --json | jq …` never parses bare text
      [[ "$as_json" == 1 ]] && _brains_auth_emit_error 'keyrack_list_failed'
      return "$(_brains_auth_code_for_error 'keyrack_list_failed')"
    fi
  fi
  _brains_auth_debug "stage=reaches.done reaches=[$(_brains_auth_reaches_oneline "$reaches")]"

  # fail loud when no subscription is stored yet
  # ⚠️ this check stays BEFORE the identity read below, and that order carries real weight.
  #   the identity read is NOT cheap — it mints against the api, so on a machine with an
  #   empty store it costs a full 15s http timeout to answer a question whose answer ("you
  #   have stored no accounts") was already in hand for free. an empty store is the one state
  #   that needs no identity at all, so it must not pay for one. that cost is measured, not
  #   assumed: with the two swapped, `coldstart.no-subscriptions.tree` prints
  #   `curl: (28) Connection timed out after 15002 milliseconds` above the message.
  #   the HINT below still names the signed-in account — read from the local profile claude
  #   keeps, which is free, and attributed to claude so a stale name cannot mislead.
  if [[ -z "$reaches" ]]; then
    _brains_auth_debug "no reaches found"
    # same --json contract: a valid json error, not stderr text, for automation.
    # .note = the json node stays the bare `no_subscriptions` shape. an identity field here
    #   would make the error object's KEYS depend on machine state, so a consumer would have
    #   to branch on presence to read a failure — a worse contract than a stable one. the
    #   empty store IS the condition, and the exit code says so; the identity is a hint for
    #   the human, and hints belong on the human surface.
    if [[ "$as_json" == 1 ]]; then
      _brains_auth_emit_error 'no_subscriptions'
      return "$(_brains_auth_code_for_error 'no_subscriptions')"
    fi
    _brains_auth_render_no_subscriptions >&2
    return "$(_brains_auth_code_for_error 'no_subscriptions')"
  fi

  # compose: fetch the usage json, then emit it (raw for --json, tree otherwise)
  local combined ua active arc
  ua="$(_brains_auth_ua)"
  # detect the signed-in account ONCE, up front. it decides which account is read from
  # ~/.claude (no refresh) instead of the keyrack, so it must be known before the gather —
  # and one detection serves every account plus the render.
  # $arc carries HOW WELL it is known: 0=verified, 2=unverified (a name that may lag the
  # live token), 1=unknown. it is passed down whole, never flattened to a boolean — the
  # read path refuses on 1 and 2 alike, but each names a different fix.
  active="$(_brains_auth_active_reach "$ua")"
  arc=$?

  # ⚠️ an unresolved identity is ONE condition about the machine, not N conditions about N
  #   accounts. the read path refuses every reach when it holds (it cannot rule out that any
  #   given reach IS the live login, and a refresh on the live account is the lockout
  #   hazard.claude-oauth-one-holder-per-token.md forbids) — so a fan-out would print the same
  #   sentence once per stored account. a reader who scans N identical ✋ rows reads N dead
  #   tokens and reaches for N re-auths, when the truth is one renew.
  #
  #   so it is reported ONCE, here, before the sweep is attempted. the guard inside
  #   _brains_auth_node_for_reach stays as the backstop that makes the refusal true no matter
  #   who calls it; this is the surface that makes the refusal LEGIBLE.
  local ident_err=''
  if ! _brains_auth_identity_is_actionable "$arc" && [[ -f "$_BRAINS_AUTH_LIVE_CREDS" ]]; then
    ident_err="$(_brains_auth_ident_err_for_arc "$arc")"
    _brains_auth_debug "stage=identity.blocked arc=${arc} err=${ident_err}"
    _brains_auth_render_identity_blocked "$ident_err" "$active" "$as_json"
    return "$(_brains_auth_code_for_error "$ident_err")"
  fi

  # the signed-in account belongs in an @all sweep even when it was never `brains.auth.set` —
  # a plain `claude /login` is exactly the account whose remaining budget you most want to
  # see, and the keyrack enumeration alone would omit it. it reads from ~/.claude, so it
  # needs no stored token to appear.
  # ⚠️ only a VERIFIED name may be unioned in. an unverified one comes from a file that can
  #   lag the live token, so it would invent a row for an account that is not signed in —
  #   a name we cannot stand behind is not a subscription to list.
  if _brains_auth_should_union_active "$arc" "$sub" "$active" "$reaches"; then
    reaches="${reaches}"$'\n'"${active}"
    _brains_auth_debug "stage=reaches.union added active=${active}"
  fi

  _brains_auth_debug "stage=gather ua=${ua} active=${active:-<unknown>} arc=${arc}"
  combined="$(_brains_auth_gather "$ua" "$reaches" "$active" "$arc")"; rc=$?
  _brains_auth_debug "stage=gather.done rc=${rc} combined=${combined}"

  # a gather that yields no json at all is a hard failure — fail loud, do not render blank
  if [[ -z "$combined" ]]; then
    echo "🐢 bummer dude — usage gather produced no data (rerun with BRAINS_AUTH_DEBUG=1 to trace)" >&2
    return 1
  fi

  # the verdict is computed from the DATA, not from how it is displayed, so both surfaces
  # agree — `--json | jq` and the tree hand back the same `$?` for the same sweep.
  local verdict
  _brains_auth_exit_for "$combined"; verdict=$?
  _brains_auth_debug "stage=verdict rc=${verdict}"

  if [[ "$as_json" == 1 ]]; then
    jq . <<< "$combined"
    return "$verdict"
  fi

  # ⚠️ only a VERIFIED name may drive the "signed in as" mark. the mark is a claim of fact,
  #   and an unverified name comes from a record that can lag the live token — so to mark
  #   with it would badge the wrong row as the live account. an absent mark is a gap the
  #   reader can see; a wrong mark reads as truth.
  local active_marked=''
  _brains_auth_identity_is_actionable "$arc" && active_marked="$active"
  _brains_auth_debug "stage=render mark=${active_marked:-<none>}"
  _brains_auth_render "$combined" "$active_marked" || return 1
  _brains_auth_debug "stage=render.done verdict=${verdict}"
  return "$verdict"
}
alias brains.auth.usage='_brains_auth_usage'

# ⚠️ this file MUST end with a newline. an absent one glues the last line to whatever follows,
#   and a prior incident killed the parse of an entire aliases file that way — every alias in
#   it, silently, from one edit at the tail (hazard.bash-aliases-parse-silently.md).
#   the extraction that created this file lost the newline exactly once, to a `teesafe` that
#   strips every trailing newline it is handed. that is worth a note, not a shrug: the tool
#   the repo paves for writes cannot, by itself, satisfy the rule this file opens with.
