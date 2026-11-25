#!/usr/bin/env bash
######################################################################
# .what = the boot's own printers and two of its steps, as functions
#
# .why  = `git.grove.provision.boot` is a skill that runs on load, so a play
#         that sourced it would boot a box. these are the parts a human reads
#         and a play must render: the step printers (`say`, `halt`), the
#         platform declaration (step 1), and the key placement (step 3)
#         (`prove.boot-steps-name-each-verdict` drives each branch)
#
# .note = reads the boot's globals: GROVE, MODE, RHX, BOOT_ORG, GIT_FOREST_DIR,
#         TRUST, BOOT_TRUST_HELD.
#         the caller sources `git.grove.operations.sh` (the escape strip) and
#         `git.grove.ssh.operations.sh` (the platform findsert) first
######################################################################

######################################################################
# .what = run one of this role's own skills, scoped to repo=.this/role=any
# .why  = the bhuild supervisor role ships its own git.grove.send, git.grove.wake,
#   duct.*, and term.*, so a bare slug refuses as ambiguous and boot never reaches
#   the box. a stub RHX (the plays) takes the args unscoped, so its echoes hold
######################################################################
rhx_run() {
  [[ "${RHX:-rhx}" == rhx ]] || { "$RHX" "$@"; return; }
  rhx "$@" --repo .this --role any
}

######################################################################
# halt — name the step, why it did not hold, and the command that repairs it
#
# 🛑 EVERY line it prints goes through `__duct_strip_escapes`
#
# .why = several callers hand it a captured `$sent` — a step's own stdout+stderr
#        — and a step reaches a GROVE, which is assumed compromised. so a halt's
#        `fix:` block is a channel that carries remote-chosen bytes to a
#        terminal, and a terminal OBEYS them: with `set-clipboard on` an OSC 52
#        in that text writes this human's clipboard, at the exact moment they
#        are about to copy a fix command out of it.
#
#        the strip goes HERE, in the one printer, rather than at each caller —
#        a caller that forgets is silent, and there is no reason for any line of
#        a halt to carry a control byte (`rule.require.solve-at-cause`).
######################################################################
halt() {
  local step="$1" label="$2" why="$3"; shift 3
  echo "      └─ ✋ step $step ($label) does not hold"
  echo ""
  echo "  why: $why" | __duct_strip_escapes
  echo "  fix:"
  # every line of every arg sits at the fix indent — a captured multi-line answer
  #   included, whose continuation lines would else land at column 0 — and an
  #   empty separator stays truly empty, with no spaces after the line's end
  local line
  for line in "$@"; do
    printf '%s\n' "$line" | __duct_strip_escapes | sed -E 's/^/    /; s/^[[:space:]]+$//'
  done
  echo ""
  # BOOT_INFLIGHT: the apply may still be at work, so a resume AT this step would send a
  #   second, concurrent one. the footer waits for this run's own verdict, then resumes
  #   PAST the seat — and step 3's keys, which ride after its apply, are named first
  if [[ "${BOOT_INFLIGHT:-0}" == 1 ]]; then
    echo "  then, once THIS run's log ends '🌲 grove.provision done' (and not before) —"
    (( step == 3 )) && echo "    $RHX git.grove.auth.keys.set $GROVE --mode apply${BOOT_ORG:+ --org $BOOT_ORG}"
    echo "    $(boot_resume_line "$(( step + 1 ))")"
    exit 3
  fi
  echo "  then run again from here —"
  # 🛑 the VERB is not optional, and its absence is silent until a human types it
  #   - `git.grove.provision` dispatches on a verb and refuses without one, so
  #     a resume line that omits `boot` exits 2 with "needs a verb"
  #   - ⇒ a halt hands a human the one command that repairs the box; a command
  #     that cannot run leaves them to guess the shape of the resume
  #   - 📜 measured 2026-09-13: this line printed
  #     `git.grove.provision <grove> --mode apply --from 2 --trust keep`,
  #     which refuses — the halt's own fix-text was unrunnable
  #   - (`rule.require.prove-the-path-the-human-runs`)
  # BOOT_RESUME_FROM: a halt whose fix redoes its own act names the NEXT step, so the
  #   resume does not re-drive a whole seat's apply for one row (the keys halt)
  echo "    $(boot_resume_line "${BOOT_RESUME_FROM:-$step}")"
  exit 3
}

######################################################################
# .what = the command that resumes a boot at a step
# .why  = `--trust keep` skips the trust step, so it is owed only where that step
#   has ALREADY held: a halt at step 2 or later, or a step-1 halt after trust ✔
#   (the platform declaration). a halt at step 0 (grants), or at the wake or the
#   trust, has not passed it — so its resume carries the trust the human chose,
#   since a `keep` there would skip the very step that failed
# .note = reads BOOT_TRUST_HELD (1 once trust held this run) and TRUST
######################################################################
boot_resume_line() {
  local step="$1" trust=keep
  (( step <= 1 )) && [[ "${BOOT_TRUST_HELD:-0}" != 1 ]] && trust="${TRUST:-verified}"
  # BOOT_RESUME_TRUST: a halt whose fix lays the trust BY HAND names verified — once
  #   the key is laid, trust.gen answers "already trusted" and the resume re-proves it,
  #   where `keep` would skip the very step that failed (the tailnet trust halt)
  [[ -n "${BOOT_RESUME_TRUST:-}" ]] && trust="$BOOT_RESUME_TRUST"
  # --what rides along: a resume without it converges the WHOLE tree, where the
  #   human asked for one bundle (measured 2026-11-22: a 5.26.backup boot's step-1
  #   halt printed a resume that would have applied every bundle)
  printf '%s git.grove.provision boot %s --mode apply --from %s --trust %s%s' "$RHX" "$GROVE" "$step" "$trust" "${WHAT:+ --what $WHAT}"
}

# .what = is this grove reached over the tailnet? (the registry's host, by the shared reader)
boot_reach_is_tailnet() {
  local host
  host=$(jq -r '.host // "localhost"' "${GIT_FOREST_DIR:-$HOME/.git.forest}/groves/$GROVE.json" 2>/dev/null) || host=localhost
  [[ "$host" == "null" ]] && host=localhost
  grove_ssh_host_is_tailnet "$host"
}

######################################################################
# .what = step 1's wake halt, in the words of the grove's own reach
# .why  = an ec2 grove's road is a tunnel behind camp credentials; a tailnet grove
#   has neither, so the ec2 text sent its human to unlock a rack that is not the cause
######################################################################
boot_wake_halt() {
  local wake_rc="${1:-1}"
  # rc 2 = the box ANSWERED and refused (a key, a clamp): wake's own lines name the fix,
  #   and a "silence" text would contradict them
  if (( wake_rc == 2 )); then
    halt 1 reach \
      "the grove answered and the wake refused (rc 2) — wake's own lines above name why and the fix" \
      "a refused key is placed from a laptop that already reaches the ground seat:" \
      "$RHX git.grove.auth.ssh.set $GROVE --identity <this laptop's key>.pub --mode plan" \
      "else follow the fix wake printed, then re-run —" \
      "$RHX git.grove.wake $GROVE --mode apply"
  fi
  if boot_reach_is_tailnet; then
    halt 1 reach \
      "the grove did not answer over ssh on the tailnet — wake's own lines above quote ssh" \
      "a tailnet grove is always on, so a silence is reach: is this laptop on the tailnet," \
      "and is the box up? read both, then re-run —" \
      "tailscale status" \
      "$RHX git.grove.wake $GROVE --mode apply"
  fi
  halt 1 reach \
    "the grove did not wake — the tunnel is the only road in" \
    "camp credentials lapse in ~55m, and a lapsed read reports as an absent key —" \
    "$RHX keyrack unlock --owner ehmpath --env camp" \
    "$RHX git.grove.wake $GROVE --mode apply"
}

# .what = the one line that names what a reach rides on, for a halt's fix list
# .why  = a tunnel rides camp credentials, so a lapse reads as a failed push; the
#   tailnet rides none, so a camp unlock there sends the human down an ec2 road
boot_reach_road_line() {
  if boot_reach_is_tailnet; then
    printf '%s' "tailscale status   # the tailnet must list the box"
    return 0
  fi
  printf '%s' "$RHX keyrack unlock --owner ehmpath --env camp   # camp lapses in ~55m"
}

######################################################################
# .what = step 1's trust halt, in the words of the grove's own reach
# .why  = on ec2 the attestation is the box's boot record, read through aws; on the
#   tailnet it is the box's own key report, read over an ssh pinned to a trusted
#   key. a halt that named the tunnel and the console sent a hetzner human to read
#   a record that does not exist
######################################################################
boot_trust_halt() {
  if boot_reach_is_tailnet; then
    BOOT_RESUME_TRUST=verified halt 1 reach \
      "the host key was not trusted, so this refuses to reach the box" \
      "trust.gen's own rows above name each fingerprint and the road it asks for." \
      "a tailnet box has no console, so its first key is yours to accept — read it first:" \
      "$RHX git.grove.trust.gen --grove $GROVE --mode plan" \
      "FIRST contact (no key on record): confirm the tailnet names the box, then —" \
      "$RHX git.grove.trust.gen --grove $GROVE --mode apply --trust tofu" \
      "a REBUILT box (a key on record that CHANGED): a key still on record attests the new —" \
      "$RHX git.grove.trust.gen --grove $GROVE --mode apply --on-changed replace" \
      "if none still matches, no channel here attests it: compare to infra's fingerprints"
  fi
  halt 1 reach \
    "the host key was not trusted, so this refuses to reach the box" \
    "the key offered on the tunnel was NOT attested by the box's own boot" \
    "record — read trust.gen's own rows above; they name each fingerprint" \
    "a REBUILT box presents a NEW key, and that is the benign cause —" \
    "$RHX git.grove.provision boot $GROVE --mode apply --trust replace" \
    "🛑 if the boot record cannot be read AT ALL, there is no flag for it." \
    "--trust tofu is refused on a CHANGED key: a prior key is on record" \
    "and disagrees, so there is no 'first use' for tofu to be about, and" \
    "a scan alone settles no question. read what holds the port instead —" \
    "ss -tlnp | grep ':<the port from git.grove.list>'" \
    "⚠️ tofu remains right for FIRST contact, where no prior key exists." \
    "even then the endpoint is a shared localhost port, so 'first use'" \
    "there is not first use of a HOST (howto.adopt-a-replacement-grove)"
}

say() { echo "      $*"; }

######################################################################
# .what = step 1's GROUND alias — the seat every box-wide step dials
#
# .why  = the wake writes the alias of the ONE entry it is called for, and
#         `git.grove.set` writes no Host block at all. so on a fresh laptop no
#         command wrote `<grove>.ground`, and step 1's platform declaration and
#         step 2's push both dialed a name ssh had no block for
# .how  = the registry's `.ground` entry is the declaration; the shared writer
#         (`grove_ssh_alias_set`) lays it where ssh reads it first, then reads it
#         back. an ec2 seat names the tunnel's local end, a tailnet seat the box
######################################################################
# .what = the ssh name the ground seat answers to (a reader)
# .why  = one reader for every step that dials ground: two spellings of it let an --alias
#   seat print KEEP at the alias step, then dial an unknown name at the platform step
boot_ground_seat_alias() {
  local reg="${GIT_FOREST_DIR:-$HOME/.git.forest}/groves/$GROVE.ground.json" alias=""
  [[ -f "$reg" ]] && alias=$(jq -r '.sshAlias // .name // empty' "$reg")
  printf '%s' "${alias:-$GROVE.ground}"
}

# .what = the key the camper seat's alias reaches with (a reader)
# .why  = step 1's wake already proved that key on this box; a fixed `id_ed25519` laid a
#   ground alias a laptop with another key could never dial
boot_camper_identity() {
  local key
  key="$(grove_ssh_alias_identity "$GROVE")"
  printf '%s' "${key:-$HOME/.ssh/id_ed25519}"
}

boot_ground_alias() {
  local reg="${GIT_FOREST_DIR:-$HOME/.git.forest}/groves/$GROVE.ground.json" alias user host port out
  if [[ ! -f "$reg" ]]; then
    halt 1 reach \
      "no '$GROVE.ground' seat is registered, and every box-wide step runs from it" \
      "register the admin seat beside the work seat (howto.add-a-new-grove, the two seats):" \
      "rhx git.grove.set $GROVE.ground --at ground@<host>:<port>"
  fi
  alias="$(boot_ground_seat_alias)"
  user=$(jq -r '.user // "ground"' "$reg")
  host=$(jq -r '.host // empty' "$reg")
  port=$(jq -r '.port // 22' "$reg")
  # 🛑 no host recorded = an --alias seat: the alias names a Host block another writer
  #   (infra) owns. a block laid here would sit in the file ssh reads FIRST and shadow
  #   infra's own address, keys, and ProxyCommand — so it is read, never written
  if [[ -z "$host" ]]; then
    say "│  ├─ ground alias [KEEP] '$alias' (no host recorded: an --alias seat, whose Host block is not ours, or one its wake addresses)"
    return 0
  fi
  if [[ "$MODE" == "plan" ]]; then
    say "│  · would set alias '$alias' → $user@$host:$port (the ground seat, read first)"
    return 0
  fi
  out="$(grove_ssh_alias_set alias="$alias" host="$host" port="$port" user="$user" identity="$(boot_camper_identity)")" \
    || halt 1 reach \
      "the ground seat's alias '$alias' could not be set (the writer names why above)" \
      "rhx git.grove.wake $GROVE.ground --mode apply"
  say "│  ├─ ground alias ${out%% *} '$alias' → ${out#* }"
}

######################################################################
# .what = step 1's platform DECLARATION — for a box that cannot answer it alone
#
# .why  a hetzner box has no metadata, so `src/grove.env.sh` reads its platform
#       off `/etc/grove/platform` and fails CLOSED where none sits. the box's
#       bootstrap (ahbode/infrastructure) lays no such file, so without this
#       the first apply on ground halts at the derive. the registry holds the
#       fact (`git.grove.set --platform`), and ground holds the sudo to lay it
#
# .how  FINDSERT, over the ground seat: absent → write · same → keep ·
#       different → ✋. a declaration this boot did not write is never
#       overwritten; a builder that lays the same line later finds it in place
######################################################################
boot_platform_declare() {
  local platform out
  platform=$(jq -r '.platform // ""' \
    "${GIT_FOREST_DIR:-$HOME/.git.forest}/groves/$GROVE.json" 2>/dev/null) || platform=""
  [[ "$platform" == "null" ]] && platform=""

  # a tailnet grove is the box that CANNOT answer alone — no metadata to probe — so
  #   an entry with no platform would halt the first apply at the derive. say so here
  if [[ -z "$platform" ]] && boot_reach_is_tailnet; then
    halt 1 reach \
      "the registry reaches $GROVE over the tailnet and declares no platform for it" \
      "a box with no metadata cannot derive its own platform, so the first apply would" \
      "halt at the derive. declare it in the registry, then re-run —" \
      "rhx git.grove.set $GROVE --platform hetzner.hetzbot"
  fi
  if [[ -z "$platform" ]]; then
    say "│  └─ platform · none declared in the registry (an ec2 box answers it alone)"
    return 0
  fi
  if [[ "$platform" != "hetzner.hetzbot" ]]; then
    halt 1 reach \
      "the registry's platform '$platform' is not one a box declares" \
      "rhx git.grove.set $GROVE --platform hetzner.hetzbot"
  fi
  local ground; ground="$(boot_ground_seat_alias)"
  if [[ "$MODE" == "plan" ]]; then
    say "│  · would findsert /etc/grove/platform = $platform, over $ground"
    return 0
  fi
  if ! out="$(grove_ssh_platform_findsert "$ground" "$platform")"; then
    # a DIFFERS is the box's own answer; any other is the seat's road (ssh, sudo)
    [[ "$out" == DIFFERS* ]] && halt 1 reach \
      "the platform declaration could not be laid over $ground: $out" \
      "a DIFFERS answer means the box already declares another platform —" \
      "read it before any apply: ssh $ground cat /etc/grove/platform"
    # a refused KEY is no sudo fault: this laptop's key is absent from ground's
    #   authorized_keys (a second laptop), and a `sudo -n true` read cannot cure it
    [[ "$out" == *"Permission denied"* ]] && halt 1 reach \
      "the ground seat $ground refused this laptop's key: $out" \
      "a laptop that already reaches $ground places this one's PUBLIC key on every seat —" \
      "rhx git.grove.auth.ssh.set $GROVE --identity <this laptop's key>.pub --mode plan" \
      "rhx git.grove.auth.ssh.set $GROVE --identity <this laptop's key>.pub --mode apply"
    halt 1 reach \
      "the platform declaration could not be laid over $ground: $out" \
      "the ground seat did not run the write — its road (ssh, then sudo) refused" \
      "read the seat's own answer: ssh $ground sudo -n true"
  fi
  say "│  └─ platform ✔ /etc/grove/platform = $platform ($out)"
}

######################################################################
# .what = a seat's three halts while its detached apply may be at work
# .why  = a resume AT the seat sends a second, concurrent apply; so each waits for the
#   run's own verdict (BOOT_INFLIGHT), or, for an unproven send, names how to tell
######################################################################
boot_seat_unproven_halt() {
  local seat="$1" step="$2" label="$3" slice="$4"
  halt "$step" "$label" \
    "the text landed and NO JOB STARTED — an unproven delivery, not a failure" \
    "look before you re-send; a blind re-send starts a second copy —" \
    "$RHX git.grove.send $seat --reply --what '$slice'" \
    "only the marker there → no copy runs, so the resume below is safe;" \
    "an apply's lines there → it runs: wait for its '🌲 grove.provision done' first"
}

boot_seat_silent_halt() {
  local seat="$1" step="$2" label="$3" log="$4"
  BOOT_INFLIGHT=1 halt "$step" "$label" \
    "the probe gave no verdict 10 times over — the apply may still be at work" \
    "⚠️ an EMPTY reply is a fault, not a 'not yet'. read the box directly," \
    "   and do NOT re-send; a blind re-send starts a second copy —" \
    "$RHX git.grove.send $seat --what 'tail -20 $log'" \
    "⚠️ that read is UNBOUNDED on purpose: a marker that never landed is one" \
    "   cause of this halt, so a slice from it would render empty too"
}

boot_seat_outran_halt() {
  local seat="$1" step="$2" label="$3" log="$4" slice="$5"
  BOOT_INFLIGHT=1 halt "$step" "$label" \
    "the apply outran ${WITHIN:-its bound}s — that is a BOUND, not a verdict. it may still be at work" \
    "do NOT re-send; read whether the log still grows, and wait while it does —" \
    "$RHX git.grove.send $seat --reply --what 'stat -c %y $log'" \
    "$RHX git.grove.send $seat --reply --what '$slice | tail -4'"
}

######################################################################
# .what = the last line of a `--what` boot — what ran, on which seats
# .why  = `--what` ends at the seats (the gate is a claim about a WHOLE box), so
#   this line is the whole verdict a human reads; a function so
#   `prove.boot-steps-name-each-verdict` can render each arm with no live seat
######################################################################
boot_what_summary() {
  echo ""
  [[ "$MODE" == "plan" ]] && { echo "🌱 plan only — no step ran. drive it with --mode apply"; return 0; }
  # name only the seats that ran: --from 3 skips the ground step
  [[ "$FROM" -le 2 ]] && { echo "🌳 $WHAT applied on $GROVE — ground, then camper, ONE apply each"; return 0; }
  echo "🌳 $WHAT applied on $GROVE — camper alone (--from $FROM skipped ground), ONE apply"
}

######################################################################
# .what = once a seat converges, respawn its duct, so the duct's shell reads the
#   rc files this apply wrote
# .why  = the duct opens at wake, before any apply lays PATH, and a tmux pane keeps
#   its birth env. 📜 2026-11-17, hetzner camper: a green boot, then
#   `--what 'rhx …'` → `rhx: command not found`; one `duct.reboot` cured it
######################################################################
boot_seat_duct_reborn() {
  local seat="$1" step="$2" label="$3" uri out
  # the address follows `_git_grove_duct_uri` (bash_aliases.sh), as git.grove.play.await does
  uri="duct://$seat/main/mechanic"
  if out="$(rhx_run duct.reboot --on "$uri" 2>&1)"; then
    say "│  └─ ✔ duct reborn ($uri) — its shell reads this apply's PATH"
    return 0
  fi
  # the apply DID converge, so the resume goes PAST the seat; step 3's keys ride after it
  local keys=()
  (( step == 3 )) && keys=("$RHX git.grove.auth.keys.set $GROVE --mode apply${BOOT_ORG:+ --org $BOOT_ORG}")
  BOOT_RESUME_FROM=$(( step + 1 )) halt "$step" "$label" \
    "the apply converged, and its duct refused a fresh shell — it still holds one born before this apply" \
    "it said:" \
    "$(printf '%s\n' "$out" | sed 's/^/  /')" \
    "a command sent there runs on the old PATH, so \`rhx\` and the toolchain read absent —" \
    "$RHX duct.reboot --on '$uri'" \
    "${keys[@]}"
}

######################################################################
# .what = step 3's KEYS, on the camper — the boot places them, never a human
#
# .why CAMPER only = ground is the ADMIN seat: it holds no aws identity and does
#         no credentialed work, so `5.16.keys` declines there and owes no row
#         (`grove_env_seat_is_admin`)
# .why  = `5.16.keys` declares which keys a grove must read, and its verify
#         fails the gate without them. the grove cannot read this laptop's
#         rack, so the laptop is the one box that can place a replica
#         (`git.grove.auth.keys.set`, its header). a boot that stopped short
#         of that handed every first gate a ✋ and a human a hand step
#         (`rule.require.one-command-provision`)
# .why HERE = the replica is written by `rhx keyrack set` ON the seat, so it
#         needs the seat's rhx, which only the applies before it lay down
# .note = idempotent: a row the seat already reads is skipped. a row THIS
#         laptop cannot read halts, and the skill names that row's fix
######################################################################
boot_keys_place() {
  if [[ "$MODE" == "plan" ]]; then
    say "│  ├─ keys · would run: $RHX git.grove.auth.keys.set $GROVE --mode apply${BOOT_ORG:+ --org $BOOT_ORG}"
    return 0
  fi
  if ! rhx_run git.grove.auth.keys.set "$GROVE" --mode apply ${BOOT_ORG:+--org "$BOOT_ORG"}; then
    # the camper's apply already held; only the keys are owed, so the fix places them
    #   and the resume starts at the gate, never a second camper apply
    BOOT_RESUME_FROM=4 halt 3 keys \
      "the required keys could not be placed on $GROVE — the skill's own lines above name the row and why" \
      "$RHX git.grove.auth.keys.set $GROVE --mode plan${BOOT_ORG:+ --org $BOOT_ORG}" \
      "once each row reads on this laptop, place them:" \
      "$RHX git.grove.auth.keys.set $GROVE --mode apply${BOOT_ORG:+ --org $BOOT_ORG}"
  fi
  say "│  ├─ keys ✔ $GROVE reads every row 5.16.keys declares"
}

######################################################################
# .what = step 3's LAST act: read the ADMIN seat's disk, and halt if it holds a
#         credential or crew work
# .why  = every bundle DECLINES on ground, yet 📜 2026-11-18 a misrouted alias put a
#         keyrack host file, a crew clone, and docker state there for days, with
#         each apply green. a decline is a fact about code; this is a read of the
#         seat, so the one command that builds a box also proves its admin seat
#         stayed an admin seat (`prove.admin-seat-holds-no-crew-work`)
# .note = READ-ONLY on ground, so it changes no state the gate measures on camper
######################################################################
boot_admin_seat_clean() {
  local play=prove.admin-seat-holds-no-crew-work
  if [[ "$MODE" == "plan" ]]; then
    say "│  └─ admin seat · would run: $RHX git.grove.send $GROVE.ground --reply --play $play"
    return 0
  fi
  if ! rhx_run git.grove.send "$GROVE.ground" --reply --play "$play"; then
    BOOT_RESUME_FROM=4 halt 3 "admin seat" \
      "the admin seat $GROVE.ground holds a credential or crew work — the play above names each by path" \
      "⇒ a camper-aimed command reached ground. read where each seat dials:" \
      "ssh -G $GROVE | grep -E '^(user|hostname) ' ; ssh -G $GROVE.ground | grep -E '^(user|hostname) '" \
      "remove what it names from ground, then re-read the seat:" \
      "$RHX git.grove.send $GROVE.ground --reply --play $play"
  fi
  say "│  └─ admin seat ✔ ground holds no credential and no crew work"
}
