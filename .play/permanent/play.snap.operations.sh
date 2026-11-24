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
#   - drifted → 💥, with the diff. to accept a drift, rerun with
#       rhx play.run --play <play> --resnap
#     (it exports GROVE_RESNAP=1, which rewrites the file; review it in the diff)
#   - under CI, GROVE_RESNAP is refused: a CI run never rewrites a baseline
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
      *) echo "   💥 MalfunctionError: the snapshot check got an unknown arg '${arg%%=*}' — it takes dir=, name=, actual=" >&2; return 1 ;;
    esac
  done
  # name the absent arg, each one: "needs dir= and name=" alone leaves the play author to guess
  local absent=""
  [[ -n "$dir" ]] || absent="dir="
  [[ -n "$name" ]] || absent="${absent:+$absent and }name="
  if [[ -n "$absent" ]]; then
    echo "   💥 MalfunctionError: the snapshot check was called with no $absent — so it cannot find a snapshot" >&2
    echo "      ⇒ fix: pass dir=<play>.snap and name=<snap>, beside actual=" >&2
    return 1
  fi

  local file="$dir/$name.snap"

  # under ci a snap is never written: an absent one was deleted or never committed,
  #   and a re-baseline there would pass the very drift the snap exists to catch
  if [[ ! -f "$file" && -n "${CI:-}" ]]; then
    echo "   💥 MalfunctionError: no snapshot at $file, and CI is set — a CI run never writes one" >&2
    echo "      ⇒ fix: run the play locally, review the new snap in the diff, commit it" >&2
    return 1
  fi

  # a resnap under ci would pass the very drift the snap exists to catch
  if [[ "${GROVE_RESNAP:-}" == 1 && -n "${CI:-}" ]]; then
    echo "   💥 MalfunctionError: GROVE_RESNAP=1 under CI — a CI run never rewrites a snapshot" >&2
    echo "      ⇒ fix: resnap locally, review the snap in the diff, commit it" >&2
    return 1
  fi

  # resnap — rewrite it, and say so; the diff of the pr is where it is reviewed
  if [[ "${GROVE_RESNAP:-}" == 1 ]]; then
    mkdir -p "$dir"
    printf '%s\n' "$actual" > "$file"
    echo "   • snapshot rewritten: $name (GROVE_RESNAP=1) — review it in the diff ✔"
    return 0
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
  # the diff sits under the 💥 at the tree's continuation depth, so it reads as part of it
  echo "   💥 MalfunctionError: '$name' drifted from its snapshot ($file)" >&2
  echo "      ├─ the diff (< this run, > the snapshot)" >&2
  # a cut diff says so: one read as whole hides the rest of the drift
  local delta; delta="$(diff <(printf '%s\n' "$actual") "$file")"
  local total; total="$(printf '%s\n' "$delta" | wc -l)"
  printf '%s\n' "$delta" | head -40 | sed 's/^/      │  /' >&2
  [[ "$total" -le 40 ]] || echo "      │  … $(( total - 40 )) more diff line(s) not shown" >&2
  echo "      └─ fix, if the new output is right: rhx play.run --play <this play> --resnap, then review the diff" >&2
  return 1
}
