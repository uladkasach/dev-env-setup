#!/usr/bin/env bash
######################################################################
# .what = the bootstrap: get this repo onto a bare machine, then hand
#         off to the installer
#
# .why  = a bare machine has no repo, so it cannot run
#         `src/grove.provision._.sh` — the entrypoint lives INSIDE the repo
#         it needs. this file breaks that circle: it is the one artifact
#         a human fetches standalone, and it is small enough to read
#         before it runs.
#
# usage (from a bare machine):
#   curl -fsSLo /tmp/grove.bootstrap.sh https://raw.githubusercontent.com/uladkasach/dev-env-setup/main/grove.bootstrap.sh
#   less /tmp/grove.bootstrap.sh          # read it first. that is the point.
#   bash /tmp/grove.bootstrap.sh --for local --mode apply
#
# .note = every flag is passed straight through to grove.provision._.sh.
#         this file reads none of them, so it can never drift from the
#         upgrader's own flag set.
#
# .note = it is STANDALONE on purpose. it cannot source
#         `grove.pkg.sh`, because that file lives in the repo this
#         one exists to fetch. so it carries its own copy of TWO things
#         from that file, and both duplications are unavoidable:
#
#           1. the apt ASSERT      — `command -v apt-get`, step 1
#           2. the apt ENV         — `PKG_APT_ENV`, step 2
#
#         a copy of an ASSERT is a far cheaper duplicate than a copy of a
#         package-manager DETECT: an assert has one branch and one message,
#         so the two copies can only agree. the detect it replaced had
#         three candidates and a per-family install case, which is three
#         ways for this file to drift from the installer it hands off to.
#
# ⚠️ .this note claimed the assert was the ONLY duplication until 2026-08-13
#         it was not a miscount — it was a MISSING copy. the env was never
#         carried across, so this file's one apt call ran bare and could hang
#         on a needrestart menu with no human to answer it. the paragraph above
#         argued correctly that an assert is safe to duplicate, and that
#         argument silently justified the state where the far more important
#         half was absent. see step 2 for the full account.
#
# guarantee:
#   - idempotent: a re-run converges; a repo already present is reused
#   - anonymous: clones over HTTPS, so it needs no credential and no
#     ssh key, which at bootstrap time does not exist yet
#   - fails loud, and names the fix
######################################################################
set -uo pipefail

REPO_URL="https://github.com/uladkasach/dev-env-setup.git"
REPO_DIR="${DEV_ENV_SETUP_DIR:-$HOME/git/more/dev-env-setup}"

echo "🐢 lets get you set up"
echo ""
echo "🐚 bootstrap"
echo "   ├─ repo: $REPO_URL"
echo "   └─ into: $REPO_DIR"
echo ""

######################################################################
# 1. the os — a DECLARED invariant, asserted here first
#
# this repo supports a debian-family unix (ubuntu, pop) and only that.
# the same assert lives in `grove.pkg.sh`, which is not on the
# machine yet — so this is the EARLIEST point a wrong image is visible,
# and the cheapest place to say so: before a clone, before a package,
# before the ten minutes an installer would spend to reach the same halt.
######################################################################
if ! command -v apt-get &>/dev/null; then
  echo "✋ this machine has no apt-get, and this repo requires a debian-family unix" >&2
  echo "" >&2
  echo "   ├─ supported: ubuntu, pop!_os — a laptop and a grove alike" >&2
  echo "   ├─ found:     $(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-an unknown distro}")" >&2
  echo "   └─ why:       the os is a DECLARATION here, not a discovery. rpm" >&2
  echo "                 support was removed on 2026-07-29, because a second" >&2
  echo "                 family meant a second answer to every package" >&2
  echo "                 question — and the two answers drifted" >&2
  echo "" >&2
  echo "   fix: build this box from a ubuntu image. the constraint belongs to" >&2
  echo "        whoever chooses the image, not to this bootstrap" >&2
  exit 1
fi
echo "▶ os: debian-family ✔ (apt-get found)"

######################################################################
# 2. git — a bare server image carries none
######################################################################
if command -v git &>/dev/null; then
  echo "   ✔ git already present; skipped"
else
  echo "▶ install git"

  ####################################################################
  # 🛑 .why the env, and what its absence cost — the SAME 57 minutes twice
  #
  #    this line was `sudo apt-get update -y && sudo apt-get install -y git`,
  #    bare, and it is the FIRST apt call a machine built from scratch ever
  #    makes. `grove.pkg.sh` documents precisely what a bare one does:
  #
  #      on 2026-08-06 `5.8.docker` called `sudo apt-get install -y docker-ce`
  #      directly. the packages installed, then apt's post-install hook ran
  #      needrestart in `-m u` — its INTERACTIVE mode. it drew a service-restart
  #      menu and waited. a grove has no human, so it waited forever, held the
  #      dpkg lock, and ate every command sent down the duct as menu input.
  #
  #    that was fixed across the bundle tree by `PKG_APT_ENV` and `pkg_apt`.
  #    this file is the ONE artifact outside that tree — standalone by design,
  #    because it runs before the repo exists — so the fix never reached it.
  #
  # ⚠️ .why it went unseen for so long
  #    the branch is unreachable on any box that HAS git, which is every box
  #    this repo has ever converged. only a machine built from scratch runs it,
  #    and that is the one machine nobody re-tests
  #    (`rule.require.one-command-provision`, `.from scratch`).
  #
  # ⚠️ .why this is a SECOND duplication, where the header claims one
  #    the header says the apt ASSERT is the only copy here, and it argued that
  #    an assert is cheap to duplicate because it has one branch and one message.
  #    that argument is sound and it was applied to the wrong half: the assert
  #    was carried across and the ENV — the part that keeps apt from a question —
  #    was left behind. a copy of a guarantee is worth more than a copy of a
  #    check, because a check that drifts reports, and a guarantee that drifts
  #    HANGS.
  #
  #    these three names must stay identical to `PKG_APT_ENV` in `grove.pkg.sh`.
  ####################################################################
  BOOTSTRAP_APT_ENV=(DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true NEEDRESTART_MODE=a)
  sudo env "${BOOTSTRAP_APT_ENV[@]}" apt-get update -y \
    && sudo env "${BOOTSTRAP_APT_ENV[@]}" apt-get install -y git

  if ! command -v git &>/dev/null; then
    echo "✋ git install reported success but git is still absent" >&2
    echo "   fix: install it by hand, then re-run — bash $0 $*" >&2
    exit 1
  fi
  echo "   ✔ git installed"
fi

######################################################################
# 3. the repo — https, so no credential is needed
#
# .note = the clone is ANONYMOUS by design. an ssh clone would need a key
#         that install_ssh has not created yet, plus a human to paste its
#         pubkey into github — neither of which exists at bootstrap time
######################################################################
# .a src has TWO legitimate provenances, and this step must name which
#
#   CLONED — fetched from origin. refreshed by `git.repo.pull`
#   PUSHED — rsync'd from a laptop worktree by `grove.push`. refreshed by
#            another push. this is DELIBERATE: `grove.push` exists so a change
#            can be proven on a grove BEFORE it is merged, which is the whole
#            reason a grove is a useful verification surface
#
# so a git-less src is NOT a defect to repair. it is a branch under test, and a
# bootstrap that demands a clone would delete the very work it was sent to run.
# what a bootstrap owes is an honest NAME for what it found.
#
# .the message this replaces
#         an earlier draft tested `[[ -d "$REPO_DIR/src" ]]` — "does it look
#         like the repo?" — so a pushed src reported "repo already present", its
#         `git pull` failed for want of a repo, and the else-branch announced
#         "left as-is (local commits or changes present)". that named a cause
#         (local commits) which cannot exist without the repo the check had just
#         failed to find. the state was fine; the REPORT was the defect.
if [[ -d "$REPO_DIR/.git" ]]; then
  echo "▶ repo present at $REPO_DIR (provenance: cloned)"
  # freshen, but never clobber: --ff-only refuses rather than rewrite.
  # a pushed src laid over a clone shows up here as a dirty tree, and the
  # refusal is correct — a pull must never overwrite work under test
  #
  ####################################################################
  # 🛑 the SAME two bounds the clone below carries, for the same two hangs
  #
  # 📜 .this line had NEITHER until 2026-08-15, and the clone 60 lines below had
  #    BOTH. that is the sharper half of the exemption lesson already recorded
  #    there: a sweep can be widened to reach an exempt FILE and still read only
  #    the call somebody thought of. the sweep that found the clone asked about
  #    a STALL, so it had no question to put to a pull.
  #
  # ⇒ a guarantee is owed to every SIBLING call, not to the one that taught it
  #   (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.12 / q11).
  #
  # 🛑 .NO READER asks this line ANY of its three questions — 2026-09-01
  #    `wire.verify` is the one check that names this file, and it holds it for
  #    its FETCH-SHAPE rules alone. the `-k 30 300` bound, the
  #    `GIT_TERMINAL_PROMPT=0`, and the transport floor below are each held by
  #    this comment and by nobody's ✋.
  #
  #    ⚠️ the CLONE's floor does have one (`scan_git_floor_is_copied`), and that
  #      is the trap: a reader that covers the call 30 lines down reads, at a
  #      glance, as cover for this one. it is not — it compares the clone line
  #      alone, by name.
  #
  #    ⚠️ so do NOT cite a play by name here as cover. a dead pointer reads
  #      exactly like a live clamp, which is how one becomes the ground for a
  #      fresh claim in the repo's own voice
  #      (`gotcha.my-own-note-became-my-evidence`). name a check only after you
  #      have run `rhx play.run --list` and seen it.
  #
  # ⚠️ and the prompt is the worse of the two here. this branch runs on a box
  #    that ALREADY holds a clone, so it is the re-bootstrap path a human takes
  #    over a duct — and a duct is tmux, so an ask sits on the pane and eats
  #    every command sent after it (`rule.forbid.tty-as-a-proxy-for-a-human`)
  ####################################################################
  ####################################################################
  # ⚠️ the transport floor here is NARROWER than the clone's, deliberately
  #
  #    the clone below writes `protocol.allow=never` + `protocol.https.allow`,
  #    because it fetches a url this file hardcodes as https. a PULL reads its
  #    remote from `.git/config` on the box, and `5.10.repos` tells a human to
  #    clone this repo over `git@github.com:` — so the clone's floor at THIS
  #    call site is a deny of ssh.
  #
  #    measured 2026-09-01, git 2.43.0, against a dead local port:
  #      `-c protocol.allow=never -c protocol.https.allow=always`  ssh → `fatal:
  #        transport 'ssh' not allowed`                        ← breaks the pull
  #      `-c protocol.http.allow=never`                         ssh → reaches the
  #        transport; https → reaches it; http → `fatal: transport 'http' not
  #        allowed`                                            ← bites, and only
  #                                                              where it should
  #
  #    ⇒ one guarantee, two call sites, opposite correct values. a copy of the
  #      clone's flags would have looked like consistency and been an outage
  #      (`gotcha.a-check-that-cries-wolf-gets-silenced`, q7).
  #
  # 🛑 what this buys is the REDIRECT hop, not the typed url. the remote is
  #    already on disk, so its scheme is not an attacker's to write — but git
  #    hands `protocol.*.allow` to libcurl as its redirect set, so an https
  #    remote that is answered with a 302 to `http://` is refused here.
  ####################################################################
  if GIT_TERMINAL_PROMPT=0 timeout -k 30 300 \
       git -c protocol.http.allow=never \
           -C "$REPO_DIR" pull --ff-only &>/dev/null; then
    echo "   ✔ updated to latest"
  elif [[ -n "$(git -C "$REPO_DIR" status --porcelain)" ]]; then
    echo "   • left as-is — the tree is dirty (a pushed src, or local edits)"
    echo "     that is expected while a branch is under test on this machine"
  else
    echo "   • left as-is — the pull could not fast-forward"
  fi
elif [[ -d "$REPO_DIR" ]]; then
  echo "▶ repo present at $REPO_DIR (provenance: pushed)"
  echo "   • no .git — this src arrived by 'grove.push', not by clone"
  echo "     it refreshes by another push, never by git.repo.pull"
  echo "     to switch it to a clone, move it aside first:"
  echo "       mv $REPO_DIR $REPO_DIR.pushed.\$(date +%s) && bash $0 $*"
else
  echo "▶ clone $REPO_URL"
  mkdir -p "$(dirname "$REPO_DIR")"

  ####################################################################
  # 🛑 .why the bound is written out HERE, rather than sourced
  #
  #    every other fetch in this repo goes through `src/grove.web.sh`. this one
  #    cannot: it is the call that FETCHES that file, so the boundary does not
  #    exist on this box yet. so the guarantee is copied, and only the guarantee.
  #
  # ⚠️ .why a bare `git clone` here was the worst instance of all
  #    this is the FIRST act a fresh box performs, over a network nobody has
  #    tested yet, with no human attached. and git over http hangs on two axes:
  #
  #      1. a STALL — git's transport is libcurl, which by default has NO
  #         total-time bound at all, so a transfer that goes quiet waits forever
  #      2. a CREDENTIAL PROMPT — github answers 401 when it rate-limits an
  #         unauthenticated ip, and a nat'd box shares that ip with every other
  #         box behind it. git then asks for a username and waits, on a machine
  #         with nobody to answer
  #
  # 📜 this ran unbounded for as long as it existed, and it survived every sweep
  #    that fixed its twelve siblings — because those sweeps scanned `src/`, and
  #    this file is the tree's one exempt artifact. an artifact exempt from a
  #    RULE is usually also exempt from the SWEEP that enforces it
  #    (`rule.require.every-function-has-a-driver`, `.the one exemption`).
  #
  #    `wire.verify` holds this file in its subject BY NAME, for that reason
  #    alone (`subject_holds`, at the top of its rules). ⚠️ what that buys is
  #    the FETCH-SHAPE rules — a bare `curl`, a `| sh`, an unchecked
  #    `web_fetch`. it puts no question to the BOUND on the call below.
  ####################################################################
  # ⚠️ `-k 30`, because a bare `timeout N` sends only SIGTERM — a REQUEST. a
  #    child that blocks or ignores TERM outlives it, and `timeout` then waits
  #    for that child without end, so the bare form adds a process to the hang
  #    rather than a stop to it. measured 2026-08-14: a TERM-deaf child under
  #    `timeout 3` still ran at 15s; under `timeout -k 2 3` it died at 5s.
  #
  #    this line was the LAST bare one in the repo, and it survived the sweep
  #    of the other 45 for the very reason recorded above: the sweep read
  #    `src/`, and this file is not in `src/`.
  #
  #    🛑 it is STILL read by no check. the `-k 30 600` here is held by this
  #      comment alone, so a later edit that drops it reddens no reader.
  ####################################################################
  # ⚠️ the TRANSPORT FLOOR, copied literally — `WEB_GIT_FLOOR` is the one
  #    declaration, and this file CANNOT source it: it runs before the repo that
  #    holds it exists. that is the same exemption recorded above, and it buys
  #    the same second exemption nobody granted: one fact, two holders, free to
  #    drift with no signal (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9).
  #
  # ✔ .THIS half now has a reader — `scan_git_floor_is_copied`, in `wire.verify`
  #    it sources `WEB_GIT_FLOOR` out of the boundary, extracts the clone line
  #    below, and names any flag the declaration holds and this copy does not.
  #    proven both directions: green on the untouched pair, red on a cut flag,
  #    and the pass PRINTS the flags it compared rather than a bare ✔.
  #
  #    ⚠️ it reads THIS clone and not the `git … pull` above, deliberately.
  #      `protocol.allow=never` would refuse an ssh remote, and `5.10.repos`
  #      tells a human to clone over ssh — one pattern, two call sites, and the
  #      correct value is opposite in each (q7).
  #
  # 🛑 .and the floor is the ONLY half that is read. the bound and the prompt on
  #    this same call still have no reader, so do not read the ✔ above as cover
  #    for the line as a whole.
  #
  #    `protocol.allow=never` + one `always` is how git spells curl's
  #    `--proto '=https' --proto-redir '=https'`. git hands the policy down to
  #    libcurl as its REDIRECT protocol set, so it covers the hop as well as the
  #    typed url — measured 2026-09-01 against a local 302 redirector; the full
  #    table sits at `WEB_GIT_FLOOR` in `src/grove.web.sh`.
  #
  # ⚠️ .which half is LIVE here, and which is depth
  #    `$REPO_URL` is a hardcoded https literal at :51, so the first-request half
  #    guards a url no attacker writes — it is depth, and it holds if that line
  #    is ever edited or templated.
  #
  #    the REDIRECT half is the live one. no hop is written in this file, github
  #    does redirect a renamed repo, and this is the FIRST fetch a fresh box
  #    makes — over a network nobody has tested, with no human attached. an
  #    https url walked down to http by a hop we never see is precisely the shape
  #    this line must refuse, and it had no floor at all.
  ####################################################################
  clone_rc=0
  GIT_TERMINAL_PROMPT=0 \
  timeout -k 30 600 \
    git -c protocol.allow=never \
        -c protocol.https.allow=always \
        -c http.sslVersion=tlsv1.2 \
        -c http.lowSpeedLimit=1024 \
        -c http.lowSpeedTime=60 \
        clone "$REPO_URL" "$REPO_DIR" </dev/null || clone_rc=$?

  if [[ $clone_rc -ne 0 ]]; then
    ##################################################################
    # ⚠️ a killed clone leaves a PARTIAL dir, and the branch that sent us here
    #    is `else` on `[[ -d "$REPO_DIR" ]]` — so a re-run would find that
    #    carcass, take the "provenance: pushed" branch, and tell a human to move
    #    a push aside that was never a push. remove it, so a re-run refetches
    ##################################################################
    if [[ -d "$REPO_DIR" ]]; then
      rm -rf "$REPO_DIR"
      echo "   • removed the partial clone at $REPO_DIR" >&2
    fi

    echo "✋ could not clone the repo" >&2
    echo "" >&2
    if [[ $clone_rc -eq 124 ]]; then
      echo "   why: it TIMED OUT after 600s — it stalled, or the far end never" >&2
      echo "        spoke. that is a wire fault, not a bad url and not a" >&2
      echo "        credential. a retry is the right first move" >&2
    else
      echo "   why: the clone is anonymous over https, so this is a network" >&2
      echo "        or dns problem rather than a credential one" >&2
      echo "        ⇒ unless git said 'could not read Username' — that is a 401," >&2
      echo "          usually an unauthenticated rate limit on this box's egress" >&2
    fi
    echo "" >&2
    echo "   fix: confirm the machine can reach github, then re-run —" >&2
    echo "     curl -fsSI --max-time 20 https://github.com" >&2
    exit 1
  fi
  echo "   ✔ cloned"
fi

######################################################################
# 4. hand off to the entrypoint
######################################################################
ENTRYPOINT="$REPO_DIR/src/grove.provision._.sh"
if [[ ! -f "$ENTRYPOINT" ]]; then
  echo "✋ the repo landed but its entrypoint is absent" >&2
  echo "" >&2
  echo "   looked for: $ENTRYPOINT" >&2
  echo "   fix: the clone may be partial — remove it and re-run —" >&2
  echo "     rm -rf $REPO_DIR && bash $0 $*" >&2
  exit 1
fi

echo ""
echo "🥥 handoff to the installer"
echo "   └─ $ENTRYPOINT $*"
echo ""

# exec, so the installer owns the process and its exit code reaches the caller
exec bash "$ENTRYPOINT" "$@"
