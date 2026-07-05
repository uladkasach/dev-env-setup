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

blocker — a network binary fetch without a verify step before extract is a
defect. no signature available is not an excuse to skip the sha256 pin.

## .see also

- inventory.security-checks.md — the accumulated inventory of adopted checks
- rule.require.install-via-procedures.md
- rule.require.repo-as-source-of-truth.md
