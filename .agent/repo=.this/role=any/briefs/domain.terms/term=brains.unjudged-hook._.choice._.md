# domain.term: unjudged-hook

term.chosen   = unjudged hook
term.kind     = noun
term.boundary = brains
term.synonyms.forbidden:
- foreign hook
- foreign-author hook

## .what
a hook in `~/.claude/settings.json` whose `author` field is set but sits outside `repo=…`.
`5.3.brains` cannot judge it: it is neither a role hook (strip) nor a commander key (keep).
so the apply keeps it byte-equal and both halves name it ✋ for a human.

## .refs
- `src/grove.provision/5.devtools/5.3.brains/_.sh` — `_grove_provision_5_3_brains_unjudged_hooks_by_author`
- `src/grove.provision/5.devtools/5.3.brains/configure.upsert.sh` — `..._settings_unjudged_name`
- `src/grove.provision/5.devtools/5.3.brains/configure.verify.sh` — `..._unjudged_hooks_verify`

## .reason
- `term=brains.unjudged-hook._.choice.reason.md`
