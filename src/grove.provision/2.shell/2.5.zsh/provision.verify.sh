#!/usr/bin/env bash
######################################################################
# .what = prove zsh exists, and that an interactive login lands in it — by EITHER
#         accepted route
#
# .why the claim is "a login LANDS in zsh" and not "chsh was run"
#   - the upsert has two legitimate outcomes
#   - the passwd record names zsh, or `.bash_profile` hands off to it
#   - both satisfy the human's actual claim
#   - ⇒ a verify that demanded only the record would report owed work on every key-only box
#   - pam refuses chsh there, and always will
#
# guarantee:
#   - READ-ONLY. it reads the passwd record and greps one file
#
# exit:
#   0 = zsh exists and a login reaches it by one of the two routes
#   1 = a claim failed, and which is named
######################################################################

grove_provision_2_5_zsh_provision_verify() {
  local failed=0

  ####################################################################
  # 1. the binary
  ####################################################################
  local zsh_bin; zsh_bin="$(command -v zsh 2>/dev/null || true)"
  if [[ -n "$zsh_bin" ]]; then
    echo "   • zsh present ($zsh_bin) ✔"
  else
    echo "   ✋ zsh is not on PATH" >&2
    echo "      ⇒ neither route below can reach a shell that is absent, and the" >&2
    echo "        rc file the configure phase copies would go unread" >&2
    echo "      fix: rhx grove.provision --what 2.5.zsh --mode apply" >&2
    return 1
  fi

  ####################################################################
  # 2. EVERY seat's record names zsh — the record, and only the record
  #
  # 🛑 a `~/.bash_profile` hand-off is NOT proof of this claim
  #   - it is guarded by `case $- in *i*`, so it is INTERACTIVE ONLY
  #   - ⇒ it answers for a human at a keyboard and for nobody else:
  #
  #       a human's login        → hands off to zsh ✔
  #       ssh seat '<cmd>'       → `bash -c`, reads NO startup file
  #       a cron, a jest child   → same
  #
  #   - a verify that takes the hand-off reports ✔ where no program can find `rhx`
  #   - that is the false-✔ half of `gotcha.a-check-that-cries-wolf-gets-silenced`
  #   - ⇒ the claim is `rule.require.one-command-provision`'s
  #   - after one apply, EVERY seat must be reachable NON-INTERACTIVELY
  #   - only the passwd record delivers that, so only the record is read
  #
  # ⚠️ it climbs every seat, never `$USER`
  #   - a seat converges its own $HOME and no other (`term=seat`, fact 5)
  #   - the RECORD is box-wide state written by the seat with sudo
  #   - ⇒ a per-$USER read reports ✔ from ground while the camper's record is bash
  #   - the seat list has one declaration in `_.sh`, which the upsert also reads
  #   - (`rule.forbid.two-writers-on-one-artifact`)
  ####################################################################
  local seats; seats="$(_grove_provision_2_5_zsh_human_seats)"

  local seat shell_now bad=""
  while IFS= read -r seat; do
    [[ -n "$seat" ]] || continue
    shell_now="$(getent passwd "$seat" 2>/dev/null | cut -d: -f7)"
    if [[ "$shell_now" == "$zsh_bin" ]]; then
      echo "   • $seat → login shell record names zsh ✔"
    else
      echo "   ✋ $seat → login shell record names '$shell_now'" >&2
      bad="${bad}${seat} "
    fi
  done <<< "$seats"

  if [[ -n "$bad" ]]; then
    echo "      ⇒ \`ssh <seat> '<cmd>'\` runs the RECORD, so these seats answer a" >&2
    echo "        program with \`bash -c\` — which reads no startup file at all." >&2
    echo "        rhx, pnpm, and node are absent from every such call" >&2
    echo "      ⇒ a ~/.bash_profile hand-off does NOT clear this claim: it is" >&2
    echo "        guarded to interactive logins, so it serves a human and no" >&2
    echo "        program" >&2
    echo "      fix: run this bundle from the seat that holds NOPASSWD sudo," >&2
    echo "           which writes the record for every seat on the box —" >&2
    echo "        ssh <grove>.ground" >&2
    echo "        rhx grove.provision --what 2.5.zsh --mode apply" >&2
    failed=$(( failed + 1 ))
  fi

  [[ "$failed" -eq 0 ]] || return 1
}
