#!/usr/bin/env bash
######################################################################
# .what = declare git's `user.name` and `user.email` on this box
#
# .the precedence, highest first
#
#   1. `$GIT_USER_EMAIL` / `$GIT_USER_NAME` — an explicit statement
#   2. a prior `git config --global` — also an explicit statement
#   3. derived from this box's github credential — the default
#   4. a prompt, ONLY where a human is confirmed present
#
#   - a derived value must never quietly outrank a stated one
#   - ⇒ 3 runs only when 1 and 2 leave a half absent
#
# ⚠️ a prompt is GATED on the machine
#   - a bare `read -rp` whenever GIT_USER_EMAIL is unset HANGS on a grove
#   - a duct is tmux, so the prompt sits open on the pane
#   - ⇒ it eats the NEXT command sent down the duct as its answer
#   - ⇒ the symptom reads as "the duct went silent", never as "a step asked"
#   - 📜 a tty probe FAILED in the field, since a tmux pane HAS a tty
#   - (`rule.forbid.tty-as-a-proxy-for-a-human`)
#
# guarantee:
#   - idempotent: two `git config --global` sets of one key each
#   - ⇒ a re-run overwrites the same value rather than accumulates
#   - NON-INTERACTIVE off `local@unix`, so it can never stall a duct
######################################################################

grove_provision_5_15_identity_configure_upsert() {
  local email="${GIT_USER_EMAIL:-}"
  local name="${GIT_USER_NAME:-}"

  # .a prior declaration on this box holds, and owes no prompt
  #   - ⇒ that is what makes a re-run silent rather than inquisitive
  [[ -n "$email" ]] || email="$(git config --global user.email 2>/dev/null || true)"
  [[ -n "$name" ]]  || name="$(git config --global user.name 2>/dev/null || true)"

  ####################################################################
  # .derive it from the box's own github credential (see `_.sh`)
  ####################################################################
  if [[ -z "$email" || -z "$name" ]]; then
    local derived dname demail
    if derived="$(grove_provision_5_15_identity_from_gh)"; then
      IFS=$'\t' read -r dname demail <<< "$derived"
      [[ -n "$name" ]]  || name="$dname"
      [[ -n "$email" ]] || email="$demail"
      [[ -n "$name" && -n "$email" ]] \
        && echo "   • identity derived from this box's github credential ($name)"
    fi
  fi

  if [[ -z "$email" || -z "$name" ]]; then
    ##################################################################
    # 🛑 an absent gh login is a ✋ here, and never a 🌙
    #   - `5.4.gh` runs BEFORE this bundle (see `5.devtools/_.sh`)
    #   - ⇒ an unauthed gh means `5.4.gh` did not converge
    #   - ⇒ a decline that holds only on where a phase SITS dies when it moves
    #
    # ⚠️ the test is `!= local@unix`, never `== cloud@*`, so it FAILS CLOSED
    #   - the question is "can i CONFIRM a human is here?"
    #   - an unset GROVE_ENV_SERVER makes `[[ "" == cloud@* ]]` false
    #   - ⇒ that form would prompt on a box it holds no fact about
    #   - `local@unix` is the ONLY value that means a human is at a keyboard
    #   - `local@cicd` is a local TIER with no human, so `local@*` fails open
    #
    # ⚠️ the TTY is read too, since the tier alone is not enough
    #   - the tier says this is the KIND of box a human sits at
    #   - it does not say a human sits at it RIGHT NOW
    #   - a laptop is `local@unix` under a cron, a unit, or a detached job
    #   - at `/dev/null` the read returns empty and the ✋ below catches it
    #   - at a PIPE that stays open it BLOCKS FOREVER
    #   - ⇒ this needs BOTH halves, the shape `pkg_can_sudo` settled on
    #   - (`rule.forbid.tty-as-a-proxy-for-a-human`, measured on a tmux pane)
    ##################################################################
    if [[ "$GROVE_ENV_SERVER" != "local@unix" || ! -t 0 ]]; then
      echo "   ✋ git has no identity, and this box's github credential named none" >&2
      if [[ "$GROVE_ENV_SERVER" == "local@unix" && ! -t 0 ]]; then
        echo "      ⇒ this box CAN hold a human, and no terminal is attached to THIS" >&2
        echo "        run — a cron, a unit, or a detached job. so there is no one" >&2
        echo "        here to answer a prompt, and one opened would block forever" >&2
        echo "      fix: export GIT_USER_EMAIL and GIT_USER_NAME, or re-run it" >&2
        echo "        from a terminal" >&2
        return 1
      fi
      echo "      ⇒ every commit this box makes is attributed to no author, which" >&2
      echo "        surfaces later as an unattributable history rather than as an" >&2
      echo "        absent config" >&2
      echo "      ⇒ 5.4.gh runs BEFORE this bundle, so an unauthed gh means THAT" >&2
      echo "        bundle did not converge — this is not a fact of order" >&2
      echo "      ⇒ no prompt is opened here: a duct is tmux, so the question would" >&2
      echo "        sit on the pane and consume the next command sent as its answer" >&2
      echo "      read why: gh api user --jq .login    # should name an account" >&2
      echo "      fix: rhx grove.provision --what 5.4.gh --mode apply" >&2
      return 1
    fi

    [[ -n "$email" ]] || read -rp "   git user.email (e.g., jane.doe@gmail.com): " email
    [[ -n "$name" ]]  || read -rp "   git user.name  (e.g., Jane Doe): " name

    if [[ -z "$email" || -z "$name" ]]; then
      echo "   ✋ git needs BOTH a user.email and a user.name" >&2
      echo "      ⇒ git refuses to commit with either absent, so a half-answer" >&2
      echo "        leaves the box unable to commit at all" >&2
      echo "      fix: re-run and answer both, or export GIT_USER_EMAIL and" >&2
      echo "        GIT_USER_NAME first" >&2
      return 1
    fi
  fi

  # .only a COMPLETE identity is written
  #   - git refuses to commit on a half one, as it does on an absent one
  #   - ⇒ a set-but-empty key reads as configured to a reader
  git config --global user.email "$email"
  git config --global user.name "$name"
  echo "   • git identity declared ($name <$email>)"
}
