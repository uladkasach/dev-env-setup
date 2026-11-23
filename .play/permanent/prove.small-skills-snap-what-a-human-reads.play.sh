#!/usr/bin/env bash
######################################################################
# .what = drive the small skills this route added through help, each refusal,
#         and their work, assert each exit, and snap every word a human reads
#
# .why  = a skill's text is its contract: a fix-text that names a verb the skill
#         refuses sends a human in a circle, and a drift in a glyph or a word ships
#         unseen with no snap. the skills here:
#           git.tree.aside            set / get / bare get, by EXACT tag
#           file.exec.set             the exec bit, and each path it refuses
#           brains.auth.reset.probe   the reset reader, with jq's own stderr
#           git.grove.sync            its help and its arg refusal
#
# guarantee:
#   - HERMETIC: a temp git repo of its own (its own stash), a temp HOME; no
#     network, no grove, and the shared stash stack is never touched
#   - each call is bounded (`timeout -k 2 20`)
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILLS="$HERE/.agent/repo=.this/role=any/skills"

home="$(mktemp -d)"
repo="$(mktemp -d)"
trap 'rm -rf "$home" "$repo"' EXIT
cp "$HERE/src/grove.provision/2.shell/2.7.aliases/bash_aliases.sh" "$home/.bash_aliases"

git -C "$repo" init -q
git -C "$repo" -c user.name=test -c user.email=human@example.com commit -q --allow-empty -m root
printf 'a0\n' >"$repo/a.txt"; printf 'b0\n' >"$repo/b.txt"
git -C "$repo" add a.txt b.txt
git -C "$repo" -c user.name=test -c user.email=human@example.com commit -q -m base

failed=0
transcript=""
fail() { echo "   💥 MalfunctionError: $1" >&2; failed=1; }
claim() { local label="$1"; shift; if "$@"; then echo "   • $label ✔"; else fail "$label"; fi; }

# one call — $1 = label · $2 = exit wanted · then the skill and its args; runs in the temp repo
OUT=""
case_run() {
  local label="$1" want="$2" skill="$3" rc
  shift 3
  OUT="$(cd "$repo" && env HOME="$home" timeout -k 2 20 bash "$SKILLS/$skill.sh" "$@" </dev/null 2>&1)" && rc=0 || rc=$?
  OUT="$(printf '%s\n' "$OUT" | sed -e "s#$repo#<repo>#g" -e "s#$home#<home>#g" -e "s#$HERE#<checkout>#g" \
           -e 's#\b[0-9a-f]\{40\}\b#<sha>#g' -e 's#jq: .*#jq: <jq>#')"
  transcript+=$'\n'"## $label"$'\n'"rc=$rc"$'\n'"$OUT"$'\n'
  if [[ "$rc" -eq "$want" ]]; then echo "   • $label → rc=$rc ✔"; return 0; fi
  fail "$label → rc=$rc, expected rc=$want"
  return 1
}
has() { [[ "$OUT" == *"$1"* ]]; }

echo "🌲 prove.small-skills-snap-what-a-human-reads"

######################################################################
# git.tree.aside
######################################################################
case_run "tree.aside · --help"                           0 git.tree.aside --help
case_run "tree.aside · no verb refuses"                  2 git.tree.aside
case_run "tree.aside · two verbs refuse"                 2 git.tree.aside set get
case_run "tree.aside · an unknown argument refuses"      2 git.tree.aside --bogus
case_run "tree.aside · set with no --tag refuses"        2 git.tree.aside set --path a.txt
case_run "tree.aside · set with no --path refuses"       2 git.tree.aside set --tag x
claim "tree.aside · each refusal names the help" test "$(grep -c 'see: rhx git.tree.aside --help' <<<"$OUT")" -eq 1
case_run "tree.aside · bare get, none held"              0 git.tree.aside get
case_run "tree.aside · set on an unedited path refuses"  2 git.tree.aside set --tag clean --path a.txt
claim "tree.aside · it names the caller's fix, never a malfunction" has "naught to set aside"
printf 'a1\n' >"$repo/a.txt"
case_run "tree.aside · set feat.old (a.txt)"             0 git.tree.aside set --tag feat.old --path a.txt
printf 'b1\n' >"$repo/b.txt"
case_run "tree.aside · set feat (b.txt)"                 0 git.tree.aside set --tag feat --path b.txt
case_run "tree.aside · a held tag refuses"               2 git.tree.aside set --tag feat --path b.txt
case_run "tree.aside · bare get lists both"              0 git.tree.aside get
claim "tree.aside · both tags listed" has "feat.old"
case_run "tree.aside · an absent tag refuses"            2 git.tree.aside get --tag nope
claim "tree.aside · its fix names a verb the skill runs" has "rhx git.tree.aside get"
# a FOREIGN entry, newest, whose message merely ends in `tree.aside: feat`
printf 'f1\n' >"$repo/f.txt"; git -C "$repo" add f.txt
git -C "$repo" stash push -q -m "wip tree.aside: feat" -- f.txt
case_run "tree.aside · bare get lists no foreign entry"  0 git.tree.aside get
claim "tree.aside · the foreign entry is not listed" test "$(grep -c 'feat (' <<<"$OUT")" -eq 1
case_run "tree.aside · get feat lays feat alone"         0 git.tree.aside get --tag feat
claim "tree.aside · feat's edit is back" test "$(cat "$repo/b.txt")" = b1
claim "tree.aside · the foreign entry stays (an exact tag, never a tail match)" test ! -e "$repo/f.txt"
claim "tree.aside · feat.old's edit stays aside" test "$(cat "$repo/a.txt")" = a0
case_run "tree.aside · get feat.old lays it"             0 git.tree.aside get --tag feat.old
claim "tree.aside · feat.old's edit is back" test "$(cat "$repo/a.txt")" = a1
# HEAD moves a held path: the get refuses BEFORE it writes conflict markers
case_run "tree.aside · set moved (a.txt)"                0 git.tree.aside set --tag moved --path a.txt
printf 'a2\n' >"$repo/a.txt"
git -C "$repo" -c user.name=test -c user.email=human@example.com commit -q -am "move a"
case_run "tree.aside · a moved path refuses, entry kept" 2 git.tree.aside get --tag moved
claim "tree.aside · the live file is untouched" test "$(cat "$repo/a.txt")" = a2
case_run "tree.aside · the kept entry still lists"       0 git.tree.aside get
claim "tree.aside · moved is still held" has "moved"

######################################################################
# file.exec.set
######################################################################
printf '#!/usr/bin/env bash\n' >"$repo/run.sh"
mkdir -p "$repo/dir"; ln -s run.sh "$repo/link.sh"
case_run "exec.set · --help"                             0 file.exec.set --help
case_run "exec.set · a file gains its bit"               0 file.exec.set --path run.sh
claim "exec.set · the bit is set" test -x "$repo/run.sh"
case_run "exec.set · a second run reports, writes naught" 0 file.exec.set --path run.sh
claim "exec.set · the rerun says already runnable" has "already runnable"
case_run "exec.set · a path outside the repo refuses"    2 file.exec.set --path "$home/.bash_aliases"
case_run "exec.set · a dir refuses"                      2 file.exec.set --path dir
case_run "exec.set · a symlink refuses"                  2 file.exec.set --path link.sh
case_run "exec.set · no --path refuses"                  2 file.exec.set
claim "exec.set · no --path names the help" has "see: rhx file.exec.set --help"
case_run "exec.set · an unknown argument refuses"        2 file.exec.set --bogus

######################################################################
# outside any repo: both repo-bound skills refuse, and name where to run
######################################################################
case_out() {
  local label="$1" want="$2" skill="$3" rc
  shift 3
  OUT="$(cd "$home" && env HOME="$home" GIT_CEILING_DIRECTORIES="$home" timeout -k 2 20 bash "$SKILLS/$skill.sh" "$@" </dev/null 2>&1)" && rc=0 || rc=$?
  OUT="$(printf '%s\n' "$OUT" | sed -e "s#$home#<home>#g")"
  transcript+=$'\n'"## $label"$'\n'"rc=$rc"$'\n'"$OUT"$'\n'
  [[ "$rc" -eq "$want" ]] && { echo "   • $label → rc=$rc ✔"; return 0; }
  fail "$label → rc=$rc, expected rc=$want"
}
case_out "tree.aside · outside a repo refuses"           2 git.tree.aside get
case_out "exec.set · outside a repo refuses"             2 file.exec.set --path x.sh

######################################################################
# git.grove.play.stop — its help and its arg refusals (a stop needs a grove)
######################################################################
case_run "play.stop · --help"                            0 git.grove.play.stop --help
case_run "play.stop · an unknown arg refuses"            2 git.grove.play.stop --bogus
case_run "play.stop · two groves refuse"                 2 git.grove.play.stop grove-a grove-b --play x

######################################################################
# brains.auth.reset.probe — this checkout's reader, on the real-offer node
######################################################################
case_run "reset.probe · --help"                          0 brains.auth.reset.probe --help
case_run "reset.probe · the default node"                0 brains.auth.reset.probe --from checkout
claim "reset.probe · jq said naught" has "jq stderr: (none)"
# the probe's reason to exist: a node jq cannot read, so the reader's `?` gains jq's own words
case_run "reset.probe · a node jq cannot parse"          0 brains.auth.reset.probe --from checkout --node 'not json'
claim "reset.probe · the reader prints its ?" has "reader: ? could not read the reset fields"
claim "reset.probe · jq's stderr is shown, each line a child branch" has "└─ jq stderr"$'\n'"      └─ "
# saved grants of both kinds: the full row folds the week-clear grants, the fable row the rest
ce='{"cedar_ember":{"grants":[{"resets_left":2,"usable_now":true,"ends_at":"2026-12-05T00:00:00Z","clears":["seven_day","five_hour"]},{"resets_left":1,"usable_now":false,"ends_at":"2026-12-01T00:00:00Z","clears":["seven_day"]},{"resets_left":1,"usable_now":true,"ends_at":"2026-12-09T00:00:00Z","clears":["five_hour"],"gives_back_weekly":true}]}}'
case_run "reset.probe · saved grants, the full row"      0 brains.auth.reset.probe --from checkout --node "$ce"
claim "reset.probe · full folds two grants, earliest expiry" has "reader: 🎁 3 saved · 2 usable now · first expires dec 01"
case_run "reset.probe · saved grants, the fable row"     0 brains.auth.reset.probe --from checkout --node "$ce" --kind fable
claim "reset.probe · fable reads the grant that leaves the week" has "reader: 🎀 1 saved · usable now · expires dec 09"
claim "reset.probe · jq said naught on the grants" has "jq stderr: (none)"
case_run "reset.probe · an unknown arg refuses"          2 brains.auth.reset.probe --bogus
case_run "reset.probe · no installed reader refuses"     2 brains.auth.reset.probe

######################################################################
# git.grove.sync — its help, and its arg refusal (a drift read needs a tailnet)
######################################################################
case_run "grove.sync · --help"                           0 git.grove.sync --help
case_run "grove.sync · an unknown arg refuses"           2 git.grove.sync --bogus
case_run "grove.sync · a --mode outside plan|apply refuses" 2 git.grove.sync --mode go

######################################################################
# aws.reach.set / .del — a given rack root that is no repo refuses before any step
######################################################################
mkdir -p "$home/notrepo"
case_run "reach.set · --help"                              0 aws.reach.set --help
claim "reach.set · its help names --gitroot" has "--gitroot"
case_run "reach.del · --help"                              0 aws.reach.del --help
claim "reach.del · its help names --gitroot" has "--gitroot"
case_run "reach.set · a --gitroot that is no repo refuses" 2 aws.reach.set --org ahbode --env test --gitroot "$home/notrepo"
claim "reach.set · it names the bundle that owns the rack root" has "5.12.rack"
case_run "reach.del · a --gitroot that is no repo refuses" 2 aws.reach.del --org ahbode --env test --gitroot "$home/notrepo"
claim "reach.del · it names the bundle that owns the rack root" has "5.12.rack"

# the credential half, on a laptop seat: a profile with no sso login is refused before any
#   write, named with the one command that declares it; a declared one needs no work. the
#   seat is pinned, so every box reads the laptop arm, and the temp HOME holds the aws config
export GROVE_ENV_SERVER=local@unix
case_run "reach.set · a laptop profile with no sso login refuses"   2 aws.reach.set --org ahbode --env test --gitroot "$repo"
claim "reach.set · it names the sso command that declares it" has "aws configure sso --profile"
reach_profile="$(grep -oE 'aws configure sso --profile [^ ]+' <<<"$OUT" | awk '{ print $NF }')"
mkdir -p "$home/.aws"; printf '[profile %s]\nregion = us-east-1\n' "$reach_profile" >"$home/.aws/config"
case_run "reach.set · a laptop profile already declared needs no work" 0 aws.reach.set --org ahbode --env test --gitroot "$repo"
claim "reach.set · it names the sts read that proves it" has "aws sts get-caller-identity --profile $reach_profile"
rm -rf "$home/.aws"
unset GROVE_ENV_SERVER

# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
play_snap_verify dir="$HERE/.play/permanent/prove.small-skills-snap-what-a-human-reads.snap" name=transcript actual="$transcript" \
  || failed=1

[[ "$failed" -eq 0 ]] && echo "🌲 all claims held ✔"
exit "$failed"
