#!/usr/bin/env bash
######################################################################
# .what = show the last known weekly read per account, from the durable
#         brains.auth.usage log — no token, no network
#
# .why  = an account with a dead token still has a knowable weekly reset
#         (the window is anchored), and `brains.auth.usage` renders it from
#         this same leaf. this exposes the leaf on its own, so a human or a
#         clone can see what the log holds for an account without a sweep.
#
# usage:
#   rhx brains.auth.usage.lastknown --reach <email> [--reach <email> ...]
#
# .note = prints `{reach: {ts, seven_day}}` json, plus one rendered week row
#         per account found. an account absent from the output had no
#         successful weekly read in the log.
######################################################################

set -uo pipefail

# locate + source brains.auth.sh, and strip the rhx `--skill` token into ${ARGS[@]}
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/brains.auth.bootstrap.sh"

_want=''
_args=(${ARGS[@]+"${ARGS[@]}"})
while (( ${#_args[@]} > 0 )); do
  case "${_args[0]}" in
    --reach) _want+="${_args[1]:-}"$'\n'; _args=("${_args[@]:2}") ;;
    -h|--help)
      echo "🐢 brains.auth.usage.lastknown — the last known weekly read per account"
      echo ""
      echo "  usage: rhx brains.auth.usage.lastknown --reach <email> [--reach <email> ...]"
      exit 0 ;;
    *) _brains_auth_say_unknown_arg "${_args[0]}"; exit 2 ;;
  esac
done
[[ -n "$_want" ]] || { echo "✋ ConstraintError: name at least one --reach <email>" >&2; exit 2; }

_found="$(_brains_auth_week_lastknown_get "$_want")"
jq . <<< "$_found"
while IFS= read -r _r; do
  [[ -z "$_r" ]] && continue
  _node="$(jq -c --arg s "$_r" '.[$s] // empty' <<< "$_found")"
  [[ -z "$_node" ]] && { echo "$_r: no successful weekly read in the log"; continue; }
  echo "$_r: $(_brains_auth_week_lastknown_body "$_node")"
done <<< "$_want"
