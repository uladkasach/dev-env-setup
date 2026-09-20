#!/usr/bin/env bash
######################################################################
# .what = the open-hours gate — a reconciler, its systemd user unit, and a
#         timer that re-asks the policy twice an hour
#
#   inside the declared window the GLOBAL commit and radio gates are closed;
#   outside it they are open. the SCHEDULE is declared below; the clock math
#   lives in `src/machine/machine_openhours_reconcile`.
#
# 🛑 .it is OPT-IN — `GROVE_OPENHOURS_ENABLED` is the whole switch
#   every other bundle converges a FACT about the box. this one enacts a human's
#   declared hours, which is a PREFERENCE — so no run installs a gate the tree
#   has not asked for, and the flag is the only place that asks.
#   ⇒ the tree currently declares `true`: every box this repo converges carries
#     the gate. set it `false` and the next apply tears it down (below).
#
# ⚠️ .why opt-out TEARS DOWN, where `6.apps` merely skips
#   `grove_optin`'s "never uninstalls" is right for an app: a forgotten
#   `--include` must not be destructive. it is wrong for a GATE — a box opted in
#   once and out later would keep a live timer that blocks commits, and no line
#   in the repo would declare it.
#   ⇒ so `false` disables the timer and removes what this bundle installed, and
#     it opens NO gate. a human may have closed one by hand, and the safe
#     direction on an unreconciled gate is closed. opt-out means STOP
#     RECONCILING, never OPEN.
#
# ⚠️ .why the flag is a REPO edit and not an `--include` flag
#   `--include` is per-run, so the gate would need the flag on every apply or be
#   torn down by the next one — and a gate a human must re-request forever is a
#   gate they will lose. a declared state converges instead: the tree says what
#   holds, and one command makes the box match (`rule.require.one-command-provision`).
#
# 🛑 .why this bundle OWNS a linked dir, rather than reach for a checkout
#   `rhx` finds a skill by a pure filesystem read of `$cwd/.agent/repo=*/
#   role=*/skills/*` (`discoverSkillExecutables.ts:26`), and the gate skills
#   also call `require_git_repo`. so the reconciler's cwd owes TWO facts.
#
#   no checkout on a grove holds both, and that is DECLARED rather than drifted:
#   `5.10.repos.configure.upsert:138` states this repo's src "arrived by
#   'grove.push', not by clone — expected on a grove". rsync skips `.git` and
#   `node_modules`, so the pushed tree is not a repo and its role symlinks
#   dangle — measured on grove-ahbode-v20260901: 110 `repo=.this` skills found,
#   both gate skills absent.
#
#   ⇒ so the cwd is a dir this bundle BUILDS: `git init`, the two role packages
#     installed, `rhachet roles link` run. one mechanism, identical on a laptop
#     and a grove (`rule.forbid.divergence-without-a-physical-reason`).
#
# .why 5.devtools and not 1.system
#   it drives `rhx git.commit.uses` and `rhx radio.uses`, so it needs `rhx`
#   (5.3.brains) and node (5.1.node). a bundle numbered for its SUBJECT while
#   its dependency lands later is defect shape 1 of
#   `define.provision-defect-shapes`; this is numbered for where its dependency
#   already is.
#
# .why it declines nowhere
#   the gate is a fact about the HUMAN's day, not a box's hardware, and the
#   human works through every box they own. a grove left open while the laptop
#   closes is the gate with a hole in it. ⇒ every box that runs `rhx` gets it,
#   and the verify names the ways a box can fail to.
#
# usage:
#   rhx grove.provision --what 5.18.openhours --mode apply
######################################################################

####################################################################
# the cwd the reconciler stands in — ONE declaration, read by the payload,
# the upsert, and the verify alike
#
# ⚠️ .why a BAKED path and not a pointer file
#   it derives from `$HOME`, so it is the same sentence on every box. a
#   pointer would be a second declaration of a fact `$HOME` already carries,
#   free to drift with no reader to catch it
####################################################################
GROVE_OPENHOURS_CWD="$HOME/.local/state/machine_openhours/cwd"

####################################################################
# the SCHEDULE — ONE declaration, read by the upsert, the verify, and by the
# payload through the file rendered below
#
# ⚠️ .why it lives in the REPO and not in a box-side file
#   a config edited on the box is lost at the next apply, and the next box never
#   gets it (`rule.require.repo-as-source-of-truth`). the tree is the sole
#   declaration of what a box holds, and a human's working day is such a fact.
#
# ⚠️ .the DAYS are a contiguous RANGE, so `mon,tue,thu` is INEXPRESSIBLE
#   a set parser is unbuilt because no one has asked for one. the bound is
#   stated rather than hidden: a split week needs this to grow a parser first.
####################################################################
GROVE_OPENHOURS_ENABLED=true
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
