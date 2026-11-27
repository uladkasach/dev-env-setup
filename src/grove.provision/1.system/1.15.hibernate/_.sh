#!/usr/bin/env bash
######################################################################
# .what = a cloud grove hibernates itself after 3h with no stir — and never
#         while a crew is at work
#
# .why it exists
#   - an idle grove bills by the hour, so it stops itself
#     (`aws ec2 stop-instances --hibernate`) once nobody has stirred for 3h
#   - the check once read only `/home/*/.claude/projects`, and every fleet clone
#     writes its brain trace inside its own clone — so a grove at work read as
#     idle and hibernated under its crews. `idle-hibernate.sh` names every signal
#     it reads, and why
#
# .why this bundle byte-owns the check, and ahbode/infrastructure still writes it
#   - infra's userdata writes the check at first boot, and userdata runs once.
#     an extant grove heals only through a repo that re-applies, and that is this
#   - so infra delivers a fresh grove's first copy; every ground apply converges
#     it to these bytes. infra compacts comments away, so its first copy reads as
#     drift until then — the LOGIC must match across the two, never the bytes
#
# .why only `*@aws.ec2`
#   - the act is `aws ec2 stop-instances` against this box's own instance id.
#     a laptop or a house grove has no ec2 identity, so the bundle declines there
#     (`rule.forbid.aws-params-off-ec2` judges the platform the same way)
#
# .why the apply retires any drop-in on either unit (F3)
#   - a stopgap once held the service with an `ExecCondition=` pre-check, beside
#     a timer stopped by hand. the fixed check needs neither, and a drop-in this
#     bundle does not write is a second writer on its unit
#   - ⇒ the apply removes every drop-in and the stopgap's pre-check, unmasks and
#     arms the timer, and says so for each. a deliberate hold by hand is undone
#     by the next ground apply, and the apply names what it undid
#
# .why only the units' OWN drop-ins
#   - systemd also loads type-wide and prefix drop-ins (`service.d/`,
#     `idle-.service.d/`), and those shape every unit of their kind. they are a
#     box-wide writer's, never this bundle's, so the reader neither names nor
#     removes them — only a path under `<unit>.d/` is a second writer on this unit
#
# .why the drift reader asks systemd, never a directory
#   - a drop-in may sit in `/etc`, `/run`, or `/usr/lib`, and on the timer as
#     well as the service; `DropInPaths` lists what systemd actually loaded
#   - a unit file rewritten with no reload leaves the old definition live, and the
#     bytes match; `NeedDaemonReload` is the one fact that catches it
#
# usage:
#   rhx grove.provision --what 1.15.hibernate --mode apply    # from the ground seat
######################################################################

# .what = is this box an ec2 instance? the one platform the act can reach
grove_provision_1_15_hibernate_platform_is_ec2() { [[ "${GROVE_ENV_SERVER:-}" == *@aws.ec2 ]]; }

# .what = systemctl, bounded: a read (`_systemctl`) and a root write (`_systemctl_root`)
# .why every call dials the manager's socket, and a wedged manager never replies — so a bare
#   call holds the provision, and on a grove the duct every later command queues behind
#   (`rule.require.bounded-probes-in-verifies`). a bound that elapses names itself on stderr
# .why a write gets the longer bound: `enable --now` waits on a start job, a read waits on naught
GROVE_PROVISION_1_15_HIBERNATE_READ_BOUND=10
GROVE_PROVISION_1_15_HIBERNATE_WRITE_BOUND=60
grove_provision_1_15_hibernate_bounded() {
  local bound="$1" rc; shift
  timeout -k 5 "$bound" "$@" </dev/null; rc=$?
  [[ "$rc" -eq 124 || "$rc" -eq 137 ]] && echo "$* did not answer within ${bound}s — systemd may be wedged" >&2
  return "$rc"
}
grove_provision_1_15_hibernate_systemctl() {
  grove_provision_1_15_hibernate_bounded "$GROVE_PROVISION_1_15_HIBERNATE_READ_BOUND" systemctl "$@"
}
grove_provision_1_15_hibernate_systemctl_root() {
  grove_provision_1_15_hibernate_bounded "$GROVE_PROVISION_1_15_HIBERNATE_WRITE_BOUND" sudo systemctl "$@"
}

# .what = the bundle's installed artifacts, declared ONCE — dst:mode
# .why no name field: each source in this dir is named as its dst's basename, so a
#   third field could only drift from the second
GROVE_PROVISION_1_15_HIBERNATE_TIMER="idle-hibernate.timer"
GROVE_PROVISION_1_15_HIBERNATE_SERVICE="idle-hibernate.service"
GROVE_PROVISION_1_15_HIBERNATE_PAIRS=(
  "/usr/local/bin/idle-hibernate.sh:755"
  "/etc/systemd/system/$GROVE_PROVISION_1_15_HIBERNATE_SERVICE:644"
  "/etc/systemd/system/$GROVE_PROVISION_1_15_HIBERNATE_TIMER:644"
)
# .what = the owner every declared file must hold, as `uid:gid` — root runs the check
GROVE_PROVISION_1_15_HIBERNATE_OWNER="0:0"

# .what = the two units whose loaded state the drift reader asks, and the stopgap's pre-check
GROVE_PROVISION_1_15_HIBERNATE_UNITS=("$GROVE_PROVISION_1_15_HIBERNATE_SERVICE" "$GROVE_PROVISION_1_15_HIBERNATE_TIMER")
GROVE_PROVISION_1_15_HIBERNATE_STOPGAP="/usr/local/bin/idle-hibernate-holds.sh"
# .what = the record each run of the check leaves, world-readable — the check's LAST_RECORD
GROVE_PROVISION_1_15_HIBERNATE_RECORD="/run/idle-hibernate.last"
# .what = the record of the last run that judged the box idle — the check's LAST_SLEEP
GROVE_PROVISION_1_15_HIBERNATE_SLEEP_RECORD="/run/idle-hibernate.last-sleep"

# .what = the declared owner's uid, and its gid — the two halves `install -o -g` takes
grove_provision_1_15_hibernate_owner_uid() { echo "${GROVE_PROVISION_1_15_HIBERNATE_OWNER%%:*}"; }
grove_provision_1_15_hibernate_owner_gid() { echo "${GROVE_PROVISION_1_15_HIBERNATE_OWNER##*:}"; }

# .what = how a file is held, as '<octal mode> <uid>:<gid>' — the shape the declaration compares to
grove_provision_1_15_hibernate_held() { stat -c '%a %u:%g' "$1" 2>&1; }

# .what = is this file held at its declared mode, by the declared owner? (is_held_at <path> <mode>)
grove_provision_1_15_hibernate_is_held_at() {
  [[ "$(grove_provision_1_15_hibernate_held "$1")" == "$2 $GROVE_PROVISION_1_15_HIBERNATE_OWNER" ]]
}

# .what = is this dst the declared copy of src — a regular file, not a link, with src's bytes?
# .why `cmp` follows a symlink, and `chown`/`chmod` would too: a link to a seat's own file
#   would read as converged, and an apply would reshape the seat's file, never root's
grove_provision_1_15_hibernate_is_declared_copy() { [[ -f "$2" && ! -L "$2" ]] && cmp -s "$1" "$2"; }

# .what = does this loaded drop-in sit in the unit's OWN `<unit>.d/`? (is_own_dropin <path> <unit>)
grove_provision_1_15_hibernate_is_own_dropin() { [[ "$1" == */"$2".d/* ]]; }

# .what = the dirs a system unit's `<unit>.d/` may sit under — the declaration a drop-in lives in
GROVE_PROVISION_1_15_HIBERNATE_UNIT_ROOTS=(/etc/systemd/system /run/systemd/system /usr/lib/systemd/system)

# .what = every drop-in under either unit's OWN `<unit>.d/`, one path per line, once each
# .why two reads, unioned: the files on disk are the declaration, and a drop-in
#   written with no reload is on disk yet absent from what systemd loaded — so a
#   loaded-only read would call that box clean until its next boot loads the file.
#   `DropInPaths` adds any own drop-in a root this list omits still carries
# .note = exits 1, with systemd's reason on stderr, when it cannot answer — an empty
#   answer would read as "no drop-in" and let a second writer's file stand
grove_provision_1_15_hibernate_dropins() {
  local unit p root paths raw found=()
  for unit in "${GROVE_PROVISION_1_15_HIBERNATE_UNITS[@]}"; do
    if ! raw="$(grove_provision_1_15_hibernate_systemctl show -p DropInPaths --value "$unit" 2>&1)"; then
      echo "systemd could not report the drop-ins of $unit: $raw" >&2
      return 1
    fi
    # systemd prints the loaded drop-ins space-separated, on one line
    read -ra paths <<< "$raw"
    for p in "${paths[@]}"; do
      grove_provision_1_15_hibernate_is_own_dropin "$p" "$unit" && found+=("$p")
    done
    for root in "${GROVE_PROVISION_1_15_HIBERNATE_UNIT_ROOTS[@]}"; do
      for p in "$root/$unit.d"/*.conf; do
        [[ -e "$p" ]] && found+=("$p")
      done
    done
  done
  [[ ${#found[@]} -eq 0 ]] || printf '%s\n' "${found[@]}" | sort -u
  return 0
}

# .what = a declared pair's fields, by name: dst, mode, and the source name its dst implies
# .note = sets PAIR_DST, PAIR_MODE, PAIR_NAME in the caller's scope; each caller declares them local
grove_provision_1_15_hibernate_pair() {
  IFS=: read -r PAIR_DST PAIR_MODE <<< "$1"
  PAIR_NAME="$(basename "$PAIR_DST")"
}

# .what = does the timer's enable state count as armed at boot? (masked counts: the apply unmasks it)
grove_provision_1_15_hibernate_is_enableable() {
  case "$1" in enabled|masked) return 0 ;; *) return 1 ;; esac
}

# .what = the source of one declared artifact, in THIS run's checkout
grove_provision_1_15_hibernate_src() {
  printf '%s/grove.provision/1.system/1.15.hibernate/%s' "$GROVE_SRC" "$1"
}

# .what = every way the box differs from the declaration, one per line; none = converged
# .why ONE reader, asked by BOTH halves: the upsert's skip-guard and the verify
#   read the same bytes and the same unit state
# .note = it names only what an apply SETS. how the last run went is an observation,
#   read by `_health` — an apply cannot clear a fault it does not cause
grove_provision_1_15_hibernate_drift() {
  local pair f unit state reload dropins enabled PAIR_NAME PAIR_DST PAIR_MODE
  local timer="$GROVE_PROVISION_1_15_HIBERNATE_TIMER"
  for pair in "${GROVE_PROVISION_1_15_HIBERNATE_PAIRS[@]}"; do
    grove_provision_1_15_hibernate_pair "$pair"
    if [[ -L "$PAIR_DST" ]]; then
      echo "$PAIR_DST is a symlink, not the file this bundle writes"
      continue
    fi
    if ! grove_provision_1_15_hibernate_is_declared_copy "$(grove_provision_1_15_hibernate_src "$PAIR_NAME")" "$PAIR_DST"; then
      echo "$PAIR_DST differs from this checkout's $PAIR_NAME"
      continue
    fi
    # the bytes alone do not converge: a 644 check never runs, and a writable one lets
    # a seat without root edit what root runs every five minutes
    grove_provision_1_15_hibernate_is_held_at "$PAIR_DST" "$PAIR_MODE" \
      || echo "$PAIR_DST is held as '$(grove_provision_1_15_hibernate_held "$PAIR_DST")', not '$PAIR_MODE $GROVE_PROVISION_1_15_HIBERNATE_OWNER'"
  done
  for unit in "${GROVE_PROVISION_1_15_HIBERNATE_UNITS[@]}"; do
    # a systemd that cannot answer reads as no gap on every later probe, so it is a gap itself
    if ! state="$(grove_provision_1_15_hibernate_systemctl show -p LoadState --value "$unit" 2>&1)"; then
      echo "systemd could not report $unit: $state"
      continue
    fi
    [[ "$state" == loaded ]] || echo "$unit is $state, not loaded"
    if ! reload="$(grove_provision_1_15_hibernate_systemctl show -p NeedDaemonReload --value "$unit" 2>&1)"; then
      echo "systemd could not report whether $unit needs a reload: $reload"
      continue
    fi
    [[ "$reload" == yes ]] \
      && echo "systemd still runs the old definition of $unit — a daemon-reload is owed"
  done
  # an unanswered list is a gap of its own; an answered one names each drop-in
  if ! dropins="$(grove_provision_1_15_hibernate_dropins 2>&1)"; then
    echo "$dropins"
    dropins=""
  fi
  while IFS= read -r f; do
    [[ -n "$f" ]] && echo "a drop-in this bundle does not write: $f"
  done <<< "$dropins"
  [[ -e "$GROVE_PROVISION_1_15_HIBERNATE_STOPGAP" ]] \
    && echo "the stopgap pre-check is still on the box: $GROVE_PROVISION_1_15_HIBERNATE_STOPGAP"
  # is-enabled / is-active exit non-zero on a plain "disabled" / "inactive", so the
  # answer is read from stdout; a real fault still reaches stderr, never a sink
  enabled="$(grove_provision_1_15_hibernate_systemctl is-enabled "$timer")"
  [[ "$enabled" == masked ]] && echo "$timer is masked — a hand hold; the apply unmasks it"
  grove_provision_1_15_hibernate_is_enableable "$enabled" || echo "$timer is not enabled"
  [[ "$(grove_provision_1_15_hibernate_systemctl is-active "$timer")" == active ]] \
    || echo "$timer is not active"
  return 0
}

# .what = one `KEY=value` a declared file in this checkout holds, quotes stripped: declared <file> <key>
# .why ONE reader for every value the units and the check declare — the PATH, the cadence,
#   the bounds, the needs — so no caller restates a value or decodes a file its own way
# .note = a ` # …` comment at the line end is cut, so `STIR_SLACK=60   # why` reads `60`
grove_provision_1_15_hibernate_declared() {
  local value
  value="$(sed -n "s/^$2=//; T; s/[[:space:]]\{1,\}#.*$//; p; q" "$(grove_provision_1_15_hibernate_src "$1")")"
  value="${value#\'}"
  echo "${value%\'}"
}

# .what = the check's idle limit, as a human reads it (`3h`), from the check's own IDLE_LIMIT
grove_provision_1_15_hibernate_idle_limit() {
  local secs
  secs="$(grove_provision_1_15_hibernate_declared idle-hibernate.sh IDLE_LIMIT)"
  [[ "$secs" =~ ^[0-9]+$ ]] || { echo "the check's IDLE_LIMIT"; return 0; }
  if (( secs % 3600 == 0 )); then echo "$((secs / 3600))h"; else echo "${secs}s"; fi
}

# .what = the installed check's path — the dst of the declared pair for idle-hibernate.sh
grove_provision_1_15_hibernate_check_dst() {
  local pair PAIR_NAME PAIR_DST PAIR_MODE
  for pair in "${GROVE_PROVISION_1_15_HIBERNATE_PAIRS[@]}"; do
    grove_provision_1_15_hibernate_pair "$pair"
    [[ "$PAIR_NAME" == idle-hibernate.sh ]] && { echo "$PAIR_DST"; return 0; }
  done
  return 1
}

# .what = does the box run this checkout's check — the one that counts every crew and writes its records?
grove_provision_1_15_hibernate_check_is_current() {
  grove_provision_1_15_hibernate_is_declared_copy "$(grove_provision_1_15_hibernate_src idle-hibernate.sh)" \
    "$(grove_provision_1_15_hibernate_check_dst)"
}

# .what = does a pre-check skip the ticks? the stopgap on the box, or a last Result that says so
grove_provision_1_15_hibernate_ticks_skipped() {
  [[ -e "$GROVE_PROVISION_1_15_HIBERNATE_STOPGAP" ]] || [[ "$(grove_provision_1_15_hibernate_result)" == exec-condition ]]
}

# .what = what a drifted box risks NOW, as one line — read from facts, never from the drift text
# .why "drifted" spans three boxes a commander must tell apart: one whose installed check may
#   not count every crew (a busy box may sleep), one the stopgap holds (no crew at risk, an
#   idle box bills), one whose check is this checkout's and only its units differ
grove_provision_1_15_hibernate_risk() {
  if [[ "$(grove_provision_1_15_hibernate_systemctl is-active "$GROVE_PROVISION_1_15_HIBERNATE_TIMER")" != active ]]; then
    echo "the idle check does not tick: no crew is at risk, and an idle box bills on"
  elif [[ -e "$GROVE_PROVISION_1_15_HIBERNATE_STOPGAP" ]]; then
    echo "the stopgap pre-check holds every tick: no crew is at risk, and an idle box bills on"
  elif ! grove_provision_1_15_hibernate_check_is_current; then
    echo "the installed check is not this checkout's, and may not count every crew: a busy box can hibernate under its crews"
  else
    echo "the check is this checkout's, and counts every crew; the gap is in how it is held or run"
  fi
}

# .what = the PATH the service declares (`Environment=PATH=`), read from this checkout's unit
# .why read, never restated: the probe below must look where the unit looks, and a second
#   copy of the PATH here could only drift from the one systemd hands the check
grove_provision_1_15_hibernate_unit_path() {
  grove_provision_1_15_hibernate_declared "$GROVE_PROVISION_1_15_HIBERNATE_SERVICE" Environment=PATH
}

# .what = the tools the check declares in its `NEEDS='…'`, one per line, read from this checkout's check
# .note = exits 1 when the check declares none — a probe of an empty list would read as healthy
grove_provision_1_15_hibernate_needs() {
  local needs
  needs="$(grove_provision_1_15_hibernate_declared idle-hibernate.sh NEEDS)"
  [[ -n "$needs" ]] || return 1
  tr -s ' ' '\n' <<< "$needs"
}

# .what = what an absent need costs, then its fix as a `⇒ fix` line (need_gap <tool> <unit path>)
# .why the fix sits on its own `⇒` line, as under every other ✋ the verify prints, so a
#   reader finds every repair in one shape
# .why aws names cloud-init first: this bundle runs only on an ec2 grove, and infra's first boot
#   installs aws v2 at /usr/local/bin before any provision runs. so an absent aws means that
#   EARLIER install failed — never that `5.6.aws`, which sorts after this bundle, has yet to run
#   (`rule.require.bundles-own-their-dependencies`: a pointer names a bundle that ran first)
grove_provision_1_15_hibernate_need_gap() {
  case "$1" in
    aws)
      echo "the stop act needs aws, and none is on the unit's PATH ($2), so an idle box would bill"
      echo "⇒ the grove's first boot installs aws, so its install failed: read /var/log/cloud-init-output.log"
      echo "⇒ fix, from the ground seat: rhx grove.provision --what 5.6.aws --mode apply" ;;
    *)
      echo "the check needs $1, and none is on the unit's PATH ($2), so every tick holds loud and an idle box would bill"
      echo "⇒ fix, from the ground seat: restore the base package that ships $1" ;;
  esac
}

# .what = the last idle check's Result; exits 1, with systemd's reason, when it cannot answer
grove_provision_1_15_hibernate_result() {
  grove_provision_1_15_hibernate_systemctl show -p Result --value "$GROVE_PROVISION_1_15_HIBERNATE_SERVICE" 2>&1
}

# .what = is this Result a run that went clean? (an empty Result: the unit never ran)
grove_provision_1_15_hibernate_result_is_clean() { [[ -z "$1" || "$1" == success ]]; }

# .what = what a Result says of the run, and where its fix lies — one line
# .why each value names a different cause: a skipped tick is config the apply retires; a
#   killed run may have left no record of its own; a run that ended on its own is a fault
#   the next tick raises again. one summary for all three names the wrong subject for two
grove_provision_1_15_hibernate_result_gloss() {
  case "$1" in
    exec-condition)
      echo "a pre-check (ExecCondition=) skipped the tick, so the check never ran — a drop-in this bundle does not write; the ground apply retires it" ;;
    timeout|signal|core-dump|watchdog|oom-kill)
      echo "the run was killed before its end, so the record above may be an earlier run's — a fault in the run, not in the config; the next tick raises it again until its cause is gone, and the box may bill until then" ;;
    *)
      echo "a fault in the last run, not in the config: an apply resets the result, and the next tick raises it again until its cause is gone — the box may bill until then" ;;
  esac
}

# .what = did this Result leave a record of its own? a skipped tick ran no check
grove_provision_1_15_hibernate_result_has_record() { [[ "$1" != exec-condition ]]; }

# .what = the last run's record, one line each, every control byte as `?`
# .why the record is a world-readable boundary: the check sanitizes what it says, and the
#   reader sanitizes again — a file at that path may hold bytes no check wrote
# .note = record_lines [path] — the run record by default. exits 1, with the read's error
#   on stdout, when the record cannot be read
grove_provision_1_15_hibernate_record_lines() {
  local record line
  record="$(cat "${1:-$GROVE_PROVISION_1_15_HIBERNATE_RECORD}" 2>&1)" || { echo "$record"; return 1; }
  while IFS= read -r line; do echo "${line//[[:cntrl:]]/?}"; done <<< "$record"
}

# .what = the run's own verdict line in a record: the last `hold —` or `sleep —` line
grove_provision_1_15_hibernate_record_verdict() { grep -E '^idle-hibernate: (hold|sleep) — ' <<< "$1" | tail -1; }

# .what = how the last idle check ran, and whether its next can act — one symptom per line; none = healthy
# .why config is not effect: a check that wedges, cannot read a source, or cannot stop
#   the box ends its run with a Result other than success. that is a fact about the
#   RUN, so the verify names it beside drift and the apply never tries to repair it
# .why each of the check's NEEDS on the unit's PATH: a box busy since its provision has
#   never run the stop act, so an absent `aws` would surface only on the first idle tick —
#   as a box that bills; an absent `setpriv` makes every seat's duct unreadable, forever
grove_provision_1_15_hibernate_health() {
  local result needs need unit_path
  if ! result="$(grove_provision_1_15_hibernate_result)"; then
    echo "systemd could not report the last idle check's result: $result"
  elif ! grove_provision_1_15_hibernate_result_is_clean "$result"; then
    echo "the last idle check ended '$result'"
  fi
  unit_path="$(grove_provision_1_15_hibernate_unit_path)"
  if [[ -z "$unit_path" ]]; then
    echo "this checkout's $GROVE_PROVISION_1_15_HIBERNATE_SERVICE reads with no Environment=PATH=, so no tool the check needs can be probed — read $(grove_provision_1_15_hibernate_src "$GROVE_PROVISION_1_15_HIBERNATE_SERVICE")"
    return 0
  fi
  if ! needs="$(grove_provision_1_15_hibernate_needs)"; then
    echo "this checkout's idle-hibernate.sh reads with no NEEDS='…', so no tool it needs can be probed — read $(grove_provision_1_15_hibernate_src idle-hibernate.sh)"
    return 0
  fi
  while IFS= read -r need; do
    ( PATH="$unit_path"; command -v "$need" >/dev/null 2>&1 ) \
      || grove_provision_1_15_hibernate_need_gap "$need" "$unit_path"
  done <<< "$needs"
  return 0
}

# .what = the indent of a line this bundle prints at its own depth in the tree
# .why the runtime indents each bundle by `(depth + 1) * 3`; a line printed from
#   dispatch must match it, or the decline reads as a peer of its parent
grove_provision_1_15_hibernate_pad() {
  printf '%*s' $(( (BUNDLE_DEPTH + 1) * 3 )) ''
}

grove_provision_1_15_hibernate() {
  # the gate sits at dispatch, as `2.9.emoji`'s does: every phase declines for the
  # one reason, and the decline prints from dispatch at this bundle's depth
  if ! grove_provision_1_15_hibernate_platform_is_ec2; then
    local pad
    pad="$(grove_provision_1_15_hibernate_pad)"
    echo "   ${pad}🌙 declined — the act is \`aws ec2 stop-instances\` on this box's own"
    echo "   ${pad}   instance, and ${GROVE_ENV_SERVER:-an unset server} has no ec2 identity"
    return 0
  fi
  bundle.upgrade 1.15.hibernate.configure.upsert
  bundle.upgrade 1.15.hibernate.configure.verify
}
