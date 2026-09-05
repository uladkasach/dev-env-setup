# rule.require.verify-binary-downloads

## .what

when an install procedure fetches a binary artifact from the network (tarball,
appimage, deb, installer), it must verify the artifact before it is extracted,
run, or installed. never extract an unverified download.

## .why

- **tamper detection**: a mirror, cdn, or account compromise could swap the bytes
- **corruption detection**: a truncated or garbled download fails loud, not silent
- **reproducibility**: a pinned artifact is the *same* artifact on every machine
- **review**: the expected hash/fingerprint lives in git, visible in the diff

tls alone proves you reached the host over an encrypted channel — it does not
prove the *bytes* are the ones upstream published.

## .the checks, best to worst

apply the strongest check the upstream project supports:

| check | strength | when available |
|-------|----------|----------------|
| gpg signature vs pinned fingerprint | best | project signs release artifacts |
| pinned sha256 | good | always (compute from a trusted source) |
| tls only | weak | fallback of last resort — avoid |

when the project offers a signature, do **both**: gpg verify *and* sha256 pin
(belt-and-suspenders). when it offers no signature, the sha256 pin is mandatory,
not optional.

## .where to source the hash

trust the hash's origin, not a random download:

- **github release asset digest** (preferred): `gh api repos/OWNER/REPO/releases/tags/vX --jq '.assets[] | .name + "  " + .digest'` — github computes this server-side
- a signed `SHA256SUMS` file published by the project
- the sha256 of a tarball you already gpg-verified

never hardcode a hash you computed from an unverified download — that just pins
the tampered bytes.

### a git COMMIT SHA is a hash source too

git addresses every object by the hash of its content and checks that hash on
checkout, so a commit sha is a content pin with no separate `sha256sum` step —
the transport supplies the guarantee. that is why `git_clone` requires `--at`
(`src/grove.web.sh`) and why an unpinned clone is a **blocker** and not a
nitpick: its url names no version at all, so the "pin" it lacks is invisible in
review, and two applies a week apart install different code from one checkout.

## 🛑 .when upstream publishes NO hash — the clause pair that cannot both hold

these two clauses collide, and the collision is not rare:

| clause | says |
|---|---|
| `.enforcement` | *"no signature available is not an excuse to skip the sha256 pin"* |
| `.where to source the hash` | *"never hardcode a hash you computed from an unverified download"* |

for an artifact whose upstream publishes neither a signature nor a checksum, the
only hash anyone could write is one computed from an unverified download. so the
rule as first stated demanded a pin and forbade the only pin available, and a
reader who hit that either skipped the check or wrote a self-computed hash.

⚠️ **a self-computed hash is not an integrity check.** it is a CHANGE DETECTOR:
it proves the bytes are the same as the day somebody last looked, and says not
one word about whether they were ever the right bytes. and it is
indistinguishable in review from a sourced one — 64 hex characters either way —
so it converts an open gap into a closed-looking one, which is worse than the
gap (`gotcha.a-check-that-cries-wolf-gets-silenced`, inverted).

### ⇒ the resolution: change the ACQUISITION PATH, do not invent a pin

when upstream publishes no verifiable hash, the fix is not a number. it is to
obtain the artifact by a route that carries its own verification:

| instead of | reach for | what verifies it |
|---|---|---|
| a loose `.deb` fetched by url | the vendor's **apt repo** | apt checks the gpg-signed `Release` against the vendor key — this is what debian is FOR |
| a `git clone` of a default branch | `git_clone … --at <commit>` | git verifies every object against its own hash |
| a `/latest/` redirect | the **versioned** url + its github digest | github computes the digest server-side |
| `curl … \| sh` | the versioned artifact + a published signature | the project's own key |

⚠️ and note what the first row buys: an apt repo verifies **every future
upgrade** too, where a one-time hash pin verifies exactly one download and then
goes stale on the next bump. the routed fix is strictly stronger than the pin it
replaces.

### ⚠️ a pin's SOURCE has tiers — it is not sourced-or-computed

sourced-or-computed is a binary, and it holds only for the tarball case: a hash
derived from one unverified download pins that download and no more.

a **long-lived trust anchor** is a different subject. measured 2026-08-13: docker
publishes **no** fingerprint on either its ubuntu or its debian install page — it
tells you to `curl` the key and stop. so tier 1 is unavailable for one of the
most-followed vendors there is, and a rule that permits only tier 1 would leave
that anchor with **no** check at all.

| tier | the fingerprint came from | strength |
|---|---|---|
| 1 | the vendor's own published documentation, at a host other than the download | best — two channels must be compromised together |
| 2 | the same value observed at two or more independent POINTS IN TIME | good — defeats a transient cdn compromise, and freezes the anchor from here on |
| 3 | one read, from one box, at one moment | weak — but see below |
| — | invented, or recalled from memory | **forbidden**, always |

⇒ **even tier 3 beats no pin**, and the reason is specific to an anchor: with no
pin, the key is re-fetched and blindly trusted on EVERY fresh box, forever. with
a pin — however it was sourced — a compromise of that vendor's cdn *tomorrow* is
caught. the pin converts an unbounded, repeated trust decision into one that was
made once and is now reviewable in git.

**the tier must be stated at the site.** a tier-3 pin that reads like a tier-1
pin is the exact defect `gotcha.my-own-note-became-my-evidence` describes — the
number looks identical either way, so only the comment can carry the truth.

### 🛑 what does NOT count as corroboration

a lookup keyed on the very value you mean to confirm. to query a keyserver by
the fingerprint you already hold returns a key with that fingerprint — which is
true of any real key, and proves not one fact about whose key it is. measured
the same day: `keys.openpgp.org` served the docker fingerprint and **stripped
the uid**, so it corroborated neither the owner nor the value.

⇒ corroboration must be reachable **without** the value in hand. a vendor's docs
page qualifies; a by-fingerprint lookup does not.

### the honest last resort

where no verified route and no corroboration exist at all, the artifact is a
**live exposure**, and it is named as one — never papered over with a hash
presented as though it were sourced. the acceptable moves are to drop the tool,
to change the acquisition path, or to pin at a named lower tier. what is
forbidden is a check that reads stronger than it is.

## 🛑 .the blast radius is the CONSUMER, not the artifact

*"but this artifact is not sensitive"* is not an exemption, for the same reason
it is not one in `rule.forbid.fixed-paths-in-a-shared-tmp`. rank a gap by what
the phase then DOES with the bytes:

| the artifact is… | consumed by | radius |
|---|---|---|
| an apt gpg key | apt, as the trust anchor for every package from that repo, forever | **highest** — one swap and root installs whatever it is handed |
| a `.deb` | `apt-get install ./x.deb`, whose maintainer procedures run as root | highest |
| an installer piped to a shell | that shell, as the user who ran the apply | high |
| a binary moved onto PATH | every later command that names it | high |
| a font zip | `unzip -o` into `$HOME` | low |

⚠️ the first row is the one that reads as harmless and is not. a key is small,
public, and dull — and it is the root of trust for every package installed after
it, so an unverified key makes every later apt signature check verify against
whatever an attacker supplied.

## .pattern

```bash
local sha256="c441b547142860bf01bcce39e36cbed185c41112813e15443b16e5237750724d"

curl -fsSL "$url" -o "$tmp/$archive"

# fail fast unless the download matches the pinned sha256
if ! echo "${sha256}  $tmp/$archive" | sha256sum -c - >/dev/null 2>&1; then
  echo "⛈️  install aborted: sha256 mismatch (expected $sha256)"
  rm -rf "$tmp"
  return 1
fi

# ...only now extract
```

verify **before** extract. abort (`return 1`) on mismatch. clean the temp dir so
a bad download cannot linger and get reused.

## .on version bumps

the pin is version-locked. when you bump the tool version, update the hash (and
fingerprint, if any) in the *same* edit — a stale hash aborts the install, which
is the safe failure mode.

## .exception

one-off commands allowed only for immediate unblock while the procedure is not
yet written — must be followed once you append the verified fetch to an install
procedure (see rule.require.install-via-procedures).

## .enforcement

- a network binary fetch with no verify step before extract, run, or install =
  **blocker**
- a `/latest/` or otherwise floating url in a provision phase = **blocker** — it
  breaks the deterministic clause of `rule.require.one-command-provision` AND it
  makes a hash pin inexpressible, since there is no fixed artifact to hash
- a `git_clone` with no `--at <commit>` = **blocker**
- a **self-computed** hash — one derived from a download nobody verified —
  presented as an integrity check = **blocker**; it is a change detector, and it
  is worse than an open gap because it reads as closed
- *"no hash is published upstream"* offered as a reason to skip = **blocker**;
  change the acquisition path (see the table above), or name the exposure
- a version bumped without its hash bumped in the same edit = **blocker**; the
  stale hash aborts the install, which is the safe failure, but a bump that
  silently drops the pin is not

## .see also

- `src/grove.web.sh` — `web_verify_sha256` (the one hash check) and `git_clone`
  (the one clone, and why `--at` is mandatory)
- `rule.require.one-command-provision` — the deterministic clause a floating url
  breaks, and why only a FIRST apply exercises any of this
- `rule.forbid.fixed-paths-in-a-shared-tmp` — the same blast-radius argument,
  applied to where the bytes land rather than what they are
- `inventory.security-checks.md` — the accumulated inventory of adopted checks
- `rule.require.install-via-procedures.md`
- `rule.require.repo-as-source-of-truth.md`
