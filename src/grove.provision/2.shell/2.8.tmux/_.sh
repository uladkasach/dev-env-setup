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

# .what = the pinned plugins, read one fact at a time
#   `..._plugin_names`     → each plugin's tpm dir name, one per line
#   `..._plugin_url <n>`   → where `<n>` clones from
#   `..._plugin_at <n>`    → the commit `<n>` is pinned to
# .why the dir NAME is tpm's contract: `@plugin 'owner/name'` resolves to
#   `~/.tmux/plugins/<name>`, so the name keys every other fact
# ⚠️ this set and the conf's `@plugin` lines are ONE SET, TWO READERS — a change
#   to either belongs in the same edit as the other
grove_provision_2_8_tmux_plugin_names() {
  printf '%s\n' tmux-resurrect
}

grove_provision_2_8_tmux_plugin_url() {
  case "$1" in
    tmux-resurrect) printf 'https://github.com/tmux-plugins/tmux-resurrect' ;;
    *) return 1 ;;
  esac
}

grove_provision_2_8_tmux_plugin_at() {
  case "$1" in
    tmux-resurrect) printf '%s' "$GROVE_UPGRADE_2_8_TMUX_RESURRECT_AT" ;;
    *) return 1 ;;
  esac
}

######################################################################
# .what = the tmux BUILD a cloud grove runs, declared ONCE
#
# 🛑 .why a grove does not take the distro package
#   - jammy ships `tmux 3.2a-4ubuntu0.2`. on a grove its SERVER segfaulted ~110
#     times in hours at one offset, and every crew shares a server, so each
#     segfault ended every crew on the box at once
#   - ⚠️ the TRIGGER is unproven. tmux 3.3a's CHANGES reads "Do not crash when
#     run-shell produces output from a config file", and this conf ends with a
#     `run` line — but `prove.tmux-pin-survives-config-run-output` started a
#     fresh 3.2a server on that path, and on the real conf, and both LIVED
#     (2026-10-23). so the pin rests on the measured crash in the 3.2a build,
#     never on a named fix in 3.5a; `1.6.8.coredump` makes the next one readable
#   - ⇒ a grove builds this pinned release into `/usr/local/bin`, which precedes
#     `/usr/bin` on PATH, so the distro binary may stay installed and is never
#     the one a crew reaches
#
# ⚠️ .why a laptop is out of this pin — a SCOPE call, not a physical one
#   - the defect was measured on a cloud grove, and the route that added the pin
#     was scoped to cloud groves by its director; a laptop runs its distro tmux
#   - ⚠️ no physical fact parts the two: a laptop can build and hold 3.5a, so by
#     `rule.forbid.divergence-without-a-physical-reason` this divergence is a
#     miss owed a route of its own, never an approved one
#
# ⚠️ .why the digest is pinned from TWO sources
#   - tmux publishes no signature and github states no digest for this asset
#   - the value below is homebrew-core's pin for the same url (commit 77313c2,
#     `bump-tmux-3.5a`), and `prove.tmux-tarball-matches-the-pin` fetches the
#     bytes through `web_fetch` and checks them against it
#   - ⇒ two parties, one of them not github, agree on the bytes
#
# to bump: change all three together, read the new digest from a second
#   party, then run `rhx play.run --play prove.tmux-tarball-matches-the-pin`
######################################################################
GROVE_UPGRADE_2_8_TMUX_VERSION="3.5a"
GROVE_UPGRADE_2_8_TMUX_URL="https://github.com/tmux/tmux/releases/download/3.5a/tmux-3.5a.tar.gz"
GROVE_UPGRADE_2_8_TMUX_SHA256="sha256:16216bd0877170dfcc64157085ba9013610b12b082548c7c9542cc0103198951"

# .what = where the pinned build lives
grove_provision_2_8_tmux_pin_dst() { printf '/usr/local/bin/tmux'; }

# .what = the tmux on PATH: its path, its version, and which of THREE states
#   `..._binary_path`    → the path PATH resolves, or empty
#   `..._binary_version` → what `tmux -V` names, `unreadable`, or empty if absent
#   `..._binary_state`   → `pinned` | `adrift` | `absent`
# .why ONE family of readers, asked by both halves — the upsert's skip and the
#   verify's ✋ must agree on what "converged" means, or a box reads ✔ and rebuilds
# .why the VERSION decides, never the path — a keepalive build and a provision
#   build of one release are one state (.refs = 1.vision case 4)
#
# guarantee:
#   - READ-ONLY. `tmux -V` starts no server; bounded, and fed no stdin
#     (rule.require.bounded-probes-in-verifies)
grove_provision_2_8_tmux_binary_path() {
  command -v tmux 2>/dev/null
}

grove_provision_2_8_tmux_binary_version() {
  local bin ver
  bin="$(grove_provision_2_8_tmux_binary_path)" || return 0
  ver="$(timeout -k 2 5 "$bin" -V </dev/null 2>/dev/null)"
  ver="${ver#tmux }"
  printf '%s' "${ver:-unreadable}"
}

grove_provision_2_8_tmux_binary_state() {
  local ver; ver="$(grove_provision_2_8_tmux_binary_version)"
  [[ -z "$ver" ]] && { printf 'absent'; return 0; }
  [[ "$ver" == "$GROVE_UPGRADE_2_8_TMUX_VERSION" ]] && { printf 'pinned'; return 0; }
  printf 'adrift'
}

# .what = what the build at the pin path names itself, or empty if no build sits there
# .why the pin path and PATH's answer can part: a tmux earlier on PATH shadows the pin,
#   and a rebuild cannot fix that — so the upsert asks both before it builds
grove_provision_2_8_tmux_pin_dst_version() {
  local dst ver; dst="$(grove_provision_2_8_tmux_pin_dst)"
  [[ -x "$dst" ]] || return 0
  ver="$(timeout -k 2 5 "$dst" -V </dev/null 2>/dev/null)"
  printf '%s' "${ver#tmux }"
}

# .what = is the pin placed, yet a different tmux answers first on PATH?
grove_provision_2_8_tmux_pin_is_shadowed() {
  [[ "$(grove_provision_2_8_tmux_binary_state)" != pinned ]] \
    && [[ "$(grove_provision_2_8_tmux_pin_dst_version)" == "$GROVE_UPGRADE_2_8_TMUX_VERSION" ]]
}

# .what = the ✋ for a pin that sits at its path while PATH resolves another tmux first
#   asked by the upsert (before a build, and after the swap) and by the verify
#   an empty `<shadow>` means PATH holds no tmux at all: the pin's dir is off PATH
grove_provision_2_8_tmux_pin_shadow_refusal() {
  local shadow="$1" dst="$2"
  if [[ -z "$shadow" ]]; then
    echo "   ✋ ConstraintError: tmux $GROVE_UPGRADE_2_8_TMUX_VERSION sits at $dst, but PATH holds no tmux" >&2
    echo "      ⇒ $(dirname "$dst") is off this PATH, so no caller finds the pin" >&2
    echo "      ⇒ no rebuild is attempted: the pin is already built, and a rebuild cannot move PATH" >&2
    echo "      read why: echo \"\$PATH\"" >&2
    echo "      fix: put $(dirname "$dst") on PATH for this seat's shells" >&2
    return 0
  fi
  echo "   ✋ ConstraintError: tmux $GROVE_UPGRADE_2_8_TMUX_VERSION sits at $dst, but PATH resolves $shadow first" >&2
  echo "      ⇒ every caller that asks PATH gets the shadow, so the pin protects no crew" >&2
  echo "      ⇒ no rebuild is attempted: the pin is already built, and a rebuild cannot move PATH" >&2
  echo "      read why: type -a tmux" >&2
  echo "      fix: remove $shadow, or put $(dirname "$dst") ahead of $(dirname "$shadow") on PATH" >&2
}

# .what = the line a pin refusal prints about the box's tmux, true on a fresh grove too
# .why a refusal leaves the box as it found it; what that MEANS turns on whether a tmux
#   was there to keep
grove_provision_2_8_tmux_refusal_note() {
  if [[ "$(grove_provision_2_8_tmux_binary_state)" == absent ]]; then
    printf '      ⇒ this box held no tmux before this step, and the floor below decides what it holds now\n'
    return 0
  fi
  printf '      ⇒ the prior tmux is untouched; no crew lost its server\n'
}

# .what = which state does THIS tier owe? a grove owes the pin; any other tier
#   owes a tmux present at all (the pin is grove-scoped, F2 struck)
grove_provision_2_8_tmux_binary_owed() {
  [[ "${GROVE_ENV_SERVER:-}" == cloud@* ]] && { printf 'pinned'; return 0; }
  printf 'present'
}

# .what = does the tmux on PATH meet what this tier owes?
# .why a tmux that does not answer `-V` meets no tier: a file on PATH is not a binary
#   that runs, and a duct needs one that runs
grove_provision_2_8_tmux_binary_meets_owed() {
  local state; state="$(grove_provision_2_8_tmux_binary_state)"
  [[ "$state" == pinned ]] && return 0
  [[ "$(grove_provision_2_8_tmux_binary_version)" == unreadable ]] && return 1
  [[ "$state" == adrift && "$(grove_provision_2_8_tmux_binary_owed)" == present ]]
}

# .what = each live server's OWN build, one `<socket>=<version>` per line, or
#   `<socket>=unreadable` for a server that did not name it
# .why  = a server keeps the binary it started on until it ends (vision case 10);
#   `#{version}` is the server's answer, never the client's. a silent server is
#   reported as such, so a clean read is never inferred from an absent line
grove_provision_2_8_tmux_server_versions() {
  local sock_name srv_ver
  while read -r sock_name; do
    [[ -n "$sock_name" ]] || continue
    srv_ver="$(timeout -k 2 5 tmux -L "$sock_name" display-message -p '#{version}' </dev/null 2>/dev/null)"
    printf '%s=%s\n' "$sock_name" "${srv_ver:-unreadable}"
  done < <(grove_provision_2_8_tmux_live_sockets)
}

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

# .what = each named plugin under a root, judged against its pin, one `<name>=<state>` per line
#   `..._plugins_judged "$root" tpm tmux-resurrect` → `tpm=present`, `tmux-resurrect=whole`
#   states: whole | adrift | half | absent (from `plugin_state`), `unpinned` for a name this
#   repo pins no commit for, and `present` for tpm, which `provision.verify` grades at its pin
# .why the verify asks the SAME state reader the upsert asks, so the two cannot disagree on a
#   carcass or a checkout at another commit (the defect `tpm_state` already cured for tpm)
grove_provision_2_8_tmux_plugins_judged() {
  local root="$1"; shift
  local name pin
  for name in "$@"; do
    if [[ "$name" == tpm ]]; then
      [[ -d "$root/$name" ]] && printf '%s=present\n' "$name" || printf '%s=absent\n' "$name"
      continue
    fi
    pin="$(grove_provision_2_8_tmux_plugin_at "$name")" || { printf '%s=unpinned\n' "$name"; continue; }
    printf '%s=%s\n' "$name" "$(grove_provision_2_8_tmux_plugin_state "$root/$name" "$pin")"
  done
}

# .what = the tpm entrypoint a conf's `run` line names, `~` expanded
#   `..._tpm_bin_of_conf "$HOME/.tmux.conf"` → `/home/<user>/.tmux/plugins/tpm/tpm`
# .why the PATH is the conf's to declare, never this bundle's; tpm's historical
#   default answers only when the conf names no run line, or is absent
grove_provision_2_8_tmux_tpm_bin_of_conf() {
  local conf="$1" bin=""
  [[ -f "$conf" ]] && bin="$(grep -oE "run(-shell)? +'[^']*tpm/tpm'" "$conf" 2>/dev/null \
    | head -1 | grep -oE "'[^']*'" | tr -d "'")"
  bin="${bin/#\~/$HOME}"
  printf '%s' "${bin:-$HOME/.tmux/plugins/tpm/tpm}"
}

# .what = the plugin names a conf declares, one per line, each the basename of its repo
#   `..._plugin_names_of_conf "$HOME/.tmux.conf"` → `tpm`, `tmux-resurrect`
# .why the upsert and the verify must agree on what "the conf names" means; one reader
#   reads only live `set -g @plugin` lines, so a commented-out plugin is owed by neither
grove_provision_2_8_tmux_plugin_names_of_conf() {
  local conf="$1" line repo
  while IFS= read -r line; do
    repo="${line#*@plugin }"
    repo="${repo//\'/}"
    repo="${repo//\"/}"
    repo="${repo%%[[:space:]]*}"
    [[ -n "$repo" ]] && printf '%s\n' "${repo##*/}"
  done < <(grep -E "^[[:space:]]*set[[:space:]]+-g[[:space:]]+@plugin" "$conf" 2>/dev/null)
}

# .what = the suffix a shadow conf takes when it is moved aside, e.g. `20261023-104339`
grove_provision_2_8_tmux_backup_stamp() { date +%Y%m%d-%H%M%S; }

# .what = the names, of those given, with no dir under the plugin root — one per line
#   `..._plugins_absent_under "$root" tpm tmux-resurrect` → `tmux-resurrect`
grove_provision_2_8_tmux_plugins_absent_under() {
  local root="$1" name; shift
  for name in "$@"; do
    [[ -d "$root/$name" ]] || printf '%s\n' "$name"
  done
}

# .what = each value a conf declares for one option, in file order, unquoted, first word
#   `..._conf_values_of "$conf" -as terminal-features` → `xterm-kitty:RGB`, …
grove_provision_2_8_tmux_conf_values_of() {
  local conf="$1" flags="$2" option="$3" line value
  while IFS= read -r line; do
    value="${line#*"$option"}"
    value="${value//\'/}"
    value="${value//\"/}"
    read -r value _ <<<"$value"
    [[ -n "$value" ]] && printf '%s\n' "$value"
  done < <(grep -E "^[[:space:]]*set[[:space:]]+${flags}[[:space:]]+${option}([[:space:]]|$)" "$conf" 2>/dev/null)
}

# .what = the default-terminal a conf declares — the LAST line wins, as tmux reads it
grove_provision_2_8_tmux_default_terminal_of_conf() {
  grove_provision_2_8_tmux_conf_values_of "$1" -g default-terminal | tail -1
}

# .what = the `term:feature` pairs a conf declares, one per line
grove_provision_2_8_tmux_terminal_features_of_conf() {
  local pair
  while read -r pair; do
    [[ "$pair" == *:* ]] && printf '%s\n' "$pair"
  done < <(grove_provision_2_8_tmux_conf_values_of "$1" -as terminal-features)
}

# .what = the body of an `A…Z` sentinel answer; an answer of `AZ` has an empty body
# .why the sentinel parts "the server spoke, and named naught" from "no answer at all"
grove_provision_2_8_tmux_sentinel_body() {
  local body="${1#A}"
  printf '%s' "${body%Z}"
}

# .what = the confs a server loaded, one per line, from its `#{config_files}` list
grove_provision_2_8_tmux_config_files_of() {
  printf '%s\n' "$1" | tr ',' '\n'
}

# .what = a client's term and its feature list, from a `term|feat,feat` body
grove_provision_2_8_tmux_client_term_of() { printf '%s' "${1%%|*}"; }
grove_provision_2_8_tmux_client_features_of() { printf '%s' "${1#*|}"; }

# .what = the term and the feature of one declared `term:feature` pair
grove_provision_2_8_tmux_pair_term_of() { printf '%s' "${1%%:*}"; }
grove_provision_2_8_tmux_pair_feature_of() { printf '%s' "${1##*:}"; }

# .what = does a client's comma list of features hold this one feature?
grove_provision_2_8_tmux_client_has_feature() {
  local feats="$1" feat="$2"
  [[ ",$feats," == *",$feat,"* ]]
}

# .what = the TERM a pane's child spawned with, from its own `/proc/<pid>/environ`
#   → exit 1 when the environ is unreadable or names no TERM
grove_provision_2_8_tmux_pane_term_of() {
  local pid="$1" entry
  [[ -r "/proc/$pid/environ" ]] || return 1
  entry="$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | grep -m1 '^TERM=')" || return 1
  printf '%s' "${entry#TERM=}"
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
  local sockets=() haunted=() mute=0 muted=" " right sock_name
  while read -r sock_name; do
    [[ -n "$sock_name" ]] && sockets+=("$sock_name")
  done < <(grove_provision_2_8_tmux_live_sockets)

  for sock_name in "${sockets[@]}"; do
    right="$(timeout -k 2 5 tmux -L "$sock_name" show-options -gv status-right 2>/dev/null)" \
      || { mute=$(( mute + 1 )); muted+="$sock_name "; continue; }
    [[ "$right" == *continuum* ]] && haunted+=("$sock_name")
  done

  # a mute socket is a corpse, never a live server — so it is counted below, apart
  local live=$(( ${#sockets[@]} - mute ))
  if [[ "$live" -eq 0 ]]; then
    echo "   • no tmux server up — none holds a stale conf"
  elif [[ ${#haunted[@]} -eq 0 ]]; then
    echo "   • $live live server(s), none runs a removed plugin's hook ✔"
  else
    echo "   ✋ ConstraintError: ${#haunted[@]} of $live live tmux server(s) still run a hook" >&2
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
    echo "      read why: coredumpctl list tmux   (a server that crashed leaves its core there)"
  }

  # 🌙 a live server older than the pin swap still runs the build it started on (case 10)
  #   - `#{version}` is the SERVER's own answer, never the client's
  #   - a 🌙, never a ✋: the only cure is a restart, and a restart ends every session on
  #     that server — a choice for whoever owns those sessions, never for an apply
  #   - it reads the sockets of the seat that runs the verify (`live_sockets`), so a seat
  #     sees its own servers only; the crew seat's own plan is the one that names them
  #   - 🛑 it prints no command that ends a server: the seat that reads it is a crew seat,
  #     often an agent inside a pane on that very server, and to end it ends every crew
  if [[ "$(grove_provision_2_8_tmux_binary_owed)" == pinned ]]; then
    local prior=() on_pin=0 unread=0 one
    while read -r one; do
      [[ -n "$one" ]] || continue
      case "${one#*=}" in
        "$GROVE_UPGRADE_2_8_TMUX_VERSION") on_pin=$(( on_pin + 1 )) ;;
        # a socket mute to BOTH asks is a corpse, reported once above; one that answered the
        #   walk above and not this ask is a live server with no build named
        unreadable) [[ "$muted" == *" ${one%%=*} "* ]] || unread=$(( unread + 1 )) ;;
        *) prior+=("$one") ;;
      esac
    done < <(grove_provision_2_8_tmux_server_versions)
    [[ ${#prior[@]} -eq 0 && "$on_pin" -gt 0 ]] \
      && echo "   • $on_pin live server(s) run the pinned build ($GROVE_UPGRADE_2_8_TMUX_VERSION) ✔"
    [[ "$unread" -gt 0 ]] \
      && echo "   🌙 $unread live server(s) did not name their build — not graded against the pin"
    [[ ${#prior[@]} -eq 0 ]] || {
      echo "   🌙 ${#prior[@]} live server(s) still run a build older than the pin"
      echo "      ⇒ each keeps the binary it started on until it ends; a new server takes the pin"
      echo "      ⇒ no apply restarts them, and no seat inside one should: a restart ends EVERY"
      echo "        session on that server — while crews share one server, that is every crew"
      echo "        on it, the reader's own session among them"
      echo "      next: a human decides when those sessions may end. once each crew holds its"
      echo "        own server (nheuron#44), a crew's restart moves only that crew to the pin"
      echo "      servers: ${prior[*]}"
    }
  fi

  # 🛑 every live SERVER holds the declared default-terminal — one started before the conf
  #    still holds `screen` (m6)
  local term_wrong=() term_live
  for sock_name in "${sockets[@]}"; do
    term_live="$(timeout -k 2 5 tmux -L "$sock_name" show-options -gv default-terminal 2>/dev/null)" \
      || continue
    [[ -n "$term_live" ]] || continue
    [[ "$term_live" == "$term_declared" ]] || term_wrong+=("$sock_name=$term_live")
  done

  # graded on LIVE servers: a corpse answers no option, so a count of sockets would print ✔ over none
  if [[ "$live" -eq 0 ]]; then
    : # no server up — the claim above already covers what the next one loads
  elif [[ ${#term_wrong[@]} -eq 0 ]]; then
    echo "   • every live server holds default-terminal '$term_declared' ✔"
  else
    echo "   ✋ ConstraintError: ${#term_wrong[@]} live server(s) hold a default-terminal the conf does NOT declare" >&2
    echo "      ⇒ each pane spawned there inherits that TERM and EMITS to match, so" >&2
    echo "        an 8-colour entry clamps colour at its source — invisible to every" >&2
    echo "        claim above, which read the conf rather than the server" >&2
    echo "      fix: rhx grove.provision --what 2.8.tmux --mode apply" >&2
    echo "      ⚠️ a pane that ALREADY exists keeps its spawn-time TERM, so open a" >&2
    echo "        new window or pane to see the repair" >&2
    echo "      servers: ${term_wrong[*]}" >&2
    failed=$(( failed + 1 ))
  fi

  # 🛑 every live PANE spawned with the declared TERM, read from its child's own
  #    `/proc/<pid>/environ`; the fix-text names a repair for a box with no human (m8)
  local pane_bad=0 pane_ok=0 pane_mute=0 p_pid p_term
  if [[ -r /proc/self/environ ]]; then
    for sock_name in "${sockets[@]}"; do
      while read -r p_pid; do
        [[ "$p_pid" =~ ^[0-9]+$ ]] || continue
        p_term="$(grove_provision_2_8_tmux_pane_term_of "$p_pid")" || p_term=""
        if [[ -z "$p_term" ]]; then
          pane_mute=$(( pane_mute + 1 ))
        elif [[ "$p_term" == "$term_declared" ]]; then
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
      echo "   ✋ ConstraintError: $pane_bad of $(( pane_ok + pane_bad )) live pane(s) hold a TERM the conf does NOT declare" >&2
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
    [[ -n "$decl" ]] && want+=("$decl")
  done < <(grove_provision_2_8_tmux_terminal_features_of_conf "$conf_live")

  if [[ ${#want[@]} -eq 0 ]]; then
    echo "   • the conf declares no terminal-features — no client claim to grade"
  else
    local seen=0 blind=0 stale=() c_raw c_term c_feats pair p_term p_feat
    for sock_name in "${sockets[@]}"; do
      while read -r c_raw; do
        [[ "$c_raw" == A*Z ]] || continue
        c_raw="$(grove_provision_2_8_tmux_sentinel_body "$c_raw")"
        c_term="$(grove_provision_2_8_tmux_client_term_of "$c_raw")"
        c_feats="$(grove_provision_2_8_tmux_client_features_of "$c_raw")"
        seen=$(( seen + 1 ))

        # no features at all: this tmux carries no `client_termfeatures` (3.2+)
        if [[ -z "$c_feats" ]]; then
          blind=$(( blind + 1 ))
          continue
        fi

        for pair in "${want[@]}"; do
          p_term="$(grove_provision_2_8_tmux_pair_term_of "$pair")"
          p_feat="$(grove_provision_2_8_tmux_pair_feature_of "$pair")"
          [[ "$c_term" == "$p_term" ]] || continue
          grove_provision_2_8_tmux_client_has_feature "$c_feats" "$p_feat" && continue
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
      echo "   ✋ ConstraintError: ${#stale[@]} attached client(s) lack a feature the conf declares" >&2
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

######################################################################
# .what = the pin's build operations — floor, toolchain, fetch, build, install
# .why here: each is one step `provision.upsert` composes; the phase keeps the order
######################################################################

# .what = on a grove with NO tmux, after the pin did not land: lay the distro tmux as a floor
# .why a duct IS tmux — a grove with none cannot be reached at all, which is worse than
#   the 3.2a build the pin replaces. the verify still ✋s, since the pin stays owed
#   - never beside a placed pin: there the cure is PATH, and a second tmux adds a shadow
grove_provision_2_8_tmux_pin_floor() {
  [[ "$(grove_provision_2_8_tmux_binary_state)" == absent ]] || return 0
  [[ "$(grove_provision_2_8_tmux_pin_dst_version)" == "$GROVE_UPGRADE_2_8_TMUX_VERSION" ]] && return 0
  if pkg_install tmux; then
    hash -r 2>/dev/null
    echo "   🌙 the pin did not land and this grove held no tmux, so the distro tmux is laid as a floor"
    echo "      ⇒ the box stays reachable over a duct, on the build whose server segfaulted;"
    echo "        the pin is still owed, and the verify says so"
    return 0
  fi
  echo "   ✋ ConstraintError: the pin did not land, and the distro tmux floor did not install either" >&2
  echo "      ⇒ this grove holds no tmux, so no duct can reach it" >&2
  echo "      read why: sudo apt-get install tmux" >&2
  return 1
}

# .what = the toolchain the build needs — each one an ordinary apt package
# .note = no yacc: a release tarball ships its parser pre-generated
grove_provision_2_8_tmux_pin_toolchain() {
  pkg_install build-essential pkg-config libevent-dev libncurses-dev && return 0
  echo "   ✋ ConstraintError: the tmux build toolchain did not install" >&2
  grove_provision_2_8_tmux_refusal_note >&2
  echo "      read why: sudo apt-get install build-essential pkg-config libevent-dev libncurses-dev" >&2
  return 1
}

# .what = fetch the pinned tarball, and verify it BEFORE any byte reaches a compiler
grove_provision_2_8_tmux_pin_fetch() {
  local tarball="$2"
  if ! web_fetch "$GROVE_UPGRADE_2_8_TMUX_URL" --into "$tarball"; then
    echo "   ✋ ConstraintError: could not fetch tmux $GROVE_UPGRADE_2_8_TMUX_VERSION" >&2
    grove_provision_2_8_tmux_refusal_note >&2
    echo "      read why: $GROVE_UPGRADE_2_8_TMUX_URL" >&2
    return 1
  fi
  web_verify_sha256 --file "$tarball" --sha256 "$GROVE_UPGRADE_2_8_TMUX_SHA256" && return 0
  # the runtime's ✋ above already names the miss; these lines are its tmux share, one block
  echo "      ⇒ the tmux tarball is discarded unbuilt" >&2
  grove_provision_2_8_tmux_refusal_note >&2
  echo "      ⇒ either the transfer corrupted, or the release was re-uploaded" >&2
  echo "      read why: rhx play.run --play prove.tmux-tarball-matches-the-pin" >&2
  echo "           a green there means the transfer corrupted — re-run the apply;" >&2
  echo "           a red means the release moved — re-pin from a second party (see _.sh)" >&2
  return 1
}

# .what = build tmux from a verified tarball, into `<dir>/tmux-<version>/tmux`
# .why the log outlives the temp dir — a compiler error is the one fact a ✋ here must hand over
grove_provision_2_8_tmux_pin_build() {
  local tarball="$2" into="$4"
  local log_dir="$HOME/.local/state/grove.provision"
  local log="$log_dir/2.8.tmux.build.log"
  # mkdir's own complaint rides inside the ✋ as its cause, never as a bare line above it
  local mkdir_err
  # LC_ALL=C: the tool's words ride inside the ✋ as `cause:`, and one locale keeps them alike on every box
  mkdir_err="$(LC_ALL=C mkdir -p "$log_dir" 2>&1)" || {
    echo "   ✋ ConstraintError: no dir for the tmux build log at $log_dir" >&2
    grove_provision_2_8_tmux_refusal_note >&2
    echo "      cause: ${mkdir_err#mkdir: }" >&2
    echo "      read why: ls -ld \"$(dirname "$log_dir")\"" >&2
    return 1
  }

  # the build is quiet for minutes, so say so first; `nice` keeps it below live crews
  echo "   • tmux $GROVE_UPGRADE_2_8_TMUX_VERSION builds from source now — a few minutes (log: $log)"
  local src="$into/tmux-$GROVE_UPGRADE_2_8_TMUX_VERSION"
  { tar -xzf "$tarball" -C "$into" \
      && ( cd "$src" && ./configure --prefix=/usr/local && nice -n 10 make -j"$(nproc)" ); } \
    >"$log" 2>&1 && return 0
  echo "   ✋ ConstraintError: tmux $GROVE_UPGRADE_2_8_TMUX_VERSION did not build" >&2
  grove_provision_2_8_tmux_refusal_note >&2
  echo "      read why: tail -40 $log" >&2
  return 1
}

# .what = place a built binary at `<dst>`: install beside it, then rename over it
# .why a rename, never a write in place: a live server holds the old inode (ETXTBSY);
#   the same stage-then-rename `1.10.hosts` uses for `/etc/hosts`
grove_provision_2_8_tmux_pin_install() {
  local from="$2" dst="$4"
  local stage="$dst.grove-provision.new"
  sudo install -m 0755 -o root -g root "$from" "$stage" && sudo mv -f "$stage" "$dst" && return 0
  sudo rm -f "$stage" 2>/dev/null
  echo "   ✋ ConstraintError: the built tmux could not be placed at $dst" >&2
  grove_provision_2_8_tmux_refusal_note >&2
  echo "      read why: ls -l $(dirname "$dst")" >&2
  return 1
}

grove_provision_2_8_tmux() {
  bundle.upgrade 2.8.tmux.provision.upsert
  bundle.upgrade 2.8.tmux.provision.verify
  bundle.upgrade 2.8.tmux.configure.upsert
  bundle.upgrade 2.8.tmux.configure.verify
}
