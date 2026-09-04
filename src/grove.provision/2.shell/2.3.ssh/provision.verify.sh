#!/usr/bin/env bash
######################################################################
# .what = prove this box holds the ssh halves its TIER declares, and no more
#
# 🛑 .the claim is TIER-SCOPED, because the upsert's package name is
#
#    | tier      | client | daemon binary | daemon RUNS |
#    |-----------|--------|---------------|-------------|
#    | `cloud@*` | must   | must          | the platform's business |
#    | `local@*` | must   | never asked for | must NOT — see below |
#
#    a grove IS reached over ssh, so the daemon is how its duct exists at all.
#    a laptop is reached by a human at its keyboard and needs no listener.
#
# .why the two halves are checked SEPARATELY on a grove
#         `ssh` is a metapackage, so a partial install is possible: apt can land
#         `openssh-client` and fail `openssh-server`. one check on `ssh` would
#         pass on exactly that box — a box that can reach out but that no duct can
#         reach. the asymmetry is invisible from a laptop and fatal on a grove
#
# 🛑 .why a LAPTOP with sshd LISTENING is a ✋ and not a note
#
#    📜 measured 2026-09-03, redteam round 22. this file's own header used to
#      say *"a local laptop deliberately keeps its daemon down"* and no code
#      made that true — the upsert asked for the metapackage on every tier, and
#      apt enables the server it pulls. one comment, no reader, and the box
#      shipped a password-authenticated port to every network it joined.
#
#    ⇒ so the sentence is now a CHECK. the upsert stopped the repo from turning
#      the daemon on; this rung reports a daemon that is already on, because a
#      box converged before that repair still carries one and apt removes none
#      of it on a re-apply.
#
#    ⚠️ this rung REPORTS and repairs no state — a verify never writes
#      (`rule.forbid.repair-plays`). the repair is a stop + disable + mask, and
#      it lives in this bundle's own `provision.upsert`, step 2.
#
#    ⇒ so the fix text names a RE-APPLY, never a hand command. a fix text that
#      hands a human three `systemctl` lines is the fourth step
#      `rule.require.one-command-provision` forbids.
#
#    ⚠️ and the re-apply is legal to name here because the upsert carries NO
#      skip-guard on that state — it re-reads `is-enabled`/`is-active` every
#      run. a fix text that names a re-apply for state the upsert's own guard
#      counts as done prints the same line forever, and that rule grades it a
#      blocker.
#
# guarantee:
#   - READ-ONLY
#
# exit:
#   0 = the tier's declared halves are present, and no undeclared listener is up
#   1 = a declared half is absent, or a laptop is listening; which one is named
######################################################################

grove_provision_2_3_ssh_provision_verify() {
  local failed=0

  ####################################################################
  # 1. the client — every tier needs it
  ####################################################################
  if command -v ssh >/dev/null 2>&1; then
    echo "   • ssh client on PATH ✔"
  else
    echo "   ✋ the ssh CLIENT is not on PATH" >&2
    echo "      ⇒ every git remote over ssh and every box-to-box hop fails" >&2
    failed=$(( failed + 1 ))
  fi

  ####################################################################
  # 2. the daemon BINARY — a grove must hold it; a laptop is asked for none
  ####################################################################
  if [[ "$GROVE_ENV_SERVER" == cloud@* ]]; then
    # sshd is not on a normal PATH, so it is looked up where debian puts it
    if [[ -x /usr/sbin/sshd ]] || command -v sshd >/dev/null 2>&1; then
      echo "   • ssh daemon binary present ✔"
    else
      echo "   ✋ the ssh DAEMON binary is absent" >&2
      echo "      ⇒ 'ssh' is a metapackage, so a partial install lands the client" >&2
      echo "        and drops the server — a box that can reach out but that no" >&2
      echo "        duct can reach. invisible from a laptop, fatal on a grove" >&2
      echo "      fix: rhx grove.provision --what 2.3.ssh --mode apply" >&2
      echo "        (or directly: sudo apt-get install openssh-server)" >&2
      failed=$(( failed + 1 ))
    fi
  else
    echo "   • daemon binary not claimed on $GROVE_ENV_SERVER 🌙"
    echo "      ⇒ this tier asks for openssh-client only; a listener is the defect"
  fi

  ####################################################################
  # 3. 🛑 a LAPTOP must run NO sshd — the rung the old header only asserted
  #
  # ⚠️ .why `is-enabled` AND `is-active`, and why neither alone suffices
  #      `is-active` alone misses a daemon that is down now and comes up at the
  #      next boot. `is-enabled` alone misses one started by hand this session.
  #      the claim is *no listener, ever*, so both are asked.
  #
  # ⚠️ .why no `ss` here
  #      a port scan needs root to name the owner, and this phase is READ-ONLY
  #      and un-privileged by contract. the unit state is the DECLARED fact and
  #      is readable by any user; the socket is the live one. a human who wants
  #      the live read runs the `ss` line the fix text prints.
  ####################################################################
  if [[ "$GROVE_ENV_SERVER" != cloud@* ]]; then
    if ! command -v systemctl >/dev/null 2>&1; then
      echo "   • sshd unit state unread — no systemctl on this box 🌙"
    else
      local unit_state unit_active
      unit_state="$(systemctl is-enabled ssh 2>/dev/null || true)"
      unit_active="$(systemctl is-active ssh 2>/dev/null || true)"

      # ⚠️ the bar is MASKED, not merely "not enabled". a unit that is disabled
      #    and not present still returns the moment an apt install restores
      #    openssh-server, and its postinst re-enables it. masked is the only
      #    state apt cannot walk over, so masked is what the upsert converges
      #    to and masked is what this rung demands
      if [[ "$unit_state" == "masked" && "$unit_active" != "active" ]]; then
        echo "   • sshd masked — this grove serves no ssh ✔"
      else
        echo "   ✋ this local grove does not have ssh masked, and it declares no" >&2
        echo "      inbound ssh at all" >&2
        echo "      ⇒ tier: $GROVE_ENV_SERVER" >&2
        echo "      ⇒ ssh.service is-enabled=${unit_state:-<absent>} is-active=${unit_active:-<absent>}" >&2
        echo "      ⇒ this repo writes no sshd_config, so a live daemon runs under" >&2
        echo "        the stock one — PasswordAuthentication at its compiled" >&2
        echo "        default of yes — and this tree declares no host firewall." >&2
        echo "        so it is an inbound auth surface on every network this box joins" >&2
        echo "      ⇒ and an unmasked-but-absent unit is not safe either: the next" >&2
        echo "        apt install that restores openssh-server re-enables it" >&2
        echo "      read the live socket:" >&2
        echo "        ss -tlnp | grep ':22 '" >&2
        echo "      fix: rhx grove.provision --what 2.3.ssh --mode apply" >&2
        echo "        (its provision.upsert stops, disables, and masks the unit)" >&2
        echo "      ⚠️ if this box is one you DELIBERATELY reach over ssh, that" >&2
        echo "        intent belongs in the repo — declare it, do not silence" >&2
        echo "        this rung (rule.forbid.exemption-as-habit)" >&2
        failed=$(( failed + 1 ))
      fi
    fi
  fi

  [[ "$failed" -eq 0 ]] || return 1
}
