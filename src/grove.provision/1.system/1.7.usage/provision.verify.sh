#!/usr/bin/env bash
######################################################################
# .what = prove each command is on PATH, matches THIS checkout, and can RUN
#
# ⚠️ .why the run probe, and not just presence + content
#   - both scripts read `/proc`, `free`, `ps`, `top`, and `sensors`
#   - the snapshot runs under `set -euo pipefail`
#   - ⇒ ONE absent tool aborts it partway and its file is a truncated capture
#   - a human who diagnoses a slow box then reasons from a snapshot that stops early
#   - ⇒ the claim is "the capacity exists", never "the bytes arrived"
#
# ⚠️ .why the probe is BOUNDED, and reads --stdout
#   - bare, `machine_usage_snapshot` WRITES into `~/.cache/machine.usage.snapshots/`
#   - ⇒ a verify that ran it bare would MUTATE state, which this phase forbids
#   - `--stdout` keeps it read-only
#   - `timeout` keeps a stalled `top` or `sensors` from a hang of the whole run
#   - (rule.require.bounded-probes-in-verifies)
#
# guarantee:
#   - READ-ONLY. it observes; it mutates no state
#   - BOUNDED. every probe is wrapped in `timeout`
######################################################################

grove_provision_1_7_usage_provision_verify() {
  local failed=0

  ####################################################################
  # 0. the tools the payloads READ the box with
  #
  # 🛑 assert the tools DIRECTLY — present, matches, and runs all miss them
  #   - 📜 all three held on a box where `iostat` and `sensors` were absent
  #   - the bundle reported ✔ while two snapshot sections printed no number at all
  #
  # ⚠️ the run-probe below CANNOT catch it
  #   - the payload guards both readers with `command -v`
  #   - ⇒ their absence is DEGRADATION, never a failure
  #   - a probe that asks "did it exit 0" is blind to a gracefully absent tool
  #   - (`rule.forbid.failhide`: the capability is gone and the check is green)
  ####################################################################
  local tool pkg absent_tools=()
  for tool in iostat:sysstat sensors:lm-sensors; do
    pkg="${tool#*:}"
    command -v "${tool%%:*}" >/dev/null 2>&1 || absent_tools+=("${tool%%:*} ($pkg)")
  done

  if [[ ${#absent_tools[@]} -eq 0 ]]; then
    echo "   • iostat + sensors on PATH, so no snapshot section reads empty ✔"
  else
    echo "   ✋ the snapshot cannot read: ${absent_tools[*]}" >&2
    echo "      ⇒ both are GUARDED in the payload, so it still exits 0 — the" >&2
    echo "        sections simply print no number, forever, on every capture" >&2
    echo "      ⇒ disk i/o is the evidence for a swap-thrash, which is the very" >&2
    echo "        event the snapshot exists to explain" >&2
    echo "      fix: rhx grove.provision --what 1.7.usage --mode apply" >&2
    failed=1
  fi

  ####################################################################
  # 1 + 2. each is on the box, and matches this checkout
  #
  # ⚠️ `bundle.bin.at`, never `bundle.bin.of`
  #   - this bundle's own upsert wrote both into `~/.local/bin` moments ago
  #   - this process's `$PATH` was captured before they existed
  #   - see `bundle.bin.at`'s header
  ####################################################################
  local name
  for name in \
    machine_resource_observe \
    machine_usage_snapshot
  do
    local bin
    bin="$(bundle.bin.at "$name")"
    local src="$GROVE_SRC/machine/$name"

    if [[ -z "$bin" ]]; then
      echo "   ✋ $name is absent from this box" >&2
      echo "      looked at: \$HOME/.local/bin/$name, then \$PATH" >&2
      echo "      ⇒ its alias in bash_aliases.sh still resolves, so a human sees" >&2
      echo "        'command not found' and reads it as their own typo" >&2
      echo "      fix: rhx grove.provision --what 1.7.usage --mode apply" >&2
      failed=1
      continue
    fi

    if [[ ! -f "$src" ]]; then
      echo "   🌙 $name is installed, but this checkout holds no $src"
      echo "      to compare it against"
      continue
    fi

    if diff -q "$src" "$bin" >/dev/null 2>&1; then
      echo "   • $name matches this checkout ✔"
    else
      echo "   ✋ the installed $name DIFFERS from this checkout" >&2
      echo "      read the drift: diff $src $bin" >&2
      echo "      fix: rhx grove.provision --what 1.7.usage --mode apply" >&2
      failed=1
    fi
  done

  ####################################################################
  # 3. each RUNS — the header says why a truncated capture reads as a complete one
  ####################################################################
  local observe_bin
  observe_bin="$(bundle.bin.at machine_resource_observe)"
  if [[ -n "$observe_bin" ]]; then
    if timeout -k 5 20 "$observe_bin" </dev/null >/dev/null 2>&1; then
      echo "   • machine_resource_observe runs clean ✔"
    else
      echo "   ✋ machine_resource_observe did not exit 0" >&2
      echo "      ⇒ it prints a partial read and a human trusts the gaps" >&2
      echo "      read why: machine_resource_observe" >&2
      failed=1
    fi
  fi

  # ⚠️ --stdout, so the probe writes NO snapshot file (see the header)
  #
  # ⚠️ .why the exit CODE and the stderr are captured, not thrown away
  #   - a bare "did not exit 0" sends a reader to re-run the command by hand
  #   - this failure does NOT reproduce by hand
  #   - it depends on the driver's own process tree at the moment of the probe
  #   - ⇒ an error unreproducible from its own fix line names no fix
  #   - (rule.require.errors-name-the-fix)
  local snapshot_bin
  snapshot_bin="$(bundle.bin.at machine_usage_snapshot)"
  if [[ -n "$snapshot_bin" ]]; then
    local snap_err
    snap_err="$(timeout -k 10 30 "$snapshot_bin" --stdout </dev/null 2>&1 >/dev/null)"
    local snap_code=$?

    if [[ "$snap_code" -eq 0 ]]; then
      echo "   • machine_usage_snapshot runs clean ✔"
    else
      echo "   ✋ machine_usage_snapshot exited $snap_code" >&2
      echo "      ⇒ under \`set -euo pipefail\` it aborts at the first command" >&2
      echo "        that fails, so the capture stops partway and READS as" >&2
      echo "        complete — a human then reasons from a truncated snapshot" >&2
      [[ -n "$snap_err" ]] && echo "      it said: $(echo "$snap_err" | tail -3)" >&2
      echo "      read why: machine_usage_snapshot --stdout" >&2
      failed=1
    fi
  fi

  return $failed
}
