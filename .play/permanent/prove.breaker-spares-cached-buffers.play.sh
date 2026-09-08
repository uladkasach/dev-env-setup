#!/usr/bin/env bash
######################################################################
# prove.breaker-spares-cached-buffers — drive a REAL trip, watch the
# cached minimap buffer survive it
#
# .what = boots nvim with the shipped config, waits for the contract to
#         become reachable, then calls `_G.nvim_selfwatch.trip_breaker()`
#         — the shipped function — and asks whether neominimap's cached
#         scratch buffer is still valid, and whether a refresh still works.
#
# .why  = the breaker's wipe is a DELETE CONTRACT with two halves: what it
#         may delete, and what it must never. the second half is
#         `get_buffers_unwipeable`, and the round that shipped it left two
#         gaps this play closes:
#
#           1. no arm ever crossed 1.2GB, so `trip_breaker` itself had
#              NEVER RUN. the ORDER claim — read the keep-set BEFORE the
#              disable — was reasoned, never measured.
#           2. the probe that "proved" the predicate REBUILT the keep-set
#              inline. one set, two readers; the half that runs in anger
#              was the half no arm touched
#              (gotcha.a-check-that-cries-wolf-gets-silenced, m.9).
#
#         ⇒ so this play calls the SHIPPED function through `_G`, and
#           drives the SHIPPED trip. it restates no part of either.
#
# .the arms — a break arm alone would prove only that a deleted buffer is
#             deleted. the control arm is what names the WIPE as the cause.
#
#   control  the config as shipped        → cached_valid_after=true
#   old      the exclusion neutered       → cached_valid_after=false
#
#   ⚠️ `old` reporting `true` is a defect in this play, never evidence about
#      the box: it means the wipe no longer reaches the cached buffer at all,
#      so the control arm proves none of what it claims (term=bite).
#
# 🛑 .the discriminator is `cached_valid_after`, and it is the ONLY one
#
#   this play once also demanded `refresh_ok=false` from the `old` arm, on the
#   reasoning that a plugin robbed of its cached buffer must break. MEASURED
#   2026-09-07, that is FALSE: with the buffer deleted, `Neominimap refresh`
#   still returns ok.
#
#   ⇒ so the expectation was dropped rather than the measurement bent. it was a
#     claim this play asserted and never checked — the exact defect its own
#     header opens by naming, committed one section below it.
#
#   `refresh_ok` stays as a REPORTED row, because it is real evidence about the
#   blast radius. it simply discriminates no arm.
#
# 🛑 .the probe body lives in ITS OWN FILE, and this play RESTATES NO PART
#     OF IT
#
#   `prove.breaker-spares-cached-buffers.probe.lua`, beside this file, and
#   `rhx nvim.test.headless --probe` drives it. that split was earned:
#   the body used to sit in a heredoc here, and every hand-driven arm
#   needed a SECOND copy under `.play/temporary/` to run at all — two
#   copies of one probe, free to drift, which is the m.9 defect above
#   committed inside the play that exists to close it.
#
#   ⇒ the invocation shape (`-u <config>` + `luafile`, the arm env, the
#     bound, the read-back) belongs to the skill, so this play holds only
#     the CLAIM and its verdicts (`rule.forbid.adhoc-shell`).
#
# .the write — this is `rule.forbid.repair-plays` exception 2, a
#   discrimination probe. the break it makes lives inside a headless nvim
#   that then exits, so the box is untouched on net. the rows land in a
#   per-run temp dir a trap removes on every exit path.
#
# ⚠️ .what it does NOT prove
#   - it drives the trip DIRECTLY rather than by real memory growth, so the
#     1.2GB threshold and the timer that reads it stay unexercised here. no
#     other play covers that either.
#   - it asks about ONE cached buffer, the only member of the keep-set
#     today. a second plugin that caches a handle needs its own arm, and
#     its absence looks exactly like a member that does not exist.
#   - it proves the wipe REACHES that buffer without the exclusion, and it
#     names NO operation that then breaks. `Neominimap refresh` survives the
#     delete (measured 2026-09-07), so the harm of a stale `empty_buffer`
#     handle lives on some other path — a fresh window attach is the
#     suspect — and no arm here walks it. the exclusion is justified by the
#     stale handle itself, not by any failure this play has observed.
#
# guarantee:
#   - it prints the evidence beside each verdict
#   - it REFUSES rather than invent a subject it did not find
#   - the cleanup is a trap, and it reports whether the cleanup took
#
# usage:
#   rhx play.run --play prove.breaker-spares-cached-buffers
######################################################################
set -uo pipefail

REPO="${GROVE_SRC:-$PWD/src}"
CONFIG="$REPO/grove.provision/4.terminal/4.5.nvim/init.lua"
PROBE="$(dirname "${BASH_SOURCE[0]}")/prove.breaker-spares-cached-buffers.probe.lua"
OUTDIR=""
FAILED=0

cleanup() {
  [[ -n "$OUTDIR" ]] && rm -rf "$OUTDIR"
  echo ""
  if [[ -n "$OUTDIR" && -e "$OUTDIR" ]]; then
    echo "   ✋ the rows dir SURVIVED — $OUTDIR"
  else
    echo "   🧹 restored: no residue"
  fi
}
trap cleanup EXIT

####################################################################
# 🛑 refuse a subject we would have to invent
#    (rule.forbid.repair-plays, exception 2, condition 2)
####################################################################
[[ -r "$CONFIG" ]] || {
  echo "✋ no config at $CONFIG"
  echo "   ⇒ this play drives the SHIPPED config; it will not invent one"
  exit 1
}
[[ -r "$PROBE" ]] || {
  echo "✋ no probe at $PROBE"
  echo "   ⇒ the probe body is a tracked file beside this play; without it"
  echo "     this play would have to restate the body, which is the m.9"
  echo "     defect it exists to close. it refuses instead"
  exit 1
}
grep -q 'get_buffers_unwipeable' "$CONFIG" || {
  echo "✋ $CONFIG declares no get_buffers_unwipeable"
  echo "   ⇒ the contract under test is absent, so this play asks no question"
  exit 1
}
grep -q '_G.nvim_selfwatch' "$CONFIG" || {
  echo "✋ $CONFIG does not expose _G.nvim_selfwatch"
  echo "   ⇒ without it this play could only RESTATE the predicate, which is"
  echo "     the exact defect it exists to close (m.9). it refuses instead"
  exit 1
}
command -v nvim >/dev/null || { echo "✋ no nvim on PATH"; exit 1; }

OUTDIR="$(mktemp -d "${TMPDIR:-/tmp}/prove.breaker.XXXXXX")"

arm() {
  local name="$1" want_valid="$2"
  local out="$OUTDIR/$name.out"

  # 🛑 the SKILL owns the invocation: `-u <config>` + `luafile` (never `-l`,
  #    which loads no init.lua at all), the arm env, and the bound
  rhx nvim.test.headless \
    --probe "$PROBE" --config "$CONFIG" \
    --arm "$name" --out "$OUTDIR" --within 90 > /dev/null 2>&1

  if [[ ! -f "$out" ]]; then
    echo "   💥 arm '$name' wrote no result — this row asked NO question"
    echo "      ⇒ a crashed probe is not a negative answer (howto, rule 4)"
    FAILED=1
    return
  fi

  echo "   ├─ arm '$name'"
  # ⚠️ the `|| [[ -n "$row" ]]` tail: a final line with no newline would
  #    otherwise vanish, and the verdict rows sit at the end
  while IFS= read -r row || [[ -n "$row" ]]; do echo "   │    $row"; done < "$out"

  if grep -q '^world=absent' "$out"; then
    echo "   │  💥 the FIXTURE did not take — this arm measured a world nobody built"
    FAILED=1
    return
  fi

  # ⚠️ a row this play cannot READ is a row it cannot judge, and an empty
  #    capture would compare equal to an empty expectation — a false ✔ built
  #    out of silence (`rule.forbid.failhide`)
  local saw_valid saw_ft
  saw_valid="$(grep -oP '^cached_valid_after=\K.*' "$out")"
  saw_ft="$(grep -oP '^cached_ft=\K.*' "$out")"
  if [[ -z "$saw_valid" ]]; then
    echo "   │  💥 no cached_valid_after row — this arm rendered NO verdict"
    FAILED=1
    return
  fi

  # 🛑 the wipe keys on `ft == 'neominimap'`. if the cached buffer does not
  #    carry that filetype, the wipe could never reach it, so BOTH arms would
  #    report `true` and the pair would discriminate no part of the claim
  #    while it still read as a pass. measured 2026-09-07: that is exactly
  #    what a mis-aimed break produced, and only this row named the cause
  if [[ "$saw_ft" != '"neominimap"' ]]; then
    echo "   │  💥 cached_ft=$saw_ft — the wipe keys on 'neominimap' and would"
    echo "   │     never reach this buffer, so no arm here can discriminate"
    FAILED=1
    return
  fi

  if [[ "$saw_valid" == "$want_valid" ]]; then
    echo "   │  ✔ as declared (cached_valid_after=$saw_valid)"
  else
    echo "   │  ✋ expected cached_valid_after=$want_valid, saw $saw_valid"
    FAILED=1
  fi
}

echo "🔭 does the breaker SPARE the buffer neominimap can never rebuild?"
echo ""
echo "   the contract: get_buffers_unwipeable() — CALLED, not restated"
echo "   the trip:     _G.nvim_selfwatch.trip_breaker(1200) — the shipped one"
echo "   the probe:    $(basename "$PROBE") — one body, one holder"
echo ""

arm control true
arm old     false

echo ""
if [[ "$FAILED" -eq 0 ]]; then
  echo "🌲 the breaker discriminates: it wipes the leak and spares the cache"
else
  echo "✋ the contract did NOT hold — read the arms above"
fi
exit "$FAILED"
