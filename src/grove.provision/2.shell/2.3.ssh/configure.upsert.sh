#!/usr/bin/env bash
######################################################################
# .what = make this box hold an ssh keypair of its own
#
# 🛑 the keygen is GUARDED on a present key
#   - a bare `ssh-keygen` with a key on disk asks "Overwrite (y/n)?" and waits
#   - ⇒ one wrong keystroke destroys the key every remote already trusts
#   - it reads as "github rejects my key now", never as "an installer overwrote it"
#   - (rule.require.idempotent-install-procedures)
#
# 🛑 gate the prompt on INTENT (`local@unix`), never on a tty
#   - with a key absent, `ssh-keygen` prompts twice: path, then passphrase
#   - a duct is tmux, so the question sits on the pane
#   - it then eats the next command sent down as its answer
#   - ⇒ the run stalls AND the channel is corrupted
#   - a tmux pane HAS a tty, so a tty test fails open
#   - same gate as `2.2.git`'s identity prompt
#
# 🛑 a headless box GETS a passphrase-less key
#   - a passphrase must sit in an agent or file ON THE SAME BOX to stay usable
#   - ⇒ it guards only against an attacker who already holds the filesystem
#   - 📜 grove-1: a refusal here caused NO key and a permanent ✋, for weeks
#   - that box could not reach an ssh git remote at all
#   - a refusal only works when someone acts on it
#   - the real boundary already exists: the key is scoped to the grove
#   - the box is reached only through ssm, and the key is revoked at the remote alone
#   - `plan.grove-credentials.md` governs WHAT it may reach, and this bundle gives it one
#
# .why the gate stays even so
#   - it decides INTERACTIVE-vs-passwordless, never refuse-vs-generate
#   - a human at a keyboard is still asked, because there the question can be answered
#
# .why ed25519 and not the stock rsa
#   - a bare `ssh-keygen` still defaults to rsa on some images
#   - ed25519 is smaller, faster, and has no key-size question to get wrong
#   - github has taken it for years
#   - an explicit `-t` also removes one of the two prompts a bare call would open
#
# guarantee:
#   - idempotent: a present key is left ALONE, with no overwrite and no question
######################################################################

grove_provision_2_3_ssh_configure_upsert() {
  local key_dir="$HOME/.ssh"
  local key_path="$key_dir/id_ed25519"

  ####################################################################
  # 0. a key already here? then the declaration holds — see the ⚠️ above
  #
  # .any of the three usual types counts
  #   - a box that already presents an rsa key must NOT be handed a second identity
  #   - and it must never be asked to overwrite the first
  ####################################################################
  local extant=""
  local candidate
  for candidate in id_ed25519 id_ecdsa id_rsa; do
    if [[ -f "$key_dir/$candidate" ]]; then extant="$candidate"; break; fi
  done

  if [[ -n "$extant" ]]; then
    echo "   • ssh key already present (~/.ssh/$extant) — no work"
    return 0
  fi

  ####################################################################
  # 1. a keygen prompt may only open where a human waits — see the ⚠️ above
  #
  # ⚠️ .why the test is `!= local@unix` and not `== cloud@*`
  #   - it must FAIL CLOSED
  #   - an unset GROVE_ENV_SERVER makes `[[ "" == cloud@* ]]` FALSE
  #   - ⇒ that form opens the prompt on a box it knows no fact about
  #   - the question is "can i CONFIRM a human is here?"
  #   - `local@unix` is the only value that means a human is at a keyboard
  #   - `local@cicd` is local TIER with no human, so `local@*` fails open too
  #
  # ⚠️ the TTY decides a THIRD case
  #   - the tier says a human COULD be at this box, never that one is here NOW
  #   - a laptop is `local@unix` under a keyboard, a cron, a unit, or a detached job
  #   - step 2 leaves the PASSPHRASE question open on purpose
  #   - ⇒ with no terminal it blocks forever
  #   - (`rule.forbid.tty-as-a-proxy-for-a-human`, `.THE MIRROR`)
  #
  # 🛑 .why this case HALTS rather than falls into the headless branch
  #   - the headless branch generates a PASSPHRASE-LESS key
  #   - that is correct for a grove, where the box is the identity and is revoked remotely
  #   - on a LAPTOP it is a security downgrade the human never chose
  #   - ⇒ a background run would leave an unprotected key beside a human's own
  #   - (`rule.require.security-paramount`)
  #   - ⇒ three cases, three answers: prompt, generate without one, or REFUSE to decide
  ####################################################################
  if [[ "$GROVE_ENV_SERVER" == "local@unix" && ! -t 0 ]]; then
    echo "   ✋ this box has no ssh key, and no terminal is attached to THIS run" >&2
    echo "      ⇒ a cron, a unit, or a detached job. step 2 asks for a PASSPHRASE," >&2
    echo "        so it would block here rather than fail" >&2
    echo "      ⇒ and the headless path is NOT the answer on a laptop: it makes a" >&2
    echo "        passphrase-less key, which is right for a grove and a silent" >&2
    echo "        downgrade on a machine that also holds a human's own keys" >&2
    echo "      fix: run it from a terminal, so you may set a passphrase —" >&2
    echo "        rhx grove.provision --what 2.3.ssh --mode apply" >&2
    return 1
  fi

  if [[ "$GROVE_ENV_SERVER" != "local@unix" ]]; then
    mkdir -p "$key_dir" && chmod 700 "$key_dir"

    echo "   • no ssh key on this box, and no human confirmed to ask for a"
    echo "     passphrase — generate a PASSPHRASE-LESS key (see the ⚠️ above)"

    if ! ssh-keygen -t ed25519 -N '' -f "$key_path" -C "$(whoami)@$(hostname)" -q; then
      echo "   ✋ ssh-keygen did not produce a key" >&2
      echo "      ⇒ this box has no identity to present, so an ssh git remote and" >&2
      echo "        every box-to-box hop are refused by the far end" >&2
      echo "      ⇒ a partial key is possible if the run was interrupted: check" >&2
      echo "        ~/.ssh/ and remove any half-written pair before a retry" >&2
      return 1
    fi

    echo "   • ssh key declared, no passphrase (~/.ssh/id_ed25519)"
    echo "     ⇒ this key is scoped to THIS box; it is never a copy of a human's."
    echo "       what it may reach is governed by plan.grove-credentials.md, and"
    echo "       it is revoked at the remote without touch to any other key"
    echo "     register the public half with a remote:"
    echo "       cat ~/.ssh/id_ed25519.pub"
    return 0
  fi

  ####################################################################
  # 2. generate it, interactively, where a human can set a passphrase
  #
  #   - `-t ed25519` and `-f` remove the type and path questions
  #   - the PASSPHRASE question is left open on purpose
  #   - ⇒ it is the one answer a human should give
  ####################################################################
  mkdir -p "$key_dir" && chmod 700 "$key_dir"

  echo "   • no ssh key on this box — generate one now"
  echo "     (a passphrase is asked for next; an empty one leaves the key unprotected)"
  if ! ssh-keygen -t ed25519 -f "$key_path" -C "$(whoami)@$(hostname)"; then
    echo "   ✋ ssh-keygen did not produce a key" >&2
    echo "      ⇒ this box has no identity to present, so an ssh git remote and" >&2
    echo "        every box-to-box hop are refused by the far end" >&2
    echo "      ⇒ a partial key is possible if the run was interrupted: check" >&2
    echo "        ~/.ssh/ and remove any half-written pair before a retry" >&2
    return 1
  fi

  echo "   • ssh key declared (~/.ssh/id_ed25519)"
  echo "     the public half, to register with a remote:"
  echo "       cat ~/.ssh/id_ed25519.pub"
}
