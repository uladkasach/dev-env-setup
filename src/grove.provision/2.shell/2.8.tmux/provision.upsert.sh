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
# .note = tpm AND the plugin are pinned to a sha, each declared in `_.sh`
#   - tpm's tip is shell code `~/.tmux.conf` runs on every session
#   - and tpm sources each `@plugin`'s own `.tmux` file at that same load
#   - ⇒ an unpinned clone of either is code execution nobody vouched for
######################################################################

######################################################################
# .what = put the pinned tmux release at `/usr/local/bin/tmux`, from source
#
# .why from SOURCE
#   - tmux publishes no linux binary; its release IS a source tarball
#   - the build needs a compiler and three more packages, each one `pkg_install`
#
# 🛑 .why the swap is a RENAME, never a write in place
#   - live crew servers run from this path. a write into a busy binary fails
#     with ETXTBSY, and a truncate under a live process can kill it
#   - `mv` over the path gives the NEW inode to new execs and leaves each live
#     server on the inode it already holds (.refs = 1.vision case 3)
#
# ⚠️ .why every failure leaves the PRIOR tmux untouched
#   - the bytes are verified before extract, the build happens in a temp dir,
#     and the rename is the last step
#   - ⇒ a mismatch or a failed build is a ✋ that names the cause, over a box
#     whose crews still reach the tmux they had (.refs = 1.vision cases 7, 8)
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

  # 2. a seat with no root declines; ground converges it (case 16)
  bundle.root.owns "the pinned tmux build at $dst" \
    "tmux on PATH: ${ver:-absent} ${bin:+($bin)}, want $GROVE_UPGRADE_2_8_TMUX_VERSION" \
    || return 0

  # 3. the toolchain, the verified tarball, the build, the swap — each ✋ leaves the prior tmux
  grove_provision_2_8_tmux_pin_toolchain || return 1

  local tmp_dir; tmp_dir="$(web_tempdir tmux)" || {
    echo "   ✋ ConstraintError: no temp dir for the tmux build" >&2
    echo "      ⇒ the prior tmux is untouched; no crew lost its server" >&2
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
}

# .what = the toolchain the build needs — each one an ordinary apt package
# .note = no yacc: a release tarball ships its parser pre-generated; only a git
#   checkout needs one (homebrew's stable formula carries none either)
grove_provision_2_8_tmux_pin_toolchain() {
  pkg_install build-essential pkg-config libevent-dev libncurses-dev && return 0
  echo "   ✋ ConstraintError: the tmux build toolchain did not install" >&2
  echo "      ⇒ the prior tmux is untouched; no crew lost its server" >&2
  echo "      read why: sudo apt-get install build-essential pkg-config libevent-dev libncurses-dev" >&2
  return 1
}

# .what = fetch the pinned tarball, and verify it BEFORE any byte reaches a compiler
grove_provision_2_8_tmux_pin_fetch() {
  local tarball="$2"
  if ! web_fetch "$GROVE_UPGRADE_2_8_TMUX_URL" --into "$tarball"; then
    echo "   ✋ ConstraintError: could not fetch tmux $GROVE_UPGRADE_2_8_TMUX_VERSION" >&2
    echo "      ⇒ the prior tmux is untouched; no crew lost its server" >&2
    echo "      read why: $GROVE_UPGRADE_2_8_TMUX_URL" >&2
    return 1
  fi
  web_verify_sha256 --file "$tarball" --sha256 "$GROVE_UPGRADE_2_8_TMUX_SHA256" && return 0
  echo "   ✋ ConstraintError: the tmux tarball did NOT match its declared digest" >&2
  echo "      ⇒ the bytes are discarded unbuilt; the prior tmux is untouched" >&2
  echo "      ⇒ either the transfer corrupted, or the release was re-uploaded" >&2
  echo "      read why: rhx play.run --play prove.tmux-tarball-matches-the-pin" >&2
  echo "           a green there means the transfer corrupted — re-run the apply;" >&2
  echo "           a red means the release moved — re-pin from a second party (see _.sh)" >&2
  return 1
}

# .what = build tmux from a verified tarball, into `<dir>/tmux-<version>/tmux`
# .why the log outlives the temp dir — a compiler error is the one fact a ✋
#   here must hand over
grove_provision_2_8_tmux_pin_build() {
  local tarball="$2" into="$4"
  local log_dir="$HOME/.local/state/grove.provision"
  local log="$log_dir/2.8.tmux.build.log"
  mkdir -p "$log_dir" || {
    echo "   ✋ ConstraintError: no dir for the tmux build log at $log_dir" >&2
    echo "      ⇒ the prior tmux is untouched; no crew lost its server" >&2
    echo "      read why: ls -ld \"$(dirname "$log_dir")\"" >&2
    return 1
  }

  local src="$into/tmux-$GROVE_UPGRADE_2_8_TMUX_VERSION"
  { tar -xzf "$tarball" -C "$into" \
      && ( cd "$src" && ./configure --prefix=/usr/local && make -j"$(nproc)" ); } \
    >"$log" 2>&1 && return 0
  echo "   ✋ ConstraintError: tmux $GROVE_UPGRADE_2_8_TMUX_VERSION did not build" >&2
  echo "      ⇒ the prior tmux is untouched; no crew lost its server" >&2
  echo "      read why: tail -40 $log" >&2
  return 1
}

# .what = place a built binary at `<dst>`: install beside it, then rename over it
# .why a rename, never a write in place (see the header: ETXTBSY); the same
#   stage-then-rename `1.10.hosts` uses for `/etc/hosts`
grove_provision_2_8_tmux_pin_install() {
  local from="$2" dst="$4"
  local stage="$dst.grove-provision.new"
  sudo install -m 0755 -o root -g root "$from" "$stage" && sudo mv -f "$stage" "$dst" && return 0
  sudo rm -f "$stage" 2>/dev/null
  echo "   ✋ ConstraintError: the built tmux could not be placed at $dst" >&2
  echo "      read why: ls -l $(dirname "$dst")" >&2
  return 1
}

grove_provision_2_8_tmux_provision_upsert() {
  ####################################################################
  # 1a. on a GROVE, the pinned build — the distro 3.2a segfaults (see `_.sh`)
  ####################################################################
  if [[ "${GROVE_ENV_SERVER:-}" == cloud@* ]]; then
    grove_provision_2_8_tmux_pin_upsert || return 1
  fi

  ####################################################################
  # 1b. elsewhere, the distro package — on a laptop it IS the tmux
  #
  # ⚠️ .why a grove does NOT also take the distro package
  #   - it would be a fallback no crew reaches, since `/usr/local/bin` leads PATH
  #   - and a fallback to the build that segfaults is a hazard, never a safety:
  #     any caller that names `/usr/bin/tmux` would get 3.2a
  #   - an extant grove keeps the package it already has; a fresh one never gets it
  ####################################################################
  if [[ "${GROVE_ENV_SERVER:-}" != cloud@* ]] && ! pkg_install tmux; then
    echo "   ✋ ConstraintError: tmux did not install" >&2
    echo "      ⇒ a duct IS tmux: ductwork.sh opens a session, sends to a pane," >&2
    echo "        and reads its output. so on a grove this failure means the box" >&2
    echo "        cannot be reached at all, and on a laptop every termwork skill" >&2
    echo "        fails" >&2
    echo "      read why: sudo apt-get install tmux" >&2
    return 1
  fi

  ####################################################################
  # 2. tpm, then its plugins — two steps, so a tpm already at its pin never
  #    skips the plugin pins below it
  ####################################################################
  grove_provision_2_8_tmux_tpm_upsert || return 1
  grove_provision_2_8_tmux_plugins_upsert || return 1
}

# .what = tpm at the exact path `~/.tmux.conf` names in its `run` line, at its pin
grove_provision_2_8_tmux_tpm_upsert() {
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
grove_provision_2_8_tmux_plugins_upsert() {
  ####################################################################
  # 🛑 now the PLUGINS, at their own declared commits
  #   - left alone, `tpm/bin/install_plugins` clones each `@plugin` at default-branch tip
  #   - ⇒ that is the exact defect the pin above removes, one layer down
  #   - these clone first, so tpm finds them present and does no fetch of its own
  #   - ⚠️ the set lives in `_.sh` (`..._plugin_names`), beside the conf it must
  #     match: conf-only means tpm fetches a plugin UNPINNED, and clone-only means
  #     a dir nobody loads (`rule.require.one-command-provision`: one set, two readers)
  ####################################################################
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

    # .`half` and `adrift` both need the dir GONE before git_clone can write it
    #   - move aside rather than delete, since a human may want to read what was there
    #   - a `rm -rf` under $HOME on a guess is not this bundle's to make
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
