#!/usr/bin/env bash
######################################################################
# .what = prove `~/.tmux.conf` matches the checkout, that NO other conf overrides it,
#         and that every plugin it names is on disk where tpm actually puts them
#
# 📜 2026-07-30: "the conf is current" and "plugins at `~/.tmux/plugins`" were too narrow
#   - tmux loaded a SECOND conf that overrode the current one
#   - and tpm put the plugins somewhere else entirely
#   - see the ⚠️ at claims 3 and 4
#
# .why the plugin list is READ FROM THE CONF and not hardcoded here
#   - the conf's `@plugin` lines ARE the declaration
#   - a list repeated here is a second copy of the same knowledge
#   - ⇒ it drifts the first time a plugin is added to the conf and not to this file
#
# .why an absent plugin is a ✋ and not a 🌙
#   - a plugin's absence is SILENT at runtime
#   - tmux starts, the conf loads, and its keybinds and status segments are omitted
#   - no error is printed anywhere
#   - ⇒ if this phase does not assert it, no surface ever will
#   - the human finds it by a dead keypress
#
# .why the conf is diffed rather than merely stat'd
#   - a stale conf exists, loads, and is simply an older revision
#   - ⇒ the symptom is "my keybind change had no effect", which a human blames on tmux
#
# guarantee:
#   - READ-ONLY. it diffs one file, greps it, stats dirs, and QUERIES a tmux
#     server that already runs. it starts no server and creates no session
#
# exit:
#   0 = the conf is current, unshadowed, and every plugin it names is present
#   1 = a claim failed, and which is named
#   0 with 🌙 = no server was up to answer the two claims that need one
######################################################################

grove_provision_2_8_tmux_configure_verify() {
  local failed=0
  local conf_live="$HOME/.tmux.conf"
  local conf_src="$GROVE_SRC/grove.provision/2.shell/2.8.tmux/tmux.conf"

  ####################################################################
  # 1. present
  ####################################################################
  if [[ ! -f "$conf_live" ]]; then
    echo "   ✋ no ~/.tmux.conf on this box" >&2
    echo "      ⇒ tmux runs with its stock defaults: no mouse, 2k scrollback, and" >&2
    echo "        none of the keybinds a duct and the termwork skills drive" >&2
    echo "      fix: rhx grove.provision --what 2.8.tmux --mode apply" >&2
    return 1
  fi

  ####################################################################
  # 2. current
  ####################################################################
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

  ####################################################################
  # 3. is a SECOND conf loaded after ours, able to override every line of it?
  #
  # ⚠️ .why this claim exists — 📜 this laptop 2026-07-30
  #   - tmux 3.4 reads a LIST of configs, in order, and a later file overrides an earlier
  #   - `#{config_files}` is tmux's own answer:
  #
  #       /home/vlad/.tmux.conf,/home/vlad/.config/tmux/tmux.conf
  #
  #   - claim 2 had just reported `~/.tmux.conf matches the checkout ✔`, correctly
  #   - `~/.config/tmux/tmux.conf` loads AFTER it and differs from the checkout
  #   - ⇒ it wins every option the two both name
  #   - so this bundle could report a converged tmux governed by a file the repo never saw
  #   - ⇒ a true answer to a question that is no longer the whole question
  #
  # .why it REPORTS and does not delete
  #   - a shadow conf is somebody's real config, with real content in it
  #   - which path this repo should own is a decision with a human's preference in it
  #   - a wrong guess deletes work
  #   - ⇒ the bundle makes the invisible visible and names both ways out
  ####################################################################
  # ⚠️ .why `timeout` wraps the ask
  #   - `tmux display-message` waits on the server's socket for a reply
  #   - a server wedged on a hung pane never replies
  #   - that is a real state on a box whose ducts are tmux
  #   - ⇒ a bare call blocks forever inside a `--mode plan`
  #   - (`rule.require.bounded-probes-in-verifies`)
  #   - a wedged server reads the same as an absent one, which is honest
  #
  # 🛑 .why EVERY socket is asked, and not the bare default
  #   - a bare `tmux display-message` speaks to the DEFAULT socket alone
  #   - a box whose ducts are tmux often has no server on `default` at all
  #   - ⇒ the bare call then answers empty, and the claim declines itself
  #   - 📜 2026-09-13, a cloud grove: this row printed "no tmux server answered"
  #     in the same output where the row below it read TWO live servers — one
  #     set, two readers, and only the default-only one went blind
  #     (gotcha.a-check-that-cries-wolf-gets-silenced, m.9)
  #   - ⇒ so the shared socket reader is asked, and the FIRST server to answer
  #     settles the claim: `#{config_files}` is a property of the conf on disk,
  #     so any one live server reports the same list
  #
  # 🛑 .why a SENTINEL wraps the format, and not a bare `-p '#{config_files}'`
  #   - `#{config_files}` lands in tmux 3.3. an OLDER tmux answers the call and
  #     expands the format to the empty string
  #   - ⇒ a bare read cannot part THREE states that all arrive as empty:
  #       · no server answered           → the claim cannot be observed
  #       · a server answered, no format → this tmux is too old to ask
  #       · a server answered, empty list → tmux loaded no conf at all
  #   - the sentinel parts them in ONE call: `A#{config_files}Z`
  #       · empty       → the server never answered
  #       · exactly AZ  → it answered, and the format is unsupported or empty
  #       · A<list>Z    → the list, and it is authoritative
  #   - 📜 2026-09-13, a cloud grove on tmux 3.2a: `display-message -p 'ALIVE'`
  #     printed `ALIVE` and `A#{config_files}Z` printed `AZ` — so the server was
  #     reachable the whole time, and this row reported "no tmux server answered"
  #   - ⇒ a TRUE verdict with the wrong SUBJECT named
  #     (gotcha.a-check-that-cries-wolf-gets-silenced, m.4)
  #
  # .why an old tmux falls back to a FILE test, and does not merely decline
  #   - the claim is about a shadow conf, and a decline reports no shadow at all
  #   - ⇒ on a grove that is a silent gap: a keybind lands in the checkout,
  #     reaches the box, verifies green, and is overridden there
  #   - the XDG path is the one this claim was written for (the 2026-07-30
  #     measurement names it), so a direct test catches the real defect
  #   - ⚠️ it is WEAKER than tmux's own answer and says so in its own output:
  #     it tests one known path where `#{config_files}` reports every conf
  #     actually loaded. do NOT re-derive tmux's search order here — that is a
  #     second list, version-dependent, free to drift from tmux itself
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
      echo "      fix, whichever this repo should own:" >&2
      echo "        · keep legacy — move the other aside: mv $xdg_conf $xdg_conf.bak" >&2
      echo "        · adopt XDG   — point this bundle at $xdg_conf instead" >&2
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
    ####################################################################
    # ⚠️ `printf '%s\n'` — that trailing newline carries the claim
    #   - `while read` returns NON-ZERO at EOF
    #   - ⇒ a final line with no newline sets the variable and still ends the loop
    #   - the last element is read and then silently dropped
    #   - here the list is `<managed>,<shadow>`
    #   - ⇒ the dropped element was always the shadow conf, the item this claim finds
    #   - 📜 2026-07-30: it reported "the only conf tmux loads ✔" where `#{config_files}` named two
    #   - it fails OPEN, on exactly the input that matters
    #   - a single-conf box parses correctly, so the check looks right except where needed
    #   - (rule.forbid.failhide, and the same family as gotcha.pipefail-grep-q)
    ####################################################################
    local one
    while IFS= read -r one; do
      [[ -n "$one" && "$one" != "$conf_live" ]] && shadow+=("$one")
    done < <(printf '%s\n' "$loaded" | tr ',' '\n')

    if [[ "${#shadow[@]}" -eq 0 ]]; then
      # .the observed list is printed, not just the verdict
      #   - a claim about WHICH files load is only as good as the list it read
      #   - ⇒ a reader who cannot see that list cannot tell a real ✔ from a misread one
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
      echo "      fix, whichever this repo should own:" >&2
      echo "        · keep legacy — move the other aside: mv ${shadow[0]} ${shadow[0]}.bak" >&2
      echo "        · adopt XDG   — point this bundle at ${shadow[0]} instead" >&2
      failed=$(( failed + 1 ))
    fi
  fi

  ####################################################################
  # 4. every plugin the LIVE conf names — read from the conf, never listed here
  #
  #   - tpm names each plugin's dir by the repo's basename
  #   - ⇒ `tmux-plugins/foo` lands at `<root>/foo`
  #   - `<root>` is tpm's to choose, so it is ASKED for rather than assumed
  #   - 📜 see `_.sh` for the 90s false failure that taught this
  ####################################################################
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

  ####################################################################
  # 5. does terminfo HOLD the entry the conf names as default-terminal?
  #
  # ⚠️ .why this claim exists — 📜 2026-09-03, grove-ahbode-v20260901
  #   - `default-terminal` sets the $TERM every pane inherits at spawn
  #   - tmux's built-in default is `screen`, which is 8 colours
  #   - ⇒ an app inside a pane emits 8-colour codes
  #   - no option downstream recovers what it never sent
  #   - that box had `terminal-features …:RGB` correct and `default-terminal` at `screen`
  #   - ⇒ the outward path was fixed and the source still clamped
  #   - the two are INDEPENDENT, and a check on one proves none of the other
  #   - a reader who saw only the RGB line called the conf converged
  #
  # .why the name is READ FROM THE CONF rather than restated here
  #   - the conf's own line IS the declaration, as claim 4 states for the plugin list
  #   - ⇒ a copy here drifts the first time the value changes in one place only
  #
  # .why an ABSENT infocmp is a 🌙 and not a ✋
  #   - `infocmp` ships in ncurses-bin, which `4.3.1.terminfo` owns
  #   - that bundle runs AFTER this one, since 4.x follows 2.x
  #   - ⇒ on a first apply the tool can legitimately be absent here
  #   - a ✋ would cry wolf on every fresh box
  #   - (gotcha.a-check-that-cries-wolf-gets-silenced)
  ####################################################################
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

  ####################################################################
  # 🛑 claim: no LIVE server still runs a plugin the conf no longer names
  #
  # .why the LIVE servers are read, and not the conf alone
  #   - every claim above reads `~/.tmux.conf`, which is a file on disk
  #   - a server reads that file ONCE, at its own start, and keeps it in memory
  #   - ⇒ a green conf proves what the NEXT server will load, and says not one
  #     word about the servers already up
  #
  # 🛑 .why a REMOVED plugin is what this hunts
  #   - tpm sources a plugin's `.tmux` file, and that file SETS tmux options
  #   - an option outlives the `@plugin` line that asked for it
  #   - ⇒ to delete the line converges the conf and converges no live server
  #   - 📜 2026-09-13: continuum was cut from the conf and the save storm went on
  #     — 118 concurrent `continuum_save.sh` at 543% cpu, fired by the
  #     `status-right` interpolation the live duct server still held
  #   - ⇒ the interpolation IS the timer: tmux evaluates `status-right` on every
  #     status refresh, so the cost scales per status line drawn
  #   - ⇒ the fix is a source per server, and THIS is the claim that grades it
  #
  # .why `status-right` is the one option read
  #   - it is where a status-segment plugin installs its `#(…)` interpolation
  #   - tmux evaluates it every `status-interval`, so the interpolation IS the timer
  #   - the conf sets `status-right` outright, so a source overwrites it whole
  #
  # .why an UNREACHABLE socket is a 🌙 and not a ✋
  #   - a socket file outlives its server, so an unreachable one is usually a corpse
  #   - a corpse runs no timer, so it cannot be the defect this claim is about
  #   - a ✋ per corpse would cry wolf on every box with a stale socket
  #   - (gotcha.a-check-that-cries-wolf-gets-silenced)
  #
  # ⚠️ BOUNDED — a wedged server never replies, and this asks ~140 of them
  #   (`rule.require.bounded-probes-in-verifies`)
  ####################################################################
  local sockets=() haunted=() mute=0 right sock_name
  while read -r sock_name; do
    [[ -n "$sock_name" ]] && sockets+=("$sock_name")
  done < <(grove_provision_2_8_tmux_live_sockets)

  for sock_name in "${sockets[@]}"; do
    right="$(timeout -k 2 5 tmux -L "$sock_name" show-options -gv status-right 2>/dev/null)" \
      || { mute=$(( mute + 1 )); continue; }
    [[ "$right" == *continuum* ]] && haunted+=("$sock_name")
  done

  if [[ ${#sockets[@]} -eq 0 ]]; then
    echo "   • no tmux server up — none holds a stale conf"
  elif [[ ${#haunted[@]} -eq 0 ]]; then
    echo "   • ${#sockets[@]} live server(s), none runs a removed plugin's hook ✔"
  else
    echo "   ✋ ${#haunted[@]} of ${#sockets[@]} live tmux server(s) still run a hook" >&2
    echo "      from tmux-continuum, which this conf no longer names" >&2
    echo "      ⇒ each fires continuum_save.sh on every status refresh, and the" >&2
    echo "        timer is PER SERVER with no lock between them — measured at 118" >&2
    echo "        concurrent saves, 543% cpu, load 40 on 12 cores" >&2
    echo "      ⇒ the conf on disk is CORRECT; these servers booted before it and" >&2
    echo "        hold their own copy in memory" >&2
    echo "      fix: rhx grove.provision --what 2.8.tmux --mode apply" >&2
    echo "        (its configure.upsert sources the conf into every live server)" >&2
    echo "      sockets: ${haunted[*]}" >&2
    failed=$(( failed + 1 ))
  fi

  [[ "$mute" -eq 0 ]] || {
    echo "   🌙 $mute socket(s) did not answer — a socket outlives its server, so"
    echo "      these are most likely corpses, and a corpse runs no timer"
  }

  ####################################################################
  # 🛑 claim: every LIVE server holds the default-terminal the conf declares
  #
  # 🛑 .why the conf alone is not the claim
  #   - the claim above reads `~/.tmux.conf` and asks terminfo about the NAME
  #   - it proves what the NEXT server will load, and says not one word about
  #     the servers already up — the same false ✔ the haunted-hook claim names
  #   - ⇒ a server started before this conf, or started with `-f` pointed
  #     elsewhere, holds tmux's built-in `screen` — 8 colours
  #   - every pane inherits `default-terminal` AT SPAWN, so an app in it emits
  #     only 8-colour codes, and no option downstream recovers a colour that was
  #     never sent (the conf's own `default-terminal` block states this)
  #
  # ⚠️ a pane that already exists keeps the TERM it spawned with
  #   - so a source repairs the SERVER and leaves every extant pane as it was
  #   - ⇒ a mixed server renders new panes correctly and old ones at 8 colours,
  #     which reads as "colour broke" with every conf claim green
  #   - the repair is a new pane (or a new window), never a re-apply
  ####################################################################
  local term_wrong=() term_live
  for sock_name in "${sockets[@]}"; do
    term_live="$(timeout -k 2 5 tmux -L "$sock_name" show-options -gv default-terminal 2>/dev/null)" \
      || continue
    [[ -n "$term_live" ]] || continue
    [[ "$term_live" == "$term_declared" ]] || term_wrong+=("$sock_name=$term_live")
  done

  if [[ ${#sockets[@]} -eq 0 ]]; then
    : # no server up — the claim above already covers what the next one loads
  elif [[ ${#term_wrong[@]} -eq 0 ]]; then
    echo "   • every live server holds default-terminal '$term_declared' ✔"
  else
    echo "   ✋ ${#term_wrong[@]} live server(s) hold a default-terminal the conf does NOT declare" >&2
    echo "      ⇒ each pane spawned there inherits that TERM and EMITS to match, so" >&2
    echo "        an 8-colour entry clamps colour at its source — invisible to every" >&2
    echo "        claim above, which read the conf rather than the server" >&2
    echo "      fix: rhx grove.provision --what 2.8.tmux --mode apply" >&2
    echo "      ⚠️ a pane that ALREADY exists keeps its spawn-time TERM, so open a" >&2
    echo "        new window or pane to see the repair" >&2
    printf '        %s\n' "${term_wrong[@]}" >&2
    failed=$(( failed + 1 ))
  fi

  ####################################################################
  # 🛑 claim: every LIVE pane spawned with the default-terminal now declared
  #
  # 🛑 .why a PANE claim, when the claim above already grades the SERVER
  #   - `default-terminal` is consumed ONCE, when a pane spawns: tmux puts it in
  #     the child's environment as TERM, and the child keeps that copy for life
  #   - ⇒ a source that repairs the server repairs NO extant pane
  #   - an app reads TERM, concludes 8 colours, and EMITS 8-colour codes; the
  #     conf's own `default-terminal` block states that no option downstream can
  #     recover a colour the app never sent
  #
  # 🛑 .why it is the LAST surface, and the only one that stays red
  #   - the three claims above grade the conf, the server, and the client
  #   - a box can pass all three and still render 8 colours in every pane that
  #     predates the conf — which reads to a human as "colour broke" with a
  #     wholly green verify (`gotcha.a-check-that-cries-wolf-gets-silenced`)
  #
  # .why /proc and not a tmux format
  #   - tmux exposes the SESSION environment, never a live pane's own copy
  #   - the child's `/proc/<pid>/environ` is the copy the app actually read
  #   - ⇒ it is the only reader that answers about the process, not the config
  #
  # ⚠️ linux-only, and a pane that will not answer is a 🌙
  #   - a pane can exit between the list and the read, and a foreign process
  #     may deny the read; neither is a defect in the conf
  ####################################################################
  local pane_bad=0 pane_ok=0 pane_mute=0 p_pid p_term
  if [[ -r /proc/self/environ ]]; then
    for sock_name in "${sockets[@]}"; do
      while read -r p_pid; do
        [[ "$p_pid" =~ ^[0-9]+$ ]] || continue
        if [[ -r "/proc/$p_pid/environ" ]]; then
          p_term="$(tr '\0' '\n' < "/proc/$p_pid/environ" 2>/dev/null | grep -m1 '^TERM=')" \
            || p_term=""
        else
          p_term=""
        fi
        if [[ -z "$p_term" ]]; then
          pane_mute=$(( pane_mute + 1 ))
        elif [[ "${p_term#TERM=}" == "$term_declared" ]]; then
          pane_ok=$(( pane_ok + 1 ))
        else
          pane_bad=$(( pane_bad + 1 ))
        fi
      done < <(timeout -k 2 5 tmux -L "$sock_name" list-panes -a -F '#{pane_pid}' 2>/dev/null)
    done

    if [[ $(( pane_ok + pane_bad )) -eq 0 ]]; then
      : # no pane answered; the 🌙 below carries it
    elif [[ "$pane_bad" -eq 0 ]]; then
      echo "   • all $pane_ok live pane(s) spawned with TERM=$term_declared ✔"
    else
      echo "   ✋ $pane_bad of $(( pane_ok + pane_bad )) live pane(s) hold a TERM the conf does NOT declare" >&2
      echo "      ⇒ TERM is copied into a pane's child AT SPAWN and never re-read, so" >&2
      echo "        these predate the conf reaching their server. the app inside each" >&2
      echo "        reads that TERM, concludes 8 colours, and EMITS only 8-colour" >&2
      echo "        codes — a clamp at the SOURCE that no client feature can undo" >&2
      echo "      ⇒ no re-apply repairs a pane. the server is already correct, so a" >&2
      echo "        NEW pane or window spawns right; these carry their old copy until" >&2
      echo "        they exit" >&2
      ################################################################
      # 🛑 the fix-text must name a command for a box with NO HUMAN on it
      #   - `prefix c` is a keystroke, so it presumes somebody sits at the
      #     keyboard that owns the pane. a grove's only affected pane is the
      #     DUCT's own, and nobody is there to press it
      #   - ⇒ a claim whose sole repair is unperformable fires on every apply
      #     forever, and a ✋ nobody can clear is the one that gets silenced
      #   - 📜 measured 2026-09-13 on a fresh grove: clamp C bit with
      #     `1 of 1 live pane(s)`, and its only fix-text was a keystroke
      #   - (`rule.require.one-command-provision`, its unrepairable-fix-text
      #      clause; `gotcha.a-check-that-cries-wolf-gets-silenced`)
      ################################################################
      echo "      fix, per affected pane — whichever reaches it:" >&2
      echo "        • a pane you sit at:  open a new one (prefix c / prefix %)" >&2
      echo "        • a grove's duct:     rhx duct.reboot --on 'duct://<grove>/<tree>/<role>'" >&2
      echo "          ⇒ the session, its name, its scrollback, and its cwd survive;" >&2
      echo "            only the pane's child dies, and its replacement spawns with" >&2
      echo "            the TERM the server now declares" >&2
      failed=$(( failed + 1 ))
    fi

    [[ "$pane_mute" -eq 0 ]] || {
      echo "   🌙 $pane_mute pane(s) did not answer — a pane can exit mid-read, and a"
      echo "      foreign process denies its own environ"
    }
  else
    echo "   🌙 /proc is unreadable here, so a pane's spawn-time TERM cannot be observed"
  fi

  ####################################################################
  # 🛑 claim: every ATTACHED client carries the features the conf declares
  #
  # 🛑 .why a CLIENT claim, when every claim above reads a SERVER
  #   - the conf's colour contract has TWO halves, applied at two moments:
  #
  #       default-terminal    a SERVER option, read when a PANE spawns
  #       terminal-features   read when a CLIENT ATTACHES, and never again
  #
  #   - ⇒ a source into a live server converges the first half and CANNOT
  #     converge the second: an attached client keeps what it negotiated
  #   - ⇒ a box can pass every claim above and still render wrong colour
  #
  # 🛑 .why that is a FALSE ✔ and not a cosmetic gap
  #   - 📜 2026-09-13, this laptop: the conf was sourced into 19 live servers,
  #     `2.8.tmux.configure.verify` printed ✔ on every claim, and the human
  #     reported broken colour in the same minute
  #   - the apply DOES warn about the reattach in prose, and prose is not a check
  #   - ⇒ a warning nobody re-reads is indistinguishable from an absent one
  #   - (`gotcha.a-check-that-cries-wolf-gets-silenced`, its false-✔ half)
  #
  # .why the SYMPTOM is a downsample and not an absence
  #   - an app inside a pane reads `default-terminal` and emits 24-bit SGR
  #   - the client was never flagged RGB, so tmux quantises each one to the
  #     nearest slot of a palette it believes is 8/16 colour
  #   - ⇒ orange reads red, red reads purple. the conf says so at its own
  #     `terminal-features` block, which is where this claim's subject is declared
  #
  # .why the conf is the DECLARATION, and no list is written here
  #   - the conf's own `set -as terminal-features` lines ARE the set
  #   - a second list here is one set with two readers, free to drift
  #   - (`rule.require.identical-bundle-composition`)
  #
  # ⚠️ a client whose TERM the conf never names is not graded
  #   - the conf declares per-term (`xterm-kitty:RGB`), so a client on another
  #     terminal is outside every declaration this conf makes
  ####################################################################
  local want=() decl
  while read -r decl; do
    decl="${decl#*terminal-features }"
    decl="${decl//\'/}"
    decl="${decl//\"/}"
    decl="${decl%%[[:space:]]*}"
    [[ "$decl" == *:* ]] && want+=("$decl")
  done < <(grep -E "^[[:space:]]*set[[:space:]]+-as[[:space:]]+terminal-features" "$conf_live" 2>/dev/null)

  if [[ ${#want[@]} -eq 0 ]]; then
    echo "   • the conf declares no terminal-features — no client claim to grade"
  else
    # ⚠️ SENTINEL-wrapped, for the reason claim 3 carries in full: an older tmux
    #   expands an unknown format to the empty string, which is the same text a
    #   supported-but-empty read returns. `A…Z` parts "no answer" from "answered"
    local seen=0 blind=0 stale=() c_raw c_term c_feats pair p_term p_feat
    for sock_name in "${sockets[@]}"; do
      while read -r c_raw; do
        [[ "$c_raw" == A*Z ]] || continue
        c_raw="${c_raw#A}"; c_raw="${c_raw%Z}"
        c_term="${c_raw%%|*}"
        c_feats="${c_raw#*|}"
        seen=$(( seen + 1 ))

        # a client that named no features at all: this tmux carries no
        # `client_termfeatures` (3.2+), so the claim cannot be observed here
        if [[ -z "$c_feats" ]]; then
          blind=$(( blind + 1 ))
          continue
        fi

        for pair in "${want[@]}"; do
          p_term="${pair%%:*}"
          p_feat="${pair##*:}"
          [[ "$c_term" == "$p_term" ]] || continue
          [[ ",$c_feats," == *",$p_feat,"* ]] && continue
          stale+=("$sock_name:$c_term lacks $p_feat")
        done
      done < <(timeout -k 2 5 tmux -L "$sock_name" list-clients \
                 -F 'A#{client_termname}|#{client_termfeatures}Z' 2>/dev/null)
    done

    if [[ "$seen" -eq 0 ]]; then
      echo "   • no client attached — the next attach reads the conf's features fresh"
    elif [[ ${#stale[@]} -eq 0 && "$blind" -eq 0 ]]; then
      echo "   • all $seen attached client(s) carry the declared features ✔ (${want[*]})"
    elif [[ ${#stale[@]} -eq 0 ]]; then
      echo "   🌙 $blind of $seen attached client(s) named no features, so this tmux"
      echo "      ($(tmux -V 2>/dev/null)) carries no 'client_termfeatures' (3.2+)"
      echo "      ⇒ the claim is unproven on this run, not disproven"
    else
      echo "   ✋ ${#stale[@]} attached client(s) lack a feature the conf declares" >&2
      echo "      ⇒ features are negotiated at ATTACH and never re-read, so a client" >&2
      echo "        that attached before this conf reached its server keeps the OLD" >&2
      echo "        set — and an RGB-less client DOWNSAMPLES every 24-bit colour an" >&2
      echo "        app emits: orange reads red, red reads purple" >&2
      echo "      ⇒ no re-apply repairs this. tmux offers no way to re-negotiate a" >&2
      echo "        live client's features, so the human's own reattach is the one" >&2
      echo "        repair — and it costs NO session, pane, or scrollback" >&2
      echo "      fix, per affected client: prefix d, then reattach" >&2
      echo "        (or close and reopen the terminal window)" >&2
      printf '        %s\n' "${stale[@]}" >&2
      failed=$(( failed + 1 ))
    fi
  fi

  [[ "$failed" -eq 0 ]] || return 1
}
