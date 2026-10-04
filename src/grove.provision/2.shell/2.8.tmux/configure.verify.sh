#!/usr/bin/env bash
######################################################################
# .what = prove `~/.tmux.conf` matches the checkout, that NO other conf overrides it,
#         that every plugin it names is on disk where tpm puts them — and that every
#         live server, pane and client holds what it declares
# .why
#   - the conf is DIFFED, since a stale conf exists and loads (m1)
#   - the plugin list and default-terminal are READ from the conf, never restated (m1, m6)
#   - an absent plugin is a ✋: its absence is SILENT at runtime (m1)
#   - the live claims sit in `_.sh` (`_verify_live_servers`), since a conf on disk proves
#     only what the NEXT server loads (m6-m9)
# .refs = gotcha.2-8-tmux.demo=verify-from-conf-to-client
#
# guarantee:
#   - READ-ONLY. it diffs one file, greps it, stats dirs, and QUERIES a tmux
#     server that already runs. it starts no server and creates no session
#
# exit:
#   0 = every claim holds | 1 = a claim failed, and which is named
#   0 with 🌙 = no server was up to answer the claims that need one
######################################################################

grove_provision_2_8_tmux_configure_verify() {
  local failed=0
  local conf_live="$HOME/.tmux.conf"
  local conf_src="$GROVE_SRC/grove.provision/2.shell/2.8.tmux/tmux.conf"

  # 1. present
  if [[ ! -f "$conf_live" ]]; then
    echo "   ✋ no ~/.tmux.conf on this box" >&2
    echo "      ⇒ tmux runs with its stock defaults: no mouse, 2k scrollback, and" >&2
    echo "        none of the keybinds a duct and the termwork skills drive" >&2
    echo "      fix: rhx grove.provision --what 2.8.tmux --mode apply" >&2
    return 1
  fi

  # 2. current
  if [[ ! -f "$conf_src" ]]; then
    echo "   ✋ the checkout has no tmux.conf at $conf_src to compare against" >&2
    echo "      ⇒ so whether ~/.tmux.conf is current cannot be judged at all" >&2
    failed=$(( failed + 1 ))
  elif cmp -s "$conf_src" "$conf_live"; then
    echo "   • ~/.tmux.conf matches the checkout ✔"
  else
    echo "   ✋ ~/.tmux.conf DIFFERS from the checkout" >&2
    echo "      ⇒ the live conf is an older revision — invisible to a file test," >&2
    echo "        since it exists and loads. the symptom is 'my keybind change had" >&2
    echo "        no effect', which a human blames on tmux" >&2
    echo "      read why: diff $conf_src $conf_live" >&2
    failed=$(( failed + 1 ))
  fi

  # 3. is a SECOND conf loaded after ours? the verify REPORTS; the upsert retires it (m2, m10)
  #   - EVERY socket is asked, bounded, and the first to answer settles it (m3)
  #   - an `A…Z` sentinel parts "no answer" from "too old to ask"; an old tmux
  #     falls back to a FILE test of the XDG path, and says it is weaker (m4)
  local loaded="" shadow=() probe answer
  while read -r probe; do
    [[ -n "$probe" ]] || continue
    answer="$(timeout -k 2 5 tmux -L "$probe" display-message -p 'A#{config_files}Z' 2>/dev/null)" \
      || continue
    [[ -n "$answer" ]] || continue

    # the server SPOKE. strip the sentinel; what is left is the list, or empty
    loaded="${answer#A}"
    loaded="${loaded%Z}"
    break
  done < <(grove_provision_2_8_tmux_live_sockets)

  # a server that spoke and named no conf is an OLD tmux, or a tmux with no conf
  if [[ -n "$answer" && -z "$loaded" ]]; then
    local xdg_conf="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf"
    if [[ -f "$xdg_conf" ]]; then
      echo "   ✋ tmux loads ANOTHER conf besides ~/.tmux.conf: $xdg_conf" >&2
      echo "      ⇒ tmux reads its confs in order and a LATER file wins, so any" >&2
      echo "        option named there overrides the one this repo declares —" >&2
      echo "        while the check above still reports ~/.tmux.conf as current" >&2
      echo "      ⚠️ read by a FILE test, not by tmux: this tmux ($(tmux -V 2>/dev/null))" >&2
      echo "        carries no '#{config_files}', which lands in 3.3" >&2
      echo "      read why: diff $conf_live $xdg_conf" >&2
      echo "      fix: rhx grove.provision --what 2.8.tmux --mode apply" >&2
      echo "        (the upsert moves every shadow aside — there can only be one, m10)" >&2
      failed=$(( failed + 1 ))
    else
      echo "   • ~/.tmux.conf is the only conf tmux loads ✔ (no $xdg_conf)"
      echo "     ⚠️ read by a FILE test — this tmux carries no '#{config_files}' (3.3+),"
      echo "        so a conf outside that one known path would go unseen here"
    fi
  elif [[ -z "$loaded" ]]; then
    echo "   🌙 no tmux server answered, so which confs tmux loads cannot be observed"
    echo "      ⇒ either none runs, or each that does did not reply within 5s"
  else
    # ⚠️ `printf '%s\n'` — its newline keeps the LAST element, the shadow (m5)
    # a server's list is fixed at its START: a shadow the upsert already moved
    # aside is still NAMED by it, so only one still on disk is a ✋ (m10)
    local one retired=()
    while IFS= read -r one; do
      [[ -n "$one" && "$one" != "$conf_live" ]] || continue
      if [[ -f "$one" ]]; then shadow+=("$one"); else retired+=("$one"); fi
    done < <(printf '%s\n' "$loaded" | tr ',' '\n')

    if [[ "${#shadow[@]}" -eq 0 && "${#retired[@]}" -gt 0 ]]; then
      echo "   • ~/.tmux.conf is the only conf on disk ✔ (retired: ${retired[*]})"
      echo "     🌙 the live server still NAMES it — its list is fixed at start — and"
      echo "        an option ONLY it set lingers there until that server restarts"
    elif [[ "${#shadow[@]}" -eq 0 ]]; then
      echo "   • ~/.tmux.conf is the only conf tmux loads ✔ ($loaded)"
    else
      echo "   ✋ tmux loads ANOTHER conf besides ~/.tmux.conf: ${shadow[*]}" >&2
      echo "      ⇒ tmux reads its confs in order and a LATER file wins, so any" >&2
      echo "        option named there overrides the one this repo declares —" >&2
      echo "        while the check above still reports ~/.tmux.conf as current" >&2
      echo "      ⇒ tmux's own answer: #{config_files} = $loaded" >&2
      echo "      ⇒ so a keybind change can land in the checkout, be copied to the" >&2
      echo "        box, verify green, and still have no effect" >&2
      echo "      read why: diff $conf_live ${shadow[0]}" >&2
      echo "      fix: rhx grove.provision --what 2.8.tmux --mode apply" >&2
      echo "        (the upsert moves every shadow aside — there can only be one, m10)" >&2
      failed=$(( failed + 1 ))
    fi
  fi

  # 4. every plugin the LIVE conf names, at `<root>/<basename>` — tpm's root is ASKED
  #    (gotcha.2-8-tmux.demo=plugin-root-and-two-readers, m1)
  local plugin_root
  if ! plugin_root="$(grove_provision_2_8_tmux_plugin_root)"; then
    echo "   🌙 no tmux server runs, so where tpm places plugins cannot be asked"
    echo "      — the plugin claim is unproven on this run, not disproven"
    [[ "$failed" -eq 0 ]] || return 1
    return 0
  fi

  local declared=()
  local line repo
  while IFS= read -r line; do
    # pull the quoted `owner/name` out of `set -g @plugin 'owner/name'`
    repo="${line#*@plugin }"
    repo="${repo//\'/}"
    repo="${repo//\"/}"
    repo="$(echo "$repo" | awk '{print $1}')"
    [[ -n "$repo" ]] && declared+=("${repo##*/}")
  done < <(grep -E "^[[:space:]]*set[[:space:]]+-g[[:space:]]+@plugin" "$conf_live" 2>/dev/null || true)

  if [[ "${#declared[@]}" -eq 0 ]]; then
    echo "   🌙 the conf names no plugins, so none are owed"
  else
    local name
    local absent=()
    for name in "${declared[@]}"; do
      [[ -d "$plugin_root/$name" ]] || absent+=("$name")
    done

    if [[ "${#absent[@]}" -eq 0 ]]; then
      echo "   • all ${#declared[@]} declared tmux plugins present ✔ ($plugin_root)"
    else
      echo "   ✋ a tmux plugin the conf names is ABSENT from $plugin_root: ${absent[*]}" >&2
      echo "      ⇒ this is SILENT at runtime: tmux starts, the conf loads, and the" >&2
      echo "        plugin's keybinds and status segments are simply omitted with no" >&2
      echo "        error anywhere. the human finds it by pressing a dead key" >&2
      echo "      ⇒ tmux-resurrect is what saves a session on prefix+ctrl-s and" >&2
      echo "        restores it on prefix+ctrl-r, so its absence makes both keys dead" >&2
      echo "      fix: rhx grove.provision --what 2.8.tmux --mode apply" >&2
      failed=$(( failed + 1 ))
    fi
  fi

  # 5. terminfo HOLDS the entry the conf names as default-terminal; an absent
  #    infocmp is a 🌙, since `4.3.1.terminfo` owns it and runs later (m6)
  local term_declared
  term_declared="$(grep -E "^[[:space:]]*set[[:space:]]+-g[[:space:]]+default-terminal" "$conf_live" 2>/dev/null \
    | tail -1 | sed -E "s/.*default-terminal[[:space:]]+//; s/['\"]//g" | awk '{print $1}')"

  if [[ -z "$term_declared" ]]; then
    echo "   ✋ the conf declares no default-terminal" >&2
    echo "      ⇒ tmux falls back to 'screen' — 8 colours — and every pane" >&2
    echo "        inherits it at spawn, so apps EMIT only 8-colour codes" >&2
    echo "      ⇒ INVISIBLE beside a correct terminal-features line: the outward" >&2
    echo "        path renders a truecolor no app ever sends" >&2
    echo "      fix: declare it in this bundle's tmux.conf, then re-apply this bundle" >&2
    failed=$(( failed + 1 ))
  elif ! command -v infocmp >/dev/null 2>&1; then
    echo "   🌙 default-terminal is '$term_declared'; infocmp is absent, so whether"
    echo "      terminfo holds that entry cannot be observed on this run"
  elif infocmp "$term_declared" >/dev/null 2>&1; then
    echo "   • default-terminal '$term_declared' — terminfo holds it ✔"
  else
    echo "   ✋ default-terminal names '$term_declared', which terminfo does NOT hold" >&2
    echo "      ⇒ tmux REFUSES to start a server on an entry it cannot look up, so" >&2
    echo "        this is not a degraded colour path — it is no tmux at all, and on" >&2
    echo "        a grove the duct IS tmux" >&2
    echo "      ⇒ 'tmux-256color' ships in ncurses-base (priority: required)" >&2
    echo "      read why: infocmp $term_declared" >&2
    failed=$(( failed + 1 ))
  fi

  # 6-9. the live server, pane and client claims (m6-m9)
  grove_provision_2_8_tmux_verify_live_servers "$conf_live" "$term_declared" \
    || failed=$(( failed + 1 ))

  [[ "$failed" -eq 0 ]] || return 1
}
