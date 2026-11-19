#!/usr/bin/env bash
######################################################################
# .what = prove the boot's step 1 platform declaration and step 3 key placement
#         render every verdict a human reads — the ✔ lines, the plan lines, and
#         each halt with its fix and its resume command
#
# .why  = these lines are what a human copies a repair out of. a grep of the
#         boot's source proves a string is THERE, never that the assembled line
#         reads right; this renders each branch and pins it
#
# guarantee:
#   - hermetic: a fixture registry, a stub seat writer, a stub `rhx`; all in
#     mktemp. the grove name is invented
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILLS="$HERE/.agent/repo=.this/role=any/skills"

fixture="$(mktemp -d)" || { echo "💥 MalfunctionError: could not make a temp dir" >&2; exit 1; }
trap 'rm -rf "$fixture"' EXIT

failed=0
check() {
  local label="$1"; shift
  if "$@"; then echo "   • $label ✔"; else echo "   💥 MalfunctionError: $label" >&2; failed=1; fi
}
has() { [[ "$1" == *"$2"* ]]; }
lacks() { [[ "$1" != *"$2"* ]]; }

transcript=""
record() {
  local text="${2//$fixture/<fix>}"
  transcript+="## $1 (rc $3)"$'\n'"${text//$(id -un)/<login>}"$'\n\n'
}

echo "🌲 prove.boot-steps-name-each-verdict"

mkdir -p "$fixture/forest/groves" "$fixture/bin" "$fixture/state"

# the stub rhx: `git.grove.auth.keys.set` answers per the state dir
cat > "$fixture/bin/rhx" <<STUB
#!/usr/bin/env bash
echo "   (stub) rhx \$*"
[[ "\$1" == duct.reboot && -f "$fixture/state/reboot-fail" ]] && { echo "✋ duct.reboot: '\$3' is absent — there is no pane to reboot" >&2; exit 2; }
[[ -f "$fixture/state/keys-fail" ]] && { echo "   ✋ ConstraintError: ahbode.prep.VENDOR_KEY — this laptop's rack reads it empty" >&2; exit 2; }
exit 0
STUB
chmod +x "$fixture/bin/rhx"

# $1 = registry platform ('' for none) · $2 = mode · $3 = step fn
# env: HOST (registry host; default localhost, an ec2 tunnel) · TRUST · BOOT_TRUST_HELD
run_step() {
  jq -n --arg p "$1" --arg h "${HOST:-localhost}" \
    '{host: $h} + (if $p == "" then {} else {platform: $p} end)' > "$fixture/forest/groves/grove-demo.json"
  (
    export GIT_FOREST_DIR="$fixture/forest"
    GROVE=grove-demo MODE="$2" RHX="$fixture/bin/rhx" BOOT_ORG=ahbode
    # shellcheck source=/dev/null
    source "$SKILLS/git.grove.operations.sh"
    # shellcheck source=/dev/null
    source "$SKILLS/git.grove.ssh.operations.sh"
    # shellcheck source=/dev/null
    source "$SKILLS/git.grove.provision.boot.operations.sh"    # the seat writer's own verdicts are pinned in prove.platform-findsert-names-each-verdict
    grove_ssh_platform_findsert() {
      [[ -f "$fixture/state/road-refused" ]] && { echo "ground@host: Permission denied (publickey)."; return 1; }
      [[ -f "$fixture/state/sudo-refused" ]] && { echo "sudo: a password is required"; return 1; }
      [[ -f "$fixture/state/differs" ]] && {
        printf 'DIFFERS: the box declares aws.ec2\033]52;c;ZXZpbA==\a\n'; return 1; }
      echo SET
    }
    "$3"
  )
}

####################################################################
# arm 1 — step 1, the platform declaration
####################################################################
out="$(run_step '' apply boot_platform_declare 2>&1)"; rc=$?
record "platform, none in the registry" "$out" "$rc"
check "platform · none, ec2 → the box answers alone" has "$out" "none declared in the registry (an ec2 box answers it alone)"
check "platform · none, ec2 → rc 0" test "$rc" -eq 0

out="$(HOST=grove-demo-1 run_step '' apply boot_platform_declare 2>&1)"; rc=$?
record "platform, none in the registry, a tailnet grove" "$out" "$rc"
check "platform · none, tailnet → halts step 1" has "$out" "✋ step 1 (reach) does not hold"
check "platform · none, tailnet → never says the box answers alone" bash -c '[[ "$1" != *"answers it alone"* ]]' _ "$out"
check "platform · none, tailnet → names the registry fix" has "$out" "rhx git.grove.set grove-demo --platform hetzner.hetzbot"
check "platform · none, tailnet → rc 3" test "$rc" -eq 3

out="$(run_step hetzner.hetzbot plan boot_platform_declare 2>&1)"; rc=$?
record "platform, hetzner, plan" "$out" "$rc"
check "platform · plan → names the findsert and the seat" has "$out" "would findsert /etc/grove/platform = hetzner.hetzbot, over grove-demo.ground"
check "platform · plan → rc 0" test "$rc" -eq 0

out="$(run_step hetzner.hetzbot apply boot_platform_declare 2>&1)"; rc=$?
record "platform, hetzner, apply, laid" "$out" "$rc"
check "platform · apply → ✔ with the seat's verdict" has "$out" "platform ✔ /etc/grove/platform = hetzner.hetzbot (SET)"
check "platform · apply → rc 0" test "$rc" -eq 0

touch "$fixture/state/differs"
# the platform runs AFTER trust held in this run, so its resume keeps the trust
out="$(BOOT_TRUST_HELD=1 TRUST=verified run_step hetzner.hetzbot apply boot_platform_declare 2>&1)"; rc=$?
record "platform, hetzner, apply, the box declares another" "$out" "$rc"
check "platform · differs → halts step 1" has "$out" "✋ step 1 (reach) does not hold"
check "platform · differs → relays the seat's answer" has "$out" "could not be laid over grove-demo.ground: DIFFERS: the box declares aws.ec2"
check "platform · differs → names the read a human owes" has "$out" "read it before any apply: ssh grove-demo.ground cat /etc/grove/platform"
check "platform · differs → the resume names the verb and the step" has "$out" "git.grove.provision boot grove-demo --mode apply --from 1 --trust keep"
check "platform · differs → the seat's escape bytes are stripped" bash -c '[[ "$1" != *$'"'"'\033'"'"'* ]]' _ "$out"
check "platform · differs → no payload debris of the escape (]52;) reaches the halt" lacks "$out" "]52;"
check "platform · differs → rc 3" test "$rc" -eq 3
rm -f "$fixture/state/differs"

touch "$fixture/state/road-refused"
out="$(BOOT_TRUST_HELD=1 TRUST=verified run_step hetzner.hetzbot apply boot_platform_declare 2>&1)"; rc=$?
record "platform, hetzner, apply, the ground seat's road refuses" "$out" "$rc"
check "platform · road refused → relays the seat's answer" has "$out" "Permission denied (publickey)"
check "platform · road refused → never explains a DIFFERS it did not get" bash -c '[[ "$1" != *"DIFFERS answer"* ]]' _ "$out"
check "platform · key refused → names the key placement, never a sudo read" \
  bash -c '[[ "$1" == *"git.grove.auth.ssh.set grove-demo --identity <this laptop'"'"'s key>.pub --mode plan"* && "$1" != *"sudo -n true"* ]]' _ "$out"
rm -f "$fixture/state/road-refused"
touch "$fixture/state/sudo-refused"
out="$(BOOT_TRUST_HELD=1 TRUST=verified run_step hetzner.hetzbot apply boot_platform_declare 2>&1)"; rc=$?
record "platform, hetzner, apply, the ground seat's sudo refuses" "$out" "$rc"
check "platform · sudo refused → names the seat's sudo road" has "$out" "ssh grove-demo.ground sudo -n true"
rm -f "$fixture/state/sudo-refused"

out="$(run_step aws.ec2 apply boot_platform_declare 2>&1)"; rc=$?
record "platform, a registry value no box declares" "$out" "$rc"
check "platform · foreign → names the registry fix" has "$out" $'fix:\n    rhx git.grove.set grove-demo --platform hetzner.hetzbot'
check "platform · foreign → rc 3" test "$rc" -eq 3

####################################################################
# arm 2 — step 3, the key placement
####################################################################
out="$(run_step '' plan boot_keys_place 2>&1)"; rc=$?
record "keys, plan" "$out" "$rc"
check "keys · plan → names the command with the org" has "${out//$fixture/<fix>}" "keys · would run: <fix>/bin/rhx git.grove.auth.keys.set grove-demo --mode apply --org ahbode"
check "keys · plan → runs no placement" bash -c '[[ "$1" != *"(stub)"* ]]' _ "${out//$fixture/<fix>}"

out="$(run_step '' apply boot_keys_place 2>&1)"; rc=$?
record "keys, apply, placed" "$out" "$rc"
check "keys · apply → passes the org through" has "$out" "(stub) rhx git.grove.auth.keys.set grove-demo --mode apply --org ahbode"
check "keys · apply → ✔" has "$out" "keys ✔ grove-demo reads every row 5.16.keys declares"
check "keys · apply → rc 0" test "$rc" -eq 0

touch "$fixture/state/keys-fail"
out="$(run_step '' apply boot_keys_place 2>&1)"; rc=$?
record "keys, apply, a row this laptop cannot place" "$out" "$rc"
check "keys · fail → the skill's own row reaches the human" has "$out" "ahbode.prep.VENDOR_KEY — this laptop's rack reads it empty"
check "keys · fail → halts step 3" has "$out" "✋ step 3 (keys) does not hold"
check "keys · fail → the fix is the skill's plan" has "$out" "git.grove.auth.keys.set grove-demo --mode plan --org ahbode"
check "keys · fail → names the keys apply as the fix" has "$out" "git.grove.auth.keys.set grove-demo --mode apply --org ahbode"
check "keys · fail → resumes at the gate, never a second camper apply" \
  bash -c '[[ "$1" == *"--from 4 --trust keep"* && "$1" != *"--from 3"* ]]' _ "$out"
check "keys · fail → rc 3" test "$rc" -eq 3
rm -f "$fixture/state/keys-fail"

####################################################################
# arm 2b — a seat's halts while its detached apply may be at work: none may resume AT
#   the seat (a second, concurrent apply), and the camper's must not skip the keys
####################################################################
seat_unproven() { boot_seat_unproven_halt grove-demo 3 camper "<slice>"; }
seat_silent_ground() { boot_seat_silent_halt grove-demo.ground 2 ground "<log>"; }
seat_silent_camper() { boot_seat_silent_halt grove-demo 3 camper "<log>"; }
seat_outran_camper() { WITHIN=2700 boot_seat_outran_halt grove-demo 3 camper "<log>" "<slice>"; }
out="$(BOOT_TRUST_HELD=1 run_step '' apply seat_unproven 2>&1)"; rc=$?
record "seat halt, an unproven send (97)" "$out" "$rc"
check "seat · unproven → names how to tell a run from none before a resume" \
  bash -c '[[ "$1" == *"only the marker there → no copy runs"* && "$1" == *"--from 3 --trust keep"* ]]' _ "$out"
out="$(BOOT_TRUST_HELD=1 run_step '' apply seat_silent_ground 2>&1)"; rc=$?
record "seat halt, ground, ten empty probes" "$out" "$rc"
check "seat · silent ground → waits for the verdict, then resumes PAST the seat" \
  bash -c '[[ "$1" == *"once THIS run'"'"'s log ends"* && "$1" == *"--from 3 --trust keep"* && "$1" != *"--from 2"* ]]' _ "$out"
check "seat · silent ground → rc 3" test "$rc" -eq 3
out="$(BOOT_TRUST_HELD=1 run_step '' apply seat_silent_camper 2>&1)"; rc=$?
record "seat halt, camper, ten empty probes" "$out" "$rc"
check "seat · silent camper → places the keys, then resumes at the gate" \
  bash -c '[[ "$1" == *"git.grove.auth.keys.set grove-demo --mode apply --org ahbode"* && "$1" == *"--from 4 --trust keep"* && "$1" != *"--from 3"* ]]' _ "$out"
out="$(BOOT_TRUST_HELD=1 run_step '' apply seat_outran_camper 2>&1)"; rc=$?
record "seat halt, camper, the apply outran its bound" "$out" "$rc"
check "seat · outran → names the bound, and no re-send" \
  bash -c '[[ "$1" == *"outran 2700s"* && "$1" == *"do NOT re-send"* ]]' _ "$out"
check "seat · outran camper → the keys line comes before the gate resume" \
  bash -c '[[ "$1" == *"keys.set grove-demo --mode apply"*"--from 4 --trust keep"* && "$1" != *"--from 3"* ]]' _ "$out"

####################################################################
# arm 2c — a seat that CONVERGED gets its duct reborn: the duct opened at wake,
#   before the apply laid PATH, and a pane keeps its birth env. 📜 2026-11-17:
#   a green boot, then `--what 'rhx …'` on the camper answered command not found
####################################################################
seat_reborn_camper() { boot_seat_duct_reborn grove-demo 3 camper; }
seat_reborn_ground() { boot_seat_duct_reborn grove-demo.ground 2 ground; }
out="$(BOOT_TRUST_HELD=1 run_step '' apply seat_reborn_camper 2>&1)"; rc=$?
record "seat converged, camper, the duct is reborn" "$out" "$rc"
check "duct · camper → reboots the seat's own duct, and says why" \
  has "$out" "✔ duct reborn (duct://grove-demo/main/mechanic) — its shell reads this apply's PATH"
check "duct · camper → rc 0" test "$rc" -eq 0
out="$(BOOT_TRUST_HELD=1 run_step '' apply seat_reborn_ground 2>&1)"; rc=$?
record "seat converged, ground, the duct is reborn" "$out" "$rc"
check "duct · ground → reboots the ground seat's duct, never the camper's" \
  bash -c '[[ "$1" == *"✔ duct reborn (duct://grove-demo.ground/main/mechanic)"* && "$1" != *"duct://grove-demo/main"* ]]' _ "$out"
touch "$fixture/state/reboot-fail"
out="$(BOOT_TRUST_HELD=1 run_step '' apply seat_reborn_camper 2>&1)"; rc=$?
record "seat converged, camper, the duct refuses its reboot" "$out" "$rc"
check "duct · refused → halts the seat's step" has "$out" "✋ step 3 (camper) does not hold"
check "duct · refused → relays the refusal" has "$out" "is absent — there is no pane to reboot"
check "duct · refused → names the reboot, then the keys, then resumes PAST the seat" \
  bash -c '[[ "$1" == *"duct.reboot --on '"'"'duct://grove-demo/main/mechanic'"'"'"*"keys.set grove-demo --mode apply --org ahbode"*"--from 4 --trust keep"* && "$1" != *"--from 3"* ]]' _ "$out"
check "duct · refused → rc 3" test "$rc" -eq 3
rm -f "$fixture/state/reboot-fail"
# the call site: drive_seat reborns the duct on the converged branch, and only there
boot_src="$(cat "$SKILLS/git.grove.provision.boot.sh")"
check "duct · drive_seat calls it once the apply reads done" \
  has "$boot_src" $'say "│  ├─ ✔ converged in ~$(( waited / 60 ))m"\n      boot_seat_duct_reborn "$seat" "$step" "$label"\n      return 0'

####################################################################
# arm 3 — step 1's wake and trust halts, in each reach's own words, and the
#   resume each hands back: a halt BEFORE trust held must not resume with
#   `--trust keep`, which would skip the very step that failed
####################################################################
for reach in ec2 tailnet; do
  host=localhost; [[ "$reach" == tailnet ]] && host=grove-demo-1
  out="$(HOST="$host" TRUST=tofu run_step '' apply boot_wake_halt 2>&1)"; rc=$?
  record "wake halt, $reach, asked --trust tofu" "$out" "$rc"
  check "wake · $reach → halts step 1, rc 3" bash -c '[[ "$1" == *"✋ step 1 (reach) does not hold"* && "$2" -eq 3 ]]' _ "$out" "$rc"
  check "wake · $reach → the resume carries the trust asked for" has "$out" "--from 1 --trust tofu"
  check "wake · $reach → never resumes with --trust keep" bash -c '[[ "$1" != *"--trust keep"* ]]' _ "$out"

  out="$(HOST="$host" TRUST=verified run_step '' apply boot_trust_halt 2>&1)"; rc=$?
  record "trust halt, $reach, asked --trust verified" "$out" "$rc"
done
out="$(HOST=localhost TRUST=verified run_step '' apply boot_trust_halt 2>&1)"
check "trust · ec2 → the resume re-runs the trust" has "$out" "--from 1 --trust verified"
check "trust · ec2 → names --trust replace for a rebuilt box (its boot record attests)" has "$out" "boot grove-demo --mode apply --trust replace"
# a tailnet box publishes no boot record: the human lays the trust through trust.gen,
#   and the resume RE-PROVES it — trust.gen answers "already trusted" once the key is
#   laid, so verified does not loop, and `keep` would skip the step that failed
out="$(HOST=grove-demo-1 TRUST=tofu run_step '' apply boot_trust_halt 2>&1)"
check "trust · tailnet → the resume re-proves the trust the fix laid, never keep" \
  bash -c '[[ "$1" == *"--from 1 --trust verified"* && "$1" != *"--trust keep"* ]]' _ "$out"
check "trust · tailnet → names no boot --trust replace road (it refuses on a rebuild)" \
  bash -c '[[ "$1" != *"--mode apply --trust replace"* ]]' _ "$out"
check "trust · tailnet → names the attested replace, and infra's fingerprints past it" \
  bash -c '[[ "$1" == *"trust.gen --grove grove-demo --mode apply --on-changed replace"* && "$1" == *"infra'"'"'s fingerprints"* ]]' _ "$out"
wake_refused() { boot_wake_halt 2; }
out="$(HOST=grove-demo-1 TRUST=tofu run_step '' apply wake_refused 2>&1)"; rc=$?
record "wake halt, tailnet, the wake refused (rc 2)" "$out" "$rc"
check "wake · refused → names the refusal and the key placement, never a silence" \
  bash -c '[[ "$1" == *"the wake refused (rc 2)"* && "$1" == *"git.grove.auth.ssh.set grove-demo"* && "$1" != *"a silence is reach"* ]]' _ "$out"
out="$(HOST=grove-demo-1 TRUST=tofu run_step '' apply boot_wake_halt 2>&1)"
check "wake · tailnet → no tunnel, no camp unlock" bash -c '[[ "$1" != *"tunnel"* && "$1" != *"keyrack unlock"* ]]' _ "$out"
check "wake · tailnet → names the tailnet read" has "$out" "tailscale status"
out="$(HOST=grove-demo-1 TRUST=verified run_step '' apply boot_trust_halt 2>&1)"
check "trust · tailnet → no tunnel, no boot record, no port" \
  bash -c '[[ "$1" != *"tunnel"* && "$1" != *"boot record"* && "$1" != *"ss -tlnp"* ]]' _ "$out"
check "trust · tailnet → names the plan, then tofu for a first contact" \
  bash -c '[[ "$1" == *"trust.gen --grove grove-demo --mode plan"* && "$1" == *"trust.gen --grove grove-demo --mode apply --trust tofu"* ]]' _ "$out"
# the push halt names the road the reach rides on
out="$(HOST=grove-demo-1 run_step '' apply boot_reach_road_line 2>&1)"
check "push · tailnet → names the tailnet, never a camp unlock" \
  bash -c '[[ "$1" == *"tailscale status"* && "$1" != *"keyrack unlock"* ]]' _ "$out"
out="$(HOST=localhost run_step '' apply boot_reach_road_line 2>&1)"
check "push · ec2 → names the camp unlock its tunnel rides" has "$out" "keyrack unlock --owner ehmpath --env camp"
check "push · the push halt reads its road line from the one reader" \
  bash -c 'grep -q "\$(boot_reach_road_line)" "$1"' _ "$SKILLS/git.grove.provision.boot.sh"
# both trust halts send the human to "trust.gen's own rows above" — so the boot must
#   keep them, never sink them
check "trust · the boot keeps trust.gen's rows (its halt cites them)" \
  bash -c '! grep -E "git\.grove\.trust\.gen .*>/dev/null" "$1" && grep -q "printf .%s\\\\n. \"\$TRUST_OUT\"" "$1"' \
  _ "$SKILLS/git.grove.provision.boot.sh"

# a step-0 halt (grants) has not reached trust either
boot_resume_line_0() { boot_resume_line 0; }
boot_resume_line_2() { boot_resume_line 2; }
out="$(TRUST=replace run_step '' apply boot_resume_line_0 2>&1)"
check "resume · step 0 carries the trust asked for" has "$out" "--from 0 --trust replace"
out="$(TRUST=replace run_step '' apply boot_resume_line_2 2>&1)"
check "resume · step 2 keeps the trust that held" has "$out" "--from 2 --trust keep"

####################################################################
# arm 4 — step 1's ground alias: no wake writes it, so the boot does, from the
#   registry's `.ground` entry; a re-run keeps it; no entry is a named halt
####################################################################
mkdir -p "$fixture/home" "$fixture/sshbin"
ground_reg="$fixture/forest/groves/grove-demo.ground.json"
printf '{"name":"grove-demo.ground","user":"ground","host":"grove-demo-1","port":22}\n' > "$ground_reg"
# 🛑 ssh finds `~` from the passwd entry, never $HOME — so the real ssh would read
#    THIS laptop's config (and print its login into the snapshot). `-F` pins the
#    fixture's config; `-G` dials naught, so the precedence read is ssh's own
REAL_SSH="$(command -v ssh)" || { echo "✋ ConstraintError: ssh is absent" >&2; exit 2; }
printf '#!/usr/bin/env bash\nexec %q -F "$HOME/.ssh/config" "$@"\n' "$REAL_SSH" > "$fixture/sshbin/ssh"
chmod +x "$fixture/sshbin/ssh"
run_ground() { ( export HOME="$fixture/home" PATH="$fixture/sshbin:$PATH"; run_step '' "$1" boot_ground_alias ); }
cp "$ground_reg" "$fixture/state/ground.json"

out="$(run_ground plan 2>&1)"; rc=$?
record "ground alias, plan" "$out" "$rc"
check "ground · plan → names the seat it would set" has "$out" "would set alias 'grove-demo.ground' → ground@grove-demo-1:22"
check "ground · plan → writes no ssh config" test ! -e "$fixture/home/.ssh/config"

cp "$fixture/state/ground.json" "$ground_reg"
out="$(run_ground apply 2>&1)"; rc=$?
record "ground alias, apply, a fresh laptop" "$out" "$rc"
check "ground · apply → SET, rc 0" bash -c '[[ "$1" == *"ground alias [SET] '"'"'grove-demo.ground'"'"'"* && "$2" -eq 0 ]]' _ "$out" "$rc"
check "ground · apply → ssh dials the ground seat" \
  bash -c '[[ "$(HOME="$1" "$2" -G grove-demo.ground </dev/null | awk "/^user /{print \$2}")" == ground ]]' _ "$fixture/home" "$fixture/sshbin/ssh"

cp "$fixture/state/ground.json" "$ground_reg"
out="$(run_ground apply 2>&1)"; rc=$?
record "ground alias, apply, a re-run" "$out" "$rc"
check "ground · re-run → KEEP" has "$out" "ground alias [KEEP]"

check "ground · the boot sets the ground alias before step 1 dials ground" \
  bash -c '[[ "$(grep -nE "^  boot_(ground_alias|platform_declare)$" "$1" | cut -d: -f2 | tr -d " " | tr "\n" ,)" == "boot_ground_alias,boot_platform_declare," ]]' \
  _ "$SKILLS/git.grove.provision.boot.sh"

# an --alias seat records no host: its Host block is infra's, so the boot writes none
#   (a block here sits in the file ssh reads FIRST and would shadow infra's own)
rm -rf "$fixture/home/.ssh"
printf '{"name":"grove-demo.ground","sshAlias":"infra-ground","user":null,"host":null,"port":null}\n' > "$ground_reg"
out="$(run_ground apply 2>&1)"; rc=$?
record "ground alias, an --alias seat (no host)" "$out" "$rc"
check "ground · --alias seat → KEEP, rc 0" bash -c '[[ "$1" == *"ground alias [KEEP] '"'"'infra-ground'"'"'"* && "$2" -eq 0 ]]' _ "$out" "$rc"
check "ground · --alias seat → writes no Host block of its own" \
  bash -c '! grep -rqs "^Host infra-ground$" "$1/.ssh"' _ "$fixture/home"
check "ground · --alias seat → never invents localhost" bash -c '[[ "$1" != *localhost* ]]' _ "$out"

# the platform step dials the SAME name the alias step kept — never the literal
#   `<grove>.ground`, which an --alias seat never registers with ssh
out="$(run_step hetzner.hetzbot plan boot_platform_declare 2>&1)"; rc=$?
record "platform, an --alias ground seat, plan" "$out" "$rc"
check "platform · --alias seat → dials the seat's own alias" has "$out" "over infra-ground"
touch "$fixture/state/differs"
out="$(BOOT_TRUST_HELD=1 TRUST=verified run_step hetzner.hetzbot apply boot_platform_declare 2>&1)"
check "platform · --alias seat → the read it names dials the alias" has "$out" "ssh infra-ground cat /etc/grove/platform"
rm -f "$fixture/state/differs"

rm -f "$ground_reg"
out="$(run_ground apply 2>&1)"; rc=$?
record "ground alias, no ground seat registered" "$out" "$rc"
check "ground · none → halts step 1 by name, rc 3" \
  bash -c '[[ "$1" == *"no '"'"'grove-demo.ground'"'"' seat is registered"* && "$2" -eq 3 ]]' _ "$out" "$rc"

####################################################################
# arm 5 — the boot's front door: --help, and each bad input. every one
#   exits before any reach, so the real skill runs here with no stub
####################################################################
boot_cli() { GIT_FOREST_DIR="$fixture/forest" bash "$SKILLS/git.grove.provision.boot.sh" "$@" 2>&1; }

out="$(boot_cli --help)"; rc=$?
record "cli · --help" "$out" "$rc"
check "cli · --help → names each input with its default" \
  bash -c '[[ "$1" == *"(default plan)"* && "$1" == *"(default 0)"* && "$1" == *"(default verified)"* && "$1" == *"(default 2700)"* ]]' _ "$out"
check "cli · --help → carries a paste-ready example" has "$out" "rhx git.grove.provision boot <name> --mode apply --trust tofu"
check "cli · --help → rc 0" test "$rc" -eq 0

for bad in "--wat" "" "grove-demo --mode" "grove-demo --mode yes" "grove-demo --from 7" "grove-demo --trust maybe" "grove-demo --within soon"; do
  # shellcheck disable=SC2086 # the words are the argv under test
  out="$(boot_cli $bad)"; rc=$?
  record "cli · refused: '${bad:-<no args>}'" "$out" "$rc"
  check "cli · '${bad:-<no args>}' → a qualified ✋, the fix, the help, rc 2" \
    bash -c '[[ "$1" == "✋ ConstraintError: "* && "$1" == *"fix: rhx git.grove.provision boot <name>"* && "$1" == *"--help"* && "$2" -eq 2 ]]' _ "$out" "$rc"
done
check "cli · an unknown flag → names every valid flag" has "$(boot_cli --wat)" "--within <secs>"

####################################################################
# arm 6 — the sink every halt line passes through (`__duct_strip_escapes`):
#   a whole OSC or CSI sequence leaves, payload and all, so a seat's answer
#   reads clean; an unterminated or 8-bit one still loses every control byte
#   (the class stages are the guard, the sequence stage is legibility only)
####################################################################
sink() {
  # shellcheck disable=SC1090,SC2059 # the format IS the bytes under test
  printf "$1" | ( source "$HERE/src/grove.provision/2.shell/2.7.aliases/ductwork.sh" >/dev/null 2>&1; __duct_strip_escapes )
}
sink_case() {
  # $1 = label, $2 = printf input, $3 = the exact output owed
  local got; got="$(sink "$2")"
  # shellcheck disable=SC2059
  record "sink · $1" "in:  $(printf "$2" | od -An -c | tr -s ' \n' ' ')"$'\n'"out: $(printf '%s' "$got" | od -An -c | tr -s ' \n' ' ')" 0
  check "sink · $1 → '$3'" test "$got" == "$3"
}
sink_case "osc 52, bel-terminated" 'DIFFERS: aws.ec2\033]52;c;ZXZpbA==\007 end' 'DIFFERS: aws.ec2 end'
sink_case "osc 52, st-terminated"  'a\033]52;c;ZXZpbA==\033\\b'                  'ab'
sink_case "osc 0 title"            '\033]0;owned\007ok'                           'ok'
sink_case "csi color"              '\033[31mred\033[0m plain'                     'red plain'
sink_case "csi cursor moves"       'x\033[2Ky\033[10;20Hz'                        'xyz'
sink_case "csi private mode"       '\033[?1049hscreen'                            'screen'
sink_case "unterminated osc"       'a\033]52;c;ZXZpbA== tail'                     'a]52;c;ZXZpbA== tail'
sink_case "8-bit csi (U+009B)"     'a\302\23331mb'                                'a31mb'
sink_case "lone esc and bel"       'a\033b\007c'                                  'abc'
sink_case "tab, tree glyph, turtle kept" 'a\tb \342\224\234 \360\237\220\242 z' "$(printf 'a\tb \342\224\234 \360\237\220\242 z')"

# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
play_snap_verify dir="$HERE/.play/permanent/prove.boot-steps-name-each-verdict.snap" name=transcript actual="$transcript" || failed=1

echo ""
if [[ $failed -ne 0 ]]; then
  echo "💥 MalfunctionError: prove.boot-steps-name-each-verdict: a claim did not hold" >&2
  exit 1
fi
echo "🌲 all claims held ✔"
