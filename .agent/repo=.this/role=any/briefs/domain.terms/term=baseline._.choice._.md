# domain.term: baseline

term.chosen   = baseline
term.kind     = noun
term.synonyms.forbidden:
- default         # the ONE the box falls back to — a baseline is the SET beside it
- preinstalled    # names the timing, not the concept; every asset is preinstalled
- common          # says how often it is used, never what the set is for
- allowlist       # implies the unlisted are refused; an unlisted version installs fine

## .what
the set of versions a box carries **beside** its default, so a per-directory
switch never has to fetch one on demand.

## ⚠️ .why a baseline is not a default
a default is what a shell gets when no version is asked for — exactly one, and
`5.1.node` sets it to fnm's `lts-latest`. a baseline is the set the box holds
*in addition*, precisely because another version WILL be asked for: every repo
pins its own via `.nvmrc`, and fnm's cd hook honors that pin.

collapse the two and the sentence "the node is installed" reads true of a box
where a `cd` still stalls.

## .why a baseline narrows odds and closes no hole
a baseline can only ever cover the repos already known. the guarantee belongs to
the HOOK — hardened to install rather than ask — and the baseline exists so the
common case costs no download. a baseline offered as the guarantee is the defect.

## .refs
- `src/grove.provision/5.devtools/5.1.node/_.sh`                 # GROVE_NODE_BASELINE, grove_node_versions_wanted
- `src/grove.provision/5.devtools/5.1.node/provision.upsert.sh`  # installs the set
- `src/grove.provision/5.devtools/5.1.node/provision.verify.sh`  # proves the set landed

## .reason
see the ref-level cluster beside this choice:
- `term=baseline._.choice.reason.md` — etymology, evidence, the default dispute
