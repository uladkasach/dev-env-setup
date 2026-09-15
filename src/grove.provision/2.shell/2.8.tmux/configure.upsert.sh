#!/usr/bin/env bash
######################################################################
# .what = put this repo's tmux conf on the box, then install the plugins it names
#
# .why the plugin install runs on an ISOLATED tmux SERVER
#   - tpm's `install_plugins` reads the plugin list from a SERVER that loaded the conf
#   - it is not a standalone fetcher
#   - a conf is read at SERVER start, never at session creation
#   - ⇒ the install needs a server that started AFTER this phase wrote the conf
#   - on a grove the duct's server has always been up longer
#   - ⇒ write the conf, start an isolated server with `-f`, install, await, kill it
#   - 📜 the obvious `tmux new-session` form landed zero plugins on every grove
#
# .why an isolated SOCKET rather than a reserved session name
#   - on a grove the duct IS tmux, so this phase often runs INSIDE a tmux session
#   - ⇒ a `kill-session` here could tear down the channel this run speaks over
#   - a reserved name avoided that by convention, and a socket removes it by construction
#   - an isolated server shares no session namespace with the duct at all
#   - 📜 an interrupted run left `_tpm_init` alive and the next start read "duplicate session"
#   - ⇒ `kill-server` on a socket only this phase uses is unconditionally safe
#   - (rule.require.idempotent-install-procedures)
#
# .why the conf IS sourced into the live server
#   - 📜 grove-ahbode-v20260901, 2026-09-03, against three prior reasons to decline:
#   - 1. "a re-run of tpm re-inits a plugin's hooks" — REFUTED
#   - ⚠️ measured while the conf still carried continuum, which it no longer does;
#     the claim it settles is about TPM, so the plugin it used as a probe is
#     incidental and the refutation stands
#   - the conf ends in `run '~/.tmux/plugins/tpm/tpm'`, and then set `@continuum-restore on`
#   - a source does re-run tpm, and it does NOT stack
#   - after three sources, `status-right "#(…/continuum_save.sh) #{@branch} "` held ONE hook
#   - 2. "a conf that does not parse breaks the duct" — STALE
#   - the isolated server below runs `-f ~/.tmux.conf` and returns 1 on a bad conf
#   - ⇒ by this point the conf is PROVEN to parse, off the duct
#   - 3. `set -as` APPENDS — REAL, and the one cost that survives
#   - the feature list gains 3 entries per source within a server's life
#   - `[2..4] [5..7] [8..10]  xterm-kitty:extkeys/clipboard/RGB`
#   - it is COSMETIC, since tmux applies the same features either way
#   - ⇒ a list that grows is cheaper than a config that never reaches the live server
#
# ⚠️ the source is HALF the job, and the phase says so
#   - `terminal-features` is negotiated at CLIENT ATTACH, not at source
#   - 📜 RGB was asserted server-side and both clients still read `feats=…` with no RGB
#   - ⇒ the source lands the server options, and a REATTACH is what a live client needs
#   - the fix-text at the end names both
#   - a source reported as "done" would be `rule.forbid.failhide`
#
# guarantee:
#   - idempotent: one copy of one file
#   - idempotent: the throwaway server is killed before it is created and again after
######################################################################

grove_provision_2_8_tmux_configure_upsert() {
  ####################################################################
  # 1. the conf
  ####################################################################
  local conf_src="$GROVE_SRC/grove.provision/2.shell/2.8.tmux/tmux.conf"

  if [[ ! -f "$conf_src" ]]; then
    echo "   ✋ the checkout has no tmux.conf at $conf_src" >&2
    echo "      ⇒ \$GROVE_SRC is this run's own checkout, so an absent file here" >&2
    echo "        means the checkout is incomplete rather than that the path is wrong" >&2
    return 1
  fi

  if ! cp "$conf_src" "$HOME/.tmux.conf"; then
    echo "   ✋ could not write ~/.tmux.conf" >&2
    echo "      ⇒ tmux keeps its PRIOR conf, so the plugin install below would" >&2
    echo "        fetch the OLD plugin list and report success" >&2
    return 1
  fi
  echo "   • tmux.conf declared (~/.tmux.conf)"

  ####################################################################
  # 2. the plugins the conf names — see the .why above for the session dance
  ####################################################################
  local tpm_install="$HOME/.tmux/plugins/tpm/bin/install_plugins"

  if [[ ! -x "$tpm_install" ]]; then
    echo "   ✋ tpm's install_plugins is absent ($tpm_install)" >&2
    echo "      ⇒ the conf is on disk but its plugins cannot be fetched, so every" >&2
    echo "        tmux session prints a run-shell error and loads none of them" >&2
    echo "      fix: rhx grove.provision --what 2.8.tmux --mode apply" >&2
    echo "        (the provision phase above owns tpm)" >&2
    return 1
  fi

  ####################################################################
  # ⚠️ the plugin install runs on an ISOLATED tmux SERVER, not a new session
  #
  # .why — 📜 grove-1, 2026-07-30
  #   - tmux reads `~/.tmux.conf` at SERVER start, never at session creation
  #   - a `tmux new-session -d -s _tpm_init` works on a box with no tmux up
  #   - there the session starts a server, which reads the conf just written
  #   - on a GROVE the duct IS tmux, so a server is ALWAYS already up
  #   - ⇒ `new-session` joined that server, whose loaded config is the old one
  #   - tpm then read a plugin list that did not name the new plugins
  #
  #       | approach                                   | plugins landed |
  #       |--------------------------------------------|----------------|
  #       | new-session on the extant server (old)     | none, exit 1   |
  #       | isolated server with `-f ~/.tmux.conf`     | both ✔         |
  #
  #   - `tmux show-options -g | grep plugin` on the live server returned EMPTY
  #   - ⇒ the server knew of no plugins at all
  #
  # .why `-L` is a STRONGER guarantee than a reserved session name
  #   - a reserved name avoided a teardown of the caller's own session
  #   - an isolated socket removes that hazard rather than avoids it
  #   - a separate server shares no session namespace with the duct
  #   - ⇒ `kill-server` here cannot reach the channel this run speaks over
  #
  # .why the plugins are POLLED for rather than trusted to run-shell's exit
  #   - `tmux run-shell` dispatches into a pane
  #   - ⇒ its exit code reports the dispatch and not the clone
  #   - the claim is "the plugins are installed", so it waits for that on disk
  #   - (rule.require.upgrade-entries-verify-themselves)
  ####################################################################
  local sock="grove_tpm"
  local plugin_dir="$HOME/.tmux/plugins"

  # which plugins does the conf name, other than tpm itself?
  local wanted=()
  local line name
  while read -r line; do
    name="${line##*/}"
    name="${name%\'}"
    name="${name%\"}"
    [[ -n "$name" && "$name" != "tpm" ]] && wanted+=("$name")
  done < <(grep -oE "@plugin +['\"][^'\"]+" "$HOME/.tmux.conf" | awk '{print $2}')

  ####################################################################
  # ⚠️ every tmux call below is BOUNDED
  #   - a tmux client waits on the server's socket for a reply
  #   - a server wedged on a hung pane never sends one
  #   - ⇒ a bare call blocks forever
  #   - `_.sh` already wraps its `show-environment` for exactly that
  #   - ⚠️ the corpse case is not hypothetical HERE
  #   - the call below exists because a PRIOR run left a server behind
  #   - an interrupted run is the likeliest way to get a wedged one
  #   - ⇒ the call that cleans up after a wedge is the one most apt to meet one
  #   - a timeout is a real answer: a server silent at 5s will stay silent
  #   - (`rule.require.bounded-probes-in-verifies`)
  ####################################################################

  # .a corpse from an interrupted prior run
  #   - kill the whole isolated server
  #   - ⇒ safe precisely because it is not the one the duct lives on
  timeout -k 2 5 tmux -L "$sock" kill-server 2>/dev/null || true

  if ! timeout -k 5 15 tmux -L "$sock" -f "$HOME/.tmux.conf" new-session -d -s tpm_init 2>/dev/null; then
    echo "   ✋ could not start an isolated tmux server to install the plugins" >&2
    echo "      ⇒ tpm reads its plugin list from a server that has LOADED the conf," >&2
    echo "        so with no such server the install finds an empty list and" >&2
    echo "        reports success with no plugins fetched" >&2
    echo "      ⇒ a conf that does not parse is the usual cause: tmux refuses to" >&2
    echo "        start a server on a bad config" >&2
    echo "      read why: tmux -L $sock -f ~/.tmux.conf new-session -d -s tpm_init" >&2
    return 1
  fi

  ####################################################################
  # ⚠️ ASK the server where tpm will put them — never assume
  #
  # .why this replaced a hardcoded `$HOME/.tmux/plugins`
  #   - tpm picks an XDG root when one exists and publishes that choice
  #   - 📜 2026-07-30: tpm answered `/home/vlad/.config/tmux/plugins/`
  #   - this poll watched `~/.tmux/plugins`
  #   - ⇒ the loop waited its full 90s on a dir tpm never writes to, and returned 1
  #   - all three plugins were installed and loadable the whole time
  #   - the server is asked AFTER the dispatch, since tpm sets the variable when it runs
  #   - see `_.sh` for why the value is read rather than re-derived
  ####################################################################
  # ⚠️ 30s bounds the DISPATCH, not the clones
  #   - `run-shell` hands the command to the server and returns
  #   - the poll below awaits the plugins, with its own 90s
  #   - ⇒ this bound cannot cut a slow network short
  timeout -k 10 30 tmux -L "$sock" run-shell -t tpm_init "$tpm_install" 2>/dev/null || true

  local asked; asked="$(grove_provision_2_8_tmux_plugin_root "$sock")" && plugin_dir="$asked"

  # await the clones, then judge by what is ON DISK — see the ⚠️ above
  local waited=0 absent=()
  while [[ "$waited" -lt 90 ]]; do
    absent=()
    for name in "${wanted[@]}"; do
      [[ -d "$plugin_dir/$name" ]] || absent+=("$name")
    done
    [[ ${#absent[@]} -eq 0 ]] && break
    sleep 3
    waited=$(( waited + 3 ))
  done

  # tear the isolated server down either way — it holds no state worth a keep
  timeout -k 2 5 tmux -L "$sock" kill-server 2>/dev/null || true

  if [[ ${#absent[@]} -gt 0 ]]; then
    echo "   ✋ tpm did not land every plugin the conf names: ${absent[*]}" >&2
    echo "      ⇒ this is SILENT at runtime: tmux starts, the conf loads, and the" >&2
    echo "        plugin's keybinds and status segments are simply omitted with no" >&2
    echo "        error anywhere. the human finds it by a dead keypress" >&2
    echo "      ⇒ tmux-resurrect is what saves a session on prefix+ctrl-s and" >&2
    echo "        restores it on prefix+ctrl-r, so its absence makes both keys dead" >&2
    echo "      ⇒ waited ${waited}s for the clones under $plugin_dir; a slow" >&2
    echo "        network or a github reach that needs auth are the usual causes" >&2
    echo "      read why, on an isolated server so the duct is untouched:" >&2
    echo "        tmux -L $sock -f ~/.tmux.conf new-session -d -s tpm_init" >&2
    echo "        tmux -L $sock run-shell -t tpm_init $tpm_install" >&2
    echo "        tmux -L $sock capture-pane -p -t tpm_init" >&2
    return 1
  fi

  echo "   • tmux plugins installed (${wanted[*]})"

  ####################################################################
  # load the conf into EVERY live server — see `.why the conf IS sourced`
  #
  # 🛑 .why EVERY, and not the default socket alone
  #   - a conf is read at SERVER start, so each server holds its own copy in memory
  #   - a write to `~/.tmux.conf` reaches none of them
  #   - ⇒ a source into `default` reaches one of however many are up
  #   - 📜 2026-09-13, this laptop: 16 sockets — the duct server, a `copygate`,
  #     and 14 probe corpses. the duct's own is not always `default`, so a
  #     default-only source is a converge of whichever server happened to be it
  #
  # 🛑 .why that is a CORRECTNESS bug and not a tidiness one
  #   - 📜 2026-09-13: tmux-continuum was removed from the conf, and the storm
  #     did not stop — every live server still carried continuum's `status-right`,
  #     which is the interpolation that FIRES the save on each status refresh
  #   - the removal was real and reached only servers booted after it
  #   - ⇒ an option a plugin set OUTLIVES the line that asked for it, so an
  #     un-sourced server does not merely hold stale values: it still runs what
  #     the conf no longer declares
  #   - this conf sets `status-right` explicitly, so one source overwrites it
  #
  # ⚠️ a FAILED socket does not fail the phase
  #   - a socket file can outlive its server, and a server can be wedged on a pane
  #   - neither is a defect in the conf this phase just wrote
  #   - ⇒ they are counted and named; the bundle's verify is what grades them
  #   - (`rule.forbid.failhide`: the count is reported, never swallowed)
  #
  # ⚠️ BOUNDED, for the reason every other tmux call here is
  #   - a client waits on the server's socket, and a wedged server never replies
  #   - at ~140 sockets an unbounded call is a hang, not a slow run
  #   - (`rule.require.bounded-probes-in-verifies`)
  #
  # ⚠️ an ABSENT server is a pass, not a claim
  #   - a box with no tmux up has no live conf to converge
  #   - ⇒ the next server reads the file fresh
  ####################################################################
  local live=() sourced=0 refused=()
  while read -r line; do
    [[ -n "$line" ]] && live+=("$line")
  done < <(grove_provision_2_8_tmux_live_sockets)

  for name in "${live[@]}"; do
    if timeout -k 2 5 tmux -L "$name" source-file "$HOME/.tmux.conf" 2>/dev/null; then
      sourced=$(( sourced + 1 ))
    else
      refused+=("$name")
    fi
  done

  if [[ ${#live[@]} -eq 0 ]]; then
    echo "   • no tmux server up — the next one reads the conf fresh"
  else
    echo "   • conf sourced into $sourced of ${#live[@]} live tmux server(s)"
  fi

  if [[ ${#refused[@]} -gt 0 ]]; then
    echo "   🌙 ${#refused[@]} live server(s) would not load the conf: ${refused[*]}"
    echo "      ⇒ each keeps its PRIOR options — a REMOVED plugin's among them,"
    echo "        since an option outlives the line that asked for it"
    echo "      ⇒ a socket that outlived its server reads the same way here; the"
    echo "        bundle's verify is what tells the two apart"
    echo "      read why: tmux -L ${refused[0]} source-file ~/.tmux.conf"
  fi

  echo "     ⚠️ a live CLIENT still needs a reattach: terminal-features (RGB,"
  echo "        extkeys, clipboard) are negotiated at attach, never at source"
}
