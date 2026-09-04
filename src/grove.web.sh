#!/usr/bin/env bash
######################################################################
# the wire boundary — every fetch this repo makes over the network
#
# .what = the ONE way this repo pulls bytes off the internet. two transports,
#         one bound, one integrity check:
#           `web_fetch <url> [--into <path>] [--within <seconds>]`   — http
#           `git_clone <url> <dir> --at <commit> [--within <sec>]`   — git
#           `web_verify_sha256 --file <path> --sha256 <hash>`        — integrity
#
# .why  = a fresh box DOWNLOADS EVERYTHING. sixteen bundles reach the wire on a
#         first apply, over twenty calls:
#
#           6 apt gpg keys   gh, docker, codium, 1password, dropbox, keyd
#           3 debs           ssm plugin, dropbox, protonvpn
#           2 installers     rustup, fnm — each piped to a shell
#           2 clones         tpm, tfenv
#           1 zip            the aws cli
#           5 archives       nvim, kitty (+ its .sig and its release key), usql,
#                            starship, the nerd font
#           1 bootstrap      the clone of THIS repo, before any of the above
#
#         on a converged box not one of them runs. so the wire is the single
#         biggest act a FIRST apply performs and a second apply does not, which
#         makes it the least-tested surface here.
#
#         ⚠️ the list above is enumerated from the source, never recalled — and
#         a count in prose has drifted here TWICE.
#         📜 2026-08-13: the header said "twelve bundles" over thirteen listed
#         items, and a grep found four more. 📜 2026-08-31: the gpg-key row read
#         4 and named four while `dropbox` had been a fifth for weeks, and
#         `keyd` made six. a count in prose is a SECOND declaration of a fact
#         the tree already holds, and no check reddens the day it drifts — so
#         re-derive before you trust it:
#           grep -rn 'web_verify_gpg_fingerprints --file' src/grove.provision/
#           grep -rln 'sources.list.d/.*\.list' src/grove.provision/
#
# 🛑 .what this boundary does NOT cover, and why the `.what` above is scoped
#         "the ONE way this repo pulls bytes" is true of the fetches this repo
#         MAKES ITSELF. it is not true of every byte a first apply pulls, and the
#         difference is worth a statement rather than a reader's inference:
#
#           apt      — 6 declared sources; apt fetches indexes and debs itself
#           flatpak  — 1 declared remote, 4 app ids; flatpak fetches them itself
#           pnpm/npm — the registry, on a global install
#
#         each of those clients has its own transport, its own retries, and its
#         own bounds, so a route through `web_fetch` is neither available nor
#         desirable. what they do NOT carry is a check that the names this repo
#         DECLARES still exist upstream — and those names rot exactly like a url.
#
#         ⇒ so that gap is covered by PLAYS rather than by this boundary:
#           `prove.apt-sources-serve`    — the apt sources, end to end
#           `prove.flathub-apps-serve`   — the remote + its app ids
#           `prove.apt-key-pins-bite`    — the pinned repo keys
#
#         ⚠️ each reads its SET from the tree, so no count is written here —
#           a number would be the second declaration named above
#
#         ⚠️ do not "fix" this by a wrapper around apt or flatpak. the fetch is
#           theirs; only the DECLARATION is ours, and a declaration is checked by
#           a read, not by a transport (`define.provision-defect-shapes`,
#           `.the DARKEST corner`).
#
# 🛑 .the defect this boundary exists to remove — an UNBOUNDED fetch
#         every one of those twelve read `curl -fsSL <url>`, bare. that is not
#         bounded, and the gap is specific:
#
#           --connect-timeout   defaults to 300s   → a DEAD host costs 5 minutes
#           --max-time          defaults to NONE   → a STALLED transfer waits
#                                                    forever
#
#         a dead host is the benign case: it fails, eventually. the STALL is the
#         one that breaks the bar — tcp connects, bytes start, the far end goes
#         quiet, and curl waits with infinite patience. no timeout fires, no error
#         prints, and `grove.provision` never returns.
#
#         `rule.require.one-command-provision` asks for a run that is
#         NON-INTERACTIVE and DETERMINISTIC. an unbounded fetch is neither: there
#         is no human to notice the hang, and whether the run finishes depends on
#         the weather on somebody else's network.
#
# ⚠️ .why a grove is the WORST box for this, not the best
#         a grove sits behind a NAT instance. a stalled or half-open flow through
#         a nat is the ordinary failure of that topology, not an exotic one — and
#         a grove is also the box with no human to notice a hang and no terminal
#         to interrupt it. so the least-tested surface meets its likeliest fault
#         on the box that can least report it.
#
# 🛑 .why the bound is a SPEED guard and not `--max-time` alone
#         a `--max-time` large enough for the aws cli zip (~60MB) on a slow link
#         is too large to bound much of use; one small enough to be useful would
#         kill a legitimately slow download. either way it measures the wrong
#         quantity.
#
#         the hazard is not "this took a long time". it is "this STOPPED and did
#         not say so". `--speed-limit` + `--speed-time` measure exactly that:
#         abort when throughput sits below 1KB/s for 60s. a slow-but-live download
#         is untouched; a stall dies in a minute.
#
#         `--max-time` is kept as a BACKSTOP, for the pathological server that
#         dribbles just above the floor forever. it is generous on purpose — the
#         speed guard is the real bound, and the backstop exists so the bound has
#         no hole.
#
# .why RETRIES, when the point is to fail fast
#         determinism cuts both ways. a bound turns an infinite hang into a
#         failure; a retry stops a one-second network blip from the failure of a
#         whole provision. a fresh box makes twelve fetches, so at any per-fetch
#         failure rate the run's failure rate is twelve times worse — retries are
#         what keep "run it once" honest on a real network.
#
# usage:
#   source grove.web.sh
#   web_fetch https://example.com/x.tgz --into "$tmp/x.tgz"   # to a file
#   web_fetch https://example.com/key.gpg | sudo dd of=/etc/... status=none
#   web_fetch https://example.com/big.zip --into "$p" --within 1800
#   git_clone https://github.com/org/tool "$HOME/.tool"
#
# guarantee:
#   - BOUNDED: it returns, always. a stall dies in ~60s, a dead host in ~20s
#   - NON-INTERACTIVE: stdin is /dev/null, so no prompt can wait on it
#   - https only, tls>=1.2, ON EVERY REDIRECT HOP — not the first request alone
#   - fails loud, names the url, and tells a stall apart from a 404
#
# 🛑 .the ONE exemption — IMDS, and do NOT route it through here
#         three calls still read `curl` directly, all to `169.254.169.254`:
#         `5.6.aws/configure.upsert.sh`, `5.6.aws/configure.verify.sh`, and
#         `grove.env.sh`. every one is correct as it stands, for four reasons
#         that all fire at once:
#
#           1. it is LINK-LOCAL, not the internet. there is no dns, no nat, and
#              no far end that can stall — the hazard this boundary exists for
#              does not reach it
#           2. it is `http://`, necessarily. the `--proto '=https'` floor above
#              would REFUSE it outright, so a conversion breaks aws detection on
#              every ec2 box
#           3. it needs `-X PUT` and a token header. `web_fetch` takes a url and
#              nothing else, on purpose — a boundary that grows a method flag is
#              a curl wrapper, not a boundary
#           4. its bound is 3s and must stay 3s. that number is a DETECTOR: a
#              non-ec2 box has no one at that address, and the whole point is to
#              learn so fast that a laptop pays nothing to ask. `web_fetch`'s
#              600s backstop would hang every local run for ten minutes
#
#         ⇒ so a bare `curl` to a link-local address is not a miss this boundary
#           forgot. it is a different act. leave it.
######################################################################

######################################################################
# .what = the bound, declared ONCE
#
# .why  = twelve call sites, one declaration. twelve copies of a flag set is the
#         two-lists defect this repo keeps re-learning
#         (`rule.require.identical-bundle-composition`) — and a drifted TIMEOUT
#         is the worst kind, because the copy that lost its bound looks identical
#         to the copy that kept it right up until it waits forever
######################################################################
WEB_FETCH_BOUND=(
  --connect-timeout 20    # a dead host fails in 20s, not curl's default 300s
  --speed-limit 1024      # below 1KB/s …
  --speed-time 60         # … for 60s straight = a stall, so abort
  --retry 3               # a blip must not fail a twelve-fetch provision
  --retry-delay 2
  --retry-connrefused     # a service still on its way up is a retry, not a defeat

  ####################################################################
  # the transport floor — https only, tls 1.2 or better, ON REDIRECTS TOO
  #
  # ⚠️ .why `--proto-redir` is the load-bear half, not `--proto`
  #      `--proto` governs the FIRST request only. this repo fetches with `-L`,
  #      and most of these urls exist to redirect — a github release url lands on
  #      objects.githubusercontent.com, `/latest/download/` lands on a tag. so
  #      without the redir clause an https url may be walked down to plaintext
  #      http by a hop we never wrote and never see.
  #
  # 📜 rustup's published one-liner ships `--proto '=https' --tlsv1.2` and no
  #    redir clause; `5.2.rust` carried that pair verbatim, and it was the ONE
  #    site of twelve with any transport floor at all. hoisted here, so what one
  #    site happened to inherit from its vendor now covers all twelve — which is
  #    what a boundary is for
  ####################################################################
  --proto '=https'
  --proto-redir '=https'
  --tlsv1.2
)

######################################################################
# .what = the same transport floor, spelled for GIT. declared once
#
# .why  `WEB_FETCH_BOUND` carries three guarantees, and `git_clone` copied two:
#       the speed bound and the prompt control. the FLOOR had no copy at all, so
#       a clone accepted a plaintext url — and a plaintext redirect hop — that a
#       curl of that very url refuses. the claim above it said a clone "carries
#       every hazard `web_fetch` exists for", which was true of the hazards and
#       untrue of the answers.
#
# 🛑 .git DOES have `--proto` AND `--proto-redir`. it spells them as one policy
#    measured 2026-09-01, git 2.43.0, against a local 302 redirector:
#
#    | the arm                                       | what git did |
#    |-----------------------------------------------|--------------|
#    | `http://`  url, no floor                      | passed, died at dns |
#    | `http://`  url, floor on                      | `transport 'http' not allowed` — before one packet |
#    | `https://` url, floor on                      | passed, died at dns |
#    | http → 302 → `https://`, https NOT permitted  | `Protocol "https" not supported or disabled in libcurl` |
#    | the SAME hop, https permitted                 | followed, died at dns |
#
#    row 4 is the load-bear one. git hands `protocol.*.allow` down to libcurl as
#    its REDIRECT protocol set, so a refusal at a hop arrives in libcurl's own
#    words — verbatim what `curl --proto-redir` prints. one config pair is
#    therefore BOTH halves, and it held at git's default
#    `http.followRedirects=initial` and at `true` alike.
#
#    row 5 is the green half: a PERMITTED redirect is untouched, so this floor is
#    no false ✋ on a url that legitimately moves
#    (`gotcha.a-check-that-cries-wolf-gets-silenced`).
#
# ⚠️ .the TLS half is carried here and has NOT been seen to bite
#    `http.sslVersion` is git's documented handle on `CURLOPT_SSLVERSION` — the
#    same knob `--tlsv1.2` sets, and a minimum rather than an exact match. it is
#    carried for that reason. what was MEASURED is only that git accepts the key;
#    a server pinned below tls 1.2 is what would prove it, and this box has none.
#    so it is stated as a residue rather than claimed as a guarantee — the whole
#    defect this block repairs was a floor whose two proven halves would have
#    read as three (`rule.require.trust-but-verify`).
#
# ⚠️ .a NON-https url is now REFUSED, deliberately
#    `never` denies every transport, then one line permits exactly one. an `ssh://`
#    or `file://` clone therefore fails loudly rather than quietly. both call sites
#    are `https://github.com/…`, and a floor that a caller can widen by accident
#    is not a floor.
######################################################################
WEB_GIT_FLOOR=(
  -c protocol.allow=never          # deny every transport …
  -c protocol.https.allow=always   # … then permit exactly one, redirects included
  -c http.sslVersion=tlsv1.2       # tls 1.2 or better, as `--tlsv1.2` (see ⚠️ above)
)

######################################################################
# .what = fetch one url, bounded, to a file or to stdout
#
# .why  the `--into` split
#       most callers want a file. three want a pipe (`| sudo dd`, `| sh`), because
#       the WRITE half needs a privilege the fetch half must not have — see
#       `5.4.gh`'s note on why `sudo curl -o` is the wrong shape
######################################################################
web_fetch() {
  local url="" into="" within=600

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --into)   into="$2";   shift 2 ;;
      --within) within="$2"; shift 2 ;;
      -*)
        echo "   ✋ web_fetch: unknown flag '$1'" >&2
        return 2 ;;
      *)
        if [[ -n "$url" ]]; then
          echo "   ✋ web_fetch takes ONE url (got '$url' and '$1')" >&2
          return 2
        fi
        url="$1"; shift ;;
    esac
  done

  if [[ -z "$url" ]]; then
    echo "   ✋ web_fetch: no url given" >&2
    return 2
  fi

  local rc=0
  if [[ -n "$into" ]]; then
    curl -fsSL "${WEB_FETCH_BOUND[@]}" --max-time "$within" "$url" -o "$into" </dev/null || rc=$?
  else
    curl -fsSL "${WEB_FETCH_BOUND[@]}" --max-time "$within" "$url" </dev/null || rc=$?
  fi
  [[ $rc -eq 0 ]] && return 0

  ####################################################################
  # ⚠️ the message must SEPARATE a stall from a 404
  #
  #    they are one exit code away and their fixes share no step. before this
  #    boundary existed every fetch reported "usually no network", which is
  #    right for 28 and wrong for 22 — and a reader who trusts it goes and
  #    checks a network that was fine
  ####################################################################
  case $rc in
    28)
      echo "   ✋ the fetch TIMED OUT (curl 28) — $url" >&2
      echo "      ⇒ the transfer stalled: it sat below 1KB/s for 60s, or ran past" >&2
      echo "        ${within}s in total. that is a wire fault, NOT an absent file" >&2
      echo "      ⇒ a grove reaches the wire through its nat, so a stalled flow" >&2
      echo "        there is the ordinary failure of that path — retry first" >&2
      ;;
    22)
      echo "   ✋ the server REFUSED the fetch (curl 22, an http >=400) — $url" >&2
      echo "      ⇒ the wire is fine; the url is wrong, moved, or needs a credential" >&2
      echo "      ⇒ a pinned version that was yanked upstream reads exactly like this" >&2
      ;;
    6)
      echo "   ✋ the host could not be RESOLVED (curl 6) — $url" >&2
      echo "      ⇒ dns, not the far end. check the box's resolver first" >&2
      ;;
    *)
      echo "   ✋ the fetch failed (curl $rc) — $url" >&2
      echo "      read why: curl -fsSL --max-time ${within} '$url' -o /dev/null" >&2
      ;;
  esac
  return 1
}

######################################################################
# .what = the SECOND road off this box — a package registry, bounded
#
# 🛑 .why a registry needed its own boundary, measured 2026-08-14
#       `web_fetch` bounds every call that pulls BYTES from a url. it says not
#       one word about the calls that ask a REGISTRY for a package, and those
#       are the calls a fresh box makes most.
#
#       `prove.tool-defaults-are-bounded` pointed each at a listener that
#       accepts a connection and then stays silent forever:
#
#         | tool     | it returned            | attempts |
#         |----------|------------------------|----------|
#         | gh       | 10s                    | 1        |
#         | aws      | 182s                   | 3        |
#         | npm      | never, cut at 240s     | 2        |
#         | pnpm     | never, cut at 240s     | 5        |
#         | corepack | never, cut at 240s     | 1        |
#         | flatpak  | never, cut at 240s     | 10       |
#
#       so FOUR of six hold a dead endpoint past four minutes, with no human,
#       on the one run nobody re-tests. that is the hang this boundary removes.
#
# ⚠️ .why TWO numbers and not one — a total alone is the wrong shape here
#       a `timeout 300` around `pnpm install -g` is a bound, and it is also a
#       REGRESSION: a fresh box on a thin link makes hundreds of small requests
#       that all move bytes, and a flat total kills the honest case along with
#       the stall. that is the trade this repo refused on 2026-08-13 while the
#       numbers above were still unmeasured.
#
#       so the two layers cap different halves, exactly as
#       `timeout 20 ssh -o ConnectTimeout=5` does:
#
#         · REQUEST — one stalled request dies fast, and a wholly dead registry
#                     therefore fails on its FIRST request rather than at the
#                     total. an install that keeps bytes in motion never reaches it
#         · TOTAL   — the backstop. it is what makes the call RETURN, which is
#                     the whole claim (`term=bound._.choice._.md`: a cutoff on
#                     one phase is not a bound)
#
# ⚠️ .why the total is 900s and not a tighter number
#       `5.3.brains` installs claude-code, codex, rhachet, and the declastruct
#       chain in four calls. 900s at even 200KB/s is ~180MB, which is past what
#       any of them weighs — so a healthy install cannot reach it, and a wedged
#       duct cannot outlast it.
#
# 🛑 .the blast radius, and what guards it
#       these flags are shared by every registry call a fresh box makes. ONE
#       flag this box's npm does not accept fails EVERY install, before any of
#       them reaches the wire — and no converged box can see it, because no
#       converged box installs. `prove.tool-defaults-are-bounded` arm 4 parses
#       each wrapper for exactly that reason, the way the wire play's arm 2b
#       does for `WEB_FETCH_BOUND`
######################################################################
WEB_REGISTRY_REQUEST_SECONDS="${WEB_REGISTRY_REQUEST_SECONDS:-60}"
WEB_REGISTRY_TOTAL_SECONDS="${WEB_REGISTRY_TOTAL_SECONDS:-900}"

######################################################################
# 🛑 .the GRACE, and why a total without one is not a bound at all
#
#    `timeout N cmd` sends **SIGTERM** at N. SIGTERM can be caught, blocked, or
#    ignored — and a package manager mid-transaction routinely does exactly
#    that, to avoid a half-written store. when the child refuses, `timeout`
#    does not give up: it WAITS, and the caller waits with it, forever.
#
#    ⇒ so a bare `timeout` states a bound and enforces a request
#
# .measured on grove-ahbode-v20260811, 2026-08-14
#    `prove.timeouts-kill-what-they-cut`, against a child that ignores TERM:
#
#      timeout 3 <deaf child>        → STILL RAN at 15s. the bound did not bite
#      timeout -k 2 3 <deaf child>   → ended at 5s, rc=137. SIGKILL cannot be
#                                      caught, blocked, or ignored
#
# .what it had already cost, before it was named
#    `prove.tool-defaults-are-bounded` arm 4 ran
#    `WEB_REGISTRY_TOTAL_SECONDS=20 web_flatpak remote-ls` at a listener built
#    never to answer. every read of the source says 20s. it held the grove's
#    duct for ~60 MINUTES, and the play's printed rows stop one line above it.
#
#    ⇒ the boundary written to keep a stall off the duct could not itself end
#      a stall. the wrapper was correct in every respect but this one flag
#
# ⚠️ the grace is generous on purpose. TERM is still sent first and is still
#    the polite path, so a well-behaved tool cleans up and exits long before
#    the KILL is reached — the grace is only ever spent by a child that
#    refused, and for a package manager 30s is ample to unwind a transaction
######################################################################
WEB_REGISTRY_GRACE_SECONDS="${WEB_REGISTRY_GRACE_SECONDS:-30}"

######################################################################
# ⚠️ the request bound is appended AFTER the caller's args, on purpose. npm and
#    pnpm both read a config flag in that position; neither accepts one before
#    the subcommand. a flag in the wrong slot is not a soft failure — it is an
#    "unknown option" that fails the install
######################################################################
web_pnpm() {
  timeout -k "$WEB_REGISTRY_GRACE_SECONDS" "$WEB_REGISTRY_TOTAL_SECONDS" \
    pnpm "$@" --fetch-timeout "$(( WEB_REGISTRY_REQUEST_SECONDS * 1000 ))"
}

web_npm() {
  timeout -k "$WEB_REGISTRY_GRACE_SECONDS" "$WEB_REGISTRY_TOTAL_SECONDS" \
    npm "$@" --fetch-timeout "$(( WEB_REGISTRY_REQUEST_SECONDS * 1000 ))"
}

######################################################################
# ⚠️ corepack and flatpak get the TOTAL alone — neither exposes a per-request
#    cutoff to set. that is a weaker guarantee and it is stated rather than
#    hidden: a thin-link install of a large flatpak may hit 900s where a
#    per-request bound would have let it through.
#
#    ⇒ the two are still worth the total, because the alternative measured
#      above is not "slower" — it is "does not return"
######################################################################
web_corepack() {
  timeout -k "$WEB_REGISTRY_GRACE_SECONDS" "$WEB_REGISTRY_TOTAL_SECONDS" corepack "$@"
}

######################################################################
# ⚠️ flatpak is the MEASURED instance of the deaf child, not a hypothetical
#    one: this exact wrapper, given a 20s total and a dead endpoint, held a
#    duct for ~60 minutes on 2026-08-14. the `-k` above is what ends it
######################################################################
web_flatpak() {
  timeout -k "$WEB_REGISTRY_GRACE_SECONDS" "$WEB_REGISTRY_TOTAL_SECONDS" flatpak "$@"
}

######################################################################
# .what = `web_tempdir <label>` — a PRIVATE, unguessable dir to land a fetch in
#
# 🛑 .why a fixed `/tmp/<name>` is a local privilege escalation on a grove
#
#    measured on grove-ahbode-v20260811, 2026-08-13
#    (`diagnose.shared-tmp-on-a-two-seat-box`):
#
#        /tmp = drwxrwxrwt root:root   (1777)
#        seats that share it: ubuntu(1000), ground(1001), camper(1002)
#
#    a fixed, guessable name in that directory serves ten upsert phases —
#    `/tmp/nvim-install`, `/tmp/aws-cli-install`, and eight more — and FOUR of
#    those are then handed to root:
#
#        sudo tar -xzf /tmp/nvim-install/<tarball> -C /opt
#        sudo /tmp/aws-cli-install/aws/install
#        apt-get install /tmp/session-manager-plugin.deb     ← maintainer
#        apt-get install /tmp/<dropbox|protonvpn>.deb          procedures as root
#
#    the sticky bit does NOT close this. sticky stops one seat from DELETION of
#    another seat's file; it does not stop a seat from CREATION of a name first,
#    and it does not stop that seat from a later write to a file it owns. so:
#
#      1. `camper` (the seat that runs the work, and so the seat an attacker
#         lands on) creates `/tmp/nvim-install/` first, world-writable
#      2. `ground` runs the same bundle. its `rm -rf /tmp/nvim-install` CANNOT
#         remove a directory it does not own out of a sticky parent, so the
#         guard that looks like a reset is a no-op
#      3. ground's fetch writes the tarball INTO camper's directory
#      4. between that write and `sudo tar`, camper — who owns the path —
#         swaps the file
#      5. root extracts camper's archive into /opt, and /opt/nvim's binary is
#         then symlinked onto PATH for every user
#
#    that is unprivileged → root, on the FIRST apply, on every grove. and it is
#    invisible to every converged box, because a converged box runs no fetch
#    (`gotcha.a-check-that-cries-wolf-gets-silenced`).
#
# .what this returns
#    a fresh `mktemp -d` under /tmp: mode 0700 and a random suffix, so no other
#    seat can pre-claim the name and none can read or write inside it.
#
# ⚠️ .why it is `web_*` though it touches no network
#    every caller is a fetch site — this is where a fetch LANDS. it sits beside
#    `web_fetch` so the two are read together and no site invents its own path
#    (`rule.require.identical-bundle-composition`).
#
# .note a leaked dir is swept by `1.8.tmpfiles`, which already owns /tmp
#       hygiene. that is why this does not install a global trap: a phase that
#       returns early leaks one dir, and the bundle that owns /tmp reclaims it
#
# ⚠️ .the TS twin — `genTempDir`, in `ehmpathy/test-fns`
#    one policy, two implementations, and neither named the other until
#    2026-08-30. both reduce to "ask the OS for a private dir", so the drift
#    risk is low — but an unnamed twin is a twin nobody re-reads together
#    (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9).
#
#    | | `web_tempdir` | `genTempDir` |
#    |---|---|---|
#    | serves | a bundle phase, on a box | a jest process, in a repo |
#    | extras | none — a label and a mode check | clone-a-fixture, auto-prune of >1hr dirs |
#
# 🛑 .do NOT replace this with a CLI bin from that package
#    it was proposed on 2026-08-30 and refused on an ORDERING constraint, not a
#    preference: `4.5.nvim` and `4.3.2.emulator` call this, and node arrives in
#    `5.1.node`. a section-4 bundle cannot depend on a bin that section 5
#    installs (`rule.require.bundles-own-their-dependencies`).
#
#    ⇒ and there is no capability to gain. `mktemp -d` is POSIX, ships in
#      coreutils, defaults to 0700, and generates the suffix. a node CLI would
#      be strictly later, strictly slower, and would add a failure mode
#      (`node absent`) where this has none.
######################################################################
web_tempdir() {
  local label="${1:-bundle}"
  local dir

  if ! dir="$(mktemp -d "/tmp/grove.${label}.XXXXXXXX" 2>/dev/null)"; then
    echo "   ✋ could not make a private temp dir for '$label'" >&2
    echo "      ⇒ /tmp may be full or read-only. a fetch has nowhere safe to" >&2
    echo "        land, and a fixed name is not an acceptable fallback" >&2
    return 1
  fi

  # mktemp already makes it 0700; this states the guarantee rather than assume
  # the implementation, since the whole point of this helper is that mode
  if ! chmod 700 "$dir" 2>/dev/null; then
    rm -rf "$dir"
    echo "   ✋ could not make $dir private (chmod 700 failed)" >&2
    return 1
  fi

  printf '%s\n' "$dir"
}

######################################################################
# .what = `web_verify_sha256 --file <path> --sha256 <hash>` — the ONE way this
#         repo proves a downloaded artifact is the artifact upstream published
#
# .why  a BOUND is not an INTEGRITY check, and this file shipped only the first
#       `web_fetch` guarantees the bytes arrive, and arrive in finite time. it
#       says not one word about WHOSE bytes they are. tls proves you reached the
#       host over an encrypted channel; it does not prove the host served what
#       upstream published, and it is silent about a cdn, a mirror, or a
#       compromised release account (`rule.require.verify-binary-downloads`).
#
# ⚠️ .why it lives HERE and not copied into each caller
#       three bundles hand-rolled this check before this function existed —
#       `4.5.nvim`, `4.3.2.emulator`, `2.6.starship` — each with its own message
#       and its own cleanup. that is three declarations of one rule, free to
#       drift, which is the two-lists defect this repo keeps killing
#       (`rule.require.identical-bundle-composition`). one function, one message.
#
# .why it accepts the `sha256:` prefix
#      `rule.require.verify-binary-downloads` names ONE preferred source for the
#      hash, and it is `gh api … --jq '… .digest'`, whose output reads
#      `sha256:24a54aa4…`. a helper that refused that form would make every
#      caller hand-strip it, and a hand-strip is a place to get it wrong. take
#      the value exactly as the named authority emits it.
#
# ⚠️ .why it does NOT delete the file on mismatch
#      the caller owns the temp dir and already `rm -rf`s it on every failure
#      path. a second owner of one artifact is the defect
#      `rule.forbid.two-writers-on-one-artifact` names — so this reports, and
#      the caller disposes.
#
# guarantee:
#   - it FAILS on a mismatch; it never warns and continues (`rule.forbid.failhide`)
#   - it fails on an absent file rather than read a mismatch as a pass
######################################################################
web_verify_sha256() {
  local file="" want=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file)   file="$2"; shift 2 ;;
      --sha256) want="$2"; shift 2 ;;
      *)
        echo "   ✋ web_verify_sha256: unknown argument '$1'" >&2
        return 2 ;;
    esac
  done

  # take `sha256:abc…` or a bare `abc…`, so a value pasted from `gh api` works
  want="${want#sha256:}"

  if [[ -z "$file" || -z "$want" ]]; then
    echo "   ✋ web_verify_sha256: needs --file AND --sha256" >&2
    return 2
  fi

  if [[ ! -f "$file" ]]; then
    echo "   ✋ web_verify_sha256: no file at $file" >&2
    echo "      ⇒ an absent file is a FAILED check, never a passed one — a fetch" >&2
    echo "        that landed no bytes must not read as an artifact that matched" >&2
    return 1
  fi

  local got
  if ! got="$(sha256sum "$file" | awk '{print $1}')"; then
    echo "   ✋ web_verify_sha256: could not hash $file" >&2
    return 1
  fi

  if [[ "$got" == "$want" ]]; then
    return 0
  fi

  echo "   ✋ INTEGRITY CHECK FAILED — $file" >&2
  echo "      expected: $want" >&2
  echo "      received: $got" >&2
  echo "      ⇒ do NOT extract, run, or install these bytes. two causes, and" >&2
  echo "        they want opposite repairs:" >&2
  echo "        · the pin is STALE — upstream published a new build under the" >&2
  echo "          same url. bump the version AND the hash in one edit" >&2
  echo "        · the bytes are WRONG — a mirror, cdn, or release account served" >&2
  echo "          something upstream did not publish. that is the case this" >&2
  echo "          check exists for, and it is not a bump" >&2
  return 1
}

######################################################################
# .what = `web_verify_gpg_fingerprints --file <key> --fpr <a> [--fpr <b> …]`
#         — the ONE way this repo proves a downloaded gpg key is the key it
#         meant to trust
#
# 🛑 .why an apt key is the HIGHEST-radius artifact this repo fetches
#    a key is small, public, and dull, so it reads as harmless. it is the
#    opposite: apt verifies EVERY package from that source against it, forever.
#    swap the key and root installs whatever the attacker signs, on this box and
#    on every box built after — and each of those installs reports a clean
#    signature check, because the check is against the swapped key.
#
#    ⇒ a tarball's hash pin protects ONE download. a key's fingerprint pin
#      protects every package that source will ever serve.
#
# 🛑 .why the check is SET EQUALITY and not "contains"
#    measured 2026-08-13 on grove-ahbode-v20260811: github's keyring carries
#    TWO primary keys, both uid `GitHub CLI`. so "does it contain the expected
#    fingerprint?" is the obvious check and it is broken — an attacker serves a
#    keyring holding the expected key AND their own, the check passes, and apt
#    now trusts both. the set of primaries must EQUAL the pinned set.
#
# ⚠️ .why only PRIMARY fingerprints are compared
#    `gpg --with-colons` emits an `fpr` line for the primary AND one per
#    subkey, in the same column, with no marker — so a pin taken from a casual
#    read is as likely to name a subkey. a subkey rotates far more often than a
#    primary, so such a pin goes green today and breaks on upstream's next
#    routine rotation, which reads as a compromise and is not one.
#
# .why it is FAIL-CLOSED on an absent gpg
#    with no gpg the read yields an empty set, an empty set never equals a
#    non-empty pin, and the function fails. that is the correct direction: a box
#    that cannot check a key must not install one (`rule.forbid.failhide`).
#
# guarantee:
#   - the extant keystore is UNTOUCHED — `--show-keys` reads without an import,
#     so no third-party key is trusted as a side effect of a check
######################################################################
web_verify_gpg_fingerprints() {
  local file=""
  local -a want=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      # `${2^^}` upper-cases the pin, because gpg emits upper — so a lowercase
      # value pasted from a vendor's docs compares equal rather than fail on case
      --file) file="$2"; shift 2 ;;
      --fpr)  want+=("${2^^}"); shift 2 ;;
      *)
        echo "   ✋ web_verify_gpg_fingerprints: unknown argument '$1'" >&2
        return 2 ;;
    esac
  done

  if [[ -z "$file" || ${#want[@]} -eq 0 ]]; then
    echo "   ✋ web_verify_gpg_fingerprints: needs --file AND at least one --fpr" >&2
    return 2
  fi

  if [[ ! -f "$file" ]]; then
    echo "   ✋ web_verify_gpg_fingerprints: no key file at $file" >&2
    return 1
  fi

  if ! command -v gpg >/dev/null 2>&1; then
    echo "   ✋ gpg is absent, so this key cannot be checked — refusing to trust it" >&2
    echo "      ⇒ a box that cannot verify a key must not install one; an" >&2
    echo "        unverified apt anchor is trusted for every package after it" >&2
    echo "      fix: rhx grove.provision --what 2.1.toolkit --mode apply" >&2
    return 1
  fi

  ####################################################################
  # read the PRIMARY fingerprints — `fpr` belongs to whichever `pub` or `sub`
  # preceded it, so the context is tracked rather than assumed
  ####################################################################
  local -a got=()
  mapfile -t got < <(
    gpg --show-keys --with-colons "$file" 2>/dev/null | awk -F: '
      /^pub:/ { ctx = "pub" }
      /^sub:/ { ctx = "sub" }
      /^fpr:/ { if (ctx == "pub") print toupper($10) }
    '
  )

  local got_set want_set
  got_set="$(printf '%s\n'  "${got[@]}"  | sort)"
  want_set="$(printf '%s\n' "${want[@]}" | sort)"

  if [[ "$got_set" == "$want_set" ]]; then
    return 0
  fi

  echo "   ✋ KEY FINGERPRINT MISMATCH — $file" >&2
  echo "      expected exactly these primary key(s):" >&2
  printf '        %s\n' "${want[@]}" >&2
  if [[ ${#got[@]} -eq 0 ]]; then
    echo "      received: no primary key at all — gpg read this file and found none" >&2
  else
    echo "      received:" >&2
    printf '        %s\n' "${got[@]}" >&2
  fi
  echo "      ⇒ do NOT install this key. it is the trust anchor for every" >&2
  echo "        package apt will take from that source, so a wrong key here is" >&2
  echo "        not one bad install — it is every future one, each with a clean" >&2
  echo "        signature check against the wrong anchor" >&2
  echo "      ⇒ an EXTRA key is as bad as a wrong one: the pin is a set, so a" >&2
  echo "        keyring holding the right key plus another still fails, and" >&2
  echo "        that is deliberate" >&2
  echo "      ⇒ if upstream genuinely rotated, source the new fingerprint from" >&2
  echo "        their published documentation — never from the download you are" >&2
  echo "        trying to verify" >&2
  return 1
}

######################################################################
# .what = `web_verify_gpg_signature --file <artifact> --sig <detached-sig>
#          --key <public-key> --fpr <fingerprint>` — prove an artifact was
#         SIGNED by a pinned key
#
# .why it is a SEPARATE function from `web_verify_gpg_fingerprints`
#      the two answer different questions, and the difference is the whole point:
#
#        · `…_fingerprints` asks: is this KEY FILE the key I meant to trust?
#        · `…_signature`    asks: was this ARTIFACT signed by that key?
#
#      the second CALLS the first, because a signature check against an
#      unverified key proves only that the bytes and the key agree — which an
#      attacker who supplies both can arrange trivially.
#
# 🛑 .why a sha256 pin does NOT make this redundant, and is in fact weaker
#    a hash pin is version-locked: it verifies exactly ONE artifact, and goes
#    stale the moment the version bumps. a signature verifies whatever upstream
#    signed, so the pin here is the KEY — a long-lived anchor that stays valid
#    across every future version bump.
#
#    ⇒ this is the `.the checks, best to worst` table's top row, and aws is the
#      one vendor in this tree that publishes what it takes to reach it
#      (`rule.require.verify-binary-downloads`).
#
# 🛑 .why GNUPGHOME is EPHEMERAL and never the caller's
#    `gpg --import` into `$HOME/.gnupg` would leave a third-party key trusted on
#    the box as a side effect of a CHECK — and it would then be trusted by every
#    later gpg call the human makes. so a private GNUPGHOME is created, used,
#    and removed. the box's own keystore is neither read nor written.
#
# 🛑 .why that private GNUPGHOME holds EXACTLY ONE key
#    `gpg --verify` returns 0 for a good signature from ANY key it knows. so a
#    keystore with several keys answers "somebody I know signed this", which is
#    not the question asked. with exactly one key present, a good signature can
#    only have come from the pinned key, and the check means what it says.
#
# .why it is FAIL-CLOSED on an absent gpg
#    same direction as the fingerprint check: a box that cannot verify a
#    signature must not run the installer it would have verified
#    (`rule.forbid.failhide`).
#
# guarantee:
#   - the caller's `$HOME/.gnupg` is never read and never written
#   - a good signature from an UNPINNED key fails, because that key was never
#     imported at all
######################################################################
web_verify_gpg_signature() {
  local file="" sig="" key="" fpr=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file) file="$2"; shift 2 ;;
      --sig)  sig="$2";  shift 2 ;;
      --key)  key="$2";  shift 2 ;;
      --fpr)  fpr="$2";  shift 2 ;;
      *)
        echo "   ✋ web_verify_gpg_signature: unknown argument '$1'" >&2
        return 2 ;;
    esac
  done

  if [[ -z "$file" || -z "$sig" || -z "$key" || -z "$fpr" ]]; then
    echo "   ✋ web_verify_gpg_signature: needs --file, --sig, --key and --fpr" >&2
    return 2
  fi

  local absent=""
  [[ -f "$file" ]] || absent="$file"
  [[ -f "$sig"  ]] || absent="${absent:+$absent, }$sig"
  [[ -f "$key"  ]] || absent="${absent:+$absent, }$key"
  if [[ -n "$absent" ]]; then
    echo "   ✋ web_verify_gpg_signature: absent file(s) — $absent" >&2
    return 1
  fi

  if ! command -v gpg >/dev/null 2>&1; then
    echo "   ✋ gpg is absent, so this signature cannot be checked" >&2
    echo "      ⇒ the artifact is NOT run. a box that cannot verify a signature" >&2
    echo "        must not execute the bytes it would have verified" >&2
    echo "      fix: rhx grove.provision --what 2.1.toolkit --mode apply" >&2
    return 1
  fi

  ####################################################################
  # 1. the KEY must be the pinned key, BEFORE it is used to judge the artifact
  #
  # without this, an attacker who serves an artifact, a signature, AND a key
  # passes trivially — all three agree, and all three are theirs
  ####################################################################
  web_verify_gpg_fingerprints --file "$key" --fpr "$fpr" || return 1

  ####################################################################
  # 2. a private GNUPGHOME, removed whatever the verdict turns out to be
  ####################################################################
  local gpghome
  gpghome="$(web_tempdir gpghome)" || return 1
  chmod 700 "$gpghome" 2>/dev/null || true

  local rc=0
  if ! GNUPGHOME="$gpghome" gpg --batch --quiet --import "$key" 2>/dev/null; then
    echo "   ✋ could not read the pinned public key — $key" >&2
    rm -rf "$gpghome"
    return 1
  fi

  GNUPGHOME="$gpghome" gpg --batch --verify "$sig" "$file" 2>/dev/null || rc=$?
  rm -rf "$gpghome"

  if (( rc == 0 )); then
    return 0
  fi

  echo "   ✋ SIGNATURE CHECK FAILED — $file" >&2
  echo "      the pinned key did NOT sign these bytes" >&2
  echo "      key: $fpr" >&2
  echo "      ⇒ do NOT run, extract, or install this artifact. one of three" >&2
  echo "        statements is true, and each is a reason to stop:" >&2
  echo "          · the bytes were altered between upstream and this box" >&2
  echo "          · the signature is for a DIFFERENT version than the file" >&2
  echo "          · upstream rotated its key, and this pin is now stale" >&2
  echo "      ⇒ to tell them apart, re-fetch both and check whether the version" >&2
  echo "        in the url matches the version in the signature's filename" >&2
  return 1
}

######################################################################
# .what = `git_clone <url> <dir> --at <commit> [--within <seconds>]`, the ONE
#         way this repo clones a repo for a provision
#
# .why  a clone is a FETCH, so it carries every hazard `web_fetch` exists for
#       two bundles clone during an upsert — tpm (`2.8.tmux`) and tfenv
#       (`5.7.terraform`) — and neither ships a debian package, so a clone is
#       their documented install. both read `git clone --depth 1 <url> <dir>`,
#       bare, which is unbounded in exactly the way the twelve curls were.
#
# ⚠️ .why a bare `git clone` is WORSE than a bare curl, not merely equal
#       curl at least fails eventually on a dead host (300s). git over http can
#       hang on TWO axes a curl call cannot:
#
#         1. a STALL, same as curl — git's http transport IS libcurl, so it
#            inherits the same infinite patience for a transfer that goes quiet
#         2. a CREDENTIAL PROMPT — git asks for a username on a 401, and on a
#            grove there is no human to answer, so it waits forever with the
#            terminal it was handed
#
#       axis 2 has no curl analogue here, because `web_fetch` closes stdin. and
#       it is not hypothetical for these two urls: a public repo answers 401 the
#       moment github rate-limits an unauthenticated ip, which a nat'd grove
#       shares with every other box behind it.
#
# .why the speed guard is set through `http.lowSpeedLimit` and not a flag
#      git exposes no `--max-time`. it does expose libcurl's speed guard as
#      config, so the SAME two numbers `WEB_FETCH_BOUND` uses are handed to git
#      through `-c` — one declaration of the bound, two transports
#      (`rule.require.identical-bundle-composition`)
#
# .why `timeout` on top
#      the speed guard covers the transfer. it does not cover a server that
#      accepts the connection and never speaks at all, nor the dns lookup. the
#      external `timeout` is the same generous backstop `--max-time` is for
#      curl — and unlike the speed guard it also bounds git's own local work
#
# 🛑 .why `--at <commit>` is MANDATORY, not optional
#       both call sites read `clone --depth 1 <url> <dir>`, which lands whatever
#       the default branch points at THE MOMENT IT RUNS. two applies a week
#       apart install different code from the same checkout, so an unpinned
#       clone breaks the bar's own DETERMINISTIC clause outright
#       (`rule.require.one-command-provision`) — and it is an unverified fetch
#       besides (`rule.require.verify-binary-downloads`).
#
#       so the pin is not a flag a caller may forget. an omitted `--at` is
#       refused, because a default of "whatever is on the tip today" is exactly
#       the defect, and a pit of success cannot have the defect as its default.
#
# .why a COMMIT SHA counts as the integrity check for a repo
#      git addresses every object by the hash of its content, and verifies that
#      hash on checkout. so a commit sha IS a content pin: to serve different
#      code under the same sha is to find a sha1 preimage, and github runs
#      sha1dc collision detection on top. that is the same guarantee
#      `web_verify_sha256` gives a tarball, supplied by the transport itself.
#
# ⚠️ .why the clone is NOT `--depth 1` once a pin is present
#      `--depth 1` fetches the tip of the default branch and no other commit, so
#      the pinned sha is usually absent from what it landed. a full clone of a
#      few megabytes is the honest cost of a pin, and both subjects here are
#      small. a shallow fetch of one sha depends on a server-side setting we do
#      not control, which is a silent failure waiting on somebody's config
#      change — so this takes the path that cannot half-work
#      (`rule.require.solve-at-cause`).
#
# guarantee:
#   - BOUNDED on both axes: a stall dies in ~60s, and the whole clone in $within
#   - NON-INTERACTIVE: `GIT_TERMINAL_PROMPT=0` turns a credential ask into a
#     clean failure rather than a wait, and stdin is /dev/null besides
#   - FLOORED: https only, on the typed url AND on every redirect hop, via
#     `WEB_GIT_FLOOR` — measured both directions. ⚠️ its tls clause is carried
#     and unproven; that residue is stated at the array, never claimed here
#   - PINNED: the tree left on disk is the declared commit, or there is no tree
######################################################################
git_clone() {
  local url="" dir="" at="" within=600

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --at)     at="$2"; shift 2 ;;
      --within) within="$2"; shift 2 ;;
      -*)
        echo "   ✋ git_clone: unknown flag '$1'" >&2
        return 2 ;;
      *)
        if   [[ -z "$url" ]]; then url="$1"
        elif [[ -z "$dir" ]]; then dir="$1"
        else
          echo "   ✋ git_clone takes ONE url and ONE dir (got a third: '$1')" >&2
          return 2
        fi
        shift ;;
    esac
  done

  if [[ -z "$url" || -z "$dir" ]]; then
    echo "   ✋ git_clone: needs a url AND a target dir" >&2
    return 2
  fi

  if [[ -z "$at" ]]; then
    echo "   ✋ git_clone: --at <commit> is required — $url" >&2
    echo "      ⇒ an unpinned clone lands whatever the default branch points at" >&2
    echo "        right now, so two applies install different code. that breaks" >&2
    echo "        the deterministic half of one-command provision" >&2
    echo "      ⇒ source the sha from the tag you mean:" >&2
    echo "        gh api -X GET repos/OWNER/REPO/git/ref/tags/vX --jq .object.sha" >&2
    return 2
  fi

  local rc=0
  GIT_TERMINAL_PROMPT=0 \
  timeout -k "$WEB_REGISTRY_GRACE_SECONDS" "$within" \
    git "${WEB_GIT_FLOOR[@]}" \
        -c http.lowSpeedLimit=1024 \
        -c http.lowSpeedTime=60 \
        clone "$url" "$dir" </dev/null || rc=$?

  ####################################################################
  # the clone landed a whole repo; now move it to the DECLARED commit. a
  # detached checkout is deliberate — this is an install, not a working copy,
  # so no branch should track a moving tip
  ####################################################################
  local named=0
  if [[ $rc -eq 0 ]]; then
    if GIT_TERMINAL_PROMPT=0 timeout -k 10 120 \
         git -C "$dir" checkout --detach "$at" --quiet </dev/null; then
      local head
      head="$(git -C "$dir" rev-parse HEAD 2>/dev/null || echo unknown)"
      if [[ "$head" == "$at" ]]; then
        return 0
      fi
      echo "   ✋ the clone checked out the WRONG commit — $url" >&2
      echo "      expected: $at" >&2
      echo "      received: $head" >&2
    else
      echo "   ✋ the pinned commit is absent from $url" >&2
      echo "      wanted: $at" >&2
      echo "      ⇒ upstream force-pushed or deleted it. do NOT relax the pin to" >&2
      echo "        make this pass — find what the sha should now be and bump it" >&2
    fi
    ####################################################################
    # ⚠️ the pin failure is already named PRECISELY above, so the transport
    #    diagnosis below must not also run. a vaguer sentence printed under a
    #    precise one is what a hurried reader acts on, and it sends them to
    #    debug the wire over a fault that was never the wire's
    #    (`gotcha.a-check-that-cries-wolf-gets-silenced`, measurement 4)
    ####################################################################
    named=1
    rc=1
  fi

  ####################################################################
  # 124 is `timeout`'s own code for "I killed it", and it is the one verdict
  # that must NOT read as a git error — the fix for a hang is a retry, and the
  # fix for a git error is to read what git said
  ####################################################################
  if [[ $named -eq 1 ]]; then
    : # the cause is already stated; fall through to the cleanup below
  elif [[ $rc -eq 124 ]]; then
    echo "   ✋ the clone TIMED OUT after ${within}s — $url" >&2
    echo "      ⇒ it stalled or never spoke. that is a wire fault, NOT a bad url" >&2
    echo "      ⇒ a grove reaches the wire through its nat, so a stalled flow" >&2
    echo "        there is the ordinary failure of that path — retry first" >&2
  else
    echo "   ✋ the clone failed (git $rc) — $url" >&2
    echo "      ⇒ the transfer was bounded and returned, so read git's own error" >&2
    echo "        above. a 'could not read Username' means github answered 401 —" >&2
    echo "        usually an unauthenticated rate limit on this box's egress ip" >&2
  fi

  ####################################################################
  # ⚠️ a killed clone leaves a PARTIAL dir, and every caller here guards on
  #    `[[ -d $dir ]]` — so a re-run would find that carcass, call it present,
  #    and skip the install. the phase would then report ✔ over a broken tree
  #    (`rule.forbid.failhide`). the boundary cleans up after itself
  ####################################################################
  if [[ -d "$dir" ]]; then
    rm -rf "$dir"
    echo "      ⇒ removed the partial clone at $dir, so a re-run refetches it" >&2
  fi
  return 1
}
