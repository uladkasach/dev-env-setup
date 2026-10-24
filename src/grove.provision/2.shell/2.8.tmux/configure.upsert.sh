#!/usr/bin/env bash
######################################################################
# .what = put this repo's tmux conf on the box, then install the plugins it names
# .why
#   - 🛑 the plugin install runs on an ISOLATED server (`-L`): tpm reads its list
#     from a server that LOADED the conf, and a grove's duct server is older
#   - the isolated socket cannot reach the duct, so `kill-server` is safe
#   - the conf IS sourced into every live server, since an option outlives the
#     line that asked for it
#   - ⚠️ the source is HALF the job — a live client needs a REATTACH
#   - ⚠️ every tmux call is BOUNDED, since a wedged server never replies
# .refs = gotcha.2-8-tmux.demo=plugin-root-and-two-readers, m4-m7
#
# guarantee:
#   - idempotent: one copy of one file, and no shadow conf beside it (m10)
#   - idempotent: the throwaway server is killed before it is created and again after
######################################################################

grove_provision_2_8_tmux_configure_upsert() {
  ####################################################################
  # 1. the conf
  ####################################################################
  local conf_src="$GROVE_SRC/grove.provision/2.shell/2.8.tmux/tmux.conf"

  if [[ ! -f "$conf_src" ]]; then
    echo "   ✋ ConstraintError: the checkout has no tmux.conf at $conf_src" >&2
    echo "      ⇒ \$GROVE_SRC is this run's own checkout, so an absent file here" >&2
    echo "        means the checkout is incomplete rather than that the path is wrong" >&2
    return 1
  fi

  # which plugins does the conf name, other than tpm itself? read from the CHECKOUT, so a
  #   refusal below leaves ~/.tmux.conf as it was
  local wanted=()
  local name
  while read -r name; do
    [[ -n "$name" && "$name" != "tpm" ]] && wanted+=("$name")
  done < <(grove_provision_2_8_tmux_plugin_names_of_conf "$conf_src")

  # 🛑 refuse a plugin this repo pins no commit for BEFORE the conf lands: tpm's install takes
  #    its tip, a source into a live server runs its .tmux, and so would the next server start or
  #    a `prefix + I` — the verify's ✋ would come after that code has run once
  local unpinned=()
  for name in "${wanted[@]}"; do
    grove_provision_2_8_tmux_plugin_at "$name" >/dev/null || unpinned+=("$name")
  done
  if [[ "${#unpinned[@]}" -gt 0 ]]; then
    echo "   ✋ ConstraintError: the conf names a tmux plugin this repo pins no commit for: ${unpinned[*]}" >&2
    echo "      ⇒ ~/.tmux.conf is left as it was, no plugin was installed, and no live server" >&2
    echo "        sourced the conf" >&2
    echo "      fix: pin it in 2.8.tmux/_.sh (plugin_names, plugin_url, plugin_at), or drop" >&2
    echo "        its @plugin line from tmux.conf" >&2
    return 1
  fi

  # each step's own complaint rides inside its ✋ as the cause, never as a bare line above it
  local step_err
  # LC_ALL=C on each captured step: its words ride as `cause:`, alike on every box
  if ! step_err="$(LC_ALL=C cp "$conf_src" "$HOME/.tmux.conf" 2>&1)"; then
    echo "   ✋ ConstraintError: could not write ~/.tmux.conf" >&2
    echo "      cause: ${step_err#cp: }" >&2
    echo "      ⇒ tmux keeps its PRIOR conf, so the plugin install below would" >&2
    echo "        fetch the OLD plugin list and report success" >&2
    return 1
  fi
  echo "   • tmux.conf declared (~/.tmux.conf)"

  # there can only be one: a conf tmux loads AFTER ours wins every option both
  # name. it is MOVED aside, never deleted — a human's edits stay readable (m10)
  local shadow stamp; stamp="$(grove_provision_2_8_tmux_backup_stamp)"
  while IFS= read -r shadow; do
    [[ -n "$shadow" ]] || continue
    if step_err="$(LC_ALL=C mv "$shadow" "$shadow.bak.$stamp" 2>&1)"; then
      echo "   • shadow conf retired: $shadow → $shadow.bak.$stamp"
      echo "     ⇒ it loaded AFTER ~/.tmux.conf and overrode it; read it there if"
      echo "       a line in it was wanted, then move that line into this bundle"
    else
      echo "   ✋ ConstraintError: could not move the shadow conf aside: $shadow" >&2
      echo "      cause: ${step_err#mv: }" >&2
      echo "      ⇒ tmux loads it after ~/.tmux.conf, so every option it names" >&2
      echo "        still overrides the one this repo declares" >&2
      return 1
    fi
  done < <(grove_provision_2_8_tmux_shadow_confs)

  ####################################################################
  # 2. the plugins the conf names — see the .why above for the session dance
  ####################################################################
  local tpm_install="$HOME/.tmux/plugins/tpm/bin/install_plugins"

  if [[ ! -x "$tpm_install" ]]; then
    echo "   ✋ ConstraintError: tpm's install_plugins is absent ($tpm_install)" >&2
    echo "      ⇒ the conf is on disk but its plugins cannot be fetched, so every" >&2
    echo "        tmux session prints a run-shell error and loads none of them" >&2
    echo "      fix: rhx grove.provision --what 2.8.tmux --mode apply" >&2
    echo "        (the provision phase above owns tpm)" >&2
    return 1
  fi

  # the install runs on an ISOLATED server, and the plugins are POLLED on disk —
  # `run-shell`'s exit reports the dispatch, never the clone (m5)
  local sock="grove_tpm"
  local plugin_dir="$HOME/.tmux/plugins"

  # ⚠️ every tmux call below is BOUNDED — this first one cleans up a corpse from
  #    an interrupted run, the likeliest wedge (`rule.require.bounded-probes-in-verifies`)
  timeout -k 2 5 tmux -L "$sock" kill-server 2>/dev/null || true

  if ! timeout -k 5 15 tmux -L "$sock" -f "$HOME/.tmux.conf" new-session -d -s tpm_init 2>/dev/null; then
    echo "   ✋ ConstraintError: could not start an isolated tmux server to install the plugins" >&2
    echo "      ⇒ tpm reads its plugin list from a server that has LOADED the conf," >&2
    echo "        so with no such server the install finds an empty list and" >&2
    echo "        reports success with no plugins fetched" >&2
    echo "      read why: tmux -L $sock -f ~/.tmux.conf new-session -d -s tpm_init" >&2
    return 1
  fi

  # ⚠️ a conf that does not parse does NOT stop the server: tmux starts, drops the whole
  #    file, and holds no @plugin — so tpm would install an empty list and report success.
  #    `source-file -n` parses without a run, and is the one read that names the fault
  local parse_err
  if ! parse_err="$(timeout -k 2 5 tmux -L "$sock" source-file -n "$HOME/.tmux.conf" 2>&1)"; then
    timeout -k 2 5 tmux -L "$sock" kill-server 2>/dev/null || true
    echo "   ✋ ConstraintError: ~/.tmux.conf does not parse, so tmux loads none of it" >&2
    [[ -n "$parse_err" ]] && echo "      cause: $(printf '%s\n' "$parse_err" | head -n 1)" >&2
    echo "      ⇒ a server still starts on it, with every option and every @plugin" >&2
    echo "        dropped, so tpm would find an empty list and report success" >&2
    echo "      fix: repair the line named above in the checkout's tmux.conf, then" >&2
    echo "        rhx grove.provision --what 2.8.tmux --mode apply" >&2
    return 1
  fi

  # ⚠️ 30s bounds the DISPATCH; the poll below awaits the clones with its own 90s.
  # the plugin ROOT is ASKED after the dispatch, never assumed — tpm may pick
  # an XDG root, and sets the variable when it runs (m1)
  timeout -k 10 30 tmux -L "$sock" run-shell -t tpm_init "$tpm_install" 2>/dev/null || true

  local asked; asked="$(grove_provision_2_8_tmux_plugin_root "$sock")" && plugin_dir="$asked"

  # await the clones, then judge by what is ON DISK — see the ⚠️ above
  local waited=0 absent=()
  while [[ "$waited" -lt 90 ]]; do
    mapfile -t absent < <(grove_provision_2_8_tmux_plugins_absent_under "$plugin_dir" "${wanted[@]}")
    [[ ${#absent[@]} -eq 0 ]] && break
    sleep 3
    waited=$(( waited + 3 ))
  done

  # tear the isolated server down either way — it holds no state worth a keep
  timeout -k 2 5 tmux -L "$sock" kill-server 2>/dev/null || true

  if [[ ${#absent[@]} -gt 0 ]]; then
    echo "   ✋ ConstraintError: tpm did not land every plugin the conf names: ${absent[*]}" >&2
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

  # 🛑 load the conf into EVERY live server — a removed plugin's option outlives
  #    its line, and an un-sourced server still RUNS it (m7)
  # ⚠️ a FAILED socket is counted and named, never fatal — the verify grades it.
  #    an ABSENT server is a pass: the next one reads the file fresh
  local live=() sourced=0 refused=() line
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
