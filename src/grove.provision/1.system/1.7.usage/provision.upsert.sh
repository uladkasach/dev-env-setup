#!/usr/bin/env bash
######################################################################
# .what = install the two machine-usage commands into ~/.local/bin
#
# .why they are COPIED from `$GROVE_SRC/machine/`, not written from a heredoc
#   - a repo can only be the source of truth for content it can read back
#   - (rule.require.repo-as-source-of-truth)
#   - these two bodies are 400 lines of shell
#   - ⇒ as a quoted heredoc no editor lints them and no verify can COMPARE them
#
# guarantee:
#   - idempotent: each file is COPIED from the declared source, so a re-run rewrites bytes
#   - it applies EVERYWHERE — see this bundle's `_.sh`
######################################################################

######################################################################
# .what = the tools the two payloads READ the box with
#
# 🛑 this bundle OWNS its two readers — no other bundle installs them
#   - `machine_usage_snapshot` reports disk i/o through `iostat` and temperature through `sensors`
#   - with neither installed, both sections print `│ (iostat not available; install sysstat)`
#   - 📜 every box this repo converged did exactly that, so the snapshot never captured disk i/o
#
# ⚠️ the tell is in the payload's own output, which NAMES the package
#   - a bundle that knows its dependency, says so, and leaves the human to act explains, never fixes
#   - (`rule.forbid.deferred-provision-defects`)
#   - the line it prints is a one-off command where a bundle belongs
#   - (`rule.require.install-via-procedures`)
#
# ⚠️ .why the gap mattered most exactly when the tool did
#   - the snapshot exists to explain a box under load
#   - 📜 the worst load measured was a daemon leak that drove the box into disk-swap thrash
#   - that is a DISK I/O event, and disk i/o is the one section that never had a number
#   - ⇒ the tool was absent precisely where it was the evidence
#
# ⚠️ .why HERE and not `2.1.toolkit`
#   - the toolkit is section 2, so it runs AFTER this
#   - ⇒ a dependency that lands later than its consumer is an order defect
#   - (`rule.require.one-command-provision`), and its fix is never "apply it again"
#
# .note `lm-sensors` on a cloud grove reads no physical die
#   - it is installed anyway, since the payload falls back to `/sys/class/thermal`
#   - one composition on every server beats a branch that saves one small package
#   - (`rule.require.identical-bundle-composition`)
#
# ⚠️ .why a decline and not a failure
#   - the copy below needs NO root, so it is the one job this phase owes a camper seat
#   - ⇒ an apt call it cannot make must not turn a seat-local success into a ✋
######################################################################
grove_provision_1_7_usage_tools() {
  # what is ALREADY true — a dpkg read, free of privilege
  if pkg_present sysstat && pkg_present lm-sensors; then
    echo "   • sysstat + lm-sensors present, so iostat and sensors can answer ✔"
    return 0
  fi

  if ! pkg_can_sudo; then
    bundle.root.declines "the machine-read tools (sysstat, lm-sensors)" \
      "sysstat=$(pkg_present sysstat && echo present || echo absent), lm-sensors=$(pkg_present lm-sensors && echo present || echo absent)"
    return 0
  fi

  if ! pkg_install sysstat lm-sensors; then
    echo "   ✋ could not install sysstat and/or lm-sensors" >&2
    echo "      ⇒ the snapshot still runs — both readers are guarded — but its" >&2
    echo "        DISK I/O and TEMPERATURES sections stay empty on this box," >&2
    echo "        and a human who diagnoses a thrash reads a gap where the" >&2
    echo "        evidence should be" >&2
    echo "      read why: sudo apt-get install sysstat lm-sensors" >&2
    return 1
  fi
}

######################################################################
# .what = the recorder's two user units, and the timer armed
#
# .why  = a snapshot answers "how is it now"; only a record kept over time
#         answers "what has cost the most" — and a spawn storm, whose
#         children die in milliseconds, is visible to the record alone
#         (`machine_usage_record`'s header says how)
#
# .why a USER timer
#   - it reads the user's own processes, so it needs no root
#   - and it writes under the user's own `~/.local/state`
#
# ⚠️ .why `daemon-reload` before `enable --now`
#   - systemd caches unit files, so a rewrite with no reload leaves the OLD
#     definition live (the same reason `1.6.2.monitor` gives)
#
# .why a decline where `systemctl --user` cannot answer
#   - a box with no user manager has no scheduler to arm; the two commands
#     still install, and `machine_usage_record` still runs by hand
######################################################################
grove_provision_1_7_usage_recorder() {
  local unit_dir="$HOME/.config/systemd/user"
  if ! systemctl --user show-environment >/dev/null 2>&1; then
    echo "   🌙 the usage recorder timer is declined — no user manager answers here,"
    echo "      so there is no scheduler to arm; machine_usage_record still runs by hand"
    return 0
  fi

  mkdir -p "$unit_dir" || return 1
  local unit
  for unit in machine_usage_record.service machine_usage_record.timer; do
    if [[ ! -f "$GROVE_SRC/machine/$unit" ]]; then
      echo "   ✋ no $unit at $GROVE_SRC/machine/$unit" >&2
      return 1
    fi
    cp "$GROVE_SRC/machine/$unit" "$unit_dir/$unit" || return 1
  done

  systemctl --user daemon-reload || {
    echo "   ✋ systemctl --user daemon-reload failed" >&2
    echo "      ⇒ the unit files are on disk and the OLD definitions stay live" >&2
    return 1
  }
  if systemctl --user enable --now machine_usage_record.timer >/dev/null 2>&1; then
    echo "   • machine_usage_record.timer enabled — one sample a minute"
  else
    echo "   ✋ could not enable machine_usage_record.timer" >&2
    echo "      ⇒ no record is kept, so 'what made it slow' has only a moment's answer" >&2
    echo "      read why: systemctl --user status machine_usage_record.timer" >&2
    return 1
  fi
}

grove_provision_1_7_usage_provision_upsert() {
  local dst_dir="$HOME/.local/bin"
  mkdir -p "$dst_dir" || return 1

  # the tools first, so a payload copied below can actually read what it reports
  local failed_tools=0
  grove_provision_1_7_usage_tools || failed_tools=1

  local failed=0
  local name
  for name in \
    machine_resource_observe \
    machine_usage_snapshot \
    machine_usage_record \
    machine_usage_history
  do
    local src="$GROVE_SRC/machine/$name"
    if [[ ! -f "$src" ]]; then
      echo "   ✋ no $name at $src" >&2
      echo "      ⇒ this run's own checkout is incomplete, so the copy would" >&2
      echo "        leave whatever version was there before" >&2
      failed=1
      continue
    fi

    cp "$src" "$dst_dir/$name" || { failed=1; continue; }
    chmod +x "$dst_dir/$name" || { failed=1; continue; }
    echo "   • $name installed → $dst_dir/$name"
  done

  grove_provision_1_7_usage_recorder || failed=1

  # ⚠️ the tool result is folded in HERE, at the end, never returned early above
  #   - ⇒ a box that cannot install sysstat still gets both payloads copied
  #   - the copy is what a seat owes its own $HOME, whatever the box-wide half did
  (( failed_tools )) && failed=1
  return $failed
}
