#!/usr/bin/env bash
######################################################################
# .what = compare a play's transcript against its stored snapshot
#
# .why  = a word-level assert proves a phrase is present, never that the rest
#         of the line still reads right. a snapshot makes every byte a human
#         reads a reviewed artifact, so a reworded message cannot ship silently
#         (`rule.require.contract-snapshot-exhaustiveness`). the shape follows
#         `brains.auth.test`'s `_snap`
#
# .how  = the snapshot sits beside the play, in `<play>.snap/<name>.snap`
#   - absent → it is written, and the run says so. review the new file in the diff
#     (under CI an absent snap is a 💥, never a write)
#   - equal  → silent pass
#   - drifted → 💥, with the diff. to accept a drift, delete the file and rerun:
#       rhx rmsafe --path .play/permanent/<play>.snap/<name>.snap
#   - `play.run` passes no flags to a play, so there is no `--resnap`; the
#     delete is the deliberate step
#
# .mask  = a caller strips every value that differs per run or per box (a
#          mktemp dir, a codename) BEFORE the call; this helper compares bytes
#
# usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/play.snap.operations.sh"
#   play_snap_verify dir="$HERE/.play/permanent/<play>.snap" name=transcript actual="$text"
#
# guarantee:
#   - returns 0 on a match or a first write, 1 on a drift
#   - writes only inside `dir`
######################################################################

play_snap_verify() {
  local dir="" name="" actual="" arg
  for arg in "$@"; do
    case "$arg" in
      dir=*)    dir="${arg#dir=}" ;;
      name=*)   name="${arg#name=}" ;;
      actual=*) actual="${arg#actual=}" ;;
      *) echo "   💥 MalfunctionError: play_snap_verify: unknown arg '${arg%%=*}'" >&2; return 1 ;;
    esac
  done
  if [[ -z "$dir" || -z "$name" ]]; then
    echo "   💥 MalfunctionError: play_snap_verify needs dir= and name=" >&2
    return 1
  fi

  local file="$dir/$name.snap"

  # under ci a snap is never written: an absent one was deleted or never committed,
  #   and a re-baseline there would pass the very drift the snap exists to catch
  if [[ ! -f "$file" && -n "${CI:-}" ]]; then
    echo "   💥 MalfunctionError: no snapshot at $file, and CI is set — a ci run never writes one" >&2
    echo "      fix: run the play locally, review the new snap in the diff, commit it" >&2
    return 1
  fi

  # first run — write it, and say so; the diff of the pr is where it is reviewed
  if [[ ! -f "$file" ]]; then
    mkdir -p "$dir"
    printf '%s\n' "$actual" > "$file"
    echo "   • snapshot written: $name — review it in the diff ✔"
    return 0
  fi

  # match — silent beyond one line
  if diff -q <(printf '%s\n' "$actual") "$file" >/dev/null; then
    echo "   • snapshot matches: $name ✔"
    return 0
  fi

  # drift — show it, and name the deliberate step that accepts it
  echo "   💥 MalfunctionError: '$name' drifted from its snapshot ($file)" >&2
  diff <(printf '%s\n' "$actual") "$file" | head -40 >&2
  echo "      ⇒ if the new output is right: rhx rmsafe --path ${file#"$(git rev-parse --show-toplevel 2>/dev/null)/"}, then rerun" >&2
  return 1
}
