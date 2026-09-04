#!/usr/bin/env bash
######################################################################
# .what = make this seat's keyrack manifest hold an entry for the box's
#         github token — with no human, and with no new secret
#
# .why  = see `_.sh`
#   - the VALUE is already central and readable
#   - the ENTRY that lets keyrack find it dies with each box's $HOME
#
# guarantee:
#   - an entry already present is left alone and re-verified
#   - the value is READ from ssm and handed straight back, unchanged
#   - the secret is piped, never in argv, so `ps` shows no token
#   - it declines, never fails, where the slug cannot apply
######################################################################

grove_provision_5_12_rack_configure_upsert() {
  local key org env vault param
  key="$(grove_provision_5_12_rack_slug_key)"
  org="$(grove_provision_5_12_rack_slug_org)"
  env="$(grove_provision_5_12_rack_slug_env)"
  vault="$(grove_provision_5_12_rack_slug_vault)"
  param="$(grove_provision_5_12_rack_param_name)"
  # .what = 0. the tools this phase leans on DECLINE rather than fail
  # .why a hard fail on an absent neighbor turns one gap into a cascade — that
  #   neighbor's own verify already reports it (rule.require.upgrade-entries-verify-themselves)
  if ! command -v rhx >/dev/null 2>&1; then
    echo "   • declined — rhx is absent, and keyrack ships inside it (5.3.brains)"
    return 0
  fi
  if ! command -v aws >/dev/null 2>&1; then
    echo "   • declined — the aws cli is absent, so the ssm read cannot run (5.6.aws)"
    return 0
  fi
  # .what = 1. an entry already wired needs no work
  # .why `keyrack list`, never `get` — a get would UNLOCK the key into the daemon
  # .why no `-q`: under `set -uo pipefail`, a matched `grep -q` SIGPIPEs the list into
  #   a 141, so the `if` reads FALSE on the case it tests for (gotcha.pipefail-grep-q)
  # .why `env -C "$gitroot"` — the CWD is part of a keyrack READ; a manifest whose
  #   `extends` is unvendored THROWS from elsewhere, and `2>/dev/null` empties that
  #   into a false "no such entry" (term=keyrack.gitroot)
  # .why a flag, never an early `return 0` — a phase that wires N things falls
  #   through, it never returns for one alone
  # .refs = gotcha.5-12-rack.demo=entry-vs-value
  local gitroot
  gitroot="$(grove_provision_5_12_rack_gitroot)"
  local ghwired="false"
  if [[ -d "$gitroot" ]] \
     && env -C "$gitroot" rhx keyrack list \
          --owner "$(grove_provision_5_12_rack_slug_owner)" 2>/dev/null \
        | grep "${env}\.${key}" >/dev/null; then
    echo "   • the manifest already names ${org}.${env}.${key} — no work"
    ghwired="true"
  fi
  # .what = 2. a git root for the cli — made even when the github entry is wired,
  #   since the aws entry (step 5) uses it too. see `_.sh` for why it is needed
  # .why the cli wants a git ROOT, never a git PROJECT — an earlier draft cloned this
  #   repo here and `rhx` died in config load (gotcha.5-12-rack.demo=entry-vs-value)
  if [[ -e "$gitroot/rhachet.use.ts" ]]; then
    # .replace the old clone shape — this bundle owns the dir entirely
    rm -rf "$gitroot"
  fi
  if [[ ! -d "$gitroot/.git" ]]; then
    mkdir -p "$gitroot"
    if ! git -C "$gitroot" init --quiet 2>/dev/null; then
      echo "   ✋ could not make a git root for the keyrack cli" >&2
      echo "      ⇒ tried: git -C $gitroot init" >&2
      echo "      ⇒ this needs no network — it is a local mkdir plus a git init, so" >&2
      echo "        the cause is a permission or a full disk" >&2
      return 1
    fi
  fi
  # .what = 2b. the manifest FILE itself, before any entry can go in it
  # .why a seat with no manifest fails the set — a manifest is per-`$HOME`, so no
  #   seat inherits another's (term=seat); it runs unconditionally, `initKeyrack` is
  #   idempotent by contract
  # .why init alone is NOT enough — it writes `hosts: {}`, an empty index, so a box
  #   can hold a manifest and a live ssm value and still answer `absent 🫧`
  # .why the output is captured and replayed on failure — init writes no secret, so
  #   its log holds no value to hide (rule.forbid.failhide)
  # .refs = gotcha.5-12-rack.demo=entry-vs-value
  local initlog
  if ! initlog="$(env -C "$gitroot" rhx keyrack init \
        --owner "$(grove_provision_5_12_rack_slug_owner)" 2>&1)"; then
    echo "   ✋ keyrack init did not complete, so there is no manifest to write into" >&2
    echo "      ⇒ init needs an ssh key to name as its age recipient, which 2.3.ssh" >&2
    echo "        creates passphrase-less on a grove" >&2
    echo "      fix: rhx grove.provision --what 2.3.ssh --mode apply" >&2
    echo "      ⇒ what it said:" >&2
    printf '%s\n' "$initlog" | sed 's/^/        /' >&2
    return 1
  fi
  # .what = 3. read the CURRENT value out of ssm, as the box's own role
  # .why the value a prompt would ask for is already on the box's side, which is
  #   what makes the whole bundle human-free — skipped where the entry holds, since
  #   step 4 returns the same bytes
  if [[ "$ghwired" == "true" ]]; then
    grove_provision_5_12_rack_upsert_awsprofile "$gitroot"
    return $?
  fi
  local token
  token="$(aws ssm get-parameter --with-decryption \
             --name "$param" --query Parameter.Value --output text 2>/dev/null)"
  # .why fail loud on a short read, and NEVER pipe what came back — step 4
  #   OVERWRITES the ssm value with whatever it is fed, and a truncated read would
  #   replace a live pat with a blank (term=entry)
  if [[ -z "$token" || "$token" == "None" || ${#token} -lt 20 ]]; then
    echo "   ✋ the ssm parameter did not yield a usable value, so the set is REFUSED" >&2
    echo "      ⇒ param: $param" >&2
    echo "      ⇒ read back ${#token} chars; a set fed this would OVERWRITE the live" >&2
    echo "        value with it, so it is refused rather than risked" >&2
    echo "      ⇒ tell the two causes apart:" >&2
    echo "        aws sts get-caller-identity        # is this box the grove role?" >&2
    echo "        aws ssm describe-parameters        # can it see the param at all?" >&2
    echo "      ⇒ if the param is genuinely absent, a human must mint a pat and place" >&2
    echo "        it once — see rule.require.github-token-at-all-camp" >&2
    return 1
  fi
  # .what = 4. write the manifest entry, with the SAME bytes back into ssm
  # .why `env -C`, never a `cd` — the cwd change stays scoped to this one command
  # 🛑 THIS WRITE IS AN OPEN SECURITY DEFECT, uncloseable here — keyrack offers no
  #   entry-only mode, so this PUTs the SAME bytes back onto the one parameter the
  #   whole fleet reads; every grove's role must then hold `ssm:PutParameter` on it
  # .why that inverts the fleet-wide-READ argument that chose `aws.params` — one
  #   COMPROMISED box can now overwrite what every other box reads, silently undoing
  #   a human's rotation (`rule.require.github-token-at-all-camp` forbids exactly
  #   this command, and this is that command, on every fresh seat)
  # .the two fixes, neither lives in this repo: an entry-only write upstream
  #   (`keyrack recipient set` the candidate), or scope the role to
  #   `ssm:GetParameter` and let this fail LOUD
  # .why captured and replayed only on failure — keyrack masks the secret at its own
  #   prompt, so this log is diagnostic (rule.forbid.failhide)
  local setlog rc
  setlog="$(printf '%s' "$token" | env -C "$gitroot" rhx keyrack set \
              --owner "$(grove_provision_5_12_rack_slug_owner)" \
              --key "$key" --org "$org" --env "$env" \
              --vault "$vault" --mech PERMANENT_VIA_REPLICA 2>&1)"
  rc=$?
  unset token
  if [[ $rc -ne 0 ]]; then
    echo "   ✋ keyrack set did not complete (exit $rc)" >&2
    echo "      ⇒ the ssm value read fine, so this is the WRITE half — a manifest," >&2
    echo "        a recipient key, or an ssm put grant" >&2
    echo "      ⇒ what it said:" >&2
    printf '%s\n' "$setlog" | sed 's/^/        /' >&2
    return 1
  fi
  echo "   • the manifest now names ${org}.${env}.${key} (value unchanged in ssm)"
  # 5. the second entry: the NAME of this box's ambient aws identity
  grove_provision_5_12_rack_upsert_awsprofile "$gitroot"
}

######################################################################
# .what = wire `ahbode.{test,prep}.AWS_PROFILE` to the literal `ambient`
#
# .why  = see `_.sh`
#   - a consumer had no way to learn WHICH profile to reach for
#   - all 19 of svc-chat's suites threw `AWS_PROFILE not set` on a box that already
#     held live credentials
#   - it declines rather than fails where no ambient identity exists — a laptop has
#     no instance role, so a consumer aimed at `ambient` fails LATER than one aimed
#     at an absent name; `5.6.aws.configure.upsert` declines on the same fact
#
# .refs = gotcha.5-12-rack.demo=entry-vs-value
######################################################################
grove_provision_5_12_rack_upsert_awsprofile() {
  local gitroot="$1"
  local key org vault value owner
  key="$(grove_provision_5_12_rack_awsprofile_key)"
  org="$(grove_provision_5_12_rack_awsprofile_org)"
  vault="$(grove_provision_5_12_rack_awsprofile_vault)"
  value="$(grove_provision_5_12_rack_awsprofile_value)"
  owner="$(grove_provision_5_12_rack_slug_owner)"
  # .ask the aws cli, never a raw IMDS curl — the claim is that a CONSUMER of this
  #   profile gets live credentials, and a raw metadata call proves only a role
  if ! aws configure export-credentials --profile "$value" >/dev/null 2>&1; then
    echo "   🌙 declined — the '${value}' profile yields no credentials here"
    echo "      ⇒ so the rack would name a profile that cannot answer, and every"
    echo "        consumer aimed there would fail later and less clearly"
    echo "      ⇒ on a laptop this is correct: aws profiles are its human's to place"
    # .why this never says "5.6.aws has not run yet" — `5.devtools/_.sh` dispatches
    #   5.6 before 5.12, so order is no cause; an absent artifact from an EARLIER
    #   bundle means it did not CONVERGE (define.provision-defect-shapes)
    echo "      ⇒ on a grove it means 5.6.aws ran and did not converge — it is"
    echo "        dispatched BEFORE this bundle, so a re-apply of this one would"
    echo "        find the same absent profile"
    echo "        rhx grove.provision --what 5.6.aws --mode apply"
    return 0
  fi
  # .why a NAMED org needs a repo keyrack.yml, and `@all` does not — the throwaway
  #   root gets a minimal declaration; this is NOT written into an ahbode repo
  #   instead, since that repo's own `.agent/keyrack.yml` would then hold two
  #   writers, and `5.10.repos` clones it AFTER this bundle
  #   (rule.forbid.two-writers-on-one-artifact)
  # .refs = gotcha.5-12-rack.demo=entry-vs-value
  local rackyml="$gitroot/.agent/keyrack.yml"
  mkdir -p "$gitroot/.agent" || return 1
  {
    printf '# .written by 5.12.rack\n'
    printf '#   - this dir is a scratch git root owned by that bundle\n'
    printf '#   - it is NOT a checkout of any repo\n'
    printf '#   - the rhachet cli refuses a `keyrack set` for a NAMED org\n'
    printf '#     unless a keyrack.yml is in scope\n'
    printf '#   - the operation needs no repo, so this declares the minimum\n'
    printf '#   - it declares MORE envs than this bundle sets, since a\n'
    printf '#     declaration is a legal name and not a value\n'
    printf '#   - see `_.sh`, `_envs_declared`\n'
    printf 'org: %s\n' "$org"
    local e
    for e in $(grove_provision_5_12_rack_awsprofile_envs_declared); do
      printf 'env.%s:\n' "$e"
      printf '  - %s\n' "$key"
    done
  } > "$rackyml" || return 1
  local env
  for env in $(grove_provision_5_12_rack_awsprofile_envs); do
    # .`-q` is absent for the same reason as the gh read above
    # .why `env -C "$gitroot"` matters MORE here — a named-org lookup reads the
    #   `keyrack.yml` written just above; read from elsewhere the cli throws, an
    #   empty list reads as "no entry", and the loop re-drives a live set on every
    #   apply (define.provision-defect-shapes, "the NINTH shape")
    if env -C "$gitroot" rhx keyrack list --owner "$owner" 2>/dev/null \
       | grep "${org}\.${env}\.${key}" >/dev/null; then
      echo "   • the manifest already names ${org}.${env}.${key} — no work"
      continue
    fi
    # .why captured and replayed on failure, as the github set above is — this
    #   value is the word `ambient`, so its log discloses no secret
    local setlog rc
    setlog="$(printf '%s' "$value" | env -C "$gitroot" rhx keyrack set \
                --owner "$owner" --key "$key" --org "$org" --env "$env" \
                --vault "$vault" 2>&1)"
    rc=$?
    if [[ $rc -ne 0 ]]; then
      echo "   ✋ could not name ${org}.${env}.${key} in the rack (exit $rc)" >&2
      echo "      ⇒ without it, every ahbode suite on this box throws" >&2
      echo "        'AWS_PROFILE not set. keyrack.source() should have set it.'" >&2
      echo "      ⇒ what it said:" >&2
      printf '%s\n' "$setlog" | sed 's/^/        /' >&2
      return 1
    fi
    echo "   • the manifest now names ${org}.${env}.${key} = ${value} (a name, not a secret)"
  done
}
