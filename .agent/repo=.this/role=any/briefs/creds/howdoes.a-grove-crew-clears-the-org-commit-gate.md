# howdoes: a grove crew clears the org commit gate

## .what

a crew's `git.commit.set` asks one gate before it commits: **is this crew's org allowed on this seat?**
the answer lives in one file per seat, the org meter:

```
$HOME/.rhachet/storage/repo=ehmpathy/role=mechanic/.meter/git.commit.uses.org.jsonc
```

an org with no leaf there, and no `@all` leaf, is refused: *"no org config for <org>"*.

## .the org is the manifest's, never the owner dir's

the gate reads the crew tree's own `.agent/keyrack.yml` `org:`. a tree under `~/git/<owner>/…` that declares
`org: ahbode` is an ahbode crew, whatever `<owner>` says.

## .the meter states, as the gate reads them

| meter | the gate says |
|---|---|
| absent file | unset — refused |
| a dir, unreadable, 0 bytes, or not a json object | corrupt — refused, every org |
| `orgs[<org>]` allowed / blocked | that verdict |
| no `orgs[<org>]` | the `@all` leaf, else unset |

## .which orgs a cloud grove allows

the orgs its github token can push to. the token's push scope is the grant: it is set where the token
is minted, and the box reads it in one call (`gh api user/repos`, `permissions.push`). each github org
maps back to its keyrack org through `grove_org_clonedir`, so a github org named apart from its
keyrack org reads as the keyrack org.

## .who does what

| actor | does |
|---|---|
| `5.26.commitorgs` (provision, cloud crew seat) | reads the token's push orgs; allows each one the meter holds unset; leaves a block as is; refuses to write over a damaged meter; re-reads the meter to prove each grant landed. its verify grades each token org the gate's way, and names each crew whose org the token cannot push to |
| `5.26.commitorgs` (local grove, admin seat) | declines. on a local grove the meter is the human's own choice, which no fact on the box answers; the admin seat hosts no crew |
| `rhx git.commit.uses --org <org> allow` | the human's grant at his own terminal — the road on a local grove, and the way to set a block anywhere |

⚠️ a damaged meter may hold a block, so the bundle never clears it. the verify names the read, the
clear, and the apply, in that order.

## .see also

- `5.10.repos` — the peer bundle that already reads which orgs the box's token can see
- `prove.commitorgs-reads-the-meter-as-the-gate` — grades the bundle's reader and writer against the real upstream gate
