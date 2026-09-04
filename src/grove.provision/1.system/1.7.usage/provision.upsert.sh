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
    machine_usage_snapshot
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

  # ⚠️ the tool result is folded in HERE, at the end, never returned early above
  #   - ⇒ a box that cannot install sysstat still gets both payloads copied
  #   - the copy is what a seat owes its own $HOME, whatever the box-wide half did
  (( failed_tools )) && failed=1
  return $failed
}
