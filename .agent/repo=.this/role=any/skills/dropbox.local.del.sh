#!/usr/bin/env bash
######################################################################
# .what = delete this machine's dropbox — its local folder, and with
#         `--scope all` every other trace — only once no account is linked,
#         so the delete stays on this disk
#
# .why  = while an account is linked, a delete in ~/Dropbox syncs to the cloud
#         and to every device. after an unlink it touches this disk alone. the
#         guard is that fact, read at the moment of the delete — never a memory
#         that "it was unlinked earlier"
#
# ⚠️ .what an unlink cannot promise
#         a file changed here and not yet uploaded before the unlink exists ONLY
#         on this disk. the plan names the newest file, so a human can check it
#         against the cloud before the apply
#
# .the scopes
#   local  ~/Dropbox — the synced files
#   all    also ~/.dropbox (app state, and a database of every file name),
#          ~/.dropbox-dist (the daemon it downloaded), its autostart entry, and
#          its live processes. the apt package is root's, so its removal is
#          printed for a human — `6.3.dropbox` reinstalls from the signed repo
#
# usage:
#   rhx dropbox.local.del                              # plan, --scope local
#   rhx dropbox.local.del --scope all                  # plan, every trace
#   rhx dropbox.local.del --scope all --mode apply     # delete every trace
#
# guarantee:
#   - plan is the default; only --mode apply deletes or signals
#   - refuses (exit 2) while ~/.dropbox/info.json names a linked account
######################################################################

set -uo pipefail

main() {
  local mode=plan scope=local
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --mode) mode="${2:-}"; shift 2 ;;
      --scope) scope="${2:-}"; shift 2 ;;
      --help|-h)
        echo "🗑️ dropbox.local.del — delete this machine's dropbox once no account is linked"
        echo ""
        echo "usage:"
        echo "  rhx dropbox.local.del [--scope local|all] [--mode plan|apply]"
        return 0 ;;
      --repo|--role|--skill) shift 2 ;;
      *) echo "✋ ConstraintError: unknown arg: $1" >&2; echo "   fix: rhx dropbox.local.del --help" >&2; return 2 ;;
    esac
  done
  if [[ "$mode" != plan && "$mode" != apply ]]; then
    echo "✋ ConstraintError: --mode must be plan or apply" >&2; return 2
  fi
  if [[ "$scope" != local && "$scope" != all ]]; then
    echo "✋ ConstraintError: --scope must be local or all" >&2; return 2
  fi

  local dir="$HOME/Dropbox" state="$HOME/.dropbox" dist="$HOME/.dropbox-dist"
  local entry="$HOME/.config/autostart/dropbox.desktop" link="$HOME/.dropbox/info.json"
  echo "🗑️ dropbox.local.del --scope $scope --mode $mode"

  # 1. the guard — read now, never remembered
  if [[ -e "$link" ]]; then
    echo "✋ ConstraintError: $link names a linked account — a delete here would sync to the cloud" >&2
    echo "   fix: unlink first (dropbox preferences → account → unlink), then rerun" >&2
    return 2
  fi
  echo "   • no account linked ($link absent) ✔"

  # 2. what would go
  local targets=("$dir") pids=""
  if [[ -d "$dir" ]]; then
    local size count newest
    size="$(du -sh "$dir" 2>/dev/null | cut -f1)"
    count="$(find "$dir" -type f 2>/dev/null | wc -l)"
    newest="$(find "$dir" -type f -printf '%TY-%Tm-%Td %TH:%TM  %P\n' 2>/dev/null | sort | tail -n 1)"
    echo "   • $dir: ${size:-?}, $count files"
    echo "     newest: ${newest:-none}"
    echo "     ⇒ a file changed after its last upload lives only here; check the newest in the cloud first"
  else
    echo "   • $dir: absent"
  fi
  if [[ "$scope" == all ]]; then
    targets+=("$state" "$dist" "$entry")
    local t
    for t in "$state" "$dist" "$entry"; do
      if [[ -e "$t" ]]; then echo "   • $t: $(du -sh "$t" 2>/dev/null | cut -f1)"; else echo "   • $t: absent"; fi
    done
    pids="$(pgrep -u "$(id -u)" -f "$dist/" 2>/dev/null | paste -sd' ')"
    echo "   • processes: ${pids:-none}"
  fi

  if [[ "$mode" == plan ]]; then
    echo ""
    echo "🌲 plan — naught deleted. to delete: rhx dropbox.local.del --scope $scope --mode apply"
    return 0
  fi

  # 3. stop the daemon first, so naught writes the state back as it goes
  if [[ -n "$pids" ]]; then
    # shellcheck disable=SC2086
    kill $pids 2>/dev/null
    sleep 2
    if [[ -n "$(pgrep -u "$(id -u)" -f "$dist/" 2>/dev/null)" ]]; then
      echo "💥 MalfunctionError: dropbox did not stop (pids: $pids) — naught deleted" >&2
      return 1
    fi
    echo "   • stopped: $pids"
  fi

  # 4. the delete — the guard is re-read, since the stop took time
  if [[ -e "$link" ]]; then
    echo "✋ ConstraintError: $link appeared — an account linked meanwhile; naught deleted" >&2
    return 2
  fi
  local t
  for t in "${targets[@]}"; do
    [[ -e "$t" ]] || continue
    if ! rm -rf -- "$t"; then
      echo "💥 MalfunctionError: could not fully delete $t" >&2
      return 1
    fi
    echo "   • deleted: $t"
  done

  echo ""
  echo "🌲 deleted — the cloud copy is untouched"
  if [[ "$scope" == all ]] && dpkg -s dropbox >/dev/null 2>&1; then
    echo "   one trace is root's: the dropbox apt package. remove it from a terminal:"
    echo "     sudo -v && sudo apt-get purge -y dropbox"
  fi
}

main "$@"
