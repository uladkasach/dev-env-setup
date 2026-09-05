#!/usr/bin/env bash
######################################################################
# .what = prove this box pushes to github with no secret at rest — by KEY, or by
#         the RACK
#
# ⚠️ the RACK counts as strongly as a key
#   - "by KEY, never a credential on disk" holds only for gh's `hosts.yml` token
#   - `2.2.git`'s keyrack helper reads a CENTRAL secret per fetch and stores none
#   - ⇒ that is stronger than a per-box key, never weaker
#   - ⇒ every branch below asks `grove_provision_5_10_repos_https_is_racked` first
#   - `_.sh` carries the measurement, and why a `gh ssh-key add` is the wrong fix
#
# ⚠️ it asks TWO questions, never one
#   - `gh config get git_protocol` governs what a FUTURE clone gets
#   - `git remote get-url origin` reports what THIS checkout already has
#   - a bootstrapped box answers `ssh` to the first and `https://…` to the second
#   - ⇒ one that asked only the first would print ✔ at the very origin to repair
#   - (`rule.require.upgrade-entries-verify-themselves`)
#
# ⚠️ an https origin is USUALLY a 🌙, never a ✋
#   - it WORKS, since gh installs a credential helper at login
#   - ⇒ a push over https succeeds, on a secret at rest rather than on the key
#   - ⇒ a ✋ would fire on every laptop between its bootstrap and its first key
#
# 🛑 the ONE case where it IS fatal, and why this verify needs it
#   - a file whose every branch prints 🌙 holds no `return 1` at all
#   - ⇒ that is a verify that cannot fail (`rule.forbid.failhide`)
#   - the claim that lets it fail is an IMPLICATION the upsert establishes:
#
#     `gh config get git_protocol` == ssh
#       ⇒ the upsert reached step 2, so a key exists AND github accepted it AND
#         `gh config set` succeeded
#       ⇒ so the upsert also reached step 3, whose job is to move THIS origin to
#         ssh, and which returns 1 if it cannot
#
#   - ⇒ `git_protocol == ssh` beside an https origin is a contradiction
#   - ⇒ the upsert claims it converged past a point it plainly did not
#   - ⇒ that is a defect in this bundle, never a box merely behind, so it is a ✋
#   - ⇒ it is also why this re-runs no `ssh -T git@github.com` live probe, whose
#     answer the declared `git_protocol` already carries
#   - (`rule.require.bounded-probes-in-verifies`, `judge-declared-state-not-live-state`)
#
# guarantee:
#   - READ-ONLY. it observes; it mutates no state
#
# exit:
#   0 = the two claims agree, whatever they say
#   1 = gh clones over ssh while this checkout still pushes https, a state the
#       upsert cannot have left behind
######################################################################

grove_provision_5_10_repos_configure_verify() {
  ####################################################################
  # 0. an absent key means neither claim below could ever have converged
  ####################################################################
  local key_dir="$HOME/.ssh" found="" candidate
  for candidate in id_ed25519 id_ecdsa id_rsa; do
    [[ -f "$key_dir/$candidate" ]] && { found="$candidate"; break; }
  done

  if [[ -z "$found" ]]; then
    echo "   🌙 no ssh key on this box, so an ssh origin cannot be judged"
    echo "      ⇒ 2.3.ssh owns the key; it is the claim to read, not this one"
    return 0
  fi

  ####################################################################
  # 1. what a future clone gets
  #   - this answer is ALSO the gate for claim 2 (see the header)
  ####################################################################
  local protocol
  protocol="$(gh config get git_protocol 2>/dev/null || true)"
  if [[ "$protocol" == "ssh" ]]; then
    echo "   • gh clones over ssh ✔"
  elif grove_provision_5_10_repos_https_is_racked; then
    echo "   • gh clones over '${protocol:-https}', and the rack authorizes it ✔"
  else
    ##################################################################
    # ⚠️ the fix here is `2.3.ssh` or a human, and NEVER a re-apply
    #   - the upsert already ran, met the same absent or unregistered key, and declined
    #   - ⇒ a re-apply prints this same line forever
    #   - its own 🌙 names the owner: `2.3.ssh` for an absent key, a human with
    #     `admin:public_key` for an unregistered one
    #   - (`term=decline._.choice._.md`)
    ##################################################################
    echo "   🌙 gh clones over '${protocol:-https}', not ssh, and no rack backs it"
    echo "      ⇒ each repo cloned from here needs a credential at push time"
    echo "      ⇒ the upsert above named the owner: 2.3.ssh when no key exists, or"
    echo "        a human with 'admin:public_key' when github has not been told of"
    echo "        one. a re-apply of THIS bundle reaches neither"
  fi

  ####################################################################
  # 2. what THIS checkout already has, the claim step 1 cannot make
  ####################################################################
  local repo_dir="${GROVE_SRC%/src}"
  if ! git -C "$repo_dir" rev-parse --git-dir >/dev/null 2>&1; then
    echo "   🌙 $repo_dir is no git checkout, so it declares no origin to judge"
    return 0
  fi

  local origin
  origin="$(git -C "$repo_dir" remote get-url origin 2>/dev/null || true)"

  if [[ "$origin" == git@github.com:* ]]; then
    echo "   • this checkout pushes over ssh ✔ ($origin)"
    return 0
  fi

  if [[ -z "$origin" ]]; then
    echo "   🌙 this checkout declares no 'origin', so it pushes nowhere"
    return 0
  fi

  ####################################################################
  # 3. the contradiction, the one claim this verify can refute
  #   - `git_protocol == ssh` is reachable only through the upsert run that
  #     must then move this origin (the header carries the chain)
  #   - ⇒ the two states below cannot honestly coexist
  ####################################################################
  if [[ "$protocol" == "ssh" ]]; then
    echo "   ✋ gh is declared to clone over ssh, yet THIS checkout still pushes" >&2
    echo "      over https" >&2
    echo "      ⇒ $origin" >&2
    echo "      ⇒ the upsert only reaches 'gh config set git_protocol ssh' once a" >&2
    echo "        key exists AND github accepted it — and the very next thing it" >&2
    echo "        does is move this origin, or return 1. so this pair means the" >&2
    echo "        origin was moved BACK after the apply, or the apply never ran" >&2
    echo "        to completion" >&2
    echo "      fix: rhx grove.provision --what 5.10.repos --mode apply" >&2
    return 1
  fi

  if grove_provision_5_10_repos_https_is_racked; then
    echo "   • this checkout pushes over https, and the rack authorizes it ✔"
    echo "     ⇒ $origin"
    echo "     ⇒ git reads the keyrack helper per fetch, so no secret sits on disk"
    return 0
  fi

  echo "   🌙 this checkout's origin is still the bootstrap's https url"
  echo "      ⇒ $origin"
  echo "      ⇒ a push here is authorized by a token sat in cleartext at"
  echo "        ~/.config/gh/hosts.yml, rather than by the key (or the yubikey"
  echo "        behind it) — it works, and it is the weaker of the two"
  echo "      ⇒ not fatal: gh clones over '${protocol:-https}', so the upsert has"
  echo "        no key github accepts. this box is behind, not broken"
  echo "      ⇒ the upsert names the owner. a re-apply of this bundle reaches it"
  echo "        only where the owner is this bundle — and here it never is"
}
