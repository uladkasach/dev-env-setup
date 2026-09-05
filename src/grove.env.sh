#!/usr/bin/env bash
######################################################################
# the environment — derived once, then propagated
#
# .what = derive the `Environment` this run is for, and expose the predicates a
#         bundle leaf needs to decide whether it applies here.
#
# .why  = "which machine is this?" is one question with one published answer:
#         `ehmpathy/sdk-environment`, whose `Environment` carries three
#         attributes. this file conforms to that contract rather than keep a
#         private vocabulary beside it (rule.require.conform-to-sdk-environment).
#
#           access  test | prep | prod        what resources may we touch?
#           server  $tier@$platform           where does this run?
#           commit  $gitref@$hash[+]          what code is this?
#
# .why conformance is by VOCABULARY, not by import
#         sdk-environment is a node package, and this provisioner runs before
#         node exists on a fresh machine. so the words and values are matched
#         exactly while the code is not shared. no compiler holds this; review
#         and the term glossary do.
#
# .why the predicates, and not a bare tier test
#         `server` carries two independent facts in `$tier@$platform`, and a
#         provisioner needs both:
#
#           local@unix     a laptop       screen: yes   human: yes
#           cloud@aws.ec2  a grove        screen: no    human: no
#
#         those two are the WHOLE detected set — see `.the CLOSED SET` below.
#
#         a bare `local` test would still be the wrong shape even so, because
#         tier alone cannot express "local tier, no human" — the ci-runner case
#         (`local@cicd`) that a two-valued tag gets wrong. we do not detect that
#         box, but the two-part `$tier@$platform` value is what keeps the door
#         open to it without a second vocabulary.
#
# usage:
#   source grove.env.sh
#   grove_env_derive --for cloud                    # once, at the entrypoint
#   [[ "$GROVE_ENV_SERVER" == local@unix ]] || return 0   # in a leaf
#
# 🛑 a leaf tests the TAG, never a `grove_env_has_*` predicate
#   - no such predicate exists here, deliberately
#   - the `.note` at the foot of this file carries all three reasons
#
# guarantee:
#   - derived ONCE. every value is exported, so a subshell at any tree depth
#     reads the same environment. a second derivation is forbidden, because two
#     parsers of one fact drift
######################################################################

######################################################################
# the PROBES — one function per platform, each a single yes/no fact
#
# .why named functions and not an inline `elif` wall
#      an unbroken `if/elif` of raw file tests hides a wrong rung. 📜 measured
#      2026-07-30: two ec2 tests sat mid-chain, both wrong, and neither could
#      be run on its own to find out. a named probe is callable, so a box can
#      be asked one question at a time — which is how that wrong answer was
#      finally cornered.
#
#      it also puts each probe's EVIDENCE beside the probe rather than in a wall
#      of comment above the whole chain. a rung with no measurement behind it is
#      visibly a rung with no measurement behind it.
#
# .why the probes stay in THIS file
#      `rule.require.conform-to-sdk-environment` names one derivation, in one
#      place, derived once. a probe is part of that derivation, so a second file
#      would be a second home for one fact — and two homes drift. the file is
#      the abstraction; the functions are its inside.
######################################################################

######################################################################
# ⚠️ .the CLOSED SET — this repo detects exactly two platforms
#
#      `aws.ec2` (a grove) and `unix` (a laptop). that is the whole set. we own
#      every machine this runs on, so the set is not a guess about the world — it
#      is a list of boxes we can name.
#
# .why probes for `aws.lambda` and `cicd` were REMOVED, 2026-07-30
#      both existed, both were correct, and neither had a machine to run on. a
#      a provision run targets a workstation. it has never run in a lambda (read-only
#      filesystem, no shell to configure) and it has never run in ci.
#
#      so they were speculative platforms: code whose only evidence was that aws
#      publishes such envvars, never that a box HERE sets them. an unrun probe is
#      an unproven probe, and this file has already paid twice for a probe nobody
#      measured (see the two ⚠️ records below).
#
# .how to add a third platform, when one actually arrives
#      write its probe, give it a rung, and MEASURE it on that box and on one it
#      must stay silent on. e.g. for a ci runner, which is `local` tier with no
#      human — a distinction the two-platform set cannot express:
#
#        grove_env_probe_cicd() { [[ "${CI:-}" == "true" || -n "${GITHUB_ACTIONS:-}" ]]; }
#
#      until then it stays out.
######################################################################

######################################################################
# .what = is this an ec2 instance? — the FREE rungs only, no network call
#
# .why  a LADDER and not one test
#       aws's own guidance is that only the instance identity document (over
#       imds) is authoritative; every cheap signal is a heuristic:
#
#         > this method is quick, but potentially inaccurate because there's a
#         > small chance that a system that is not an EC2 instance could have a
#         > UUID that starts with these characters
#         — aws, "detect whether a host is an ec2 instance"
#
#       so no free rung is trustworthy alone, and the answer is breadth: four
#       independent facts, any one of which is enough, none of which shares a
#       failure mode with another. imds remains the authority, and it runs last
#       (`grove_env_probe_aws_ec2_imds`) because it is the only one that costs.
#
# .the evidence — measured 2026-07-30 on BOTH boxes, which is what makes each
#                 rung a DISCRIMINATOR rather than merely a true statement
#
#   | rung                | laptop (dell, pop-os) | grove-1 (r5.xlarge, nitro) |
#   |---------------------|-----------------------|----------------------------|
#   | dmi sys_vendor      | `Dell Inc.`           | `Amazon EC2`               |
#   | dmi chassis_vendor  | `Dell Inc.`           | `Amazon EC2`               |
#   | dmi bios_vendor     | `Dell Inc.`           | `Amazon EC2`               |
#   | systemd-detect-virt | `none`, exit 1        | `amazon`, exit 0           |
#   | cloud-init cloud-id | absent                | `aws`                      |
#   | hypervisor/uuid     | absent                | absent (nitro)             |
#
# .why these four and not the other five that also discriminated
#       the sweep measured nine candidates. five were rejected, each for cause:
#
#         · dns search domain (`ec2.internal`)     — a dhcp OPTION SET, and a vpc
#           can be given any domain, so a grove may legitimately not have it
#         · hostname (`ip-<private-ip>`)           — a human renames a host, and a
#           provisioner often renames it first
#         · block device model (`Amazon Elastic Block Store`) — needs `lsblk`,
#           which is a package, not a file
#         · nic driver (`ena`)                     — ena is aws's, but the check
#           is an interface walk, and an instance can carry other nics
#         · route to 169.254.169.254               — NOT a discriminator: every
#           box with a default route "has a route" to it. the laptop answered
#           `via <lan-gateway>`. a signal that fires on both boxes is not a probe
#
#       the four kept are all: readable by a NON-ROOT user, free of any network
#       call, and silent on the laptop.
#
# ⚠️ .why NEITHER uuid probe is a primary rung any more
#       both prior probes read a uuid, and on 2026-07-30 a real grove was measured
#       against them. BOTH declined, so the chain fell through to `local@unix`
#       and the box called itself a laptop:
#
#         /sys/hypervisor/uuid                      ABSENT
#         /sys/devices/virtual/dmi/id/product_uuid  mode 400, readable=no
#         /sys/class/dmi/id/sys_vendor              mode 444, "Amazon EC2"
#
#       each failed for its own unfixable reason:
#
#         · `/sys/hypervisor/uuid` is a XEN-era file. every current instance
#           family runs on nitro, which publishes no such file at all — so the
#           probe read a path that has not existed on a new box for years
#         · `product_uuid` is mode 400, ROOT-ONLY. a provision run is not root, so
#           `-r` is false no matter what the file holds. and even read as root it
#           would still decline: the `ec2` uuid prefix is xen-era too, and a nitro
#           uuid is a plain random one
#
#       aws's own doc calls this family "quick, but potentially inaccurate". the
#       xen path survives below as the LAST free rung, for a legacy instance
#       family that reports `Xen` as its sys_vendor — not as a primary test.
#
# ⚠️ .why this was the most expensive bug in the file
#       a misread platform is not cosmetic. every interactive gate in this repo
#       tests `!= local@unix` to decide whether a human is present to answer a
#       prompt (2.2.git's identity, 2.3.ssh's keygen, 5.4.gh's login). a grove
#       that calls itself `local@unix` answers "a human is here" — so all three
#       gates FAIL OPEN on the one box they were written to protect, and
#       `ssh-keygen` opens a passphrase prompt onto a duct.
#
#       the gates were correct and the detector was wrong, which is why the defect
#       survived: it hid behind `--for cloud`, whose explicit tier sidesteps the
#       inference entirely. so it only appeared on the path a grove actually takes
#       — an unattended run with no flag.
######################################################################
grove_env_probe_aws_ec2() {
  # rung 1 — the DMI VENDOR fields. mode 444, world-readable by design, and on a
  #          nitro box every one of them holds the literal string `Amazon EC2`.
  #          four fields rather than one because a future family may populate a
  #          different subset, and four reads cost what one read costs
  local f
  for f in sys_vendor board_vendor chassis_vendor bios_vendor; do
    grep -qi 'amazon ec2' "/sys/class/dmi/id/$f" 2>/dev/null && return 0
  done

  # rung 2 — the OS's OWN answer. systemd carries a hypervisor vendor table and
  #          names amazon explicitly; it is a different mechanism from the dmi
  #          read above, so it survives a dmi field rename
  if command -v systemd-detect-virt >/dev/null 2>&1; then
    [[ "$(systemd-detect-virt 2>/dev/null)" == "amazon" ]] && return 0
  fi

  # rung 3 — cloud-init's own record of WHICH cloud it ran against. this is the
  #          only rung that reports the provisioner's belief rather than the
  #          hardware's, so it holds even on a box whose dmi was masked
  if [[ -r /run/cloud-init/cloud-id ]]; then
    grep -qx 'aws' /run/cloud-init/cloud-id 2>/dev/null && return 0
  fi

  # rung 4 — the XEN-era uuid. kept only for a legacy instance family, which
  #          reports `Xen` as its sys_vendor and so answers none of the above.
  #          aws marks this family of check inaccurate; it is last for that reason
  if [[ -r /sys/hypervisor/uuid ]]; then
    grep -qi '^ec2' /sys/hypervisor/uuid 2>/dev/null && return 0
  fi

  return 1
}

######################################################################
# .what = is this an ec2 instance? — ASK AWS, at the cost of a network call
#
# .why  it is a separate probe from the free rungs
#       imds is the only method aws calls authoritative, and it is also the only
#       one that costs. a split lets the derivation place it where its cost is
#       justified — after every free probe has declined — rather than demand that
#       one function be both cheap and authoritative.
#
# ⚠️ .why the AUTHORITATIVE probe is nonetheless the LAST one, and never the first
#       imds is not guaranteed present on an ec2 box. it is the one probe here
#       that an operator can switch OFF:
#
#         > enables or disables the HTTP metadata endpoint on your instances. if
#         > you specify a value of disabled, you cannot access your instance
#         > metadata
#         — aws, `modify-instance-metadata-options --http-endpoint disabled`
#
#       and even where it is enabled, `--http-put-response-hop-limit` (default 1)
#       can put it out of reach of a container or a nested netns, and a hardened
#       ami may firewall 169.254.169.254 for non-root.
#
#       so the two halves of this ladder fail in OPPOSITE directions, which is
#       the whole reason to keep both:
#
#         · the free rungs are what aws calls inaccurate — but they cannot be
#           turned off. dmi is firmware; cloud-init's record is on disk
#         · imds is exact — but it is switchable, hop-limited, and firewallable
#
#       an ec2 box with imds disabled therefore still answers rung 1. an ec2 box
#       with masked dmi still answers imds. neither probe alone covers the other's
#       hole, and "authoritative" was never the same claim as "always present".
#
# .why  `-m 1` and not the 2s default
#       169.254.169.254 is link-local: on a real ec2 box it answered in 8ms, so
#       1s is ~100x headroom. it also caps what a laptop-over-ssh run pays to
#       notice imds is absent (measured: 0.385s to a full `local@unix` verdict).
#
# ⚠️ .why an AWS_* envvar is NOT consulted, here or anywhere
#       `AWS_REGION`, `AWS_PROFILE`, `AWS_ACCESS_KEY_ID` and friends are set by a
#       HUMAN or by the aws cli — they say "this box talks to aws", never "this
#       box IS aws". a laptop with credentials configured sets every one, so a
#       probe that read them would report `cloud` for a machine at a desk.
#
#       an envvar is a usable fact only when the PLATFORM sets it, and ec2 sits
#       on the wrong side of that line: measured on a real grove, every
#       aws-related envvar was unset. ec2 publishes none at all — which is the
#       whole answer to "can we detect ec2 by envvar?"  no. it must be asked of
#       the hardware, or of aws.
######################################################################
grove_env_probe_aws_ec2_imds() {
  command -v curl >/dev/null 2>&1 || return 1
  curl -s -m 1 -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 60" >/dev/null 2>&1
}

######################################################################
# .what = is this a DESKTOP — a machine with a screen a human is sat at?
#
# .why  = it is the one positive fact that distinguishes a laptop AT ITS OWN
#         KEYBOARD from a headless box. it declines for a laptop reached over
#         ssh, which is why the last resort below still hands out `local`
#
# ⚠️ .why it tests the VALUE of XDG_SESSION_TYPE and not merely its presence
#         `[[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}${XDG_SESSION_TYPE:-}" ]]` —
#         a non-empty test across all three concatenated — answers YES on a
#         real grove. 📜 measured 2026-07-30:
#
#           WAYLAND_DISPLAY     （unset）
#           DISPLAY             （unset）
#           XDG_SESSION_TYPE    tty        ← non-empty, so the test passed
#
#         a `tty` session is the OPPOSITE of a desktop one. so such a probe
#         names one fact and checks another, and on a headless box it claims a
#         screen.
#
#         it does not bite while `grove_env_probe_aws_ec2` answers first on
#         that box. that is the whole hazard: a wrong probe hidden behind a
#         right one. it surfaces the moment the ec2 probe declines — which is
#         what happened on 2026-07-30, and the path that ended with a
#         passphrase prompt on a duct.
#
#         found only because the probes are callable one at a time. an
#         end-to-end check of `$server` reports `cloud@aws.ec2` and passes.
######################################################################
grove_env_probe_desktop() {
  # a display socket is unambiguous: something is there to draw on
  [[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]] && return 0

  # else the session type must NAME a graphical session. `tty` must not qualify,
  # and neither must an unset value
  case "${XDG_SESSION_TYPE:-}" in
    wayland|x11|mir) return 0 ;;
  esac

  return 1
}

######################################################################
# the derivation — an ordered parser chain per attribute, first answer wins
#
# .why an envar override ahead of every inference: an inference is a guess about
#       the machine, and a human or a ci job that KNOWS must be able to say so
#       without a code change. this mirrors sdk-environment's own parser order.
######################################################################
grove_env_derive() {
  local for_flag=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --for) for_flag="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  ####################################################################
  # access — what resources may we touch?
  #
  # .why the default is `prep` and not `prod`: a provision run installs tools and
  #      writes dotfiles, and the safe default for an unlabelled machine is the
  #      shared pre-production tier, never the production one
  ####################################################################
  export GROVE_ENV_ACCESS="${GROVE_ENV_ACCESS:-prep}"
  case "$GROVE_ENV_ACCESS" in
    test|prep|prod) ;;
    *) echo "✋ GROVE_ENV_ACCESS must be test|prep|prod (got '$GROVE_ENV_ACCESS')" >&2
       echo "   └─ the values come from sdk-environment; 'dev' is not among them" >&2
       return 2 ;;
  esac

  ####################################################################
  # server — where does this run? `$tier@$platform`
  #
  # .why `--for` maps onto this rather than beside it: `--for local|cloud` is
  #      exactly `server`'s tier, so it is a cli form of one attribute, not a
  #      second axis. it names a tier only, so the platform is still inferred —
  #      a human who types `--for cloud` on an ec2 box gets `cloud@aws.ec2`
  ####################################################################
  if [[ -z "${GROVE_ENV_SERVER:-}" ]]; then
    local tier="" platform=""

    # the tier: the flag when given, else inferred
    case "$for_flag" in
      local|cloud) tier="$for_flag" ;;
    esac

    ####################################################################
    # the platform — one named probe per candidate, cheapest first
    #
    # .why this reads as a bare ladder
    #      each probe carries its own evidence and its own caveats, declared
    #      above. so this block states only the ORDER, which is the one fact a
    #      reader needs here and the one fact no single probe can hold.
    #
    # .the order, and why
    #      1. ec2      — four FREE rungs, no network call (see the probe)
    #      2. desktop  — a session envvar, free
    #      3. ec2/imds — aws's own authoritative answer, and the ONLY probe that
    #                    costs. it runs last because the two above are free, and
    #                    it runs AT ALL because it covers the one hole the free
    #                    rungs cannot: an ec2 box whose dmi does not answer
    ####################################################################
    # ⚠️ each probe names the tier that box class NATURALLY carries, and it is
    #    exported beside the server so a caller can see whether `--for` overrode
    #    it. `--for` sets only the TIER — the platform comes from a probe alone —
    #    so an override cannot produce a new box class, only a contradicted pair
    #    (`cloud@unix`, `local@aws.ec2`). the driver refuses those on an apply
    local tier_natural=""
    if grove_env_probe_aws_ec2; then
      platform="aws.ec2";  tier_natural="cloud"
    elif grove_env_probe_desktop; then
      platform="unix";     tier_natural="local"
    elif grove_env_probe_aws_ec2_imds; then
      platform="aws.ec2";  tier_natural="cloud"
    fi
    tier="${tier:-$tier_natural}"

    ####################################################################
    # ⚠️ NO FALLBACK — an undetected box is an ERROR, not a default
    #
    # .why NO last resort
    #      a closing `platform="${platform:-unix}"; tier="${tier:-local}"`
    #      silently calls a box that answered NO probe a laptop. that is
    #      `rule.forbid.failhide` in its purest form: the derivation reports
    #      success and hands back a guess.
    #
    #      and it is not a harmless guess. `local@unix` is the value every
    #      interactive gate reads as "a human is at a keyboard" — so the default
    #      for "I could not tell" is the single most dangerous of the two
    #      answers. 📜 on 2026-07-30 a real grove took exactly that line and got
    #      offered an `ssh-keygen` passphrase prompt onto a duct.
    #
    # .why a fallback is not needed at all
    #      we own every machine this runs on. the set is two: a grove and a
    #      laptop. a fallback exists to cover boxes you cannot enumerate — and
    #      there are none. so the honest response to "no probe fired" is not to
    #      pick the likelier of two; it is to say so, and name the fix.
    #
    # .what a human does about it
    #      the error names both escapes, because both are one word
    #      (`rule.require.errors-name-the-fix`). an override ahead of inference is
    #      already the contract's own parser order — this just makes it the ONLY
    #      way past an undetected box, rather than a courtesy beside a guess.
    ####################################################################
    if [[ -z "$platform" ]]; then
      echo "✋ cannot tell which machine this is — no platform probe answered" >&2
      echo "" >&2
      echo "   asked, in order:" >&2
      echo "     aws_ec2       (dmi vendor · systemd-detect-virt · cloud-init · xen uuid)  → no" >&2
      echo "     desktop       (WAYLAND_DISPLAY · DISPLAY · XDG_SESSION_TYPE)              → no" >&2
      echo "     aws_ec2_imds  (169.254.169.254, capped at 1s)                             → no" >&2
      echo "" >&2
      echo "   why this is an error and not a guess:" >&2
      echo "     a guess here would be 'local@unix', which every interactive step" >&2
      echo "     reads as 'a human is at a keyboard'. on a headless box that opens" >&2
      echo "     a prompt nobody can answer. so it refuses instead." >&2
      echo "" >&2
      echo "   fix — name the box yourself:" >&2
      echo "     GROVE_ENV_SERVER=local@unix    grove.provision   # a laptop" >&2
      echo "     GROVE_ENV_SERVER=cloud@aws.ec2 grove.provision   # a grove" >&2
      echo "" >&2
      echo "   and if this box is one we own, the probe is what is wrong, not the box." >&2
      echo "   each probe above is one command; run them by hand and read which lies." >&2
      return 2
    fi

    export GROVE_ENV_SERVER="$tier@$platform"

    # the probe's own answer, kept beside the resolved one. EMPTY when the caller
    # supplied GROVE_ENV_SERVER whole — no probe ran, so there is no natural tier
    # to compare against, and a reader must treat empty as "unknown", never as a
    # mismatch (rule.forbid.failhide)
    export GROVE_ENV_TIER_NATURAL="$tier_natural"
  fi

  case "$GROVE_ENV_SERVER" in
    local@*|cloud@*) ;;
    *) echo "✋ GROVE_ENV_SERVER must be \$tier@\$platform with tier local|cloud" >&2
       echo "   └─ got '$GROVE_ENV_SERVER'; this repo knows two: local@unix, cloud@aws.ec2" >&2
       return 2 ;;
  esac

  ####################################################################
  # commit — what code is this?
  #
  # .why it is derived at all, when no step reads it: it is what makes a run
  #      traceable. a machine provisioned from a dirty tree is a machine whose
  #      state matches no commit, and the `+` is the only record of that
  ####################################################################
  if [[ -z "${GROVE_ENV_COMMIT:-}" ]]; then
    local gitref="" hash="" dirty=""
    if hash="$(git rev-parse --short HEAD 2>/dev/null)"; then
      gitref="$(git describe --tags --exact-match 2>/dev/null \
        || git rev-parse --abbrev-ref HEAD 2>/dev/null)"
      git diff --quiet 2>/dev/null || dirty="+"
      git diff --cached --quiet 2>/dev/null || dirty="+"
      export GROVE_ENV_COMMIT="${gitref:-unknown}@${hash}${dirty}"
    else
      # a bootstrap runs before any checkout exists, so there is no commit to name
      export GROVE_ENV_COMMIT="none@none"
    fi
  fi
}

######################################################################
# the predicates — what a leaf asks
#
# .why wrapped, one place each: the contract states `server.split('@')[0]` is
#      always parseable, and a leaf should not have to know that. a second copy
#      of the split is a second place to get it wrong
######################################################################

# .what = the tier half of $server — `local` or `cloud`
grove_env_server_tier() { echo "${GROVE_ENV_SERVER%%@*}"; }

# .what = the platform half of $server — `unix` or `aws.ec2`
grove_env_server_platform() { echo "${GROVE_ENV_SERVER#*@}"; }

######################################################################
# .note = there are NO `grove_env_has_*` predicates, and that is deliberate.
#         `grove_env_has_screen` and `grove_env_has_human` were declared here
#         and removed on 2026-07-29. three reasons, each on its own sufficient:
#
#         1. they were SYNONYMS. both bodies were the identical text
#            `[[ "$GROVE_ENV_SERVER" == "local@unix" ]]` — two names for one
#            test, which is exactly what rule.forbid.domain-term-synonyms forbids.
#
#         2. each name asserted a fact it could not check. `has_screen` reads the
#            server string; it cannot see a display. so on a `local@cicd` runner —
#            local tier, no display — it answered YES. and that very case was
#            cited, in this file, as the REASON the helper existed. the name
#            claimed more than the test, which is the worst shape a predicate has.
#
#         3. they were only ever needed because applicability was PASSED (as
#            `--applies <fn>`). a bundle that declines with an early return states
#            its own condition, inline, beside the reason it declines for — so
#            there is no argument left to pass, and a named predicate has no caller.
#
#         a bundle that genuinely cannot apply reads `$server` directly:
#
#           # a gpu terminal needs a display; a cloud box has none
#           [[ "$GROVE_ENV_SERVER" == local@* ]] || return 0
#
#         and that is the EXCEPTION, not the shape. cloud and local get identical
#         bundle composition unless a bundle articulates why it cannot — see
#         `rule.require.grove-provision-bundles`.
######################################################################

# .what = a one-line account of this environment, for a run's header
grove_env_report() {
  echo "access $GROVE_ENV_ACCESS · server $GROVE_ENV_SERVER · commit $GROVE_ENV_COMMIT"
}
