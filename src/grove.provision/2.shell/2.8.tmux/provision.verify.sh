#!/usr/bin/env bash
######################################################################
# .what = prove tmux is present, and that the path the conf runs holds a tpm at
#         the commit this repo declares
#
# .why tpm is checked by its ENTRYPOINT and not by its dir
#   - a dir can exist and be empty, which is exactly what a cut clone leaves
#   - `~/.tmux.conf` runs `tpm/tpm`
#   - ⇒ the entrypoint is the file that matters
#   - its absence is what makes tmux print a run-shell error
#
# 🛑 this file cuts that set with NO inline test of its own
#   - an `[[ -x "$tpm_bin" ]]` here beside a `[[ -d "$tpm_dir" ]]` there is two readers
#   - the fix such a verify names is `rm -rf ~/.tmux/plugins/tpm`
#   - ⇒ a HAND STEP no grove can take (`rule.require.solve-at-cause`)
#   - both halves ask `grove_provision_2_8_tmux_tpm_state`, declared once in `_.sh`
#   - ⇒ the upsert SEES what this half sees, moves it aside, and re-clones
#
# ⚠️ the COMMIT is a claim this file makes
#   - `-x` cannot see a sha
#   - ⇒ under it, a tpm at some other commit reports ✔ on every apply
#   - that defeats the pin's own stated purpose
#
# guarantee:
#   - READ-ONLY. it observes; it mutates no state
#
# exit:
#   0 = tmux present, and the conf's tpm path holds a checkout at the pin
#   1 = a claim failed, and which is named
######################################################################

grove_provision_2_8_tmux_provision_verify() {
  local failed=0

  if command -v tmux >/dev/null 2>&1; then
    echo "   • tmux present ($(tmux -V 2>/dev/null | awk '{print $2}')) ✔"
  else
    echo "   ✋ tmux is not on PATH" >&2
    echo "      ⇒ a duct IS tmux, so this box cannot be reached over a duct and" >&2
    echo "        every termwork skill fails" >&2
    echo "      fix: rhx grove.provision --what 2.8.tmux --mode apply" >&2
    failed=$(( failed + 1 ))
  fi

  ####################################################################
  # ⚠️ the entrypoint path is READ FROM THE CONF, never restated here
  #   - a `local tpm_bin=…` is a second copy of a path the conf already declares
  #   - ⇒ edit the conf and such a check still asks about the stale path
  #   - green while every tmux session prints a run-shell error, or red while tmux is happy
  #   - that is `rule.require.seam-claims-have-an-owner` from the derive side
  #   - the fallback is tpm's historical default, used only when the conf names no run line
  ####################################################################
  local conf_live="$HOME/.tmux.conf"
  local tpm_bin=""
  if [[ -f "$conf_live" ]]; then
    tpm_bin="$(grep -oE "run(-shell)? +'[^']*tpm/tpm'" "$conf_live" 2>/dev/null \
      | head -1 | grep -oE "'[^']*'" | tr -d "'")"
    tpm_bin="${tpm_bin/#\~/$HOME}"
  fi
  [[ -n "$tpm_bin" ]] || tpm_bin="$HOME/.tmux/plugins/tpm/tpm"

  ####################################################################
  # ⚠️ the SHARED reader from `_.sh`, asked about the dir the conf's run line names
  #   - an inline `[[ -x "$tpm_bin" ]]` would be a second cut of the upsert's set
  #   - the two disagree on both inputs that matter
  #   - a clone killed mid-flight, and a tpm at some other commit
  #
  # .why the PATH comes from the conf and the STATE from the reader
  #   - they are two facts, not one
  #   - "which path does tmux run" is the conf's to declare
  #   - "is what sits there usable and at the declared commit" is this bundle's
  #   - ⇒ the reader answers the second about whatever the first names
  ####################################################################
  case "$(grove_provision_2_8_tmux_tpm_state "$(dirname "$tpm_bin")")" in
    whole)
      echo "   • tpm present at the declared commit ✔ ($tpm_bin)"
      ;;
    adrift)
      echo "   ✋ tpm is present but NOT at the commit this repo declares" >&2
      echo "      ⇒ tpm's tip is shell code ~/.tmux.conf RUNS on every session, so" >&2
      echo "        this box executes different code than a box at the pin — which" >&2
      echo "        is the deterministic clause of one-command provision" >&2
      echo "      ⇒ a -d guard cannot see a sha at all, so under one this goes" >&2
      echo "        unreported on every apply" >&2
      echo "      read why: cat $(dirname "$tpm_bin")/.git/HEAD" >&2
      echo "      fix: rhx grove.provision --what 2.8.tmux --mode apply" >&2
      echo "           its upsert moves the adrift tpm aside and re-clones it" >&2
      failed=$(( failed + 1 ))
      ;;
    *)
      echo "   ✋ no usable tpm at the path the conf runs ($tpm_bin)" >&2
      echo "      ⇒ tmux starts with no plugins and prints a run-shell error on" >&2
      echo "        every session — which reads as a broken conf, not an absent tool" >&2
      echo "      ⇒ a clone killed mid-flight leaves exactly this: a dir, a .git," >&2
      echo "        and no usable entrypoint" >&2
      echo "      fix: rhx grove.provision --what 2.8.tmux --mode apply" >&2
      echo "           its upsert moves the carcass aside and re-clones it, so no" >&2
      echo "           human owes an 'rm -rf'" >&2
      failed=$(( failed + 1 ))
      ;;
  esac

  [[ "$failed" -eq 0 ]] || return 1
}
