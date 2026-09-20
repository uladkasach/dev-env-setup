#!/usr/bin/env bash
######################################################################
# .what = install the open-hours reconciler, the linked cwd it stands in, and
#         the systemd user unit + timer that drive it
#
# .a USER timer, not a system one
#   the gate state lives under the HUMAN's `~/.rhachet/storage`, and a system
#   unit fires as root, whose `$HOME` is `/root` — so it would run correctly
#   and gate the wrong account.
#
# ⚠️ .`daemon-reload` before `enable --now`
#   systemd caches unit files, so a rewrite alone leaves the OLD one live: the
#   fix lands on disk and the box keeps its prior behavior.
#
# .the files are COPIED from `$GROVE_SRC/machine/`, never heredoc'd here
#   a heredoc makes this phase the only place the text exists, so a verify
#   could assert presence and never CURRENCY.
#
# ⚠️ .why LINGER is attempted and never asserted
#   `systemctl --user` units live in the user's session manager, which exits
#   with the last session — so a headless box needs linger and a laptop with a
#   live session does not. one claim cannot be true of both, so this attempts
#   the grant and reports; the verify reads it back and names which box it is.
######################################################################

grove_provision_5_18_openhours_provision_upsert() {
  local bin_dir="$HOME/.local/bin"
  local unit_dir="$HOME/.config/systemd/user"

  ####################################################################
  # 0. the schedule is graded BEFORE the flag is read
  #
  # .why even when opted OUT: a typo is caught the day it is written, rather
  #   than the day somebody flips the flag and wonders why the gate shuts at
  #   the wrong hour
  ####################################################################
  local fault
  if ! fault="$(grove_provision_5_18_openhours_schedule_check)"; then
    echo "   ✋ the declared schedule is malformed: $fault" >&2
    echo "      ⇒ fix it at its one declaration:" >&2
    echo "        src/grove.provision/5.devtools/5.18.openhours/_.sh" >&2
    return 1
  fi

  ####################################################################
  # the opt-out leg — see the bundle header for why it TEARS DOWN
  #
  # 🛑 it opens NO gate. a human may have closed one by hand, and the safe
  #   direction on an unreconciled gate is closed
  ####################################################################
  if [[ "$GROVE_OPENHOURS_ENABLED" != "true" ]]; then
    if [[ -f "$unit_dir/machine_openhours_reconcile.timer" ]]; then
      systemctl --user disable --now machine_openhours_reconcile.timer 2>/dev/null
      rm -f "$bin_dir/machine_openhours_reconcile" \
            "$unit_dir/machine_openhours_reconcile.service" \
            "$unit_dir/machine_openhours_reconcile.timer" \
            "$GROVE_OPENHOURS_SCHEDULE"
      systemctl --user daemon-reload 2>/dev/null
      echo "   🌙 openhours is opted out — the timer is stopped and its files removed"
      echo "      the gates are left EXACTLY as they stand; this opens none"
    else
      echo "   🌙 openhours is opted out — no gate installed"
    fi
    echo "      opt in: set GROVE_OPENHOURS_ENABLED=true in this bundle's _.sh"
    return 0
  fi

  mkdir -p "$bin_dir" "$unit_dir" || return 1

  ####################################################################
  # 1. the reconciler and its two units — each from a declared source
  ####################################################################
  local pair
  for pair in \
    "machine_openhours_reconcile:$bin_dir/machine_openhours_reconcile" \
    "machine_openhours_reconcile.service:$unit_dir/machine_openhours_reconcile.service" \
    "machine_openhours_reconcile.timer:$unit_dir/machine_openhours_reconcile.timer"
  do
    local name="${pair%%:*}"
    local dst="${pair#*:}"
    local src="$GROVE_SRC/machine/$name"

    if [[ ! -f "$src" ]]; then
      echo "   ✋ no $name at $src" >&2
      echo "      ⇒ this run's own checkout is incomplete" >&2
      return 1
    fi
    cp "$src" "$dst" || return 1
  done
  chmod +x "$bin_dir/machine_openhours_reconcile" || return 1
  echo "   • the open-hours reconciler and its two units declared"

  ####################################################################
  # 2. the cwd the reconciler stands in — see the bundle header for why
  #    this is BUILT rather than borrowed from a checkout
  #
  # ⚠️ the guard is the shared THREE-valued reader, never `[[ -d ]]`. a build
  #   cut partway leaves a dir that passes a presence test and resolves no
  #   skill, so a presence guard would skip it on every apply thereafter and
  #   the box would be unrepairable by this command
  #   (`define.provision-defect-shapes`, shape 6)
  ####################################################################
  local cwd_state
  cwd_state="$(grove_provision_5_18_openhours_cwd_state)"

  if [[ "$cwd_state" == "whole" ]]; then
    echo "   • the reconciler's cwd is built and at the pin"
  else
    command -v pnpm >/dev/null 2>&1 || {
      echo "   ✋ pnpm is absent, so the reconciler's cwd cannot be built" >&2
      echo "      ⇒ 5.1.node installs it and runs BEFORE this bundle, so an" >&2
      echo "        absent pnpm means THAT bundle did not converge" >&2
      echo "      fix: rhx grove.provision --what 5.1.node --mode apply" >&2
      return 1
    }

    # ⚠️ `rhachet`, never `rhx`. `rhx` IS `rhachet run`, so `rhx roles link`
    #    asks for a SKILL named "roles" and dies with a ConstraintError. the
    #    link is a top-level rhachet verb, so it wants the base binary
    #    (`rule.require.invoke-rhx-by-its-bare-name` governs the SKILL surface)
    command -v rhachet >/dev/null 2>&1 || {
      echo "   ✋ rhachet is absent, so no role can be linked into the cwd" >&2
      echo "      ⇒ 5.3.brains installs it and runs BEFORE this bundle" >&2
      echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
      return 1
    }

    mkdir -p "$GROVE_OPENHOURS_CWD" || return 1

    # ⚠️ `git init` alone satisfies the gate skills — both ask
    #    `git rev-parse --show-toplevel`, which answers on a repo with no
    #    commit (`git.commit.operations.sh:102`). so no commit is owed here
    if [[ ! -d "$GROVE_OPENHOURS_CWD/.git" ]]; then
      git -C "$GROVE_OPENHOURS_CWD" init -q || return 1
    fi

    # a package.json is what `pnpm add` writes into; without one it walks UP
    # and installs into whatever parent it finds
    [[ -f "$GROVE_OPENHOURS_CWD/package.json" ]] \
      || printf '{\n  "name": "machine-openhours-cwd",\n  "private": true\n}\n' \
         > "$GROVE_OPENHOURS_CWD/package.json" \
      || return 1

    # ⚠️ `web_pnpm`, never a bare `pnpm` — an unbounded registry call on the
    #    provision path does not fail one phase, it holds the duct and every
    #    command sent after it (`rule.require.bounded-probes-in-verifies`)
    if ! ( cd "$GROVE_OPENHOURS_CWD" && web_pnpm add "${GROVE_OPENHOURS_ROLE_PKGS[@]}" ); then
      echo "   ✋ could not install the gate skills' role packages" >&2
      echo "      ⇒ the reconciler would tick, read the clock, and reach no" >&2
      echo "        skill — the gate never moves" >&2
      echo "      read why: cd $GROVE_OPENHOURS_CWD && pnpm add ${GROVE_OPENHOURS_ROLE_PKGS[*]}" >&2
      return 1
    fi

    # `rhachet roles link` writes `.agent/repo=X/role=Y/skills` as a symlink
    # into the installed package — the tree `rhx` reads (`execRoleLink.ts:156`)
    local link
    for link in "ehmpathy:mechanic" "bhuild:dispatcher"; do
      if ! ( cd "$GROVE_OPENHOURS_CWD" \
             && rhachet roles link --repo "${link%%:*}" --role "${link#*:}" >/dev/null 2>&1 ); then
        echo "   ✋ could not link repo=${link%%:*}/role=${link#*:} into the cwd" >&2
        echo "      ⇒ rhx finds a skill among the roles linked into its cwd, so" >&2
        echo "        the reconciler resolves no gate skill without this" >&2
        echo "      read why: cd $GROVE_OPENHOURS_CWD && rhachet roles link --repo ${link%%:*} --role ${link#*:}" >&2
        return 1
      fi
    done

    # ⚠️ the same reader is asked AGAIN. every step above can report success
    #   and leave the claim unmet, so the phase proves its own outcome rather
    #   than infer it from its last exit code (`rule.forbid.failhide`)
    cwd_state="$(grove_provision_5_18_openhours_cwd_state)"
    if [[ "$cwd_state" != "whole" ]]; then
      echo "   ✋ the cwd was built and still reads '$cwd_state'" >&2
      echo "      ⇒ expected a git repo that carries both gate skills at the pin:" >&2
      echo "        $GROVE_OPENHOURS_CWD" >&2
      return 1
    fi
    echo "   • the reconciler's cwd built and linked"
  fi
  echo "     $GROVE_OPENHOURS_CWD"

  ####################################################################
  # 2.5 the schedule the payload reads
  #
  # ⚠️ RENDERED, never hand-placed. the payload runs from `~/.local/bin`,
  #   outside any checkout, so it cannot source the bundle's declaration — this
  #   is how that one declaration reaches it, and the verify diffs a fresh
  #   render against what sits here to prove it CURRENT
  ####################################################################
  mkdir -p "$(dirname "$GROVE_OPENHOURS_SCHEDULE")" || return 1
  grove_provision_5_18_openhours_schedule_render > "$GROVE_OPENHOURS_SCHEDULE" || {
    echo "   ✋ could not write the schedule to $GROVE_OPENHOURS_SCHEDULE" >&2
    echo "      ⇒ the reconciler reads no window and dies on every tick" >&2
    return 1
  }
  echo "   • schedule declared — days $GROVE_OPENHOURS_DAYS, ${GROVE_OPENHOURS_FROM}–${GROVE_OPENHOURS_TILL} $GROVE_OPENHOURS_ZONE"

  ####################################################################
  # 3. reload FIRST — the header says why a rewrite alone does no work
  ####################################################################
  systemctl --user daemon-reload || {
    echo "   ✋ systemctl --user daemon-reload failed" >&2
    echo "      ⇒ the new unit files are on disk and the OLD definitions stay" >&2
    echo "        live, so the fix appears applied and the box does not change" >&2
    return 1
  }

  if systemctl --user enable --now machine_openhours_reconcile.timer; then
    echo "   • machine_openhours_reconcile.timer enabled and started (2/hr)"
  else
    echo "   ✋ could not enable machine_openhours_reconcile.timer" >&2
    echo "      ⇒ the gate never converges, so a box left open at 20:00 stays" >&2
    echo "        open through the next work day with no signal that it did" >&2
    return 1
  fi

  ####################################################################
  # 4. linger — attempted, reported, never fatal (see the header)
  ####################################################################
  local linger
  linger="$(loginctl show-user "$USER" --property=Linger --value 2>/dev/null)"
  if [[ "$linger" == "yes" ]]; then
    echo "   • linger already on — the timer survives a logout"
  elif loginctl enable-linger "$USER" 2>/dev/null; then
    echo "   • linger enabled — the timer survives a logout"
  else
    echo "   🌙 could not enable linger for '$USER'"
    echo "      costs no gate while a human session is live; on a HEADLESS box"
    echo "      the user manager exits with the last session and the gate stops."
    echo "      grant it from a seat with sudo:"
    echo "        sudo loginctl enable-linger $USER"
  fi

  ####################################################################
  # 5. converge once, now, rather than wait out the interval
  #
  # .why: an apply that installs a gate un-converged reports success over a box
  #   whose gate is whatever it was — on a first apply, "open", inside open
  #   hours. that is the wrong direction to be wrong in.
  ####################################################################
  if "$bin_dir/machine_openhours_reconcile"; then
    echo "   • the gate converged to the policy for right now"
  else
    echo "   ✋ the reconciler ran and could not converge the gate" >&2
    echo "      read why: $bin_dir/machine_openhours_reconcile" >&2
    return 1
  fi
}
