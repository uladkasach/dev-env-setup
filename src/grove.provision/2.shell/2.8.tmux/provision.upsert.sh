#!/usr/bin/env bash
######################################################################
# .what = make tmux and its plugin manager EXIST on this machine
#
# .why a grove builds the PINNED tmux, a laptop takes the distro one
#   - the distro 3.2a server segfaults; one crash ends every crew (see `_.sh`)
#
# .why tpm is a `git clone`, not a package
#   - tpm ships no debian package; its documented install IS a clone into
#     `~/.tmux/plugins/tpm`, the path `~/.tmux.conf` names in its `run` line
#
# 🛑 every guard reads a STATE, never a dir
#   - a `-d` guard counted a killed clone as done, and let a tpm at the wrong
#     commit stand (2026-08-14); the state readers live in `_.sh`
#
# guarantee:
#   - idempotent: tmux, tpm, and each plugin at its pin are left alone
#   - self-repair: any other state is moved aside and re-cloned; no human `rm -rf`
#   - every pin failure leaves the PRIOR tmux untouched (1.vision cases 7, 8)
#
# .note = tpm AND each plugin are pinned to a sha in `_.sh`: tpm's code and each
#   plugin's `.tmux` file run at every session load, so an unpinned clone is code
#   execution nobody vouched for
######################################################################

######################################################################
# .what = put the pinned tmux release at `/usr/local/bin/tmux`, from source
#
# .why from SOURCE: tmux publishes no linux binary; its release IS a source tarball
# 🛑 .why a RENAME swap: a live crew server keeps the inode it holds (1.vision case 3)
#
# guarantee:
#   - idempotent: a PATH tmux at the pin short-circuits, whoever built it
#   - a seat with no root DECLINES; the verify still ✋s on an adrift box
######################################################################
grove_provision_2_8_tmux_pin_upsert() {
  local ver bin dst
  ver="$(grove_provision_2_8_tmux_binary_version)"
  bin="$(grove_provision_2_8_tmux_binary_path)"
  dst="$(grove_provision_2_8_tmux_pin_dst)"

  # 1. converged already? a keepalive build of the pin counts (case 4)
  if [[ "$(grove_provision_2_8_tmux_binary_state)" == pinned ]]; then
    echo "   • tmux $ver already at the pin ($bin)"
    return 0
  fi

  # 1b. the pin is placed but PATH answers another tmux first: a ✋, never an endless rebuild
  if grove_provision_2_8_tmux_pin_is_shadowed; then
    grove_provision_2_8_tmux_pin_shadow_refusal "$bin" "$dst"
    return 1
  fi

  # 2. a seat with no root declines; ground converges it (case 16)
  bundle.root.owns "the pinned tmux build at $dst" \
    "tmux on PATH: ${ver:-absent} ${bin:+($bin)}, want $GROVE_UPGRADE_2_8_TMUX_VERSION" \
    || return 0

  # 3. the toolchain, the verified tarball, the build, the swap — each ✋ leaves the prior tmux
  grove_provision_2_8_tmux_pin_toolchain || return 1

  local tmp_dir; tmp_dir="$(web_tempdir tmux)" || {
    echo "   ✋ ConstraintError: no temp dir for the tmux build" >&2
    grove_provision_2_8_tmux_refusal_note >&2
    echo "      read why: df -h \"\${TMPDIR:-/tmp}\"" >&2
    return 1
  }
  local tarball="$tmp_dir/tmux-$GROVE_UPGRADE_2_8_TMUX_VERSION.tar.gz"
  grove_provision_2_8_tmux_pin_fetch --into "$tarball" \
    && grove_provision_2_8_tmux_pin_build --tarball "$tarball" --into "$tmp_dir" \
    && grove_provision_2_8_tmux_pin_install --from "$tmp_dir/tmux-$GROVE_UPGRADE_2_8_TMUX_VERSION/tmux" --into "$dst"
  local rc=$?
  rm -rf "$tmp_dir"
  [[ "$rc" -eq 0 ]] || return 1

  hash -r 2>/dev/null
  echo "   • tmux $GROVE_UPGRADE_2_8_TMUX_VERSION built → $dst"
  echo "     prior: ${ver:-absent} ${bin:+($bin)}; live servers keep the build they started on"
  echo "     ⇒ that holds for EVERY seat's servers, and this seat's plan sees its own only:"
  echo "       a crew seat's servers stay on the prior build until they end, and the crew"
  echo "       seat's own plan names them (rhx grove.provision --what 2.8.tmux)"

  # the swap is proven by what PATH now answers, never assumed
  if grove_provision_2_8_tmux_pin_is_shadowed; then
    grove_provision_2_8_tmux_pin_shadow_refusal "$(grove_provision_2_8_tmux_binary_path)" "$dst"
    return 1
  fi
}

grove_provision_2_8_tmux_provision_upsert() {
  # 1a. on a grove, the pinned build; one reader decides what this tier owes
  local owed; owed="$(grove_provision_2_8_tmux_binary_owed)"
  if [[ "$owed" == pinned ]]; then
    grove_provision_2_8_tmux_pin_upsert || { grove_provision_2_8_tmux_pin_floor; return 1; }
  fi

  # 1b. elsewhere, the distro package. ⚠️ never ALSO on a grove: a caller that names
  #     `/usr/bin/tmux` would get the 3.2a that segfaults (the one exception: `_pin_floor`)
  if [[ "$owed" != pinned ]] && ! pkg_install tmux; then
    echo "   ✋ ConstraintError: tmux did not install" >&2
    echo "      ⇒ a duct IS tmux: ductwork.sh opens a session, sends to a pane," >&2
    echo "        and reads its output. so on a grove this failure means the box" >&2
    echo "        cannot be reached at all, and on a laptop every termwork skill" >&2
    echo "        fails" >&2
    echo "      read why: sudo apt-get install tmux" >&2
    return 1
  fi

  # 2. tpm, then its plugins — two steps, so a tpm at its pin never skips the plugin pins
  grove_provision_2_8_tmux_tpm_upsert || return 1
  grove_provision_2_8_tmux_plugins_upsert || return 1
}

# .what = tpm at the exact path `~/.tmux.conf` names in its `run` line, at its pin
grove_provision_2_8_tmux_tpm_upsert() {
  local tpm_dir="$HOME/.tmux/plugins/tpm"

  # the question is "is this tpm USABLE and at the DECLARED commit", never "is there a dir"
  local state; state="$(grove_provision_2_8_tmux_tpm_state "$tpm_dir")"
  if [[ "$state" == whole ]]; then
    echo "   • tpm already at the declared commit ($tpm_dir)"
    return 0
  fi

  # git is THIS bundle's dependency: `--what 2.8.tmux` alone must converge a fresh box
  #   (`rule.require.bundles-own-their-dependencies`), and an install is shorter than a pointer
  if ! command -v git >/dev/null 2>&1; then
    pkg_install git || return 1
    echo "   • git installed — this box shipped without it"
  fi

  # the path holds what this bundle cannot use: MOVE it aside, never delete — an `adrift`
  #   tpm may hold a human's edits. one branch serves `half` and `adrift` alike
  #   (`rule.require.fewer-paths-via-idempotency`)
  if [[ "$state" != absent ]]; then
    local aside="$tpm_dir.aside.$(date +%Y%m%dT%H%M%S)"
    if ! mv "$tpm_dir" "$aside"; then
      echo "   ✋ ConstraintError: $tpm_dir holds a tpm this bundle cannot use ($state), and the" >&2
      echo "      dir could not be moved aside" >&2
      echo "      ⇒ the path is named in ~/.tmux.conf's 'run' line, so a clone" >&2
      echo "        cannot land anywhere else" >&2
      echo "      read why: ls -ld $tpm_dir ; touch $tpm_dir/.probe" >&2
      return 1
    fi
    echo "   • tpm was '$state'; moved aside, re-clone follows"
    echo "     kept at: $aside"
  fi

  # the pin is declared in `_.sh`, where the state reader also reads it
  if ! git_clone https://github.com/tmux-plugins/tpm "$tpm_dir" \
       --at "$GROVE_UPGRADE_2_8_TMUX_TPM_AT"; then
    echo "   ✋ ConstraintError: could not clone tpm to $tpm_dir" >&2
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
}

# .what = each tpm plugin at its own declared commit
# 🛑 left alone, tpm clones each `@plugin` at default-branch tip — the defect the tpm pin
#   removes, one layer down. these clone first, so tpm finds them present and fetches naught.
#   the set lives in `_.sh` beside the conf it must match: one set, two readers
grove_provision_2_8_tmux_plugins_upsert() {
  local plug_name plug_url plug_at plug_dir plug_state plug_aside
  while read -r plug_name; do
    [[ -n "$plug_name" ]] || continue
    plug_url="$(grove_provision_2_8_tmux_plugin_url "$plug_name")"
    plug_at="$(grove_provision_2_8_tmux_plugin_at "$plug_name")"
    plug_dir="$HOME/.tmux/plugins/$plug_name"

    plug_state="$(grove_provision_2_8_tmux_plugin_state "$plug_dir" "$plug_at")"
    if [[ "$plug_state" == whole ]]; then
      echo "   • $plug_name already at the declared commit"
      continue
    fi

    # `half` and `adrift` both need the dir gone first; move aside, as tpm above
    if [[ "$plug_state" != absent ]]; then
      plug_aside="$plug_dir.aside.$(date -u +%Y%m%dT%H%M%SZ)"
      if ! mv "$plug_dir" "$plug_aside"; then
        echo "   ✋ ConstraintError: $plug_name is '$plug_state' and could not be moved aside" >&2
        echo "      ⇒ wanted: $plug_dir -> $plug_aside" >&2
        return 1
      fi
      echo "   • $plug_name was '$plug_state'; moved aside, re-clone follows"
      echo "     kept at: $plug_aside"
    fi

    if ! git_clone "$plug_url" "$plug_dir" --at "$plug_at" </dev/null; then
      echo "   ✋ ConstraintError: could not clone $plug_name to $plug_dir" >&2
      echo "      ⇒ tmux.conf names it as a tpm '@plugin', so tpm would fetch it" >&2
      echo "        at default-branch tip instead — which is the unpinned clone" >&2
      echo "        this step exists to prevent. do NOT let tpm cover for it" >&2
      echo "      ⇒ git_clone named the fault above and removed the partial dir" >&2
      return 1
    fi

    echo "   • $plug_name installed at the declared commit"
  done < <(grove_provision_2_8_tmux_plugin_names)
}
