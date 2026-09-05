#!/usr/bin/env bash
######################################################################
# .what = prove the aws cli is v2 at the declared version, and that the ssm
#         plugin is beside it
#
# .the MAJOR VERSION is part of the claim
#   - debian's `awscli` package puts a v1 `aws` on PATH that answers `command -v`
#   - ⇒ every v2-only call this repo makes fails with an opaque arg error
#
# 🛑 the UPSERT'S guard must NOT be that same presence check
#   - a guard blind to that skips the box this file refutes
#   - ⇒ a re-apply hits the same guard, skips again, and prints this forever
#   - ⇒ both halves ask the state reader declared once in this bundle's `_.sh`
#   - ⇒ so the fix the upsert names is one an apply can honor
#   - (`rule.require.solve-at-cause`)
#
# ⚠️ the EXACT VERSION is part of the claim too
#   - `aws-cli/2.*` passes any v2, so another version reads ✔ on every apply
#   - ⇒ the upsert pins one, since an unpinned version breaks determinism
#
# guarantee:
#   - READ-ONLY: it observes and mutates no state
######################################################################

grove_provision_5_6_aws_provision_verify() {
  local failed=0

  ####################################################################
  # ⚠️ the SHARED reader, from this bundle's `_.sh` — one question, one reader
  #   - an inline `command -v` plus a version match would be a second cut
  #   - ⇒ the two would disagree on exactly the input this header names
  #   - read the reader's own header for the measurement
  #
  # ⚠️ `timeout` wraps a mere `--version`, and it lives INSIDE the reader
  #   - the v2 cli unpacks a bundled runtime and imports botocore before its
  #     first byte, which on a cold page cache is seconds to minutes
  #   - ⇒ a `--mode plan` is a survey a human expects to be quick
  #   - (`rule.require.bounded-probes-in-verifies`)
  ####################################################################
  case "$(grove_provision_5_6_aws_cli_state)" in
    whole)
      echo "   • aws cli is v2 at the declared version ✔"
      ;;
    unknown)
      echo "   🌙 aws did not answer a version within 20s, so its major is unproven"
      echo "      ⇒ usually a cold start of the bundled runtime"
      echo "      read it by hand, unbounded: aws --version"
      ;;
    absent)
      echo "   ✋ the aws cli is absent from PATH" >&2
      echo "      ⇒ no grove can be woken — git.grove.wake opens its tunnel" >&2
      echo "        through 'aws ssm start-session'" >&2
      echo "      fix: rhx grove.provision --what 5.6.aws --mode apply" >&2
      failed=1
      ;;
    adrift)
      echo "   ✋ aws is v2, and NOT at the version this repo declares" >&2
      echo "      ⇒ two boxes then run different cli code from one unchanged" >&2
      echo "        line — the deterministic clause of one-command provision" >&2
      echo "      ⇒ a command -v guard cannot see a version at all, so a" >&2
      echo "        presence check reports this state nowhere" >&2
      echo "      read why: aws --version" >&2
      echo "      fix: rhx grove.provision --what 5.6.aws --mode apply" >&2
      echo "           its upsert re-runs the installer with --update" >&2
      failed=1
      ;;
    *)
      echo "   ✋ the aws on PATH is NOT v2" >&2
      echo "      ⇒ debian's awscli package is v1, which answers command -v" >&2
      echo "        and then fails every v2-only call with an opaque arg error" >&2
      echo "      ⇒ a presence-check guard counts it done and skips, so this" >&2
      echo "        line would name a re-apply that could never clear it" >&2
      echo "      read why: aws --version ; type -a aws" >&2
      echo "      fix: rhx grove.provision --what 5.6.aws --mode apply" >&2
      echo "           its upsert installs v2 over it, and says so when a v1" >&2
      echo "           earlier on PATH still shadows the result" >&2
      failed=1
      ;;
  esac

  if command -v session-manager-plugin >/dev/null 2>&1; then
    echo "   • the ssm session-manager plugin is present ✔"
  else
    echo "   ✋ the ssm session-manager plugin is absent" >&2
    echo "      ⇒ 'aws ssm start-session' fails with 'SessionManagerPlugin is" >&2
    echo "        not found' — the cli alone cannot open a session" >&2
    echo "      fix: rhx grove.provision --what 5.6.aws --mode apply" >&2
    failed=1
  fi

  return $failed
}
