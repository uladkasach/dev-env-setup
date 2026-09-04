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
  local loaded shadow=()
  loaded="$(timeout -k 2 5 tmux display-message -p '#{config_files}' 2>/dev/null || true)"
  if [[ -z "$loaded" ]]; then
    echo "   🌙 no tmux server answered, so which confs tmux loads cannot be observed"
    echo "      ⇒ either none runs, or one runs and did not reply within 5s"
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
      echo "      ⇒ tmux-resurrect and tmux-continuum are what restore a session" >&2
      echo "        across a reboot, so their absence costs the duct its memory" >&2
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
    echo "      fix: declare it in src/tmux.conf, then re-apply this bundle" >&2
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

  [[ "$failed" -eq 0 ]] || return 1
}
