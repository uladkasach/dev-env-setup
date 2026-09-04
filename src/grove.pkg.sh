#!/usr/bin/env bash
######################################################################
# the package boundary — apt, and only apt
#
# .what = `pkg_refresh` and `pkg_install <name...>`, the ONE way this repo asks
#         for a package. every ask routes through here.
#
# .why apt is an INVARIANT and not a variable
#         a debian-family box (ubuntu, pop) is the only machine this repo
#         supports — a laptop and a grove alike. that is a DECLARATION, not a
#         discovery, and it is what lets every installer read as one procedure.
#
#         the alternative is a shim over apt and dnf/yum together, on the claim
#         that a grove is "whatever AMI the account offers" and amazon linux
#         2023 is the aws default. what such a shim costs:
#
#           · a per-manager name map — one software, two names, and a bug when
#             they drifted (`imagemagick` vs `ImageMagick`: rpm names are
#             case-sensitive, so a lowercase ask read back as "absent from the
#             repos" on a box that plainly had it)
#           · a second branch in every non-apt installer — gh, the ssm plugin,
#             chsh — each its own chance to diverge
#           · an applicability decision SMUGGLED into an os map: two packages
#             mapped to `""` for "headless boxes do not need this", which is a
#             claim about the SCREEN dressed as a claim about the OS
#           · a terminfo fallback that compiled an entry by hand, because
#             `kitty-terminfo` is absent from rpm repos
#
#         the AMI is a choice, and one debian choice is cheaper than a shim
#         forever. so the constraint moves UPSTREAM — to whoever bakes the
#         image — and this repo asserts it rather than accommodates it.
#
# .why it ASSERTS rather than assumes
#         an invariant nobody checks is a wish. on a box with no apt, every
#         `pkg_install` would fail one at a time, each reported as its own absent
#         package — sixty failures that name a symptom, and the cause named
#         nowhere. so the FIRST ask fails loud, once, and names the real problem
#         (rule.require.failfast, rule.require.failloud).
#
# usage:
#   source grove.pkg.sh
#   pkg_refresh
#   pkg_install jq tree tmux
#
# guarantee:
#   - idempotent: a package already installed is read from dpkg and skipped, so
#     the ask costs no network, no lock, and NO SUDO on a re-run
#   - per-package tolerance: one absent package cannot halt the other asks; each
#     miss is named, and the ask returns non-zero once at the end
######################################################################

######################################################################
# .what = halt unless this box is debian-family
# .why  = the invariant, enforced at the boundary where it becomes concrete.
#         a package manager is exactly where "which unix is this?" stops being
#         abstract, so this is the honest place to insist
######################################################################
pkg_assert_apt() {
  command -v apt-get &>/dev/null && return 0

  echo "✋ this box has no apt-get, and this repo requires a debian-family unix" >&2
  echo "   ├─ supported: ubuntu, pop!_os — a laptop and a grove alike" >&2
  echo "   ├─ found:     $(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-an unknown distro}")" >&2
  echo "   │" >&2
  echo "   └─ fix: rebuild this box from a debian-family image. the OS is a" >&2
  echo "      DECLARATION here, not a discovery — rpm support was removed on" >&2
  echo "      2026-07-29 because a two-family shim cost a name map, a second" >&2
  echo "      branch in every installer, and a real bug when the two drifted." >&2
  echo "      for a grove, that choice belongs to whoever bakes the AMI." >&2
  return 1
}

######################################################################
# .what = the env every apt call runs under, so a package cannot ask a question
#
# ⚠️ .why this exists
#         apt hands a package's own config step to `debconf`, which by default
#         tries to OPEN A DIALOG. on a grove there is no terminal to draw it on,
#         and on 2026-07-30 a real `ssh` install printed:
#
#           debconf: unable to initialize frontend: Dialog
#           debconf: (This frontend requires a controlling tty.)
#           debconf: falling back to frontend: Teletype
#           dpkg-preconfigure: unable to re-open stdin:
#
#         `ssh` asks no question, so it fell through to a default and installed.
#         that is the LUCKY case, and it made the noise look cosmetic. a package
#         that genuinely asks — a `postfix` mail config, an `iperf3` daemon choice,
#         a kernel `needrestart` policy — reaches that same code with no tty and
#         either stalls or silently takes a default nobody chose.
#
#         `noninteractive` is the declaration that no question may be asked: every
#         package takes its default, and none opens a prompt. that is the correct
#         and only safe answer for an unattended run, which is what a grove always
#         is — and it is the same fact every other gate in this repo tests for
#         (rule.forbid.tty-as-a-proxy-for-a-human, read from the apt side).
#
# .why it is set for a LAPTOP too, where a tty does exist
#         a provision run declares a machine; it is not a place to answer a mail-relay
#         question. identical behaviour on both boxes is the whole point of
#         `rule.require.identical-bundle-composition` — a package that configures
#         itself one way on a laptop and another on a grove is exactly the drift
#         this repo removes. so the answer is the same everywhere: take the default
######################################################################
PKG_APT_ENV=(DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true NEEDRESTART_MODE=a)

######################################################################
# .what = halt unless sudo can actually obtain a credential
#
# ⚠️ .why this exists — the misdiagnosis it ends
#         `pkg_install` read every non-zero from `apt-get install` as "absent from
#         this box's repos". sudo is the most common OTHER cause, and it produced
#         the worst possible report: on 2026-07-30 a run with no tty printed
#
#           sudo: a terminal is required to read the password
#           ✋ absent from this box's repos: jq tree unzip ripgrep
#           fix: confirm each name, or enable the repo that carries it
#
#         four packages that have been in every debian repo for twenty years,
#         reported as absent, with a fix that sends a human to hunt a repo problem
#         that does not exist. the cause was printed one line above and named
#         nowhere (rule.require.errors-name-the-fix).
#
#         so the precondition is asserted ONCE, up front, exactly as
#         `pkg_assert_apt` asserts the other one — and for the same reason its
#         header already gives: an invariant nobody checks is a wish, and sixty
#         failures that each name a symptom leave the cause named nowhere.
#
# 🛑 .a TTY EXEMPTION here is WRONG, however well argued
#
#         the claim that reads well: *"a tty test is correct HERE, where it is
#         forbidden elsewhere … this is not a proxy: 'can sudo read a password?'
#         is answered by a tty because a tty is the literal mechanism sudo uses
#         … so a false read is impossible rather than merely unlikely"*.
#
#         it IS a proxy, the false read is not impossible, and it fires on the
#         one seat that matters. `prove.root-decline-bites` caught it on its
#         first run against the camper: `bundle.root.owns → rc=0` on a seat that
#         holds no sudo at all.
#
#         the flaw is one word. a tty says whether sudo can **ask**; the fact
#         worth a read is whether anyone will **reply**. a duct is tmux, and a
#         tmux pane has a tty — so on a grove the mechanism is present and the
#         human is absent, which is the precise case
#         `rule.forbid.tty-as-a-proxy-for-a-human` names.
#
# ⚠️ .the shape to watch for
#         that claim does not overlook the rule — it CITES the rule and then
#         argues its way to an exemption. an exemption that names its trigger
#         is checkable (`rule.require.exemptions-name-their-trigger`); this one
#         names a rationale instead, and a rationale cannot be tested. what
#         settles it is a probe, not a better argument.
######################################################################
######################################################################
# .what = CAN this seat write to the box, unattended? — the bare predicate
#
# .why it is split from the assert below
#         two callers want the same fact and want opposite things from it:
#
#           `pkg_assert_sudo`   — a run that MUST write; a no is fatal
#           a box-wide upsert   — a no means "the seat with root owns this",
#                                 which is a decline, not a failure
#
#         one declaration, two consumers. a fact held only inside the assert
#         leaves the second caller to either accept a fatal error or
#         re-implement the two tests — and every site that
#         re-implements a fact is a site that can drift from it
#         (`rule.require.bundle-as-sole-declaration`).
#
# ⚠️ .why a seat with NO root is normal, not broken
#         a grove has two seats. `ground` holds NOPASSWD sudo; the `camper` —
#         the seat that does the work — holds none, by design (`term=seat`).
#         so a `1` from here is the common case on the box this repo exists to
#         raise, and a bundle that treats it as a failure fails every camper
#         apply over work ground already did.
#
# exit:
#   0 = a write to the box can proceed with no human
#   1 = it cannot, and no human is present to change that
######################################################################
pkg_can_sudo() {
  # already usable with no password owed — a cached credential, or NOPASSWD.
  # this half needs no judgement: sudo itself answers it
  sudo -n true 2>/dev/null && return 0

  ####################################################################
  # 🛑 a password is owed. a TTY alone does NOT mean it can be answered —
  #    📜 measured on grove-ahbode-v20260811's camper seat, 2026-08-12
  #
  #    a bare `[[ -t 0 ]] && return 0` rests on the claim that the tty is safe
  #    HERE because it is "the literal mechanism sudo uses". that argument is
  #    wrong, and `prove.root-decline-bites` disproved it on its first run:
  #
  #      🔭 prove.root-decline-bites
  #         ├─ seat: camper
  #         ├─ sudo: this seat holds none without a password
  #         ├─ bundle.root.owns → rc=0        ← waved through
  #
  #    a duct IS tmux, and a tmux pane HAS a tty. so on the seat that does the
  #    work, over the transport this repo reaches it by, the answer was yes —
  #    and the consequence is the worst kind: every box-wide upsert would reach
  #    for root, sudo would PROMPT onto the pane, and the prompt would sit there
  #    and eat the next command sent down the duct.
  #
  # ⚠️ .the distinction that argument misses
  #    a tty answers "can sudo ASK?". it does not answer "will anyone ANSWER?".
  #    those are different questions, and only the second one matters here —
  #    which is exactly what `rule.forbid.tty-as-a-proxy-for-a-human` says, and
  #    exactly the exemption a tty test claims for itself.
  #
  # .so the tier is read too, and it is the load-bear half
  #    `local@unix` is the one tier with a human at a keyboard. `local@cicd` has
  #    a runner, `cloud@aws.ec2` has a duct — neither can answer a prompt. the
  #    tty then narrows it further, so a cron on the laptop is judged right too
  ####################################################################
  [[ "${GROVE_ENV_SERVER:-}" == "local@unix" && -t 0 ]] && return 0

  return 1
}

######################################################################
# 🛑 .why the fix-text SPLITS on the box
#
#    one list on every box would read:
#
#      · run this from a terminal, so sudo can prompt you
#      · warm the credential first, then re-run:  sudo -v
#      · on a grove, give the user NOPASSWD for apt-get in /etc/sudoers.d/
#
#    on a GROVE all three are false, and the third is harmful:
#      · a terminal changes none of it — the camper holds no sudoers entry, so
#        there is no prompt to answer
#      · there is no credential to warm, for the same reason
#      · NOPASSWD would grant the camper root-equivalent reach on the host —
#        the precise power this seat exists WITHOUT (`term=seat`)
#
#    and each is a HAND STEP, which `rule.require.one-command-provision` calls
#    a blocker in those words.
#
# 📜 `4.5.nvim` wrote this defect down on 2026-08-10 —
#
#      *"camper is structurally unprivileged BY DESIGN, so 'no terminal is
#       attached for it to ask on' points a reader at a tty when the truth is
#       this seat may never hold sudo (rule.require.errors-name-the-fix)"*
#
#    — an explanation written in place of a fix is what
#    `rule.forbid.deferred-provision-defects` forbids by name.
#
# ⚠️ .why this is a fix-text change and NOT a verdict change
#    a bundle whose SUBJECT is box-wide declines instead, via
#    `bundle.root.owns`. what reaches HERE is a caller that genuinely must
#    write and cannot — most often `pkg_install` with a package ground has
#    not installed yet. that is a real, box-level fault and deserves a ✋; it
#    simply deserves a TRUE one.
######################################################################
pkg_assert_sudo() {
  pkg_can_sudo && return 0

  echo "✋ this seat cannot write to the box, and no human is here to change that" >&2
  echo "   ├─ so EVERY package this run installs would fail, and each would be" >&2
  echo "   │  reported as its own absent package — sixty symptoms, no cause" >&2
  echo "   ├─ this box is '${GROVE_ENV_SERVER:-unknown}', seat '${USER:-unknown}'" >&2
  echo "   │" >&2

  if [[ "${GROVE_ENV_SERVER:-}" == local@* ]]; then
    echo "   └─ fix, whichever fits the box:" >&2
    echo "      · run this from a terminal, so sudo can prompt you" >&2
    echo "      · warm the credential first, then re-run:  sudo -v" >&2
    return 1
  fi

  echo "   └─ a grove has two seats, and this is the one WITHOUT sudo, by design" >&2
  echo "      · that is correct — the camper does the work; ground converges the box" >&2
  echo "      · so this is NOT a step for you: the same bundle, run on the ground" >&2
  echo "        seat, installs it box-wide. one apply per seat, and no more" >&2
  echo "      · do NOT grant this seat NOPASSWD to silence it — that is" >&2
  echo "        root-equivalent reach on the host (term=seat)" >&2
  return 1
}

######################################################################
# .what = run ANY apt-family command under the boundary's env
#
# ⚠️ .why this exists — the env was declared and then walked around
#         `PKG_APT_ENV` says no package may ask a question. it reached only the
#         two calls inside this file, and NINE call sites across the bundle tree
#         reached `sudo apt-get` / `sudo add-apt-repository` directly. an env
#         that guards two of eleven doors is a wish, not a boundary.
#
#         on 2026-08-06 that gap stalled a grove for 57 minutes. `5.8.docker`
#         called `sudo apt-get install -y docker-ce …` directly; the packages
#         installed fine and dockerd came up, then apt's post-install hook ran
#
#           sh -c -- test -x /usr/lib/needrestart/apt-pinvoke \
#                    && /usr/lib/needrestart/apt-pinvoke -m u || true
#
#         `-m u` is needrestart's INTERACTIVE mode: it draws a service-restart
#         menu and waits. a grove has no human, so it waited forever, held the
#         dpkg lock, and ate every command sent down the duct as menu input —
#         the exact failure `PKG_APT_ENV`'s `NEEDRESTART_MODE=a` was written to
#         prevent, at a door it never covered.
#
# .why a passthrough rather than one wrapper per verb
#         the bypasses are not one shape: `update`, `remove`, `install ./x.deb`,
#         and `add-apt-repository`. a wrapper per verb would grow with each new
#         need and leave the next one to bypass again. one passthrough covers
#         every verb apt has, the ones nobody has reached for yet as well.
#
# usage:
#   pkg_apt apt-get update -y
#   pkg_apt apt-get install -y ./local.deb
#   pkg_apt apt-get remove -y firefox
#   pkg_apt add-apt-repository -y ppa:keyd-team/ppa
######################################################################
######################################################################
# .what = wait, bounded, for whoever else holds the dpkg lock to finish
#
# 🛑 .why a FRESH box is the one that needs this
#         ubuntu boots `unattended-upgrades` on first boot. it takes the dpkg
#         lock for a few minutes, and `2.1.toolkit` is the first bundle to
#         install a package — so on a box built minutes ago the two collide,
#         and on a converged box they never do. that is
#         `define.provision-defect-shapes` #10: a path that runs on ONE box
#         class, at ONE moment, and is invisible every other time.
#
#         measured on grove-ahbode-v20260811, 2026-09-02, first apply of a
#         disk 20 minutes old:
#
#           E: Could not get lock /var/lib/dpkg/lock-frontend.
#              It is held by process 9221 (apt-get)
#           ✋ apt HAS these, and the install still failed: jq tree ripgrep
#
#         the box was fine, the mirror was fine, the names were fine. a second
#         apply would have passed — which is exactly what
#         `rule.require.one-command-provision` forbids: a run that needs two
#         passes is an ORDERING defect, not idempotency.
#
# ⚠️ .why not `apt-get -o DPkg::Lock::Timeout` alone
#         that option covers apt-get and dpkg. `add-apt-repository` goes through
#         this same funnel and takes no such flag, so the wait belongs HERE,
#         ahead of every verb, rather than as an argument only some accept.
#
# ⚠️ .why it returns 0 when the wait elapses
#         this is not the check — the caller is. if the lock is still held, the
#         apt call below runs, fails on its own, and `pkg_install` reports the
#         real cause with its real fix-text. to halt here would replace a
#         precise error with a vaguer one (`rule.forbid.failhide` inverted).
######################################################################
PKG_APT_LOCK_WITHIN="${PKG_APT_LOCK_WITHIN:-300}"

pkg_await_apt_lock() {
  command -v fuser >/dev/null 2>&1 || return 0

  local waited=0 announced=0
  while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
    [[ "$waited" -ge "$PKG_APT_LOCK_WITHIN" ]] && {
      echo "   ⚠️ the dpkg lock is STILL held after ${PKG_APT_LOCK_WITHIN}s — the apt call runs anyway," >&2
      echo "      so its own error names the cause" >&2
      return 0
    }

    # announce ONCE, and only if we actually wait — a silent stall reads as a hang
    [[ "$announced" -eq 0 ]] && {
      echo "   • another process holds the dpkg lock (unattended-upgrades, on a fresh box) — waited up to ${PKG_APT_LOCK_WITHIN}s"
      announced=1
    }

    sleep 5
    waited=$((waited + 5))
  done

  [[ "$announced" -eq 1 ]] && echo "   • the dpkg lock is free after ${waited}s — apt continues"
  return 0
}

pkg_apt() {
  pkg_assert_apt || return 1
  pkg_assert_sudo || return 1
  pkg_await_apt_lock
  sudo env "${PKG_APT_ENV[@]}" "$@"
}

# .what = refresh the package index
pkg_refresh() {
  pkg_apt apt-get update -y
}

######################################################################
# .what = is this package already installed, per dpkg's own record?
#
# .why  = so `pkg_install` can ask whether its goal ALREADY HOLDS before it
#         asserts the machinery needed to change it. this is a read of dpkg's
#         local database: no network, no sudo, no lock
#
# .note `db:Status-Status` is the middle field of dpkg's status triple, and the
#       only one that answers this question. a package that was removed but kept
#       its config reads `deinstall ok config-files` — `Status-Status` is
#       `config-files`, not `installed`, so a purge-and-reinstall is correctly
#       treated as absent
######################################################################
pkg_present() {
  [[ "$(dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null)" == "installed" ]]
}

######################################################################
# .what = install packages, one at a time, and report each outcome
#
# .why  = a single batch call halts the whole run when ONE package is absent from
#         the box's repos. per-package tolerance keeps parity partial instead of
#         absent, and names each miss so a human can act on it
#
# ⚠️ .why the ALREADY-PRESENT split comes before the sudo assert
#         a seat with no sudo on a box that already holds the package used to
#         fail here — and the failure was pure ceremony, because the state the
#         upsert wanted was already true.
#
#         measured 2026-08-10 on the camper seat of a grove. the seat split gives
#         `ground` NOPASSWD sudo and the camper none, by design (`term=seat`).
#         ground had already installed `ssh` box-wide, so `ssh` was present and on
#         PATH — and `2.3.ssh.provision.upsert` still halted with "sudo needs a
#         password". its `configure` phase, which wants NO sudo and only writes an
#         ssh key into `$HOME`, was then skipped by the phase chain — so a seat
#         could not get a keypair because of a package it already had.
#
#         ⇒ so the question is asked in the right ORDER: what is already true is
#           read first (a free, sudo-free dpkg read), and the machinery to CHANGE
#           the box is asserted only when there is a change left to make. an
#           upsert whose goal already holds does no work and needs no privilege
#           (`rule.require.idempotent-install-procedures`).
#
# ⚠️ .why a FAILED install is not the same claim as an ABSENT package
#         to read every non-zero from `apt-get install` as "absent from this
#         box's repos" names one cause among many, and the others are more
#         common: a held dpkg lock, no route to the mirror, a stale index, a full
#         disk, or sudo (which `pkg_assert_sudo` catches up front).
#
#         so the ask is SPLIT from the claim. after a failed install, apt is asked
#         whether the name has a candidate at all — a read-only question that wants
#         no sudo. no candidate is the only evidence that supports "absent from the
#         repos"; a candidate that failed to install is a DIFFERENT defect and gets
#         a different fix. under one shared message the wrong one prints for a
#         package that has shipped in debian for twenty years
######################################################################
pkg_install() {
  pkg_assert_apt || return 1

  # what is already true, read before any privilege is asked for
  local name wanted=()
  for name in "$@"; do
    if pkg_present "$name"; then
      echo "   • $name ✔ (already installed)"
      continue
    fi
    wanted+=("$name")
  done

  # every ask already holds — so there is no box to change, and no sudo to want
  [[ ${#wanted[@]} -eq 0 ]] && return 0

  # a real install remains, so NOW the machinery to change the box must be there
  pkg_assert_sudo || return 1

  local absent=() broken=() cand
  for name in "${wanted[@]}"; do
    if pkg_apt apt-get install -y "$name"; then
      echo "   • $name ✔"
      continue
    fi

    # the install failed. ask apt WHY before a cause is claimed — a name with no
    # candidate is genuinely absent; a name with one broke for another reason
    cand="$(apt-cache policy "$name" 2>/dev/null | awk -F': ' '/Candidate:/{print $2}')"
    if [[ -z "$cand" || "$cand" == "(none)" ]]; then
      absent+=("$name")
    else
      broken+=("$name")
    fi
  done

  if [[ ${#absent[@]} -gt 0 ]]; then
    echo "   ✋ absent from this box's repos: ${absent[*]}" >&2
    echo "      ⇒ apt offers no candidate version for these, so no amount of" >&2
    echo "        retry installs them — the name or the repo list is wrong" >&2
    echo "      fix: confirm each name, or enable the repo that carries it" >&2
  fi

  if [[ ${#broken[@]} -gt 0 ]]; then
    echo "   ✋ apt HAS these, and the install still failed: ${broken[*]}" >&2
    echo "      ⇒ so this is NOT an absent package: apt offers a candidate" >&2
    echo "        version for each. the cause is above, in apt's own output" >&2
    echo "      ⇒ the usual causes: another process holds the dpkg lock, no" >&2
    echo "        route to the mirror, or a stale index" >&2
    echo "      fix: read apt's output above, then re-run. for a stale index:" >&2
    echo "        sudo apt-get update" >&2
  fi

  [[ ${#absent[@]} -eq 0 && ${#broken[@]} -eq 0 ]]
}
