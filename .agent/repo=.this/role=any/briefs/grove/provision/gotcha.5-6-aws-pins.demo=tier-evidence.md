# demo: 5.6.aws — the pin tiers behind the cli and the ssm plugin

## .what

`5.6.aws/provision.upsert.sh` installs two artifacts, each pinned by a different
mechanism at a different evidence tier. this brief records where each tier comes from.

## the cli's signature is TIER 1, read 2026-08-13

- aws publishes the cli's signer key fingerprint on `docs.aws.amazon.com`, a host
  separate from `awscli.amazonaws.com`, where the zip and its `.sig` are served
- two channels must be compromised together to defeat it
- the key lives IN THIS REPO rather than fetched, since aws serves no url for it — the
  anchor sits in git and in the diff. no wire fetch is itself trusted

## `type -a`, never `command -v -a`

- a fix-text once read `command -v -a aws`, and that command returned
  `command: -a: invalid option` — `-a` is not a valid option there
- a fix-text that does not run defeats `rule.require.errors-name-the-fix`

## the ssm plugin's url names a VERSION, undocumented by aws — read 2026-08-13

- aws's own install docs give only a `/latest/` path
- the versioned path (`.../plugin/1.2.835.0/...`) answers 200 all the same
- ⇒ the determinism `rule.require.one-command-provision` asks for was available the
  whole time, merely undocumented. the pin is what makes the signature below
  expressible at all

## the ssm plugin's signature is served though undocumented

- aws's install page for this plugin documents no verification at all
- the bucket was probed directly, and a `.sig` sits beside every artifact — a vendor's
  docs describe what they SUPPORT, never what they SERVE

## the ssm plugin's key is TIER 2, and a DIFFERENT key from the cli's

- the `.deb` is signed by an ECDSA key, where the cli's is RSA. the cli's tier-1
  anchor does not cover this artifact
- aws publishes no fingerprint for it anywhere reachable, so tier 1 is unavailable
- three facts corroborate the value instead: the uid is an `@amazon.com` signer
  identity, unrelated public repos pin this same fingerprint by other authors, and it
  verifies the signature aws serves today, proven on a grove
- what the pin buys: an attacker who owns this s3 path must also forge a `.sig` this
  key accepts. a WRONG key can only cause a false ✋, never a false ✔ — the pin fails
  in the safe direction

## .see also

- `5.6.aws/provision.upsert.sh` — the header these measurements back
- `gotcha.5-6-aws-cli-two-readers.demo=v1-debian-package` — the neighbor demo, the
  skip-guard shape rather than the pins
- `rule.require.verify-binary-downloads`
- `rule.require.errors-name-the-fix`
