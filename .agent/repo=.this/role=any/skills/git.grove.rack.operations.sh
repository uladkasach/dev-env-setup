#!/usr/bin/env bash
######################################################################
# .what = read ONE credential off this laptop's rack, for ANY org
#
# .why  🛑 keyrack scopes a NAMED-ORG read to the CHECKOUT it runs in
#
#   measured 2026-09-28, from this repo's own checkout:
#
#     $ rhx keyrack get --owner ehmpath --org aether --env camp \
#         --key AWS_PROFILE --value
#     ✋ ConstraintError: --org 'aether' does not match manifest org 'ahbode'
#        └─ hint: use an org under 'ahbode', or pass --org @all
#
#   ⇒ so a laptop in the ahbode checkout cannot name aether — and `--org @all`
#     is no substitute, because it resolves a DIFFERENT slug
#     (`@all.camp.GITHUB_TOKEN`, never `aether.camp.AWS_PROFILE`)
#
#   ⚠️ FOUR reach skills read AWS_PROFILE for the grove's own org — `wake`,
#     `stop`, `trust.gen`, `auth.ssh.set`. so the refusal above is not a corner
#     case; it is every grove whose org is not this checkout's
#
#   ⇒ and all four now read it through `_rack_profile`, below. each held its own
#     copy until 2026-09-28, three of them without the foreign arm, so `wake`
#     worked and its three peers refused — one claim, four readers
#
# .how  a scratch GIT ROOT with a one-org manifest, read via `env -C`
#
#   FIVE callers in this repo already do exactly this, and they are the
#   precedent this holder consolidates (`term=keyrack.gitroot`):
#
#     | caller                       | phases                |
#     |------------------------------|-----------------------|
#     | `5.12.rack`                  | configure upsert+verify |
#     | `5.13.reach`                 | configure upsert+verify |
#     | `5.16.keys`                  | configure verify      |
#     | `5.4.gh`                     | configure upsert      |
#     | `git.grove.auth.keys.set`    | its local read        |
#
#   ⚠️ keyrack resolves a manifest from a GIT ROOT, so a plain dir answers
#     "no such entry" for every slug. the `git init` is load-bear
#
#   ⚠️ and the scratch manifest must declare the KEY, not merely the org —
#     keyrack refuses a named-org read of a key the yml in scope omits
#     (`5.16.keys/_.sh`, its `_declare` operation)
#
# 🛑 .why NOT in `git.grove.operations.sh`
#   that file declares itself READ-ONLY — "every operation here observes; none
#   mutates" — and every sourcing caller trusts it. this holder WRITES a file,
#   so it cannot live there without a lie in that contract
#
# .safety
#   - it writes ONE file: the scratch manifest, rewritten per read
#   - every value it writes is a NAME (org, env, key) — never a secret
#   - it RELAYS keyrack's stderr and never sinks it: `locked 🔒` and
#     `absent 🫧` both exit 2 with empty stdout, and want opposite repairs
#     (`term=entry`)
#   - it CLAMPS each coordinate, because all three reach a command line and
#     the org reaches a file
######################################################################

# .what = where the scratch rack root lives, relative to $HOME
# ⚠️ the same path `git.grove.auth.keys.set` uses, on purpose: one root, one
#   place to look when a read answers empty
GROVE_RACK_GITROOT_REL=".local/state/keyrack.gitroot"

# .what = read one key for one org+env, whatever org this checkout declares
# .usage = _rack_get <org> <env> <key>
# .emits = the value on stdout; keyrack's own stderr on stderr
# .exits = 0 with a value · 2 with none
_rack_get() {
  local org="${1:-}" env="${2:-}" key="${3:-}"
  local root="$HOME/$GROVE_RACK_GITROOT_REL"

  [[ -n "$org" && -n "$env" && -n "$key" ]] || {
    echo "✋ _rack_get wants <org> <env> <key>" >&2
    return 2
  }

  # 🛑 a LIVE clamp: all three reach a command line, and the org reaches a file
  local part
  for part in "$org" "$env" "$key"; do
    if [[ "$part" == *[!A-Za-z0-9._@-]* ]]; then
      echo "✋ a rack coordinate holds a character a read cannot carry: '$part'" >&2
      echo "   want: [A-Za-z0-9._@-]" >&2
      return 2
    fi
  done

  mkdir -p "$root/.agent" || {
    echo "✋ could not make the scratch rack root at $root" >&2
    return 2
  }
  git -C "$root" rev-parse --git-dir >/dev/null 2>&1 || git init -q "$root" || {
    echo "✋ could not init the scratch rack root at $root" >&2
    echo "   ⇒ keyrack resolves a manifest from a GIT ROOT, so a plain dir" >&2
    echo "     answers 'no such entry' for every slug (term=keyrack.gitroot)" >&2
    return 2
  }

  # ⚠️ REWRITTEN per read, by design. one org, one env, one key is the minimum
  #   a named-org read needs, and a narrower scope cannot leak a neighbour
  {
    printf '# .written by git.grove.rack.operations — a scratch git root, NOT a checkout\n'
    printf '#   - one org, one env, one key: the minimum a named-org read needs\n'
    printf '#   - REWRITTEN per read. every value here is a NAME, never a secret\n'
    printf 'org: %s\n' "$org"
    printf 'env.%s:\n' "$env"
    printf '  - %s\n' "$key"
    printf '  - AWS_PROFILE\n'
  } | tee "$root/.agent/keyrack.yml" >/dev/null || return 2

  local got
  got="$(env -C "$root" rhx keyrack get --owner ehmpath \
           --org "$org" --env "$env" --key "$key" --value)" || got=""

  [[ -n "$got" ]] || return 2
  printf '%s' "$got"
}

# .what = unlock one org's env on this laptop, whatever org this checkout declares
# .usage = _rack_unlock <org> <env> [key]
#
# 🛑 .why this exists beside `_rack_get`, and why its ABSENCE was a defect
#   `unlock` is checkout-scoped exactly as `get` is, and it refuses DIFFERENTLY.
#   measured 2026-09-28 from the ahbode checkout:
#
#     rhx keyrack unlock --owner ehmpath --env camp --key AWS_PROFILE --org aether
#       → ✋ key excluded by --org filter: AWS_PROFILE
#          ├─ orgsHeld: ahbode
#          └─ hint: re-run without --org, or with --org ahbode
#
#   ⇒ so a `_rack_get` that answered `locked 🔒` would print a tip
#     (`rhx keyrack unlock … --env camp --key AWS_PROFILE`) that CANNOT unlock the
#     slug it just named. a correct verdict whose repair is refused
#     (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.4)
#
#   ⚠️ and the hint's own advice is worse than useless here: `--org ahbode`
#     unlocks a DIFFERENT account's profile and reads as success
_rack_unlock() {
  local org="${1:-}" env="${2:-}" key="${3:-}"
  local root="$HOME/$GROVE_RACK_GITROOT_REL"

  [[ -n "$org" && -n "$env" ]] || {
    echo "✋ _rack_unlock wants <org> <env> [key]" >&2
    return 2
  }

  # 🛑 the same LIVE clamp `_rack_get` carries — these reach a command line too
  local part
  for part in "$org" "$env" ${key:+"$key"}; do
    if [[ "$part" == *[!A-Za-z0-9._@-]* ]]; then
      echo "✋ a rack coordinate holds a character an unlock cannot carry: '$part'" >&2
      echo "   want: [A-Za-z0-9._@-]" >&2
      return 2
    fi
  done

  # ⚠️ the manifest must already name this org. a `_rack_get` for the same
  #    coordinates writes it, so the common caller order is get → unlock → get.
  #    where a caller unlocks FIRST, seed the manifest the same way
  if [[ ! -f "$root/.agent/keyrack.yml" ]] \
     || ! grep -qxF "org: $org" "$root/.agent/keyrack.yml" 2>/dev/null; then
    _rack_get "$org" "$env" "${key:-AWS_PROFILE}" >/dev/null 2>&1 || true
  fi

  env -C "$root" rhx keyrack unlock --owner ehmpath --env "$env" ${key:+--key "$key"}
}

# .what = read AWS_PROFILE for a grove's org, whatever org this checkout declares
# .usage = _rack_profile <env> [org]
# .emits = the profile name on stdout; keyrack's own stderr, unsunk, on stderr
# .exits = 0 with a name · 2 with none
#
# 🛑 .why ONE reader — the header above named three skills, and only ONE was fixed
#   `wake`, `stop`, `trust.gen`, and `auth.ssh.set` each held their own copy of
#   this read. `wake` grew the native/foreign split on 2026-09-28; the other
#   three kept the plain named-org call, so each refused every foreign grove:
#
#     $ rhx git.grove.stop grove-aether-v20260921 --how hibernate --mode plan
#       ✋ ConstraintError: --org 'aether' does not match manifest org 'ahbode'
#
#   ⚠️ measured 2026-09-28, and the defect was already WRITTEN DOWN — this file's
#     own header says the refusal "is every grove whose org is not this
#     checkout's" and names all three skills. a note that names the other
#     readers repairs none of them
#
#   ⇒ four copies of one claim, free to drift, and the drift is silent: each
#     copy reads correctly alone (`gotcha.a-check-that-cries-wolf-gets-silenced`,
#     m.9 — one set, two readers). so the repair is a reader, never a fifth copy
#
#   ⚠️ and a FIFTH reader was found the same hour, with the axis absent rather
#     than mis-read: `aws.ec2.get` carried no `--org` at all, so its answer to
#     "is the box actually up?" — its own declared `.why` — was about whichever
#     account this checkout names. it now takes the axis and this reader
#
# ✔ .PROVEN on the FOREIGN path 2026-09-28, per caller, against aether from the
#   ahbode checkout. each printed `account: <acct> ✔ matches the registry`,
#   where the plain read it replaced answered a ConstraintError:
#
#     | caller                    | how it was proven                        |
#     |---------------------------|------------------------------------------|
#     | `git.grove.stop`          | plan, then a live hibernate              |
#     | `git.grove.wake`          | the wake that restored that box           |
#     | `aws.ec2.get`             | a tag read that found the box + its tags |
#     | `git.grove.auth.ssh.set`  | `--mode plan`, both seats `[KEEP]`       |
#
#   ⚠️ `git.grove.trust.gen` is the ONE caller not proven live. its `source` of
#     this holder loads (the skill runs clean), and its call site sits behind an
#     `already trusted` short-circuit — so to reach it needs a deliberate trust
#     break on a box tagged `protected=true`, which wants an ask first
#     (`rule.forbid.repair-plays`, exception 2 condition 0). the call shape is
#     the same five tokens as the four above, and that is evidence, never proof
#
# ⚠️ `--org` is passed ONLY when one is declared. an empty `--org ''` is NOT the
#   same as its absence — keyrack reads the empty string AS the org, so every
#   slug answers absent
_rack_profile() {
  local env="${1:-}" org="${2:-}" got=""

  [[ -n "$env" ]] || {
    echo "✋ _rack_profile wants <env> [org]" >&2
    return 2
  }

  # ⚠️ stderr is deliberately UNSUNK on every arm. `locked 🔒` and `absent 🫧`
  #   share exit code 2 and empty stdout, and differ only in that stream — which
  #   also carries the one repair each wants (`term=entry`, `term=swallow`)
  if [[ -z "$org" ]]; then
    got="$(rhx keyrack get --owner ehmpath --env "$env" --key AWS_PROFILE --value)" || got=""
  elif _rack_org_is_native "$org"; then
    # the native org takes the plain read — one fewer file written, and it is
    # the common case
    got="$(rhx keyrack get --owner ehmpath --org "$org" --env "$env" --key AWS_PROFILE --value)" || got=""
  else
    got="$(_rack_get "$org" "$env" AWS_PROFILE)" || got=""
  fi

  [[ -n "$got" ]] || return 2
  printf '%s' "$got"
}

# .what = the fix-text for a `_rack_profile` that answered empty
# .usage = _rack_profile_fix <env> [org]   — every line to STDERR
#
# 🛑 .why it is a reader too, and not four hand-written blocks
#   a FOREIGN org's unlock is checkout-scoped exactly as its read is, and it
#   refuses DIFFERENTLY — `unlock --org aether` from this checkout answers
#   "key excluded by --org filter … orgsHeld: ahbode", and its own hint
#   (`--org ahbode`) unlocks ANOTHER account's profile and reads as success.
#
#   ⇒ so the tip keyrack prints is unusable for a foreign org, and the one that
#     reaches must be named here. `wake` carried that branch; `stop` carried a
#     copy with no foreign arm, and `auth.ssh.set` a two-line stub. the repair a
#     caller prints is a CLAIM about which command works
#     (`rule.require.a-cue-is-not-a-claim`), so it gets one declaration
_rack_profile_fix() {
  local env="${1:-}" org="${2:-}"
  echo "  fix: the rack named it above — read that line, not this one." >&2
  if [[ -n "$org" ]] && ! _rack_org_is_native "$org"; then
    echo "       locked 🔒 wants an unlock — and '$org' is NOT this checkout's" >&2
    echo "       org, so a plain unlock refuses it. run the org-scoped one:" >&2
    echo "         rhx git.grove.rack.unlock --org $org --env $env --key AWS_PROFILE" >&2
    echo "       ⚠️ do NOT take the rack's own hint above: 'without --org' and" >&2
    echo "          '--org <this checkout>' each unlock ANOTHER account's" >&2
    echo "          profile, and each looks like a pass." >&2
  else
    echo "       locked 🔒 wants an unlock." >&2
  fi
  echo "       absent 🫧 is most often the WRONG ORG, not an unfiled key —" >&2
  echo "       the slug's org comes from .agent/keyrack.yml's 'org:' line," >&2
  echo "       and a wrong one reports absent while the rack holds the key:" >&2
  echo "         rhx keyrack list --owner ehmpath   # every entry's real org" >&2
  echo "       only a slug absent from THAT list wants a set — and a set has" >&2
  echo "       no entry-only mode, so it OVERWRITES whatever is live." >&2
}

# .what = does this checkout's own manifest declare this org?
# .why  a native org needs no scratch root at all — the plain read works, and
#   it is one fewer file written. so a caller asks this FIRST and only reaches
#   for `_rack_get` when the answer is no
_rack_org_is_native() {
  local org="${1:-}" declared
  [[ -n "$org" ]] || return 1
  declared="$(grep -m1 -E '^org:[[:space:]]*[^[:space:]]' \
                "$HOME/git/more/dev-env-setup/.agent/keyrack.yml" 2>/dev/null \
              | sed -E 's/^org:[[:space:]]*//; s/[[:space:]]+$//')"
  [[ -n "$declared" && "$declared" == "$org" ]]
}
