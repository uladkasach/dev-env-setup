#!/usr/bin/env bash
######################################################################
# .what = drive `play.run --all` over temp repos of stub plays — one that
#         passes, one that declines, one that fails — and snap every answer.
#         then prove each run leaves exactly one verdict log in its tree
#
# .why  = `--all` folds many verdicts into one exit code. a fold that read a
#         decline as a pass, or a failure as a decline, would report a suite
#         green that proved naught. each fold is driven, its exit asserted,
#         and its text snapped
#
#         and a ship report reads the verdict from the TREE, never the terminal:
#         the newest `.log/role=mechanic/skill=play.run/what=all/<stamp>.stdout.log`,
#         its last line the tally. so each run's log is counted and its literal
#         last line read — a "some file under what=all" check would pass on a
#         tree that never wrote this shape
#
# .how  = `play.run` derives its checkout from its OWN file, never the cwd, so
#         a copy of it inside a temp git repo runs against that repo's plays
#
# guarantee:
#   - HERMETIC. it writes only inside its own mktemp dir, removed on exit
#   - the real skill's bytes run; only the plays it is shown are stubs
#   - non-root only: root writes through any mode, so the cases that need a
#     dir the run cannot write could not be driven, and the clamp declines whole
######################################################################

set -u

# root writes through a read-only dir, so four cells below cannot be reached.
#   decline before any case, so no verdict is half-measured. a decline, not a
#   failure: the box cannot pose the question, which is what exit 2 means here,
#   as for every play that declines on a seat it cannot measure. this refusal
#   is not snapped — a non-root run, the only kind that snaps, never reaches it
if [[ "$(id -u)" -eq 0 ]]; then
  echo "✋ ConstraintError: run as a non-root user — root writes through any dir mode, so the locked, unsearch, truncated, and playlock cases cannot be driven" >&2
  echo "   fix: rerun as a user without root, e.g. the seat's own login" >&2
  exit 2
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL="$HERE/.agent/repo=.this/role=any/skills/play.run.sh"
[[ -r "$SKILL" ]] || {
  echo "✋ ConstraintError: the subject is absent: $SKILL" >&2
  echo "   fix: run this play from a checkout of this repo, which tracks that file" >&2
  exit 2
}

# the box's user, which a refusal names; masked in the snap, since a ci runner's differs
USERNAME="$(id -un)"

fixture="$(mktemp -d)"
trap 'chmod -R u+rwx "$fixture" 2>/dev/null; rm -rf "$fixture"' EXIT
mkdir -p "$fixture/tmp"

failed=0
transcript=""
cry() { echo "$1" >&2; transcript+="$1"$'\n'; }

LOGREL=".log/role=mechanic/skill=play.run/what=all"
# seconds any one runner call may take, and the grace after its TERM: a runner that wedges
#   before it reaches a play (git, a claim) hangs no clamp, since --within bounds plays alone
RUN_BOUND=120
RUN_GRACE=5
# seconds of stamps a case holds taken. the run tries 5, one per second, so the window
#   dwarfs any delay between the seed and the run's first try
WINDOW=60

echo "🌲 prove.play-run-all-reads-three-verdicts"

######################################################################
# operations
######################################################################

# .what = one temp repo per suite shape — $1 = name · then the stub plays it
#         tracks, as `<slug>=<exit>` pairs
mkrepo() {
  local repo="$fixture/$1" pair slug code
  shift
  mkdir -p "$repo/.play/permanent" "$repo/skills"
  git -C "$repo" init -q
  cp "$SKILL" "$repo/skills/play.run.sh"
  for pair in "$@"; do
    slug="${pair%=*}"; code="${pair#*=}"
    printf '#!/usr/bin/env bash\necho "stub %s says exit %s"\nexit %s\n' "$slug" "$code" "$code" \
      > "$repo/.play/permanent/$slug.play.sh"
  done
  git -C "$repo" add -A
}

# .what = the epoch second now
as_epoch_now() { date -u +%s; }

# .what = the utc stamp of an epoch second, in the shape play.run names its logs by
as_stamp_at() { date -u -d "@$1" +%Y-%m-%dT%H-%M-%SZ; }

# .what = the stamp a verdict log's name carries
as_stamp_of_log() { basename "$1" .stdout.log; }

# .what = how many lines a list holds; an empty list holds 0
count_lines() {
  if [[ -z "$1" ]]; then echo 0; return 0; fi
  printf '%s\n' "$1" | wc -l
}

# .what = how many entries `find` reports — the clamp halts if find itself fails
# .why  = a zero from a find that never ran would read as a measured pass
count_found() {
  local out
  out="$(find "$@")" || { echo "💥 MalfunctionError: find failed on $1, so the claim cannot be measured" >&2; exit 1; }
  count_lines "$out"
}

# .what = the stdout logs in a repo's what=all dir, one name per line, sorted
logs_of() {
  local f
  for f in "$fixture/$1/$LOGREL"/*.stdout.log; do
    [[ -e "$f" ]] && basename "$f"
  done | sort
}

# .what = the logs in list $2 and not in list $1 — the logs a case added
get_logs_added() { comm -13 <(printf '%s\n' "$1") <(printf '%s\n' "$2") | sed '/^$/d'; }

# .what = a path component of $1 bytes
as_pad() { printf "%${1}s" '' | tr ' ' d; }

# .what = a repo path under the fixture whose what=all/ dir is $1 bytes long
# .why  = it is built of 200-byte components, since one component may hold at most 255
as_deep_path() {
  local want=$(( $1 - ${#LOGREL} - 1 - ${#fixture} - 1 )) rel="deep.real"
  while (( want - ${#rel} > 201 )); do rel+="/$(as_pad 199)"; done
  printf '%s' "$rel/$(as_pad $(( want - ${#rel} - 1 )))"
}

# .what = a case's output, with what varies per run or per box masked — $1 = the
#         output · $2 = the fixture path · $3 = the deep fixture's real path, or
#         empty · $4 = the box's user. each stamp is masked too, and git's own
#         words, which vary by git version in both text and line count, collapse
#         to one masked `git said:` line
as_redacted_output() {
  local out="$1" base="$2" deep="$3" user="$4"
  [[ -n "$deep" ]] && out="${out//$deep/<fixture>/deep}"
  out="${out//$base/<fixture>}"
  out="${out//writable by $user,/writable by <user>,}"
  sed -E -e 's#[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}-[0-9]{2}-[0-9]{2}Z#<stamp>#g' \
    -e 's#^( +git said: ).*#\1<git, in its own words>#' <<< "$out" \
    | awk '!(/ git said: / && $0 == prev) { print } { prev = $0 }'
}

# .what = hold $3 stamps taken in repo $1's what=all/, from epoch second $2 on,
#         as a peer run holds each: its dir and its empty log
seed_stamps_taken() {
  local dir="$fixture/$1/$LOGREL" i s
  mkdir -p "$dir"
  for (( i = 0; i < $3; i++ )); do
    s="$(as_stamp_at "$(( $2 + i ))")"
    mkdir -p "$dir/$s"
    : > "$dir/$s.stdout.log"
  done
}

# .what = hold $3 stamps in repo $1's what=all/, from epoch second $2 on, each by
#         an orphan log alone — no dir beside it. a file at an even offset, a
#         broken link at an odd one
seed_orphan_stamps() {
  local dir="$fixture/$1/$LOGREL" i s
  mkdir -p "$dir"
  for (( i = 0; i < $3; i++ )); do
    s="$(as_stamp_at "$(( $2 + i ))")"
    if (( i % 2 )); then
      ln -s "$fixture/$1/absent" "$dir/$s.stdout.log"
      continue
    fi
    printf 'orphan\n' > "$dir/$s.stdout.log"
  done
}

# .what = of $1 seeds at offsets 0..$1-1, how many sit at an even offset, and how many at an odd
as_count_even_offsets() { echo $(( ( $1 + 1 ) / 2 )); }
as_count_odd_offsets()  { echo $(( $1 / 2 )); }

# .what = true if path $1 is a regular file whose content is exactly $2
is_file_holding() { [[ -f "$1" && "$(cat "$1")" == "$2" ]]; }

# .what = one case's block in the transcript: a blank line, its label, its rc, its output
as_transcript_entry() { printf '\n## %s\nrc=%s\n%s' "$1" "$2" "$3"; }

# .what = one artifact's block in the transcript: a blank line, its label, its content.
#         no rc — a file on disk has none
as_artifact_entry() { printf '\n## %s\n%s' "$1" "$2"; }

# .what = the sorted paths of a `find . -mindepth 1`, two deep, as a treestruct: the top
#         entries as peers, a dir's own entries nested under it
as_tree_of_paths() {
  awk '
    { sub(/^\.\//, "") }
    !index($0, "/") { top[++nt] = $0; next }
    { p = substr($0, 1, index($0, "/") - 1); kid[p] = kid[p] (kid[p] == "" ? "" : "\n") substr($0, index($0, "/") + 1) }
    END {
      for (i = 1; i <= nt; i++) {
        last = (i == nt)
        print (last ? "└─ " : "├─ ") top[i] ((top[i] in kid) ? "/" : "")
        if (!(top[i] in kid)) continue
        m = split(kid[top[i]], k, "\n")
        for (j = 1; j <= m; j++) print (last ? "   " : "│  ") (j == m ? "└─ " : "├─ ") k[j]
      }
    }' <<< "$1"
}

# .what = the tally a reader takes from a log: the LAST match of its own three-count regex
#         (nheuron director.bar.operations.sh), or empty
as_tally_read() { grep -oE '[0-9]+ passed[^0-9]+[0-9]+ declined[^0-9]+[0-9]+ failed' "$1" | tail -n 1; }

# .what = snap a log a red run cut short — $1 = repo · $2 = the log it added · $3 = the title —
#         and prove the reader's regex finds no tally in it, so the cell reads `fail`
snap_cut_log() {
  local log="$fixture/$1/$LOGREL/$2"
  [[ -n "$2" && -r "$log" ]] || { cry "   💥 MalfunctionError: $1 — no cut log to snap"; failed=1; return 1; }
  transcript+="$(as_artifact_entry "$3" "$(as_redacted_output "$(cat "$log")" "$fixture" "" "$USERNAME")")"$'\n'
  expect_text "$1" "the tally the reader's regex takes from the cut log" "$(as_tally_read "$log")" ""
}

# .what = one case — $1 = label · $2 = exit wanted · $3 = repo · then the skill's args
# .note = it sets this case's ledger, `case_new` (the stdout logs it added) and
#         `case_out` (its redacted output). both reset first, so no assert can
#         read a prior case's data. each assert takes the ledger as an argument
case_new=""
case_out=""
case_run() {
  local label="$1" want="$2" name="$3" repo="$fixture/$3" out rc before
  shift 3
  case_new=""; case_out=""
  before="$(logs_of "$name")"
  # LC_ALL=C: a tool's own error line quotes by locale, and a ci runner's locale differs
  out="$(LC_ALL=C TMPDIR="$fixture/tmp" timeout -k "$RUN_GRACE" "$RUN_BOUND" \
    bash "$repo/skills/play.run.sh" "$@" < /dev/null 2>&1)" && rc=0 || rc=$?
  case_new="$(get_logs_added "$before" "$(logs_of "$name")")"
  case_out="$(as_redacted_output "$out" "$fixture" "$deepreal" "$USERNAME")"
  transcript+="$(as_transcript_entry "$label" "$rc" "$case_out")"$'\n'
  if [[ "$rc" -eq "$want" ]]; then
    echo "   • $label → rc=$rc ✔"
    return 0
  fi
  cry "   💥 MalfunctionError: $label → rc=$rc, expected rc=$want"
  failed=1
  return 1
}

# .what = a run's receipt — $1 = repo · $2 = the logs it added · $3 = the literal
#         last line wanted. exactly one log, and that line its last
expect_one_log() {
  local name="$1" added="$2" want="$3" count last
  count="$(count_lines "$added")"
  if [[ "$count" -ne 1 ]]; then
    cry "   💥 MalfunctionError: $name — the run added $count stdout log(s) under $LOGREL, expected exactly 1"
    failed=1
    return 1
  fi
  last="$(tail -n 1 "$fixture/$name/$LOGREL/$added")"
  if [[ "$last" != "$want" ]]; then
    cry "   💥 MalfunctionError: $name — the stdout log's last line is '$last', expected '$want'"
    failed=1
    return 1
  fi
  echo "   • $name leaves one <stamp>.stdout.log, its last line as wanted ✔"
}

# .what = a refusal's receipt — $1 = repo · $2 = the logs it added. none
expect_no_log() {
  local name="$1" added="$2" count
  count="$(count_lines "$added")"
  if [[ "$count" -ne 0 ]]; then
    cry "   💥 MalfunctionError: $name — a refused run added $count stdout log(s), expected none"
    failed=1
    return 1
  fi
  echo "   • $name adds no stdout log ✔"
}

# .what = a refusal names its true cause — $1 = repo · $2 = its output · $3 = the phrase
expect_cause() {
  if [[ "$2" == *"$3"* ]]; then
    echo "   • $1 — the refusal names '$3' ✔"
    return 0
  fi
  cry "   💥 MalfunctionError: $1 — the refusal does not name '$3'"
  failed=1
}

# .what = a count the case must leave — $1 = repo · $2 = what is counted · $3 = got · $4 = want
expect_count() {
  if [[ "$3" -eq "$4" ]]; then
    echo "   • $1 — $2: $3 ✔"
    return 0
  fi
  cry "   💥 MalfunctionError: $1 — $2: $3, expected $4"
  failed=1
}

# .what = a text the case must leave — $1 = repo · $2 = what is read · $3 = got · $4 = want
expect_text() {
  if [[ "$3" == "$4" ]]; then
    echo "   • $1 — $2: '$3' ✔"
    return 0
  fi
  cry "   💥 MalfunctionError: $1 — $2: '$3', expected '$4'"
  failed=1
}

# .what = launch $2 `--all` runs in repo $1 at once, await each, and print how many exited non-zero
# .note = each run's output goes to its own file under the fixture's tmp. which run wins which
#         second varies per box, but only the stamp varies, and it is masked: so each racer's
#         output is compared with the first's, and the first's is snapped
race_runs() {
  local repo="$fixture/$1" n="$2" i pid lost=0 pids=()
  for (( i = 0; i < n; i++ )); do
    LC_ALL=C TMPDIR="$fixture/tmp" timeout -k "$RUN_GRACE" "$RUN_BOUND" \
      bash "$repo/skills/play.run.sh" --all --within 30 \
      < /dev/null > "$fixture/tmp/race.$i.out" 2>&1 &
    pids+=("$!")
  done
  for pid in "${pids[@]}"; do wait "$pid" || lost=$(( lost + 1 )); done
  echo "$lost"
}

# .what = start an `--all` run in repo $1, await file $2 (a play's signal that it runs), then
#         end the run with SIGTERM, as a closed terminal would. prints the run's exit code
# .why  = the marker is the signal, never a timer: the poll is bounded, and an absent marker
#         is a fault of the fixture, named, never a pass
kill_run_midway() {
  local repo="$fixture/$1" marker="$2" pid i rc=0
  # timeout forwards the TERM below to the run, and exits as the run did
  LC_ALL=C TMPDIR="$fixture/tmp" timeout -k "$RUN_GRACE" "$RUN_BOUND" \
    bash "$repo/skills/play.run.sh" --all --within 30 \
    < /dev/null > "$fixture/tmp/killed.out" 2>&1 &
  pid=$!
  for (( i = 0; i < 100; i++ )); do
    [[ -e "$marker" ]] && break
    sleep 0.1
  done
  if [[ ! -e "$marker" ]]; then
    kill -TERM "$pid" 2>/dev/null; wait "$pid"
    echo "💥 MalfunctionError: the killed fixture's play never signalled it ran ($marker), so no midway kill was measured" >&2
    exit 1
  fi
  kill -TERM "$pid"
  wait "$pid" || rc=$?
  echo "$rc"
}

# .what = how many lines of log $1 read exactly $2
count_lines_equal() { grep -cxF -- "$2" "$1"; }

######################################################################
# fixtures
######################################################################
mkrepo mixed     prove.a-passes=0 prove.b-declines=2 prove.c-fails=1
mkrepo declined  prove.a-passes=0 prove.b-declines=2
mkrepo green     prove.a-passes=0
mkrepo empty
mkrepo untracked prove.a-passes=0
mkrepo stamps    prove.a-passes=0
mkrepo shift     prove.a-passes=0
mkrepo orphans   prove.a-passes=0
mkrepo locked    prove.a-passes=0
mkrepo unsearch  prove.a-passes=0
mkrepo truncated prove.b-passes=0
mkrepo redafter  prove.a-passes=0
mkrepo race      prove.a-passes=0
mkrepo nested    prove.a-passes=0
mkrepo killed    prove.b-passes=0
mkrepo unproven  prove.d-passes=0
mkrepo unicode   prove.a-passes=0 prove.ü-passes=0
# a tracked repair play, read by `--play` alone: repairs are bundles, never plays
mkrepo verbs     repair.a-fixes=0
# a checkout with no play dir, and a skill copy outside any checkout
mkrepo noplays
rmdir "$fixture/noplays/.play/permanent" "$fixture/noplays/.play"
mkdir -p "$fixture/nogit/skills"
cp "$SKILL" "$fixture/nogit/skills/play.run.sh"

# the unproven repo holds the three causes `--play` answers 2 for beyond a stub's own
#   decline: a play that outlasts --within, a tracked play with no sanctioned verb, and
#   a tracked play gone from disk. `--all` reads each as declined (fulcrum F7)
printf '#!/usr/bin/env bash\necho "stub prove.a-hangs sleeps past its bound"\nsleep 10\nexit 0\n' > "$fixture/unproven/.play/permanent/prove.a-hangs.play.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$fixture/unproven/.play/permanent/bogus.b-noverb.play.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$fixture/unproven/.play/permanent/prove.c-vanished.play.sh"
git -C "$fixture/unproven" add -A
rm "$fixture/unproven/.play/permanent/prove.c-vanished.play.sh"

# the killed repo's first play signals that it runs, then waits, so the clamp can end
#   the run with SIGTERM while a play is in flight
printf '%s\n' '#!/usr/bin/env bash' \
  'here="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"' \
  ': > "$here/inflight.marker"' \
  'sleep 5' \
  'exit 0' > "$fixture/killed/.play/permanent/prove.a-waits.play.sh"
git -C "$fixture/killed" add -A

# the nested repo tracks a play one dir below .play/permanent/. the suite is the
#   top level alone, as the untracked count reads it: a git pathspec `*` crosses
#   `/`, so a bare glob would list the nested play and `--play` would refuse it
mkdir -p "$fixture/nested/.play/permanent/sub"
printf '#!/usr/bin/env bash\nexit 1\n' > "$fixture/nested/.play/permanent/sub/prove.z-nested.play.sh"
git -C "$fixture/nested" add -A

# the green repo holds a prior run's log, so "exactly one NEW log" is measured
#   against history, never against an empty dir
mkdir -p "$fixture/green/$LOGREL"
printf '      └─ 9 passed · 0 declined · 0 failed\n' > "$fixture/green/$LOGREL/2000-01-01T00-00-00Z.stdout.log"

# and a legacy run's dir, as #184 left it: `<stamp>.pid<N>/summary.log`. a reader
#   globs both layouts and picks the newest by mtime, so the new log must outdate it,
#   and the run must leave it as it found it
LEGACY="2000-01-02T00-00-00Z.pid1/summary.log"
mkdir -p "$fixture/green/$LOGREL/${LEGACY%/*}"
printf '      └─ 8 passed · 0 declined · 0 failed\n' > "$fixture/green/$LOGREL/$LEGACY"
touch -d '2000-01-02 00:00:00' "$fixture/green/$LOGREL/$LEGACY" "$fixture/green/$LOGREL/2000-01-01T00-00-00Z.stdout.log"

# the untracked repo holds a play on disk that the index does not
printf '#!/usr/bin/env bash\nexit 0\n' > "$fixture/untracked/.play/permanent/prove.z-stray.play.sh"

# the truncated repo's first play makes the verdict log read-only mid-run, as a
#   full disk or a peer's chmod would
printf '%s\n' '#!/usr/bin/env bash' \
  'here="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"' \
  'chmod a-w "$here/.log/role=mechanic/skill=play.run/what=all/"*.stdout.log' \
  'exit 0' > "$fixture/truncated/.play/permanent/prove.a-locks-the-log.play.sh"
git -C "$fixture/truncated" add -A

# the deep repo's what=all/ path sits DEEP_RESERVE bytes under this fs's PATH_MAX:
#   a `<stamp>/` claim (+21) fits, and `<stamp>.stdout.log` (+32) does not. so the
#   dir claim wins and the log create fails for a cause other than a held name.
#   the clamp reads it through a short link; play.run reads its checkout from
#   git, which resolves the link, so the run sees the deep path
DEEP_RESERVE=27
pathmax="$(getconf PATH_MAX "$fixture")"
if [[ ! "$pathmax" =~ ^[0-9]+$ ]]; then
  echo "✋ ConstraintError: getconf names no numeric PATH_MAX for $fixture ('$pathmax'), so the deep case cannot be sized" >&2
  echo "   fix: run on a linux fs that reports one (getconf PATH_MAX /tmp)" >&2
  exit 2
fi
deeprel="$(as_deep_path $(( pathmax - DEEP_RESERVE )))"
mkrepo "$deeprel" prove.a-passes=0
# a box whose fs cannot hold a path that long cannot pose the deep case: a decline,
#   as for root or an absent PATH_MAX, never a failure of the subject
if [[ ! -d "$fixture/$deeprel/.git" ]]; then
  echo "✋ ConstraintError: this box could not build the deep fixture at $(( pathmax - DEEP_RESERVE )) bytes, so the create-refused case cannot be posed" >&2
  echo "   fix: run on a linux fs with 255-byte names and a short TMPDIR, or read why git or mkdir refused under $fixture" >&2
  exit 2
fi
ln -s "$fixture/$deeprel" "$fixture/deep"
deepreal="$fixture/$deeprel"

# the squat repo holds a FILE at the what=all path, so the log root cannot be made
mkrepo squat prove.a-passes=0
mkdir -p "$fixture/squat/${LOGREL%/*}"
printf 'squat\n' > "$fixture/squat/$LOGREL"

# the playlock repo's first play makes the per-play dir read-only mid-run, so the
#   next play's log cannot be written
mkrepo playlock prove.b-passes=0
printf '%s\n' '#!/usr/bin/env bash' \
  'here="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"' \
  'chmod a-w "$here/.log/role=mechanic/skill=play.run/what=all/"*/' \
  'exit 0' > "$fixture/playlock/.play/permanent/prove.a-locks-the-plays.play.sh"
git -C "$fixture/playlock" add -A

# the badindex repo's index is garbage: git still names the checkout, and cannot
#   read the index
mkrepo badindex prove.a-passes=0
printf 'not an index\n' > "$fixture/badindex/.git/index"

######################################################################
# cases
######################################################################
case_run "--all · a pass, a decline, a failure → 1"  1 mixed    --all --within 30
expect_one_log mixed "$case_new" "      └─ 1 passed · 1 declined · 1 failed"

# the per-play logs share the stamp of the verdict log, so a human pairs them by eye
stem="$(as_stamp_of_log "$case_new")"
if [[ -n "$case_new" && -r "$fixture/mixed/$LOGREL/$stem/prove.c-fails.log" ]]; then
  echo "   • the per-play logs sit in what=all/<stamp>/, the verdict log's stamp ✔"
else
  cry "   💥 MalfunctionError: mixed — no per-play log at $LOGREL/<stamp>/prove.c-fails.log beside the verdict log"
  failed=1
fi

# the verdict log holds what the human saw, header to tally — its stamp masked, it
#   reads as the terminal's lines up to the blank before the coda — and a per-play
#   log holds its play's own words
if [[ -n "$case_new" ]]; then
  body="$(as_redacted_output "$(cat "$fixture/mixed/$LOGREL/$case_new")" "$fixture" "" "$USERNAME")"
  if [[ "$case_out" == "$body"$'\n'* ]]; then
    echo "   • mixed — the verdict log is the terminal's tree, header to tally ✔"
  else
    cry "   💥 MalfunctionError: mixed — the verdict log's body differs from the tree the terminal showed"
    failed=1
  fi
  expect_count mixed "stub lines in prove.c-fails.log" \
    "$(count_lines_equal "$fixture/mixed/$LOGREL/$stem/prove.c-fails.log" "stub prove.c-fails says exit 1")" 1

  # the receipt itself, snapped: the verdict log a reader opens, and the layout the run
  #   leaves, so a reviewer sees the artifact and a stray summary.log or pid suffix shows
  layout="$(cd "$fixture/mixed/$LOGREL" && find . -mindepth 1 | LC_ALL=C sort)" || exit 1
  transcript+="$(as_artifact_entry "the mixed run's receipt · what=all/<stamp>.stdout.log" "$body")"$'\n'
  transcript+="$(as_artifact_entry "the mixed run's receipt · the tree of what=all/" \
    "$(as_redacted_output "$(as_tree_of_paths "$layout")" "$fixture" "" "$USERNAME")")"$'\n'
  # a per-play log is that play's own `--play` run, header to coda
  transcript+="$(as_artifact_entry "the mixed run's receipt · what=all/<stamp>/prove.c-fails.log" \
    "$(as_redacted_output "$(cat "$fixture/mixed/$LOGREL/$stem/prove.c-fails.log")" "$fixture" "" "$USERNAME")")"$'\n'

  # the consumer's own read: the reader's regex, last match, on the newest log
  expect_text mixed "the tally the reader's regex takes" \
    "$(as_tally_read "$fixture/mixed/$LOGREL/$case_new")" "1 passed · 1 declined · 1 failed"
fi

# summary.log is retired (F1): one writer per artifact, so no second verdict file
#   may land for a reader's fallback glob to pick up
retired="$(count_found "$fixture/mixed/$LOGREL" -name summary.log)" || exit 1
expect_count mixed "summary.log files under what=all" "$retired" 0

# the wish keeps `.log` out of git: this checkout's own ignore rules must cover the
#   path a run writes. read-only — check-ignore asks the rules, and writes naught
if git -C "$HERE" check-ignore -q "$LOGREL/2000-01-01T00-00-00Z.stdout.log"; then
  echo "   • this repo ignores $LOGREL/<stamp>.stdout.log ✔"
else
  cry "   💥 MalfunctionError: this repo's ignore rules do not cover $LOGREL/<stamp>.stdout.log, so a run's log could be committed"
  failed=1
fi

case_run "--all · a pass and a decline → 2"          2 declined --all --within 30
expect_one_log declined "$case_new" "      └─ 1 passed · 1 declined · 0 failed"

# today's fold, pinned so a change to it is seen: a timeout, a play with no sanctioned
#   verb, and a tracked play gone from disk each read as declined, never failed. the
#   director owes the verdict on whether they should (F7); this case flips with it
case_run "--all · a timeout, no verb, a vanished play → each declined" 2 unproven --all --within 1
expect_one_log unproven "$case_new" "      └─ 1 passed · 3 declined · 0 failed"

case_run "--all · every play passes → 0"             0 green    --all --within 30
expect_one_log green "$case_new" "      └─ 1 passed · 0 declined · 0 failed"
# the green receipt — the cell a director reads as green — snapped, and read by the reader's regex
if [[ -n "$case_new" ]]; then
  transcript+="$(as_artifact_entry "the green run's receipt · what=all/<stamp>.stdout.log" \
    "$(as_redacted_output "$(cat "$fixture/green/$LOGREL/$case_new")" "$fixture" "" "$USERNAME")")"$'\n'
  expect_text green "the tally the reader's regex takes" \
    "$(as_tally_read "$fixture/green/$LOGREL/$case_new")" "1 passed · 0 declined · 0 failed"
fi

# beside a legacy summary.log, the new log is the newest of both layouts by mtime —
#   the reader's two-glob pick — and the legacy file is intact
if [[ -n "$case_new" ]]; then
  later="$(count_found "$fixture/green/$LOGREL" \( -name '*.stdout.log' -o -name summary.log \) -newer "$fixture/green/$LOGREL/$case_new")" || exit 1
  expect_count green "logs of either layout with a later mtime than the new one" "$later" 0
fi
if is_file_holding "$fixture/green/$LOGREL/$LEGACY" "      └─ 8 passed · 0 declined · 0 failed"; then
  echo "   • green — the legacy summary.log is intact ✔"
else
  cry "   💥 MalfunctionError: green — the legacy $LEGACY was changed or removed"
  failed=1
fi

case_run "--all with --play → two subjects, refused" 2 green    --all --play prove.a-passes
expect_no_log green "$case_new"
case_run "an unknown flag → refused, names the valid" 2 green   --every 5
expect_no_log green "$case_new"
case_run "--help → the usage"                        0 green    --help
expect_no_log green "$case_new"
# `-h` is the same door: its output must equal --help's, so it is compared, not snapped twice
helpout="$case_out"
hout="$(bash "$fixture/green/skills/play.run.sh" -h < /dev/null 2>&1)" && hrc=0 || hrc=$?
expect_count green "-h exit code" "$hrc" 0
if [[ "$(as_redacted_output "$hout" "$fixture" "$deepreal" "$USERNAME")" == "$helpout" ]]; then
  echo "   • green — -h prints exactly what --help prints ✔"
else
  cry "   💥 MalfunctionError: green — -h output differs from --help's"
  failed=1
fi
case_run "--list with --all → two subjects, refused" 2 green    --list --all
expect_no_log green "$case_new"
expect_cause green "$case_out" "takes no --all or --play"
case_run "--list with --play → two subjects, refused" 2 green   --list --play prove.a-passes
expect_cause green "$case_out" "takes no --all or --play"

# the door a human uses: `rhx play.run` hands the skill its own --skill/--repo/--role.
#   the runner must absorb each pair and run the suite it was asked for
case_run "--all under rhx's injected flags → 0"      0 green    --skill play.run --repo .this --role any --all --within 30
expect_one_log green "$case_new" "      └─ 1 passed · 0 declined · 0 failed"

case_run "--all · an empty index → refused, no log"  2 empty    --all --within 30
expect_no_log empty "$case_new"

# red after green, in one tree: a green run, then a play that fails joins the
#   index. the second run adds exactly one log, it is the newest, and it reads red
case_run "--all · red after green, run 1 → 0"        0 redafter --all --within 30
expect_one_log redafter "$case_new" "      └─ 1 passed · 0 declined · 0 failed"
printf '#!/usr/bin/env bash\nexit 1\n' > "$fixture/redafter/.play/permanent/prove.b-fails.play.sh"
git -C "$fixture/redafter" add -A
case_run "--all · red after green, run 2 → 1"        1 redafter --all --within 30
expect_one_log redafter "$case_new" "      └─ 1 passed · 0 declined · 1 failed"
# newest by name, and by mtime too — the reader's own rule (stat -c %Y): no other log
#   may carry a later mtime than the red one
newest="$(logs_of redafter | tail -n 1)"
if [[ -n "$case_new" && "$newest" == "$case_new" ]]; then
  echo "   • redafter — the red log is the newest by name ✔"
else
  cry "   💥 MalfunctionError: redafter — the newest log is '$newest', not the red run's '$case_new'"
  failed=1
fi
later="$(count_found "$fixture/redafter/$LOGREL" -maxdepth 1 -name '*.stdout.log' -newer "$fixture/redafter/$LOGREL/$case_new")" || exit 1
expect_count redafter "logs with a later mtime than the red one" "$later" 0

case_run "--all · a play nested below the suite → not in it" 0 nested --all --within 30
expect_one_log nested "$case_new" "      └─ 1 passed · 0 declined · 0 failed"

# a tracked play whose name is not ascii: git quotes such a name by default, so a
#   quoted index would match no file on disk and read the play as untracked
case_run "--all · a non-ascii play name → in the suite" 0 unicode --all --within 30
expect_one_log unicode "$case_new" "      └─ 2 passed · 0 declined · 0 failed"

# --within 0 reads to `timeout` as no bound at all, so it is refused before any log
case_run "--all --within 0 → refused, no log"        2 green    --all --within 0
expect_no_log green "$case_new"
expect_cause green "$case_out" "whole seconds, at least 1"

case_run "--all · an untracked play → refused, no log" 2 untracked --all --within 30
expect_no_log untracked "$case_new"
expect_cause untracked "$case_out" "outside the index"

# every stamp the run could try is taken, as dir and log both — a peer run's
#   claim. the run must name the defect, add no log, and overwrite none
seed_stamps_taken stamps "$(as_epoch_now)" "$(( WINDOW + 1 ))"
case_run "--all · every stamp taken → 💥, no overwrite" 1 stamps --all --within 30
expect_no_log stamps "$case_new"
expect_cause stamps "$case_out" "no free stamp"
written="$(count_found "$fixture/stamps/$LOGREL" -maxdepth 1 -name '*.stdout.log' -size +0)" || exit 1
expect_count stamps "taken logs written over" "$written" 0

# two runs in one second both land: the stamps of this second and the next are
#   taken, as a peer run would hold them. the run must move to a free second,
#   leave its own log, and overwrite neither taken one
seed_stamps_taken shift "$(as_epoch_now)" 2
case_run "--all · a taken stamp → the next free second" 0 shift --all --within 30
expect_one_log shift "$case_new" "      └─ 1 passed · 0 declined · 0 failed"
written="$(count_found "$fixture/shift/$LOGREL" -maxdepth 1 -name '*.stdout.log' -size +0)" || exit 1
expect_count shift "logs with content (the new one alone)" "$written" 1

# RACERS runs at once, in one tree, with no seed: real peers, not a held name. the
#   `mkdir` claim admits one winner per second, so each run lands its own stamp —
#   a check-then-write claim lets two pass the check, share a log, and write it
#   twice. RACERS stays under the run's TRIES, so every racer finds a second
RACERS=4
lost="$(race_runs race "$RACERS")"
expect_count race "racers that exited non-zero" "$lost" 0
raced="$(logs_of race)"
expect_count race "stdout logs" "$(count_lines "$raced")" "$RACERS"
dirs="$(count_found "$fixture/race/$LOGREL" -mindepth 1 -maxdepth 1 -type d)" || exit 1
expect_count race "per-play dirs" "$dirs" "$RACERS"
while IFS= read -r f; do
  [[ -n "$f" ]] || continue
  log="$fixture/race/$LOGREL/$f"
  expect_count race "tally lines in one racer's log" \
    "$(count_lines_equal "$log" "      └─ 1 passed · 0 declined · 0 failed")" 1
  [[ "$(tail -n 1 "$log")" == "      └─ 1 passed · 0 declined · 0 failed" ]] \
    || { cry "   💥 MalfunctionError: race — $f does not end in its tally"; failed=1; }
done <<< "$raced"
# each racer printed the same tree, its stamp aside: each is compared with the first, and
#   the first is snapped, so a racer whose output drifts reads red and the shape reads in the snap
race0="$(as_redacted_output "$(cat "$fixture/tmp/race.0.out")" "$fixture" "" "$USERNAME")"
drift=0
for (( i = 1; i < RACERS; i++ )); do
  [[ "$(as_redacted_output "$(cat "$fixture/tmp/race.$i.out")" "$fixture" "" "$USERNAME")" == "$race0" ]] \
    || drift=$(( drift + 1 ))
done
expect_count race "racers whose output differs from the first's, stamp masked" "$drift" 0
transcript+="$(as_transcript_entry "--all · $RACERS runs at once → each its own stamp (the first racer's output)" 0 "$race0")"$'\n'

# an orphan log holds each stamp — the log with no dir beside it, files at even
#   seconds and broken links at odd. the dir claim then wins, and the log's
#   noclobber create must refuse: each orphan reads as taken, never as a fault,
#   never written over, and no claimed dir is left behind
orphanseeds=$(( WINDOW + 1 ))
seed_orphan_stamps orphans "$(as_epoch_now)" "$orphanseeds"
case_run "--all · every stamp held by an orphan log → 💥, no overwrite" 1 orphans --all --within 30
expect_no_log orphans "$case_new"
expect_cause orphans "$case_out" "no free stamp"
intact="$(count_found "$fixture/orphans/$LOGREL" -maxdepth 1 -type f -name '*.stdout.log' -size +0)" || exit 1
expect_count orphans "orphan logs intact" "$intact" "$(as_count_even_offsets "$orphanseeds")"
links="$(count_found "$fixture/orphans/$LOGREL" -maxdepth 1 -type l -name '*.stdout.log')" || exit 1
expect_count orphans "orphan links intact" "$links" "$(as_count_odd_offsets "$orphanseeds")"
dirs="$(count_found "$fixture/orphans/$LOGREL" -mindepth 1 -maxdepth 1 -type d)" || exit 1
expect_count orphans "claimed dirs left behind" "$dirs" 0

# a log dir the run cannot write refuses by name, before any claim
mkdir -p "$fixture/locked/$LOGREL"
chmod a-w "$fixture/locked/$LOGREL"
case_run "--all · a log dir it cannot write → 💥, no log" 1 locked --all --within 30
expect_no_log locked "$case_new"
expect_cause locked "$case_out" "cannot be written"
chmod u+w "$fixture/locked/$LOGREL"
entries="$(count_found "$fixture/locked/$LOGREL" -mindepth 1)" || exit 1
expect_count locked "entries in the dir" "$entries" 0

# a log dir it may write but not search: `-w` passes, and `mkdir` of a stamp
#   fails for a cause other than a held name. the claim must name the fault at
#   once — never retry it, never blame a "taken stamp"
mkdir -p "$fixture/unsearch/$LOGREL"
chmod u=rw,go= "$fixture/unsearch/$LOGREL"
case_run "--all · a stamp claim refused for a fault → 💥 at once" 1 unsearch --all --within 30
expect_no_log unsearch "$case_new"
expect_cause unsearch "$case_out" "could not claim"
chmod u+rwx "$fixture/unsearch/$LOGREL"
entries="$(count_found "$fixture/unsearch/$LOGREL" -mindepth 1)" || exit 1
expect_count unsearch "entries in the dir" "$entries" 0

# the dir claim wins and the log create is refused, with no file at the name: the
#   claim must name the fault at once, and remove its own dir so no claim is left
case_run "--all · a log create refused after the dir claim → 💥 at once" 1 deep --all --within 30
expect_no_log deep "$case_new"
expect_cause deep "$case_out" "after its dir claim won"
entries="$(count_found "$fixture/deep/$LOGREL" -mindepth 1)" || exit 1
expect_count deep "entries in the dir" "$entries" 0

# the same refused create, and then the dir it claimed will not come off: the run
#   must name that fault, never blame a held stamp. no real peer can be timed into
#   that gap, so an `rmdir` stub on PATH poses it; the runner calls no other rmdir
mkdir -p "$fixture/stubs"
printf '#!/usr/bin/env bash\necho "rmdir: failed to remove '"'"'$1'"'"': Device or resource busy" >&2\nexit 1\n' > "$fixture/stubs/rmdir"
chmod +x "$fixture/stubs/rmdir"
PATH="$fixture/stubs:$PATH" case_run "--all · its own claim will not come off → 💥 at once" 1 deep --all --within 30
expect_no_log deep "$case_new"
expect_cause deep "$case_out" "could not remove this run's own claim"
rmdir "$fixture/deep/$LOGREL"/*/ || { cry "   💥 MalfunctionError: the stub-held claim dir could not be removed"; failed=1; }

# the verdict log turns read-only mid-run: the run must halt and name the log,
#   and the log must end short of a tally, so no reader takes it as a verdict
case_run "--all · the verdict log stops a write mid-run → 💥, its tree left open at the fault" 1 truncated --all --within 30
expect_one_log truncated "$case_new" "   └─ verdicts"
expect_cause truncated "$case_out" "ends short of its tally"
snap_cut_log truncated "$case_new" "the truncated run's receipt · what=all/<stamp>.stdout.log, no tally"

# a run ended by SIGTERM while a play is in flight: its log stays, and ends short of
#   a tally, so a reader takes it as no verdict (`fail`), never as a green. its
#   terminal shows the same cut tree: the header, then naught after `└─ verdicts`.
#   a green log sits there first, so the cut log must be the NEWEST — the one a reader
#   picks — or the reader would read the prior green over a run that proved naught
prior="$fixture/killed/$LOGREL/2000-01-01T00-00-00Z.stdout.log"
mkdir -p "$fixture/killed/$LOGREL"
printf '      └─ 2 passed · 0 declined · 0 failed\n' > "$prior"
touch -d '2000-01-01T00:00:00Z' "$prior"
before="$(logs_of killed)"
killrc="$(kill_run_midway killed "$fixture/killed/inflight.marker")" || exit 1
if [[ "$killrc" -ne 0 ]]; then
  echo "   • --all · a run killed midway → rc=$killrc, non-zero ✔"
else
  cry "   💥 MalfunctionError: killed — a run ended by SIGTERM exited 0"
  failed=1
fi
cut="$(get_logs_added "$before" "$(logs_of killed)")"
expect_one_log killed "$cut" "   └─ verdicts"
if [[ -n "$cut" ]]; then
  later="$(count_found "$fixture/killed/$LOGREL" -name '*.stdout.log' -newer "$fixture/killed/$LOGREL/$cut")" || exit 1
  expect_count killed "logs with a later mtime than the cut one" "$later" 0
fi
if is_file_holding "$prior" "      └─ 2 passed · 0 declined · 0 failed"; then
  echo "   • killed — the prior green log is intact, and older ✔"
else
  cry "   💥 MalfunctionError: killed — the prior green log was changed or removed"
  failed=1
fi
# the snap pins the class the assert above proves, never the number: `timeout` relays the TERM,
# and its own exit then varies by coreutils version (143 on one, 124 on another)
transcript+="$(as_transcript_entry "--all · a run killed midway → its tree ends at the verdicts" "non-zero" \
  "$(as_redacted_output "$(cat "$fixture/tmp/killed.out")" "$fixture" "" "$USERNAME")")"$'\n'
snap_cut_log killed "$cut" "the killed run's receipt · what=all/<stamp>.stdout.log, no tally"

# a file holds the what=all name: the run must name the path it could not make,
#   add no log, and leave the file as it found it
case_run "--all · a file holds the log dir's name → 💥, no log" 1 squat --all --within 30
expect_no_log squat "$case_new"
expect_cause squat "$case_out" "could not make the log dir"
if is_file_holding "$fixture/squat/$LOGREL" squat; then
  echo "   • squat — the file at the name is intact ✔"
else
  cry "   💥 MalfunctionError: squat — the file at $LOGREL was changed or removed"
  failed=1
fi

# the per-play dir turns read-only mid-run: the next play never runs, and the
#   run must say so — never report it as a failed play, never reach a tally
case_run "--all · a play's log cannot be written → 💥, its tree left open at the fault" 1 playlock --all --within 30
expect_one_log playlock "$case_new" "      ├─ ✔ prove.a-locks-the-plays"
expect_cause playlock "$case_out" "so prove.b-passes never ran"
snap_cut_log playlock "$case_new" "the playlock run's receipt · what=all/<stamp>.stdout.log, no tally"

# a git that names the checkout and cannot read its index: a fault, never an
#   empty suite, and never an untracked play
case_run "--all · git cannot read the index → 💥, no log" 1 badindex --all --within 30
expect_no_log badindex "$case_new"
expect_cause badindex "$case_out" "git could not read the index"

# --list reads the same set, so it shares each answer
case_run "--list · the tracked set"                  0 green     --list
expect_cause green "$case_out" "1 play(s)"
case_run "--list · an empty index"                   0 empty     --list
expect_cause empty "$case_out" "(none)"
expect_cause empty "$case_out" "0 play(s)"
case_run "--list · an untracked play → refused"      2 untracked --list
expect_cause untracked "$case_out" "outside the index"
case_run "--list · git cannot read the index → 💥"   1 badindex  --list
expect_cause badindex "$case_out" "git could not read the index"

# --play runs one play, maps its exit to the runner's, and writes no verdict log
case_run "--play · a passed play → 0"               0 green --play prove.a-passes --within 30
expect_no_log green "$case_new"
case_run "--play · a failed play → 1"               1 mixed --play prove.c-fails --within 30
expect_no_log mixed "$case_new"
case_run "--play · a declined play → 2"             2 mixed --play prove.b-declines --within 30
expect_no_log mixed "$case_new"
case_run "--play · no such play → refused"          2 green --play prove.zz-absent
expect_no_log green "$case_new"
case_run "--play --within 0 → refused"              2 green --play prove.a-passes --within 0
expect_no_log green "$case_new"
expect_cause green "$case_out" "whole seconds, at least 1"
case_run "--play · a hung play → timed out, 2"      2 unproven --play prove.a-hangs --within 1
expect_cause unproven "$case_out" "did not finish within 1s"
case_run "--play · a play with no verb → refused"   2 unproven --play bogus.b-noverb
expect_cause unproven "$case_out" "does not name a verb"
case_run "--play · a repair play → refused"         2 verbs --play repair.a-fixes
expect_cause verbs "$case_out" "is a repair play"
# the slug guard is what keeps the runner from a general shell: a path is never a slug
case_run "--play · a path, not a slug → refused"    2 green --play ../escape
expect_cause green "$case_out" "never by path"
case_run "--play · a flag, not a slug → refused"    2 green --play -x
expect_cause green "$case_out" "never by path"
# a play on disk and not in the index: the publish guard. a pulled tree can write here
case_run "--play · an untracked play → refused"     2 untracked --play prove.z-stray
expect_cause untracked "$case_out" "NOT in this repo's index"

# the args a caller can leave out, and the trees with no suite to name
case_run "--play with no value → refused"           2 green --play
expect_cause green "$case_out" "--play needs a value"
case_run "--within with no value → refused"         2 green --all --within
expect_cause green "$case_out" "--within needs a value"
# the class of a bad bound, not one value: each would reach `timeout` as its own fault
for bad in abc -5 1.5 007 ''; do
  case_run "--within '$bad' → refused"               2 green --all --within "$bad"
  expect_no_log green "$case_new"
  expect_cause green "$case_out" "whole seconds, at least 1"
done

# a git that answers and warns: the set still lands, and git's words sit under the
#   header, labeled, never raw at column 0. a stub on PATH warns, then hands the call on
gitreal="$(command -v git)"
printf '#!/usr/bin/env bash\necho "warning: the clamp stub warns" >&2\nexec %s "$@"\n' "$gitreal" > "$fixture/stubs/git"
chmod +x "$fixture/stubs/git"
PATH="$fixture/stubs:$PATH" case_run "--list · git answers and warns → its words labeled" 0 green --list
expect_cause green "$case_out" "git said:"
expect_cause green "$case_out" "prove.a-passes"
rm -f "$fixture/stubs/git"
case_run "no subject → refused, names the three"    2 green --within 30
expect_cause green "$case_out" "name a play"
case_run "a checkout with no play dir → refused"    2 noplays --all --within 30
expect_no_log noplays "$case_new"
expect_cause noplays "$case_out" "no tracked play dir at"
case_run "no checkout at all → refused"             2 nogit --all --within 30
expect_cause nogit "$case_out" "no tracked play dir at <no checkout>"

# a fold that dropped a play is the defect this clamp exists for: each verdict
#   line must name its own play, in the mixed suite
for want in "✔ prove.a-passes" "🌙 prove.b-declines" "💥 prove.c-fails" "1 passed · 1 declined · 1 failed"; do
  if [[ "$transcript" == *"$want"* ]]; then
    echo "   • the mixed suite names '$want' ✔"
  else
    cry "   💥 MalfunctionError: the mixed suite never names '$want'"
    failed=1
  fi
done

# every case ran with TMPDIR inside the fixture: the runner writes its logs to the
#   tree alone, so the tmp dir holds only the outputs this clamp itself captured
strays="$(count_found "$fixture/tmp" -mindepth 1 ! -name 'race.*.out' ! -name killed.out)" || exit 1
expect_count tmp "entries the runner wrote under TMPDIR" "$strays" 0

# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
play_snap_verify dir="$HERE/.play/permanent/prove.play-run-all-reads-three-verdicts.snap" name=transcript actual="$transcript" \
  || failed=1

[[ "$failed" -eq 0 ]] && echo "🌲 all claims held ✔"
exit "$failed"
