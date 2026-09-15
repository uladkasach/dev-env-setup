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
#
# 🛑 .why a box holds MORE THAN ONE server, and why that is the whole point
#   - a conf is read at SERVER start, so each server holds its own copy IN MEMORY
#   - ⇒ a write to `~/.tmux.conf` reaches exactly zero live servers
#   - and a source into the DEFAULT socket reaches exactly one of however many
#   - 📜 2026-09-13, this laptop: 16 sockets — the duct server, a `copygate`, and
#     14 probe corpses left by `prove.*` plays. so the count is small and it is
#     not one, and a phase that converges only `default` leaves the rest adrift
#
# ⚠️ .the ducts are SESSIONS on one server, not a server each
#   - ductwork addresses `-t "$DUCT_SESSION"`, so 74 ducts share one socket
#   - a prior draft here claimed one `-L` server per duct and was wrong
#   - ⇒ it changes the MAGNITUDE and not the claim: a live server still holds an
#     in-memory conf, and a removed plugin's option still outlives its `@plugin`
#     line, so every live server must be sourced whatever the count
#
# .why the SOCKET DIR is asked rather than a session list
#   - tmux keeps one unix socket per server under `${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/`
#   - ⇒ the dir IS the inventory, so no second list can drift from it
#   - a stale file is left for the caller's own bounded probe to answer
#   - ⚠️ never `tmux ls`: it speaks to ONE server and reports its SESSIONS
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
#
# 🛑 there is no continuum pin, and its absence is DELIBERATE — the plugin is
#   removed, since its per-server autosave timer storms a box that runs one tmux
#   server per duct. the measurement, and why resurrect is unaffected, sit at the
#   site that would re-introduce it: `tmux.conf`, where the `@plugin` line was
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

grove_provision_2_8_tmux() {
  bundle.upgrade 2.8.tmux.provision.upsert
  bundle.upgrade 2.8.tmux.provision.verify
  bundle.upgrade 2.8.tmux.configure.upsert
  bundle.upgrade 2.8.tmux.configure.verify
}
