# domain.term: role-hook

term.chosen   = role hook
term.kind     = noun
term.boundary = brains (a hook entry in a claude settings file)
term.synonyms.forbidden:
- repo hook     (names where it SHOULD live, not who wrote it — and a commander's own hook in a
                 repo's settings is a repo hook too)
- rhachet hook  (names the tool, and rhachet writes hooks for no one but roles; the role is the
                 author the stamp names)
- managed hook  (says naught about the manager; reads as "safe to leave", the opposite of the claim)
- foreign hook  (foreign to whom? home is foreign to every repo, and the commander's hooks there
                 are his own)

## .what
a **role hook** is a hook entry in a claude settings file whose `author` is a string that begins
`repo=` — the stamp rhachet writes on every hook a role authors (`repo=<org>/role=<role>`).

an entry with no `author`, or any other `author`, is NOT a role hook. it is the commander's own.

the selector is held ONCE, in `_GROVE_PROVISION_5_3_BRAINS_ROLE_HOOK`, and read by the strip, the
count, and the verify, so the three cannot disagree on what a role hook is.

## .why the word matters
a role hook belongs in the settings of the repo that enrolled the role. in `~/.claude/settings.json`
it fires in every session on the box, in every repo — so home must hold zero.

## .refs
- src/grove.provision/5.devtools/5.3.brains/configure.upsert.sh   # the selector, the strip
- src/grove.provision/5.devtools/5.3.brains/configure.verify.sh   # the zero claim
- .play/permanent/prove.claude-home-settings-refuses-a-foreign-write.play.sh
- .behavior/v2026_10_20.fix-home-claude-settings-lock/.fulcrums/inventory.of=fulcrums.case=F2-role-hook-by-author-prefix.md

## .reason
- `term=brains.role-hook._.choice.reason.md`
