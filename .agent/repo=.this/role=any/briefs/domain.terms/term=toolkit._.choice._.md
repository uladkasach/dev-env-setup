# domain.term: toolkit

term.chosen   = toolkit
term.kind     = noun
term.synonyms.forbidden:
- cli_deps     (names a RELATIONSHIP — "what other steps depend on" — not a subject. so it can hold
                any package at all, which is what made it a junk drawer; see the .reason)
- deps         (same defect, shorter. a dependency is a relation between two things, never a thing)
- utils        (generic — says no word about what it holds. the blocklist already forbids its nearest
                twin for exactly that defect)
- coreutils    (taken, and factually wrong: gnu coreutils is `ls`/`cp`/`mv`, none of which this
                bundle installs. they ship with the os)
- essentials   (a judgment, not a subject — and half this bundle is deliberately NOT essential)
- basics       (same; it also names a LEVEL rather than a thing, per
                rule.require.bundle-names-name-their-subject)
- misc         (names the absence of a name)

## .what
the set of terminal tools a shell session assumes but that carry no config of their own — `jq`,
`tree`, `unzip`, `ripgrep`, `xclip`, `fzf`. held as the bundle `2.1.toolkit`.

the boundary is **config, not cost**. a tool belongs to the toolkit only while this repo writes no
file for it. the moment it grows one, that file is a second declaration, so the tool earns its own
bundle (`rule.require.bundle-as-sole-declaration`). `tmux` and `starship` both left by that rule, and
their dirs are the precedent.

## .why `toolkit`
a toolkit is a real thing a person owns and carries — a named collection with a purpose. that is
exactly what this bundle is, and it is what every rejected alternative failed to be: `cli_deps` named
how the set relates to other steps, `utils` named no subject at all, `essentials` named a judgment
about the set rather than the set.

the test from `rule.require.bundle-names-name-their-subject` — "could this be installed?" — passes:
you can install a toolkit. you cannot install a `dep`.

## .the one tension, named
a toolkit is a SET, so one bundle holds many package names — where every other bundle in the tree
holds one subject. that is deliberate: a bundle per tool would be six directories whose bodies are
one line each and whose headers would all say the same word. the set IS the subject.

## .refs
- src/grove.provision/2.shell/2.1.toolkit/                    # the bundle
- src/grove.provision/2.shell/2.1.toolkit/_.sh                # why one bundle holds many names
- src/grove.provision/2.shell/2.1.toolkit/provision.upsert.sh # the essential/comfort split
- .agent/repo=.this/role=any/briefs/grove/provision/rule.require.bundle-names-name-their-subject.md
- .agent/repo=.this/role=any/briefs/grove/provision/rule.require.bundle-as-sole-declaration.md  # the exit rule

## .reason
see the ref-level cluster beside this choice:
- `term=toolkit._.choice.reason.md` — etymology, the `cli_deps` dispute, and the two tools that
  left the set
