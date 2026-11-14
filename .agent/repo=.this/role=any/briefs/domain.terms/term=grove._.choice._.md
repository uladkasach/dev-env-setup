# domain.term: grove

term.chosen   = grove
term.kind     = noun
term.synonyms.forbidden:
- machine
- box
- node

## .what
a machine (a host) that holds trees. `localhost` is a grove; an ec2 box is a grove.

## .the three kinds — and the noun spans ALL of them

settled by the human 2026-08-30: *"local and cloud are two types of groves."* the house kind
joined in the house-grove route (2026-10-17): a seat on a box we own is a grove too.

| kind | `$GROVE_ENV_SERVER` | `--for` | reached by |
|---|---|---|---|
| **local** | `local@unix`, `local@cicd` | `local` | no transport — the shell is already on it |
| **house** | `house@unix` | `house` | loopback ssh to a seat user on a box we own, named by a root-owned election |
| **cloud** | `cloud@aws.ec2`, `cloud@hetzner.hetzbot` | `cloud` | a duct (`term=duct`) |

⚠️ a house grove shares its HARDWARE with a local grove and is still a second grove: it has its
own unix users, its own home, its own reach. the kind is read off the election, never the box.
the uri form a house grove is addressed by is an open fork (F1 in the house-grove route), so this
row names no uri.

⚠️ **the word is not a synonym for "a remote box".** the tree already treats the kinds as
one subject with a tag — `--for local|house|cloud` is one flag over one bundle list — so a
reading of `grove` that excludes the laptop contradicts the inventory it describes.

⇒ what the kinds differ in is **reach**, never nature. a laptop is a grove you stand on;
a house grove is one you reach over loopback; a cloud grove is one you speak to through a
duct. every bundle, every phase, and every verify is written for all three, and a bundle
that cannot serve one
DECLINES inline beside the reason (`repo.overview.md`).

⚠️ and this is why `git.grove.provision` reads honestly for a laptop: the act is the same
act. what a laptop skips is the TRANSPORT half — the wake, the trust, the push — not
the convergence.

## .note
`host` is not forbidden — it is ductwork's vantage on the same machine (`user@host:name`).
within git-forest contracts use `grove`; ductwork uses `host` for the transport address.
the two name one physical machine from two layers (see `define.git-forest-grove-tree.md`).

## .refs
where the term is declared / used:
- .agent/repo=.this/role=any/briefs/grove/reach/define.git-forest-grove-tree.md
- .dream/2026_06_17.git-forest.dream.md      # git.grove.* commands (dreamed)
- .dream/2026_06_14.cloud-agent-host.dream.md

## .reason
see the ref-level cluster beside this choice:
- `term=grove._.choice.reason.md` — etymology, disputes, evidence
