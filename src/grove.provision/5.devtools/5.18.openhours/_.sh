#!/usr/bin/env bash
######################################################################
# .what = the open-hours gate — a reconciler, its systemd user unit, and a
#         timer that re-asks the policy twice an hour
#
#   inside the declared window the GLOBAL commit and radio gates are closed;
#   outside it they are open. the SCHEDULE is declared below; the clock math
#   lives in `src/machine/machine_openhours_reconcile`.
#
# 🛑 .it is OPT-IN, PER BOX — the marker at `GROVE_OPENHOURS_OPTIN` is the switch
#   - hours are a seat's PREFERENCE, never a tree fact; the default is off
#   - every box runs every phase; only what it converges TO varies by the marker
#   - opt-out TEARS DOWN the reconciler and opens NO gate
#   - the marker is box-side and presence-only; the schedule stays in the tree
#   - the full argument: `rule.require.optin-bundles-converge-to-their-flag`
#
# 🛑 .why this bundle OWNS a linked dir, rather than reach for a checkout
#   `rhx` finds a skill by a pure filesystem read of `$cwd/.agent/repo=*/
#   role=*/skills/*` (`discoverSkillExecutables.ts:26`), and the gate skills
#   also call `require_git_repo`. so the reconciler's cwd owes TWO facts.
#
#   - a grove's pushed tree is no repo and its role links dangle (rsync skips
#     `.git` and `node_modules`; measured on a grove: both gate skills absent)
#   - ⇒ the cwd is a dir this bundle BUILDS: `git init`, the two pinned role
#     packages, `rhachet roles link` — one mechanism on every box
#
# .why 5.devtools: it needs `rhx` (5.3.brains) and node (5.1.node) to land first
#   (`define.provision-defect-shapes`, shape 1)
#
# .why it declines nowhere: every box that runs `rhx` can hold this subject
#
# ⚠️ a grove left open while the laptop closes still takes commits — the per-seat
#   recipe and that hole: `howto.opt-into-openhours`
#
# usage:
#   rhx grove.provision --what 5.18.openhours --mode apply
######################################################################

####################################################################
# the OPT-IN MARKER — this seat's election, and the whole switch
#   - under `~/.config`, never `~/.local/state`: a human owns it, and the teardown
#     clears the state dir
#   - PRESENCE is the contract; the body is free text, never parsed
####################################################################
GROVE_OPENHOURS_OPTIN="${XDG_CONFIG_HOME:-$HOME/.config}/grove/openhours.optin"

# .what = has THIS box elected the gate?  `in` | `out`
# .why  = ONE reader for both halves (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9)
# 🛑 it READS and never writes: a write would grant the opt-in it asks about
grove_provision_5_18_openhours_optin_state() {
  [[ -f "$GROVE_OPENHOURS_OPTIN" ]] && { echo in; return 0; }
  echo out
}

####################################################################
# the cwd the reconciler stands in — ONE declaration, read by the payload,
# the upsert, and the verify alike
# ⚠️ .why a BAKED path: it derives from `$HOME`; a pointer file would be a second declaration
####################################################################
GROVE_OPENHOURS_CWD="$HOME/.local/state/machine_openhours/cwd"

####################################################################
# the SCHEDULE — ONE declaration, read by the upsert, the verify, and by the
# payload through the file rendered below
#
# ⚠️ .why the SCHEDULE lives in the REPO: the hours are one fact for every box
#   (`rule.require.repo-as-source-of-truth`); the marker is a per-seat election
#
# ⚠️ .the DAYS are a contiguous RANGE, so `mon,tue,thu` is INEXPRESSIBLE
#   a set parser is unbuilt because no one has asked for one. the bound is
#   stated rather than hidden: a split week needs this to grow a parser first.
####################################################################
GROVE_OPENHOURS_DAYS="1-5"             # iso weekdays, mon=1 .. sun=7, contiguous
GROVE_OPENHOURS_FROM="08:00"           # inclusive
GROVE_OPENHOURS_TILL="20:00"           # exclusive
GROVE_OPENHOURS_ZONE="America/Chicago"

# the rendered copy the PAYLOAD reads. it runs from `~/.local/bin`, outside any
# checkout, so it cannot source this file — see the render below
GROVE_OPENHOURS_SCHEDULE="$HOME/.local/state/machine_openhours/schedule.env"

# .what = is the declared schedule well formed? stdout names the first fault
# .why  = ONE reader, so the upsert and the verify cannot cut the set two ways
#   (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9)
#
# 🛑 .why the zone is checked against `/usr/share/zoneinfo` and NEVER via `date`
#   measured 2026-09-17: `TZ="Nonsense/Zone" date +%H%M` exits 0 and answers in
#   UTC. so a typo'd zone yields a silently WRONG window, and an exit-code check
#   would read it as valid — a gate that closes at the wrong hour, with no signal
#
# ⚠️ `10#` on the times: bash reads `0800` as OCTAL, and `8` is no octal digit
grove_provision_5_18_openhours_schedule_check() {
  local lo hi
  [[ "$GROVE_OPENHOURS_DAYS" =~ ^([1-7])-([1-7])$ ]] || {
    echo "days '$GROVE_OPENHOURS_DAYS' is no contiguous iso range — expected e.g. '1-5'"
    return 1
  }
  lo="${BASH_REMATCH[1]}"; hi="${BASH_REMATCH[2]}"
  [[ "$lo" -le "$hi" ]] || {
    echo "days '$GROVE_OPENHOURS_DAYS' runs backward — a range wraps no week"
    return 1
  }

  [[ "$GROVE_OPENHOURS_FROM" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]] || {
    echo "from '$GROVE_OPENHOURS_FROM' is no HH:MM clock time"; return 1; }
  [[ "$GROVE_OPENHOURS_TILL" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]] || {
    echo "till '$GROVE_OPENHOURS_TILL' is no HH:MM clock time"; return 1; }
  [[ $((10#${GROVE_OPENHOURS_FROM//:/})) -lt $((10#${GROVE_OPENHOURS_TILL//:/})) ]] || {
    echo "from '$GROVE_OPENHOURS_FROM' is not before till '$GROVE_OPENHOURS_TILL'"
    return 1
  }

  [[ -f "/usr/share/zoneinfo/$GROVE_OPENHOURS_ZONE" ]] || {
    echo "zone '$GROVE_OPENHOURS_ZONE' names no file under /usr/share/zoneinfo"
    return 1
  }
}

# .what = run one file step of the upsert; on a fault, a ✋ that carries the tool's own words
# .why  = a bare `|| return 1` let a raw coreutils line print above no ✋ at all
grove_provision_5_18_openhours_step() {
  local what="$1"; shift
  local err
  # LC_ALL=C: the tool's words ride as `cause:`, alike on every box
  err="$(LC_ALL=C "$@" 2>&1)" && return 0
  echo "   ✋ ConstraintError: could not $what" >&2
  [[ -n "$err" ]] && echo "      cause: $err" >&2
  return 1
}

# .what = the schedule as the payload reads it
# .why  = ONE renderer, so the upsert WRITES and the verify DIFFS one text
grove_provision_5_18_openhours_schedule_render() {
  cat <<EOF
# GENERATED by: rhx grove.provision --what 5.18.openhours --mode apply
# the declaration lives in src/grove.provision/5.devtools/5.18.openhours/_.sh
# an edit here is overwritten by the next apply
OPENHOURS_DAYS=$GROVE_OPENHOURS_DAYS
OPENHOURS_FROM=$GROVE_OPENHOURS_FROM
OPENHOURS_TILL=$GROVE_OPENHOURS_TILL
OPENHOURS_ZONE=$GROVE_OPENHOURS_ZONE
EOF
}

####################################################################
# the role packages the gate skills come from — pinned, ONE declaration,
# read by BOTH halves (`gotcha.a-check-that-cries-wolf`, m.9 / m.13)
#
# .why pinned: this dir is installed once and never re-resolved, so a float
#   would make two boxes provisioned a month apart disagree on the skill that
#   moves the gate
####################################################################
GROVE_OPENHOURS_ROLE_PKGS=(
  "rhachet-roles-ehmpathy@1.38.12"   # git.commit.uses
  "rhachet-roles-bhuild@0.21.36"     # radio.uses
)

####################################################################
# the two skill paths the cwd must carry, relative to it — ONE declaration
####################################################################
GROVE_OPENHOURS_SKILL_COMMIT=".agent/repo=ehmpathy/role=mechanic/skills/git.commit/git.commit.uses.sh"
GROVE_OPENHOURS_SKILL_RADIO=".agent/repo=bhuild/role=dispatcher/skills/radio.uses.sh"

# .what = which of THREE states is the reconciler's cwd in? whole|half|absent
# .why a state, never a boolean, so the upsert and the verify share one fact
#   rather than cut the same set two ways (`gotcha.a-check-that-cries-wolf`, m.9)
#
# 🛑 .why it reads the installed VERSION and not merely the file
#   a pin guarded on presence governs the first apply and no other, so a bump
#   reaches no box that already holds the tool — the deterministic clause of
#   `rule.require.one-command-provision`, defeated by the bundle's own guard.
#   ⇒ drift off the pin reads `half`, and the upsert rebuilds
#
# stdout: whole = a git repo, both packages AT THE PIN, both gate skills on disk
#         half  = the dir exists and one of those does not hold
#         absent = never built
grove_provision_5_18_openhours_cwd_state() {
  local dir="$GROVE_OPENHOURS_CWD" spec name want have
  [[ -d "$dir" ]] || { echo absent; return 0; }
  [[ -d "$dir/.git" ]] || { echo half; return 0; }

  for spec in "${GROVE_OPENHOURS_ROLE_PKGS[@]}"; do
    name="${spec%@*}"
    want="${spec##*@}"
    have="$(jq -r '.version // empty' "$dir/node_modules/$name/package.json" 2>/dev/null)"
    [[ "$have" == "$want" ]] || { echo half; return 0; }
  done

  [[ -r "$dir/$GROVE_OPENHOURS_SKILL_COMMIT" ]] || { echo half; return 0; }
  [[ -r "$dir/$GROVE_OPENHOURS_SKILL_RADIO"  ]] || { echo half; return 0; }
  echo whole
}

grove_provision_5_18_openhours() {
  bundle.upgrade 5.18.openhours.provision.upsert
  bundle.upgrade 5.18.openhours.provision.verify
}
