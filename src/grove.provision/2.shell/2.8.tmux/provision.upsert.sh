#!/usr/bin/env bash
######################################################################
# .what = make tmux and its plugin manager EXIST on this machine
#
# .why tpm is fetched by `git clone` and not by a package
#   - tpm ships no debian package
#   - its documented install IS a clone into `~/.tmux/plugins/tpm`
#   - `~/.tmux.conf` names that exact path in its `run` line
#   - ⇒ the path is part of the contract, not a choice
#
# .why the clone is GUARDED and not re-run
#   - `git clone` into a populated dir fails on "already exists and is not empty"
#   - with no guard, every re-run prints that error and, with no `set -e`, carries on
#   - ⇒ the phase reports a failure it had already satisfied
#   - (rule.require.idempotent-install-procedures)
#
# 🛑 the guard reads a STATE, not a dir
#   - 📜 2026-08-14: a `[[ -d "$tpm_dir" ]]` is a presence test over a multi-step artifact
#   - two inputs walk straight through it
#   - a clone killed mid-flight, and a tpm at the wrong commit
#   - ⇒ the second makes the pin below enforceable by nobody
#   - both halves ask `grove_provision_2_8_tmux_tpm_state`, declared once in `_.sh`
#
# guarantee:
#   - idempotent: a tpm at the declared commit is left alone, never re-cloned
#   - self-repair: any other state is moved aside and re-cloned
#   - ⇒ one apply converges it and no human owes an `rm -rf`
#
# .note = tpm AND both plugins are pinned to a sha, each declared in `_.sh`
#   - tpm's tip is shell code `~/.tmux.conf` runs on every session
#   - `@continuum-restore 'on'` runs the plugins' code unattended on every server start
#   - ⇒ an unpinned clone of any of the three is code execution nobody vouched for
######################################################################

grove_provision_2_8_tmux_provision_upsert() {
  ####################################################################
  # 1. the binary — a duct IS tmux, so this is the reachability of the box
  ####################################################################
  if ! pkg_install tmux; then
    echo "   ✋ tmux did not install" >&2
    echo "      ⇒ a duct IS tmux: ductwork.sh opens a session, sends to a pane," >&2
    echo "        and reads its output. so on a grove this failure means the box" >&2
    echo "        cannot be reached at all, and on a laptop every termwork skill" >&2
    echo "        fails" >&2
    echo "      read why: sudo apt-get install tmux" >&2
    return 1
  fi

  ####################################################################
  # 2. tpm — at the exact path `~/.tmux.conf` names in its `run` line
  ####################################################################
  local tpm_dir="$HOME/.tmux/plugins/tpm"

  ####################################################################
  # ⚠️ the question is "is this tpm USABLE and at the DECLARED commit"
  #   - never "is there a dir"
  #   - the shared reader lives in this bundle's `_.sh` and carries the measurement
  #   - 📜 a `-d` guard counted a killed clone as done
  #   - and it made the pin above enforceable by nobody
  ####################################################################
  local state; state="$(grove_provision_2_8_tmux_tpm_state "$tpm_dir")"

  if [[ "$state" == whole ]]; then
    echo "   • tpm already at the declared commit ($tpm_dir)"
    return 0
  fi

  ####################################################################
  # .a clone is tpm's documented install, so git is THIS bundle's dependency
  #
  # 🛑 a `fix: --what 2.2.git` pointer is the shape the rule forbids
  #   - (`rule.require.bundles-own-their-dependencies`)
  #   - `2.2.git` runs earlier, so such a pointer is at least reachable
  #   - ⇒ the rule's test is sharper: can `--what 2.8.tmux` ALONE converge on a fresh box?
  #   - with a pointer, it cannot
  #
  # ⚠️ git IS named in that rule's one exception, as a boundary the bootstrap owns
  #   - ⇒ an ASSERT here would not itself be the violation, but the fix-text would
  #   - git is an ordinary apt package `pkg_install` converges for free when present
  #   - ⇒ the install is the shorter fix and the one that makes this slug drivable alone
  ####################################################################
  if ! command -v git >/dev/null 2>&1; then
    pkg_install git || return 1
    echo "   • git installed — this box shipped without it"
  fi

  ####################################################################
  # .the path is OCCUPIED by what this bundle cannot use
  #   - a killed clone, a tpm at some other commit, or a dir a human filled
  #   - one move frees it, and `git_clone` needs no more than that
  #
  # 🛑 .why it is MOVED aside and not deleted
  #   - an `rm -rf ~/.tmux/plugins/tpm` as fix-text is a HAND STEP no grove can take
  #   - ⇒ the repair belongs here
  #   - unattended, irreversible, and under a human's `$HOME` is three reasons to rename
  #   - an `adrift` tpm may hold a human's own edits
  #   - a move costs one rename and converges the box just as well
  #
  # ⚠️ .why ONE branch serves both `half` and `adrift`
  #   - a fetch-then-recheckout is cheaper for `adrift`
  #   - it is a SECOND way to converge one state
  #   - its failure mode, a pin absent from a shallow local, needs this branch anyway
  #   - tpm is a few hundred kilobytes
  #   - ⇒ the single path is the honest cost (`rule.require.fewer-paths-via-idempotency`)
  ####################################################################
  if [[ "$state" != absent ]]; then
    local aside="$tpm_dir.aside.$(date +%Y%m%dT%H%M%S)"
    if ! mv "$tpm_dir" "$aside"; then
      echo "   ✋ $tpm_dir holds a tpm this bundle cannot use ($state), and the" >&2
      echo "      dir could not be moved aside" >&2
      echo "      ⇒ the path is named in ~/.tmux.conf's 'run' line, so a clone" >&2
      echo "        cannot land anywhere else" >&2
      echo "      read why: ls -ld $tpm_dir ; touch $tpm_dir/.probe" >&2
      return 1
    fi
    echo "   • tpm was '$state'; moved aside, re-clone follows"
    echo "     kept at: $aside"
  fi

  ####################################################################
  # .the pin is declared in this bundle's `_.sh`, where the state reader also reads it
  #
  # ⚠️ .why a pin at all, for a plugin manager
  #   - tpm's tip is shell code `~/.tmux.conf` RUNS on every session
  #   - ⇒ an unpinned clone means two boxes execute different code from one checkout
  #   - that breaks the deterministic clause of one-command provision
  #   - the state reader above gives that argument teeth
  #   - a presence guard cannot see a sha, so under one the pin binds nobody
  ####################################################################
  if ! git_clone https://github.com/tmux-plugins/tpm "$tpm_dir" \
       --at "$GROVE_UPGRADE_2_8_TMUX_TPM_AT"; then
    echo "   ✋ could not clone tpm to $tpm_dir" >&2
    echo "      ⇒ ~/.tmux.conf names that exact path in its 'run' line, so tmux" >&2
    echo "        will start with NO plugins and print a run-shell error on every" >&2
    echo "        session — which reads as a broken conf rather than an absent tool" >&2
    echo "      ⇒ the path is part of the contract; do not move it elsewhere" >&2
    echo "      ⇒ git_clone named the fault above, and it already removed the" >&2
    echo "        partial dir. a kill it cannot observe would leave one — and the" >&2
    echo "        guard above reads state rather than presence, so a re-run moves" >&2
    echo "        that carcass aside instead of a report of ✔ over it" >&2
    return 1
  fi

  echo "   • tpm installed at the declared commit ($tpm_dir)"

  ####################################################################
  # 🛑 now the PLUGINS, at their own declared commits
  #   - left alone, `tpm/bin/install_plugins` clones each `@plugin` at default-branch tip
  #   - ⇒ that is the exact defect the pin above removes, one layer down
  #   - these clone first, so tpm finds them present and does no fetch of its own
  #   - ⚠️ the dir NAME is the contract
  #   - tpm resolves `@plugin 'owner/name'` to `~/.tmux/plugins/<name>`
  #   - ⇒ these paths are not ours to choose
  ####################################################################
  local plug plug_name plug_url plug_at plug_dir plug_state plug_aside
  for plug in \
    "tmux-resurrect|https://github.com/tmux-plugins/tmux-resurrect|$GROVE_UPGRADE_2_8_TMUX_RESURRECT_AT" \
    "tmux-continuum|https://github.com/tmux-plugins/tmux-continuum|$GROVE_UPGRADE_2_8_TMUX_CONTINUUM_AT"
  do
    plug_name="${plug%%|*}"
    plug_url="${plug#*|}";  plug_url="${plug_url%%|*}"
    plug_at="${plug##*|}"
    plug_dir="$HOME/.tmux/plugins/$plug_name"

    plug_state="$(grove_provision_2_8_tmux_plugin_state "$plug_dir" "$plug_at")"
    if [[ "$plug_state" == whole ]]; then
      echo "   • $plug_name already at the declared commit"
      continue
    fi

    # .`half` and `adrift` both need the dir GONE before git_clone can write it
    #   - move aside rather than delete, since a human may want to read what was there
    #   - a `rm -rf` under $HOME on a guess is not this bundle's to make
    if [[ "$plug_state" != absent ]]; then
      plug_aside="$plug_dir.aside.$(date -u +%Y%m%dT%H%M%SZ)"
      if ! mv "$plug_dir" "$plug_aside"; then
        echo "   ✋ $plug_name is '$plug_state' and could not be moved aside" >&2
        echo "      ⇒ wanted: $plug_dir -> $plug_aside" >&2
        return 1
      fi
      echo "   • $plug_name was '$plug_state'; moved aside, re-clone follows"
      echo "     kept at: $plug_aside"
    fi

    if ! git_clone "$plug_url" "$plug_dir" --at "$plug_at"; then
      echo "   ✋ could not clone $plug_name to $plug_dir" >&2
      echo "      ⇒ tmux.conf names it as a tpm '@plugin', so tpm would fetch it" >&2
      echo "        at default-branch tip instead — which is the unpinned clone" >&2
      echo "        this step exists to prevent. do NOT let tpm cover for it" >&2
      echo "      ⇒ git_clone named the fault above and removed the partial dir" >&2
      return 1
    fi

    echo "   • $plug_name installed at the declared commit"
  done
}
