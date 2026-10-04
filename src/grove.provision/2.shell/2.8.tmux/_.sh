#!/usr/bin/env bash
# .what = tmux, its plugin manager, its conf, and its plugins
# .why the BINARY lives HERE, beside its conf — a package name in one bundle
#   and a heredoc in another is one concern, two homes
#   (rule.require.bundle-as-sole-declaration)
# .why tmux is not a comfort on any box — a duct IS tmux, so on a grove it
#   is the only way the box is reachable; on a laptop it drives every termwork skill
# .why TPM is a provision act and the PLUGINS are a configure one — tpm is a
#   git clone of a tool that either exists or does not, and the plugins are
#   what the CONF asks for, so their install belongs beside it

# .what = where tpm ACTUALLY puts plugins on this box — asked, never assumed
# .why the root is DERIVED, never the constant `$HOME/.tmux/plugins` — tpm
#   picks an XDG root when one exists and publishes it as
#   `TMUX_PLUGIN_MANAGER_PATH`, so this reads that rather than re-derive it
#   .refs = gotcha.2-8-tmux.demo=plugin-root-and-two-readers, m1
# .why an absent server answers `1`, not a guess — `show-environment -g`
#   needs a live server; each caller decides what unknown means for its own claim
#
# guarantee:
#   - READ-ONLY. it queries a server that already runs; it starts none
#
# exit:
#   0 = the root is known, printed with no slash at the end
#   1 = no server to ask, so the root is unknown on this box
grove_provision_2_8_tmux_plugin_root() {
  local sock="${1:-}"
  local root

  # `timeout -k 2 5`, not `timeout 5` alone — a wedged tmux client may not
  # act on a bare TERM, and this ask is reached from every `--mode plan`
  # (rule.require.bounded-probes-in-verifies)
  # .refs = gotcha.2-8-tmux.demo=plugin-root-and-two-readers, m2
  if [[ -n "$sock" ]]; then
    root="$(timeout -k 2 5 tmux -L "$sock" show-environment -g TMUX_PLUGIN_MANAGER_PATH 2>/dev/null | cut -d= -f2-)"
  else
    root="$(timeout -k 2 5 tmux show-environment -g TMUX_PLUGIN_MANAGER_PATH 2>/dev/null | cut -d= -f2-)"
  fi

  [[ -n "$root" ]] || return 1
  printf '%s' "${root%/}"
}

# .what = every LIVE tmux server on this box, by socket name, one per line
#   `..._live_sockets` → `default`, `duct_worktree_mechanic`, …
# .why
#   - 🛑 each server holds its conf IN MEMORY, so every live one must be sourced
#   - the SOCKET DIR is the inventory, never `tmux ls` (one server's sessions)
#   - a stale socket file is left to the caller's own bounded probe
# .refs = gotcha.2-8-tmux.demo=plugin-root-and-two-readers, m4
#
# guarantee:
#   - READ-ONLY. it lists sockets; it starts no server and it kills none
#
# stdout: one socket name per line, `default` among them when it is up
grove_provision_2_8_tmux_live_sockets() {
  local dir="${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)"
  [[ -d "$dir" ]] || return 0

  local sock
  for sock in "$dir"/*; do
    [[ -S "$sock" ]] || continue
    printf '%s\n' "${sock##*/}"
  done
}

# .what = every conf tmux would load AFTER `~/.tmux.conf`, which is on disk
# .why there can only be one: a later conf wins every option both name, so a
#   shadow turns the repo's conf into a suggestion (m2, m10). the upsert retires
#   each; the verify names any that tmux still reports
#
# stdout: one path per line, deduped — the XDG root and its fallback coincide
grove_provision_2_8_tmux_shadow_confs() {
  local path seen=""
  for path in "${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf" "$HOME/.config/tmux/tmux.conf"; do
    [[ -f "$path" && "$seen" != *"|$path|"* ]] || continue
    seen+="|$path|"
    printf '%s\n' "$path"
  done
}

# .what = the tpm commit this repo installs, declared ONCE
# .why here, not inside `provision.upsert` — the state reader below compares
#   against the same value, so a second `local tpm_at=` would drift
#   (rule.require.bundle-as-sole-declaration)
# to bump: read the sha you mean, then change BOTH the value and this date
#   gh api -X GET repos/tmux-plugins/tpm/commits/master --jq .sha
GROVE_UPGRADE_2_8_TMUX_TPM_AT="e261deb1b47614eed3400089ce7197dc68acc4eb"  # master, 2026-05-17

# .why the PLUGIN needs the same pin — tpm sources each `@plugin`'s own `.tmux`
#   file at conf load, so resurrect's tip is shell code that runs UNATTENDED on
#   every server start; push access to that repo is code execution on every box.
#   this bundle clones it itself via `git_clone --at`, and tpm skips it
#   (`@plugin` carries no ref, so the pin cannot live in the conf)
# to bump: read the sha you mean, then change BOTH the value and its date
#   gh api -X GET repos/tmux-plugins/tmux-resurrect/commits/master --jq .sha
# 🛑 no continuum pin, DELIBERATELY — the plugin is removed. the why sits where
#   it would come back: `tmux.conf`, at its old `@plugin` line
GROVE_UPGRADE_2_8_TMUX_RESURRECT_AT="cff343cf9e81983d3da0c8562b01616f12e8d548"  # master, 2023-03-06

# .what = which of FOUR states is a PINNED plugin dir in?
#   `..._plugin_state "$HOME/.tmux/plugins/x" "$pin"` → absent|half|adrift|whole
# .why a STATE reader, not a `-d` test — a presence test lets the pin govern
#   only the FIRST apply, and a run cut partway leaves a carcass that passes
#   forever (rule.require.one-command-provision, the deterministic clause)
grove_provision_2_8_tmux_plugin_state() {
  local dir="$1" pin="$2" head

  [[ -e "$dir" ]] || { echo absent; return 0; }
  [[ -d "$dir/.git" && -r "$dir/.git/HEAD" ]] || { echo half; return 0; }

  head="$(cat "$dir/.git/HEAD" 2>/dev/null || true)"
  [[ "$head" == "$pin" ]] || { echo adrift; return 0; }

  echo whole
}

# .what = which of FOUR states is a tpm dir in?
#   `..._tpm_state "$HOME/.tmux/plugins/tpm"` → whole|adrift|half|absent
# .why ONE reader, asked by BOTH halves — a separate `-d` (upsert) and `-x`
#   (verify) test disagreed on a killed-mid-clone carcass and on a
#   wrong-commit checkout, and both are invisible to a plain presence test
#   .refs = gotcha.2-8-tmux.demo=plugin-root-and-two-readers, m3
# .why the sha reads from `.git/HEAD`, not `git rev-parse` — `git_clone`
#   checks out `--detach`, so HEAD holds the raw 40-char sha, and a plain
#   read answers it even where git is not yet on PATH
#
# stdout:
#   whole  = a usable checkout, at the declared commit
#   adrift = a usable checkout, at some OTHER commit
#   half   = the path is occupied by what is not a usable checkout
#   absent = the path is free
grove_provision_2_8_tmux_tpm_state() {
  local dir="$1" head

  [[ -e "$dir" ]] || { echo absent; return 0; }

  # a usable tpm is a git checkout WHOSE ENTRYPOINT RUNS — `~/.tmux.conf`
  # execs `tpm/tpm`, so a checkout without it is as broken as no checkout
  [[ -d "$dir/.git" && -r "$dir/.git/HEAD" && -x "$dir/tpm" ]] \
    || { echo half; return 0; }

  head="$(cat "$dir/.git/HEAD" 2>/dev/null || true)"
  [[ "$head" == "$GROVE_UPGRADE_2_8_TMUX_TPM_AT" ]] || { echo adrift; return 0; }

  echo whole
}

# .what = the verify's LIVE claims: every server, pane and client holds what the conf declares
#   `..._verify_live_servers "$conf_live" "$term_declared"` → 0 = none disproven, 1 = a ✋ printed
# .why a conf on disk proves only what the NEXT server loads — each surface below reads it at
#   its own moment and keeps its copy (.refs = gotcha.2-8-tmux.demo=verify-from-conf-to-client)
#
# guarantee:
#   - READ-ONLY, and every ask is bounded (rule.require.bounded-probes-in-verifies)
grove_provision_2_8_tmux_verify_live_servers() {
  local conf_live="$1" term_declared="$2"
  local failed=0

  # 🛑 no live server still runs a plugin the conf no longer names — `status-right` IS the
  #    timer, and an unreachable socket is a corpse, so a 🌙 (m7)
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

  # 🛑 every live SERVER holds the declared default-terminal — one started before the conf
  #    still holds `screen` (m6)
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

  # 🛑 every live PANE spawned with the declared TERM, read from its child's own
  #    `/proc/<pid>/environ`; the fix-text names a repair for a box with no human (m8)
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

  # 🛑 every ATTACHED client carries the declared features — negotiated at attach, never
  #    again, so a sourced server leaves an old client downsampled (m9). `A…Z` as in m4
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
    local seen=0 blind=0 stale=() c_raw c_term c_feats pair p_term p_feat
    for sock_name in "${sockets[@]}"; do
      while read -r c_raw; do
        [[ "$c_raw" == A*Z ]] || continue
        c_raw="${c_raw#A}"; c_raw="${c_raw%Z}"
        c_term="${c_raw%%|*}"
        c_feats="${c_raw#*|}"
        seen=$(( seen + 1 ))

        # no features at all: this tmux carries no `client_termfeatures` (3.2+)
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

  [[ "$failed" -eq 0 ]]
}

grove_provision_2_8_tmux() {
  bundle.upgrade 2.8.tmux.provision.upsert
  bundle.upgrade 2.8.tmux.provision.verify
  bundle.upgrade 2.8.tmux.configure.upsert
  bundle.upgrade 2.8.tmux.configure.verify
}
