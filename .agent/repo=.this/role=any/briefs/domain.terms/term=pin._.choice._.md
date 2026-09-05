# domain.term: pin

term.chosen   = pin
term.kind     = noun
term.forms    = a version pin, a hash pin, a commit pin — one word, three shapes
term.synonyms.forbidden:
- version (a version is ONE KIND of pin; a sha256 is a pin and is no version — to
  spell the general by the specific loses the other two shapes)
- hash (the same error inverted — a `v3.5.0` in a url is a pin and is no hash)
- lock (pnpm/npm already own it for a resolved dependency set, and a lockfile is
  generated where a pin is authored — an overload of two opposite things)
- freeze (implies a temporary hold that later thaws; a pin holds until somebody
  deliberately bumps it, and never on its own)
- anchor (collides with the TRUST anchor sense a gpg key carries here)

## .what

the exact identity of an artifact this repo fetches, declared in the source, so
that two applies on different days obtain the same bytes.

three shapes, one concept:

| shape | where | what it fixes |
|-------|-------|---------------|
| version pin | a url that names a release | WHICH artifact is fetched |
| hash pin | `web_verify_sha256 --sha256 …` | WHETHER those are the published bytes |
| commit pin | `git_clone … --at <commit>` | both at once — git verifies content by hash |

## .why the term is needed

a pin serves two rules that are usually discussed apart, and the single word is
what keeps them from being solved separately and half-done:

- `rule.require.one-command-provision` — its DETERMINISTIC clause. an unpinned
  fetch installs different bytes on different days from one checkout
- `rule.require.verify-binary-downloads` — its integrity clause. an unpinned
  fetch has no fixed artifact, so there is no subject a hash could be about

⇒ the version pin is what makes the hash pin **expressible**. they land together
or neither does, which is why one word covers both.

## .the invariant

> a pin is SOURCED, never computed. a hash derived from a download nobody
> verified is a change detector, not a pin — it proves the bytes are the same as
> the day somebody last looked, and says not one word about whether they were
> ever right.

## .refs

where the term is declared / used:
- src/grove.web.sh                                              # `git_clone --at`, `web_verify_sha256`
- src/grove.provision/2.shell/2.8.tmux/provision.upsert.sh         # `tpm_at`, a commit pin
- src/grove.provision/5.devtools/5.7.terraform/provision.upsert.sh # `tfenv_at`, a commit pin
- src/grove.provision/4.terminal/4.1.fonts/provision.upsert.sh     # version + hash, together
- src/grove.provision/4.terminal/4.5.nvim/provision.upsert.sh      # version + hash
- src/grove.provision/2.shell/2.6.starship/provision.upsert.sh     # version + hash
- src/grove.provision/4.terminal/4.3.kitty/4.3.2.emulator/provision.upsert.sh  # version + hash + gpg
- .agent/repo=.this/role=any/briefs/grove/provision/rule.require.verify-binary-downloads.md

## .reason

see the ref-level cluster beside this choice:
- `term=pin._.choice.reason.md` — etymology, the rejected words, the clause pair
  that settled the SOURCED invariant, and why a self-computed hash is worse than
  an open gap
