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

# .what = the tpm commit this repo installs, declared ONCE
# .why here, not inside `provision.upsert` — the state reader below compares
#   against the same value, so a second `local tpm_at=` would drift
#   (rule.require.bundle-as-sole-declaration)
# to bump: read the sha you mean, then change BOTH the value and this date
#   gh api -X GET repos/tmux-plugins/tpm/commits/master --jq .sha
GROVE_UPGRADE_2_8_TMUX_TPM_AT="e261deb1b47614eed3400089ce7197dc68acc4eb"  # master, 2026-05-17

# .why the PLUGINS need the same pin — tpm's tip is shell code `.tmux.conf`
#   RUNS every session, and `@continuum-restore 'on'` runs it UNATTENDED on
#   every server start, so push access to either repo is code execution on
#   every box; this bundle clones them itself via `git_clone --at`, and tpm
#   skips them (`@plugin` carries no ref, so the pin cannot live in the conf)
# to bump: read the sha you mean, then change BOTH the value and its date
#   gh api -X GET repos/tmux-plugins/tmux-resurrect/commits/master --jq .sha
GROVE_UPGRADE_2_8_TMUX_RESURRECT_AT="cff343cf9e81983d3da0c8562b01616f12e8d548"  # master, 2023-03-06
GROVE_UPGRADE_2_8_TMUX_CONTINUUM_AT="0698e8f4b17d6454c71bf5212895ec055c578da0"  # master, 2024-01-20

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
