#!/usr/bin/env bash
######################################################################
# .what = prove the `ambient` profile is declared AND that it actually
#         yields credentials
#
# ⚠️ it asks TWICE, and the second question is the real one
#   - a `[profile ambient]` block reads the same whether the instance role is
#     attached or revoked
#   - ⇒ the second probe runs `aws configure export-credentials`, a consumer's call
#   - (`rule.require.upgrade-entries-verify-themselves`)
#
# ⚠️ the probe is BOUNDED
#   - IMDS with no route to 169.254.169.254 HANGS rather than refuses
#   - ⇒ an unbounded verify stalls a whole run behind one metadata call
#   - (`rule.require.bounded-probes-in-verifies`)
#
# guarantee:
#   - READ-ONLY: it observes and mutates no state
#   - it prints no secret, only whether one was obtained
######################################################################

grove_provision_5_6_aws_configure_verify() {
  local cfg="$HOME/.aws/config"

  # a house seat has no IMDS; its badge has its own claims
  if [[ "${GROVE_ENV_SERVER:-}" == house@* ]]; then
    grove_provision_5_6_aws_configure_verify_house
    return
  fi

  ####################################################################
  # applicability — the same IMDS question the upsert asks
  ####################################################################
  if ! curl -sS -m 3 -X PUT 'http://169.254.169.254/latest/api/token' \
    -H 'X-aws-ec2-metadata-token-ttl-seconds: 60' >/dev/null 2>&1; then
    echo "   🌙 not applicable — no ec2 instance metadata here"
    return 0
  fi

  ####################################################################
  # claim 1 — the profile is DECLARED
  ####################################################################
  if [[ ! -r "$cfg" ]] || ! grep -q '^\[profile ambient\]' "$cfg" 2>/dev/null; then
    echo "   ✋ the 'ambient' profile is NOT declared in ~/.aws/config" >&2
    echo "      ⇒ every consumer that reads AWS_PROFILE has no name to read," >&2
    echo "        so it fails with 'AWS_PROFILE not set' while the box's own" >&2
    echo "        instance role sits one metadata call away" >&2
    echo "      fix: rhx grove.provision --what 5.6.aws --mode apply" >&2
    return 1
  fi
  echo "   • the 'ambient' profile is declared ✔"

  ####################################################################
  # claim 2 — and it LIVES. the claim above says only that text exists
  ####################################################################
  local out
  if out="$(AWS_PROFILE=ambient timeout -k 5 20 aws configure export-credentials \
    --profile ambient --format env 2>&1)"; then
    # ⚠️ `-q` is absent, and the direction is why it matters most here
    #   - under `set -uo pipefail` a matched `grep -q` SIGPIPEs `printf` → 141
    #   - ⇒ a MATCH takes the ELSE branch on a box with live credentials
    #   - (`gotcha.pipefail-grep-q`, `gotcha.a-check-that-cries-wolf-gets-silenced`)
    if printf '%s' "$out" | grep 'AWS_ACCESS_KEY_ID' >/dev/null; then
      echo "   • the ambient profile yields live credentials ✔ (value not printed)"
    else
      echo "   ✋ the profile exported NO access key" >&2
      echo "      ⇒ it is declared and inert, which reads as healthy to a" >&2
      echo "        presence check and fails at the first real aws call" >&2
      return 1
    fi
  else
    echo "   ✋ the ambient profile could not export credentials" >&2
    echo "      ⇒ the block is present, so a file check would report ✔ — this" >&2
    echo "        is exactly the gap between DECLARED and LIVE" >&2
    echo "      it said:" >&2
    printf '%s\n' "$out" | head -3 | sed 's/^/        /' >&2
    echo "      fix: confirm an iam role is attached to this instance" >&2
    return 1
  fi

  ####################################################################
  # claim 2b — and it works with NO profile named at all
  #
  # ⚠️ a profile-less ask is its own claim
  #   - a consumer may drop AWS_PROFILE once it holds keys in env, and the
  #     region goes with it:
  #
  #       ConfigError: Missing region in config
  #
  #   - 📜 grove-1 2026-08-06: 22 of 31 tests died on that line
  #   - ⇒ the claim above was green throughout, since it NAMES the profile
  ####################################################################
  local bare
  if bare="$(env -u AWS_PROFILE -u AWS_REGION -u AWS_DEFAULT_REGION \
    timeout -k 5 20 aws configure get region 2>&1)" && [[ -n "$bare" ]]; then
    echo "   • with NO profile named, a region still resolves ✔ ($bare)"
  else
    echo "   ✋ with NO profile named, NO region resolves" >&2
    echo "      ⇒ a consumer that drops AWS_PROFILE (keys in env outrank it)" >&2
    echo "        then fails on a region it cannot find — while a check that" >&2
    echo "        NAMES the profile reads perfectly green" >&2
    echo "      ⇒ a laptop hides this: a human's ~/.aws/config carries a" >&2
    echo "        [default] block, so a profile-less sdk still finds a region" >&2
    echo "      fix: rhx grove.provision --what 5.6.aws --mode apply" >&2
    echo "        (it writes a [default] block that mirrors [profile ambient])" >&2
    return 1
  fi

  ####################################################################
  # claim 3 — the credentials file aws-sdk v2 opens unconditionally
  #
  # .this is asked here, never left to an sdk to discover
  #   - `2.shell/2.5.zsh/zshrc.sh` sets AWS_SDK_LOAD_CONFIG=1, which routes v2's region
  #     lookup through a loader that opens that file unconditionally
  #   - ⇒ absent, it throws ENOENT from `Config.region`, four steps from a
  #     symptom that reads as a credential problem (see `configure.upsert.sh`)
  ####################################################################
  if [[ -e "$HOME/.aws/credentials" ]]; then
    echo "   • ~/.aws/credentials is present ✔ (aws-sdk v2 opens it unconditionally)"
  else
    echo "   ✋ ~/.aws/credentials is ABSENT" >&2
    echo "      ⇒ this box sets AWS_SDK_LOAD_CONFIG=1 (2.5.zsh/zshrc.sh), so aws-sdk" >&2
    echo "        v2 opens that file to derive a region and throws ENOENT when" >&2
    echo "        it is absent — even with valid credentials already in env" >&2
    echo "      fix: rhx grove.provision --what 5.6.aws --mode apply" >&2
    return 1
  fi

  ####################################################################
  # claim 4 — does a fresh shell leave AWS_PROFILE UNSET?
  #
  # 🛑 a NON-INTERACTIVE zsh that carries AWS_PROFILE=ambient is the DEFECT
  #   - rhachet's own type doc explains it:
  #
  #       KeyrackHostVault.d.ts —
  #         "os.envvar is always checked first in grant flow (ci passthrough)"
  #
  #   - ⇒ an exported AWS_PROFILE OUTRANKS EVERY RACK ENTRY, org and env alike
  #   - 📜 grove-1, after the prep hop was written AND proven by a live sts call:
  #
  #       rack    ahbode.test.AWS_PROFILE = "ambient"  ← read off the ENV
  #       profile ahbode.test.ehmpath     = …<prep-acct>:…/<prep-oidc-role> ✔
  #       suite   all 44 refusals         = …<camp-acct>:…/<camp-grove-role>
  #
  #   - ⇒ one shell variable answered for all four envs, so the hop worked
  #     and no consumer could name it (`rule.forbid.failhide`)
  #
  # ⚠️ what answers an `AWS_PROFILE not set` consumer is never an export
  #   - it is claim 2b's `[default]` block, plus the rack per env
  #
  # ⚠️ `zsh -c`, deliberately NOT `zsh -lic`
  #   - `-lic` opens ~/.zshrc, a shell no program ever runs
  #   - ⇒ the shell that matters is the one jest, npm, and `sg docker -c` get
  #   - (`term=probe`, the sixth hazard)
  #
  # ⚠️ `env -u AWS_PROFILE` wraps the probe, since a child zsh INHERITS this env
  #   - 📜 grove-1 2026-08-08: this claim reported an export from a ~/.zshenv
  #     that was byte-identical to a checkout that exports none
  #   - ⇒ the probe was right about the SESSION and wrong about the FILE
  ####################################################################
  local seen
  seen="$(env -u AWS_PROFILE zsh -c 'printf "%s" "${AWS_PROFILE:-}"' 2>/dev/null | tail -1)"
  if [[ -z "$seen" ]]; then
    echo "   • a fresh NON-INTERACTIVE zsh exports NO AWS_PROFILE ✔ (the rack is not shadowed)"

    ##################################################################
    # claim 4b — and no TMUX GLOBAL ENVIRONMENT re-injects it
    #
    # ⚠️ a second layer is owed
    #   - 📜 grove-1 2026-08-08: claim 4 went green, and every duct pane still
    #     carried `ambient`:
    #
    #       $ tmux show-environment -g | grep -i aws
    #       AWS_PROFILE=ambient
    #
    #   - tmux keeps its OWN environment, captured while ~/.zshenv exported it,
    #     and it OUTLIVES the file's correction
    #   - ⇒ a file-shaped claim is not enough, since a duct IS tmux
    #
    # ⚠️ this is a WARN, never a failure
    #   - a human may have set it deliberately for a session
    #   - ⇒ it is named so a reader knows which account a bare command reaches
    ##################################################################
    if command -v tmux >/dev/null 2>&1; then
      local tmuxenv
      # ⚠️ BOUNDED, and this is the worst site in the tree to leave bare
      #   - with no `-L` it asks the DUCT's own server, which a wedged pane hangs
      #   - ⇒ an unknown answer is a 🌙, never a client that waits forever
      tmuxenv="$(timeout -k 2 5 tmux show-environment -g 2>/dev/null | grep '^AWS_PROFILE=' | head -1)"
      if [[ -n "$tmuxenv" ]]; then
        echo "   ⚠️ tmux's GLOBAL environment still exports ${tmuxenv}"
        echo "      ⇒ every new pane inherits it, so a bare command reads that"
        echo "        profile rather than the rack (keyrack checks os.envvar first)"
        echo "      clear it: tmux set-environment -g -u AWS_PROFILE"
        echo "        (then rhx duct.reboot, or a new pane, to pick the change up)"
      else
        echo "   • tmux's global environment exports no AWS_PROFILE ✔"
      fi
    fi

    if [[ -n "${AWS_PROFILE:-}" ]]; then
      echo "     .note = THIS session still carries AWS_PROFILE='${AWS_PROFILE}', from"
      echo "       before the change. the file is correct; the live shell predates it."
      echo "       a fresh login is clean; to clear this one: rhx duct.reboot"
    fi
  else
    echo "   ✋ a fresh non-interactive zsh exports AWS_PROFILE='$seen'" >&2
    echo "      ⇒ keyrack checks 'os.envvar' FIRST, so this one value outranks" >&2
    echo "        EVERY rack entry on this box — every org, every env. a suite" >&2
    echo "        that asks the rack for its account gets '$seen' instead, and" >&2
    echo "        runs as the wrong identity with no error at all" >&2
    echo "      ⇒ measured on grove-1 2026-08-08: 44 aws refusals as the camp" >&2
    echo "        role, on a box whose prep hop was declared and proven" >&2
    echo "      ⇒ this probe already unset the variable, so the value came from a" >&2
    echo "        FILE a zsh reads — ~/.zshenv, or a ~/.zprofile a human wrote" >&2
    echo "      fix: rhx grove.provision --what 2.5.zsh --mode apply" >&2
    echo "        (~/.zshenv is 2.5.zsh's, and it exports no AWS_PROFILE)" >&2
    return 1
  fi

  return 0
}

######################################################################
# .what = prove a house seat's badge: its shape, its files, its hours, its renewal
#
# .why a house seat signs as a cert on disk, so four facts hold its badge, and each
#   breaks alone (vision case=4, case=6, case=7):
#     a. the profile SHAPE — `credential_process` alone. a `serve` port, a static
#        key, or an sso token beside it is a second identity (rows 27, 28)
#     b. the FILE MODES — 0600 in a 0700 dir. a widened key is a key every uid
#        can sign as (row 24)
#     c. the HOURS left — at least a day, so a dead renewal is loud a day early
#     d. the RENEWAL — the timer armed, the unit rendered from this checkout
#
# guarantee:
#   - READ-ONLY. no aws call: (a)–(c) read files, (d) asks the user manager
######################################################################
grove_provision_5_6_aws_configure_verify_house() {
  local failed=0 name unit_dir state_active state_enabled
  grove_provision_5_6_aws_house_badge_verdicts \
    "$HOME/.aws/config" \
    "$(grove_provision_5_6_aws_house_cert)" \
    "$(grove_provision_5_6_aws_house_key)" \
    "" || failed=1

  # d — the renewal timer, armed, and rendered from THIS checkout
  name="$(grove_provision_5_6_aws_house_renew_name)"
  unit_dir="$(grove_provision_5_6_aws_house_unit_dir)"
  state_active="$(systemctl --user is-active "$name.timer" 2>/dev/null)"
  state_enabled="$(systemctl --user is-enabled "$name.timer" 2>/dev/null)"
  if [[ "$state_active" == active && "$state_enabled" == enabled ]] \
    && grove_provision_5_6_aws_house_service_text | cmp -s - "$unit_dir/$name.service"; then
    echo "   • $name.timer is enabled and active, its unit from this checkout ✔"
  else
    echo "   ✋ the renewal timer is not armed as this checkout declares" >&2
    echo "      ⇒ active: ${state_active:-?} · enabled: ${state_enabled:-?} · unit matches: $(grove_provision_5_6_aws_house_service_text | cmp -s - "$unit_dir/$name.service" && echo yes || echo no)" >&2
    echo "      ⇒ unrenewed, the cert lapses within 7 days and the badge dies with it" >&2
    echo "      fix: rhx grove.provision --what 5.6.aws --mode apply" >&2
    failed=1
  fi

  return "$failed"
}

######################################################################
# .what = the three FILE-shaped claims of a house badge, over paths a caller names
#
# .why apart from the verify so the hermetic clamp (`grove.house.test`) asks the
#   SAME judge over fixtures — one judge, never a copy of it in a test
#
# usage: _house_badge_verdicts <aws config> <cert> <key> [<now epoch>]
######################################################################
grove_provision_5_6_aws_house_badge_verdicts() {
  local cfg="$1" cert="$2" key="$3" now="${4:-}" failed=0 at shape sect f state left
  at="$GROVE_PROVISION_5_6_AWS_HOUSE_RENEW_AT_HOURS"

  # a — the shape, of the named badge and of the bare call alike
  for sect in 'profile ambient' default; do
    shape="$(grove_provision_5_6_aws_badge_shape "$cfg" "$sect")"
    case "$shape" in
      process)
        echo "   • [$sect] is credential_process via aws_signing_helper, and no other source ✔" ;;
      # ⚠️ no fix-text here names a 5.6.aws apply: the badge line carries the
      #    trust anchor, profile, and role that #36 places, so the MINT writes it
      #    beside the cert, and an apply here would loop on the same refusal
      absent)
        echo "   ✋ [$sect] holds no badge source" >&2
        echo "      ⇒ a consumer that names no profile, or names ambient, finds no identity" >&2
        echo "      ⇒ the mint writes this line with the cert, once ahbode/infrastructure#36" >&2
        echo "        names the trust anchor it chains to" >&2
        failed=1 ;;
      serve|instance_role)
        echo "   ✋ [$sect] reads an imds endpoint ($shape) — on a house seat that is a 127.0.0.1 serve port" >&2
        echo "      ⇒ every uid on this box can reach 127.0.0.1, so every uid would wear this badge" >&2
        echo "      fix: delete that line from [$sect] in ~/.aws/config, then stop the serve process" >&2
        failed=1 ;;
      *)
        echo "   ✋ [$sect] draws from $shape, never credential_process alone" >&2
        echo "      ⇒ a static key never expires; an sso token puts a human on a schedule;" >&2
        echo "        two sources side by side is a second identity behind the first" >&2
        echo "      fix: delete every source line in [$sect] of ~/.aws/config but the" >&2
        echo "           aws_signing_helper credential-process one" >&2
        failed=1 ;;
    esac
  done

  # b — the file modes, cert and key alike
  for f in "$cert" "$key"; do
    state="$(grove_provision_5_6_aws_badge_file_state "$f")"
    case "$state" in
      tight) echo "   • $(basename "$f") is this seat's own, 0600 in a 0700 dir ✔" ;;
      absent)
        echo "   ✋ no badge file at $f" >&2
        echo "      ⇒ the first cert and key are placed by the mint, from the host, once" >&2
        echo "        ahbode/infrastructure#36 places the trust they chain to" >&2
        failed=1 ;;
      *)
        echo "   ✋ $(basename "$f") is $state — the per-uid wall is open" >&2
        echo "      ⇒ $(stat -c '%U %a' "$f" 2>/dev/null), in a dir of $(stat -c '%a' "$(dirname "$f")" 2>/dev/null)" >&2
        echo "      fix: chmod 600 $f && chmod 700 $(dirname "$f")" >&2
        failed=1 ;;
    esac
  done

  # c — the hours left
  left="$(grove_provision_5_6_aws_cert_hours_left "$cert" "$now")"
  if [[ "$left" == '?' ]]; then
    echo "   ✋ the cert at $cert cannot be read" >&2
    failed=1
  elif (( left < 0 )); then
    echo "   ✋ the cert ended $(( -left )) hours ago — the badge is dead" >&2
    echo "      ⇒ a dead cert cannot sign its own renewal; a human re-issues from the host" >&2
    echo "      read why: journalctl --user -u $(grove_provision_5_6_aws_house_renew_name).service" >&2
    failed=1
  elif (( left < at )); then
    echo "   ✋ the cert has $left hours left — the renewal owed below $at has not landed" >&2
    echo "      ⇒ the badge dies in $left hours unless a renewal lands first" >&2
    echo "      read why: journalctl --user -u $(grove_provision_5_6_aws_house_renew_name).service" >&2
    failed=1
  else
    echo "   • the cert has $left hours left ✔ (renewal owed below $at)"
  fi

  return "$failed"
}
