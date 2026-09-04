#!/usr/bin/env bash
######################################################################
# .what = install tfenv and symlink its binaries onto ~/.local/bin
#
# .a symlink, never a PATH entry for ~/.tfenv/bin
#   - `5.1.node`'s login hook already puts ~/.local/bin on every declared shell
#   - ⇒ one more PATH entry is a second place to sync, across .profile, .zshrc,
#     and the grove's non-interactive shell
#
# guarantee:
#   - an extant ~/.tfenv short-circuits, and `ln -sf` overwrites cleanly
#   - it DECLINES where no human is, since an apply changes real infra
######################################################################

grove_provision_5_7_terraform_provision_upsert() {
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 declined — a terraform apply changes real infrastructure, so it"
    echo "      wants a human to read the plan (see this bundle's _.sh)"
    return 0
  fi

  ####################################################################
  # .the pin — tfenv v3.2.2, as the commit that tag points at
  #   - a commit sha IS the integrity check: git verifies every object against
  #     its own hash (see `git_clone`)
  #
  # ⚠️ the COMMIT, never the tag name
  #   - upstream can retag v3.2.2 at other code, and every box would take it
  #   - ⇒ a commit sha cannot be repointed
  #
  # .to bump, dereference the tag you mean — its object is annotated, so two hops:
  #       gh api -X GET repos/tfutils/tfenv/git/ref/tags/vX   --jq .object.sha
  #       gh api -X GET repos/tfutils/tfenv/git/tags/<thatsha> --jq .object.sha
  ####################################################################
  local tfenv_at="de6ce2e809c155cbc5e2cfeb3b1bef151244e045"   # v3.2.2

  if [[ ! -d "$HOME/.tfenv" ]]; then
    if ! git_clone https://github.com/tfutils/tfenv.git "$HOME/.tfenv" --at "$tfenv_at"; then
      echo "   ✋ could not clone tfenv" >&2
      echo "      ⇒ with no tfenv, a stack whose required_version differs from" >&2
      echo "        whatever terraform is installed refuses to plan at all" >&2
      echo "      ⇒ git_clone named the fault above, and it already removed the" >&2
      echo "        partial dir — so a re-run refetches rather than skip on a" >&2
      echo "        carcass this phase's own -d guard would have believed" >&2
      return 1
    fi
  fi

  mkdir -p "$HOME/.local/bin" || return 1

  ####################################################################
  # .`ln -sf`, so a re-run repoints rather than fails on an extant link
  ####################################################################
  local f
  for f in "$HOME/.tfenv/bin/"*; do
    [[ -e "$f" ]] || continue
    ln -sf "$f" "$HOME/.local/bin/$(basename "$f")" || return 1
  done

  if [[ ! -L "$HOME/.local/bin/tfenv" ]]; then
    echo "   ✋ no tfenv symlink at ~/.local/bin/tfenv" >&2
    echo "      ⇒ tfenv is on the box and unreachable, so terraform resolves to" >&2
    echo "        some other build on PATH, or to none at all" >&2
    return 1
  fi

  echo "   • tfenv installed → ~/.local/bin/tfenv"
}
