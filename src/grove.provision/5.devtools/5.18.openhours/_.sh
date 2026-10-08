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
#   every other bundle converges a FACT about the box. this one enacts a human's
#   declared hours, which is a PREFERENCE — and a preference is held by a SEAT,
#   not by a tree. one human runs a laptop they want fenced and a grove they do
#   not, so a single tree-wide boolean could not express what they actually want.
#   ⇒ the DEFAULT is off. a box carries the gate only where the marker is placed.
#
# 🛑 .why this is NOT a per-machine bundle subset
#   `rule.require.identical-bundle-composition` forbids a per-machine subset, and
#   it is not bent here: EVERY box runs this bundle and every one of its phases.
#   the bundle declines nowhere. what varies is what it CONVERGES TO — installed
#   where the marker is present, torn down where it is absent — which is the same
#   shape as `1.2.power` converging logind to a declared value.
#   ⇒ the rule governs which bundles RUN. it says no word about what a bundle
#     converges to, and a flag the BODY reads is not a decline.
#     see `rule.require.optin-bundles-converge-to-their-flag`.
#
# ⚠️ .why opt-out TEARS DOWN, where `6.apps` merely skips
#   `grove_optin`'s "never uninstalls" is right for an app: a forgotten
#   `--include` must not be destructive. it is wrong for a GATE — a box opted in
#   once and out later would keep a live timer that blocks commits, and no line
#   anywhere would declare it.
#   ⇒ so an absent marker disables the timer and removes what this bundle
#     installed, and it opens NO gate. a human may have closed one by hand, and
#     the safe direction on an unreconciled gate is closed. opt-out means STOP
#     RECONCILING, never OPEN.
#
# ⚠️ .why a BOX-SIDE marker, where the schedule stays in the TREE
#   the two facts have different owners, and `rule.require.repo-as-source-of-truth`
#   is satisfied by both. the SHAPE of the gate — its hours, its zone, its units,
#   its pins — is one fact for every box, so the tree holds it and a fresh box
#   inherits it. the ELECTION — does THIS seat want fencing — differs per box, so
#   no tree value can carry it.
#   ⇒ the rule's two stated harms both miss here: no value is "lost at the next
#     apply", because this bundle READS the marker and never writes or removes it;
#     and "the next machine never gets it" is not a loss but the POINT, since
#     opt-in-only means a fresh box correctly carries no gate.
#
# ⚠️ .why the marker is a box-side file and not an `--include` flag
#   `--include` is per-run, so the gate would need the flag on every apply or be
#   torn down by the next one — and a gate a human must re-request forever is a
#   gate they will lose. a placed marker converges instead: the box says what it
#   wants, and one command makes it match (`rule.require.one-command-provision`).
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
#   a decline is a claim that a box CANNOT hold the subject, and every box that
#   runs `rhx` can hold this one. so there is no decline to write: the bundle and
#   all four of its phases run everywhere, and the verify names the ways a box
#   can fail to carry what its own marker asked for.
#
# ⚠️ .the HOLE moved to the marker, and it is the human's to close
#   the gate is a fact about the HUMAN's day, and the human works through every
#   box they own — so a grove left open while the laptop closes is a box that
#   still takes commits. a tree-wide flag closed that hole by force and cost the
#   human the choice; a per-box marker hands the choice back and the hole with it.
#   ⇒ opting in is therefore a PER-BOX act, and `howto.opt-into-openhours`
#     carries the per-seat recipe.
#
# usage:
#   rhx grove.provision --what 5.18.openhours --mode apply
######################################################################

####################################################################
# the OPT-IN MARKER — this seat's election, and the whole switch
#
# ⚠️ .why `~/.config` and not `~/.local/state`
#   xdg splits them by OWNER, and this repo reads that split literally elsewhere
#   (`${XDG_CONFIG_HOME:-$HOME/.config}` at `4.5.nvim`, `2.8.tmux`). config is
#   what a HUMAN writes; state is what a program writes. this marker is the one
#   file in this bundle a human owns, so it cannot sit beside the two files the
#   bundle renders under `~/.local/state/machine_openhours/`.
#   ⇒ and the teardown below removes files from THAT dir, so a marker kept there
#     would be deleted by the very opt-out it is supposed to survive.
#
# 🛑 .PRESENCE is the contract — the content is never parsed
#   a parsed value needs a grammar, and a grammar can be typo'd: `OPTIN=ture`
#   reads as neither true nor false, so the bundle must either guess (and tear
#   down a gate the human asked for) or fail (and block a run over a stray
#   character). presence has no grammar to get wrong.
#   ⇒ so the file's BODY is free text, and a human is invited to leave their
#     reason in it. this bundle reads only whether the path exists.
####################################################################
GROVE_OPENHOURS_OPTIN="${XDG_CONFIG_HOME:-$HOME/.config}/grove/openhours.optin"

# .what = has THIS box elected the gate?  `in` | `out`
# .why  = ONE reader, so the upsert and the verify cannot cut the set two ways
#   (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9) — the same reason the
#   schedule check and the cwd state reader below are each written once
#
# 🛑 it READS and never writes. a bundle that created this file on apply would
#   grant the opt-in it was sent to ask about, so the first apply would enroll
#   every box and the default would be off in name alone
grove_provision_5_18_openhours_optin_state() {
  [[ -f "$GROVE_OPENHOURS_OPTIN" ]] && { echo in; return 0; }
  echo out
}

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
# ⚠️ .why the SCHEDULE lives in the REPO, where the MARKER above does not
#   a config edited on the box is lost at the next apply, and the next box never
#   gets it (`rule.require.repo-as-source-of-truth`) — and both harms land on a
#   schedule. the hours are ONE fact for every box, so the tree is their sole
#   declaration and a fresh box inherits them.
#   ⇒ the marker is the opposite case on both counts: it is never written by this
#     bundle, so no apply can lose it, and a fresh box inheriting no gate is what
#     opt-in-only MEANS. one bundle, two facts, two correct owners.
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
