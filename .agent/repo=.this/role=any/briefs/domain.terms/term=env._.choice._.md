# domain.term: env

term.chosen   = env
term.kind     = noun
term.synonyms.forbidden:
- environment  (the long form. `env` IS `environment` — a blessed alias, not a distinct concept.
                write `env` in every contract; `environment` may appear in prose that quotes
                sdk-environment's own dobj name)
- ctx          (context is a different concept — the injected dependencies of a call. an env is a
                fact about the machine and the run)
- config       (a config is what a human chose. an env is largely what the box IS)
- settings     (same objection as `config`, plus it names no owner)

## .what
**`env` = `environment`.** a blessed alias — the short form is the canonical one.

it names sdk-environment's `Environment` dobj: the three attributes that answer *where and what*
this run is.

```ts
interface Environment {
  access: 'test' | 'prep' | 'prod';   // what resources may we touch?
  server: string;                     // where does this run?  `$tier@$platform`
  commit: string;                     // what code is this?    `$gitref@$hash` (+ if dirty)
}
```

## .why the SHORT form is canonical
`env` is already how the surface this repo lives in spells it — `$ENV`, `env(1)`, `printenv`,
`.env`, `NODE_ENV`, `env -i`. a shell provisioner that wrote `ENVIRONMENT` would be the odd one out
on its own platform.

it also keeps the exported names legible at the length they actually get read:

```sh
GROVE_ENV_ACCESS   GROVE_ENV_SERVER   GROVE_ENV_COMMIT
```

the long form gives `GROVE_ENVIRONMENT_ACCESS` — 25 characters to say what 17 said, in a prefix
that repeats on every line of a header block.

## .the ALIAS is blessed; the CONCEPT is imported
two separate facts, and they matter separately:

- the **concept** is sdk-environment's. this repo does not own `Environment`, its three attributes,
  or their value sets — see `rule.require.conform-to-sdk-environment`
- the **alias** is this repo's, and it is blessed. so `env` is itemized here while `access`,
  `server`, and `commit` are cited to the package rather than owned

## .what `env` is NOT
`env` is the whole dobj, never one of its attributes. the most common drift is to say "env" and mean
`access`:

| you mean | write |
|---|---|
| the three attributes together | `env` |
| test \| prep \| prod | **`access`** — never `env` |
| where it runs | **`server`** |

`rule.require.conform-to-sdk-environment` already forbids `env` alone for access. this file is why
the word is otherwise fine.

## .refs
- src/grove.env.sh                                              # the declaration
- .agent/repo=.this/role=any/briefs/grove/provision/rule.require.conform-to-sdk-environment.md
- .agent/repo=.this/role=any/briefs/grove/provision/howto.detect-env-server.md

## .reason
see the ref-level cluster beside this choice:
- `term=env._.choice.reason.md` — the blessed-alias doctrine, why an abbreviation is normally a
  smell and why this one is not, and the boundary that stops `env` from absorbing `access`
