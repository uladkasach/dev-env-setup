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
  #   - `src/zshrc.sh` sets AWS_SDK_LOAD_CONFIG=1, which routes v2's region
  #     lookup through a loader that opens that file unconditionally
  #   - ⇒ absent, it throws ENOENT from `Config.region`, four steps from a
  #     symptom that reads as a credential problem (see `configure.upsert.sh`)
  ####################################################################
  if [[ -e "$HOME/.aws/credentials" ]]; then
    echo "   • ~/.aws/credentials is present ✔ (aws-sdk v2 opens it unconditionally)"
  else
    echo "   ✋ ~/.aws/credentials is ABSENT" >&2
    echo "      ⇒ this box sets AWS_SDK_LOAD_CONFIG=1 (src/zshrc.sh), so aws-sdk" >&2
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
