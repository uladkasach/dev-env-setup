#!/usr/bin/env bash
######################################################################
# .what = prove `pkg_await_apt_lock` WAITS when another process holds the dpkg
#         lock, and stands aside when no one does
#
# 📜 grove-ahbode-v20260811, 2026-09-02, first apply of a 20-minute-old disk:
#
#     E: Could not get lock /var/lib/dpkg/lock-frontend.
#        It is held by process 9221 (apt-get)
#     ✋ apt HAS these, and the install still failed: jq tree ripgrep
#
# .why
#   - a fresh ubuntu box boots `unattended-upgrades`, which holds the dpkg lock for a few minutes
#   - `2.1.toolkit` is the first bundle to install a package, so a disk minutes old collides with it
#   - a second apply passes — `rule.require.one-command-provision` forbids that: two passes is an ORDERING defect, not idempotency
#
# 🛑 .why this play must exist at all
#   - the wait is a GUARANTEE; a guarantee is invisible when it holds
#   - it engages on ONE box class at ONE moment (`define.provision-defect-shapes` #10)
#   - a converged box never exercises it; a from-scratch run exercises it only if it collides by chance again
#   - a fix nobody has seen ENGAGE is a guess dressed as a repair (`gotcha.a-check-that-cries-wolf-gets-silenced`, `.the corollary`)
#
# 🛑 .why the SUBJECT IS SOURCED and never restated here
#   - a re-typed loop proves a loop nobody ships
#   - two copies drift in silence — one set, two holders (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9)
#   - so this sources `src/grove.pkg.sh` and calls the shipped function
#
# .what it does to the box
#   - holds `/var/lib/dpkg/lock-frontend` OPEN, as root, for a bounded few seconds, then releases
#   - installs no package, removes no package, writes no file
#   - the hold's net effect is zero — a plain `prove.*`, no carve-out from `rule.forbid.repair-plays` needed
#
# guarantee:
#   - the holder is bounded by its own `sleep`, so it releases even if this play is killed mid-run — the `trap` is the SECOND belt, not the only one
#   - arm A reads the lock FIRST and declines if it is already held, so a pass is never about a fixture that failed to build (`gotcha.a-check-that-cries-wolf-gets-silenced`, q5)
#   - arm B is the clamp: it demands the wait ENGAGE — a trivial pass here means the guarantee reverted (`rule.require.clamp-edge-cases`)
#   - the release is judged by a RE-READ of the lock, never by the kill's exit code (`rule.forbid.failhide`)
#
# usage:
#   rhx play.run --play prove.apt-lock-wait-engages
#
# exit:
#   0 = the wait engages when held, and stands aside when free
#   1 = it does not
#   2 = the subject could not be read, so no claim was proven
######################################################################

set -uo pipefail

######################################################################
# ⚠️ the root leads with the play's OWN location, then falls back
#
#   - `git.grove.send --play` lands a play at `$HOME/.local/state/grove.play/`, outside any checkout
#   - a bare `git rev-parse` from the play's own dir answers empty there, so the probe declines where it should measure
#   - a hardcoded `$HOME/git/more/dev-env-setup` names MAIN's checkout on every box
#   - a run from a worktree then measures a tree under nobody's hand (`prove.every-bundle-is-dispatched` carries the two false verdicts that taught this)
#   - the ladder below is the same one that play uses, anchored on THIS probe's subject rather than the bundle tree
######################################################################
_self="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)" || _self=""
if   [[ -n "$_self" && -f "$_self/src/grove.pkg.sh" ]]; then ROOT="$_self"
elif [[ -f "$PWD/src/grove.pkg.sh" ]];                  then ROOT="$PWD"
else                                                         ROOT="$HOME/git/more/dev-env-setup"
fi
SUBJECT="$ROOT/src/grove.pkg.sh"
LOCK="/var/lib/dpkg/lock-frontend"

echo "🔎 prove.apt-lock-wait-engages"
echo "   └─ subject: ${SUBJECT#"$ROOT"/}"
echo ""

######################################################################
# 0. decline unless every precondition holds
#
# ⚠️ each of these is a reason the claim CANNOT be measured here, never a reason to believe it false
#   - so each exits 2, not 1
######################################################################
if [[ -z "$ROOT" || ! -r "$SUBJECT" ]]; then
  echo "   ✋ no readable subject at ${SUBJECT:-<no checkout>}" >&2
  echo "      ⇒ an absent subject proves no claim, so this declines" >&2
  exit 2
fi

if ! command -v fuser >/dev/null 2>&1; then
  echo "   🌙 no fuser on this box — the wait short-circuits by design" >&2
  echo "      ⇒ there is no claim to measure here" >&2
  exit 2
fi

if [[ ! -e "$LOCK" ]]; then
  echo "   🌙 no $LOCK on this box" >&2
  echo "      ⇒ not a debian-family box, so the wait has no subject" >&2
  exit 2
fi

# 🛑 the function runs `sudo fuser` with no guard of its own
#   - `pkg_apt` checks sudo BEFORE it calls the wait
#   - called directly, that check is ours to make
#   - it must be NON-INTERACTIVE: a password prompt on a grove sits on the duct pane and eats the next command sent down it (`rule.forbid.tty-as-a-proxy-for-a-human`)
if ! sudo -n true >/dev/null 2>&1; then
  echo "   🌙 this seat has no password-less sudo" >&2
  echo "      ⇒ the wait reads the lock as root, so it cannot be driven here." >&2
  echo "        run this on a seat that holds NOPASSWD sudo — a grove's ground" >&2
  exit 2
fi

# shellcheck source=/dev/null
source "$SUBJECT"

if ! declare -F pkg_await_apt_lock >/dev/null; then
  echo "   ✋ the subject declares no pkg_await_apt_lock" >&2
  echo "      ⇒ either the wait was removed, or it moved. both are worth a" >&2
  echo "        human's eye — read ${SUBJECT#"$ROOT"/}" >&2
  exit 2
fi

######################################################################
# the holder — a root process that keeps the lock file OPEN, bounded
#
# ⚠️ `exec sleep` REPLACES the shell — the fd stays open with no shell left to outlive it
#   - the sleep is the real release; the trap is the second belt
######################################################################
HOLD_SECS=12
HOLDER=""

_is_held() { sudo -n fuser "$LOCK" >/dev/null 2>&1; }

_release() {
  [[ -z "$HOLDER" ]] && return 0
  sudo -n kill "$HOLDER" >/dev/null 2>&1
  wait "$HOLDER" 2>/dev/null
  HOLDER=""
}
trap _release EXIT

fails=0

######################################################################
# arm A — the lock is FREE. the wait must stand aside
#
# 🛑 this arm doubles as the FIXTURE READ for arm B
#   - a lock already held by something else (unattended-upgrades, a human's apt) blocks arm B from attributing its wait to its own holder
#   - this play declines rather than report a verdict about a world it did not build
######################################################################
if _is_held; then
  echo "   🌙 some other process already holds $LOCK" >&2
  echo "      ⇒ arm B could not attribute its wait to its own holder, so no" >&2
  echo "        verdict is claimed. wait for that process, then re-run" >&2
  exit 2
fi

echo "   ├─ arms"

t0=$SECONDS
out_a="$(pkg_await_apt_lock 2>&1)"
free_elapsed=$(( SECONDS - t0 ))

if [[ "$free_elapsed" -le 1 && -z "$out_a" ]]; then
  echo "   │  ├─ A. lock free  ✔ returned in ${free_elapsed}s, stayed silent"
else
  echo "   │  ├─ A. lock free  ✋ took ${free_elapsed}s and printed: ${out_a:-<no output>}" >&2
  echo "   │  │     ⇒ a wait that engages when no one holds the lock is a" >&2
  echo "   │  │       false ✋ that costs every apply time it never owed" >&2
  fails=$(( fails + 1 ))
fi

######################################################################
# 🛑 arm B — THE CLAMP. the lock is HELD, and the wait must engage
#
#   - this is the direction the guarantee exists for
#   - the only direction a converged box never shows
######################################################################
sudo -n sh -c "exec 9< '$LOCK'; exec sleep $HOLD_SECS" &
HOLDER=$!

# confirm the FIXTURE took before we measure against it
held=0
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if _is_held; then held=1; break; fi
  sleep 0.5
done

if [[ "$held" -ne 1 ]]; then
  echo "   │  └─" >&2
  echo "   🌙 the holder never took the lock, so arm B has no fixture" >&2
  echo "      ⇒ no verdict is claimed (a probe that measures a world its own" >&2
  echo "        fixture failed to build is worse than one that declines)" >&2
  exit 2
fi

t0=$SECONDS
out_b="$(PKG_APT_LOCK_WITHIN=60 pkg_await_apt_lock 2>&1)"
held_elapsed=$(( SECONDS - t0 ))

said_wait=0;   [[ "$out_b" == *"holds the dpkg lock"* ]] && said_wait=1
said_free=0;   [[ "$out_b" == *"is free after"*       ]] && said_free=1
waited_real=0; [[ "$held_elapsed" -ge 5 ]] && waited_real=1

if [[ "$waited_real" -eq 1 && "$said_wait" -eq 1 && "$said_free" -eq 1 ]]; then
  echo "   │  ├─ B. lock held  ✔ waited ${held_elapsed}s, announced both edges"
else
  echo "   │  ├─ B. lock held  ✋ waited=${held_elapsed}s announce-start=${said_wait} announce-end=${said_free}" >&2
  echo "   │  │     ⇒ the wait did NOT engage against a real holder. an apply" >&2
  echo "   │  │       on a fresh box races unattended-upgrades and loses" >&2
  echo "   │  │     read it: ${SUBJECT#"$ROOT"/}" >&2
  printf '   │  │     %s\n' "${out_b:-<no output>}" >&2
  fails=$(( fails + 1 ))
fi

######################################################################
# the restore — and its own verdict
#
# ⚠️ judged by a RE-READ of the lock, never by the kill's exit code
#   - a probe that breaks a box and goes quiet about the repair is worse than no probe (`rule.forbid.repair-plays`, exception 2, condition 4)
######################################################################
_release
restored=0
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if ! _is_held; then restored=1; break; fi
  sleep 0.5
done

if [[ "$restored" -eq 1 ]]; then
  echo "   │  └─ restore     ✔ $LOCK is free again"
else
  echo "   │  └─ restore     ✋ $LOCK is STILL held" >&2
  echo "   │        ⇒ the holder is bounded by its own sleep (${HOLD_SECS}s), so" >&2
  echo "   │          this should clear on its own. confirm before you run apt" >&2
  fails=$(( fails + 1 ))
fi

echo ""

if [[ "$fails" -eq 0 ]]; then
  echo "🌲 the dpkg-lock wait engages ✔"
  echo "   ├─ free: stands aside in ${free_elapsed}s"
  echo "   └─ held: waits ${held_elapsed}s and says so at both edges"
  exit 0
fi

echo "   ✋ $fails arm(s) disagree with the required verdict" >&2
echo "      ⇒ read the wait: ${SUBJECT#"$ROOT"/}" >&2
exit 1
