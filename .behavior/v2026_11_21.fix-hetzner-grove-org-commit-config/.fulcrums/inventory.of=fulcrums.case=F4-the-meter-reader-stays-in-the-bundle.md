# F4 — the meter reader stays in the bundle's `_.sh`, beside the table it grades

## .the fork

peer round i004 (r011 nitpick.4) asks to lift the meter reader (`meter_path`, `state_of`,
`states_of`, `orgs_in`, `scope_of`, `meter_presence`, `meter_bytes`, `has_jq`) out of
`5.26.commitorgs/_.sh` into its own sourced unit beside `src/grove.org.sh`, since the laptop
skill sources `_.sh` as a library and some functions there need runtime files the skill never
sources.

| option | for | against |
|---|---|---|
| keep it in `_.sh` (taken) | one declaration: the table, the classifier, and the grant line live where the bundle that owns them lives; the skill reads the box's own copy (`rule.require.bundle-as-sole-declaration`) | a future skill call to a runtime-bound function dies on 127 |
| lift to `src/grove.commitmeter.sh` | the skill sources only pure functions | a second file for one bundle's facts; the table and its grader split across two homes |

## .taken, and why

keep. the skill calls only pure functions (no `grove_env_*`, `grove_org_*`, `pkg_*`), which the
clamp proves: rows 7 and 8 run the skill with none of those runtime files sourced, over 30 paths,
and every one holds. the 127 hazard is real for a FUTURE call; a lift is cheap the day a second
consumer outside this bundle's own family needs the reader (`rule.prefer.most-common-denominator`:
the skill is this bundle's own grant tool, not a peer domain).

## .rework

clean. a file move plus three `source` lines (the bundle's `_.sh`, the skill, clamp row 1).

## .confidence — 80%

the open 20%: a reviewer could rule the skill a second domain, which would make the lift owed now.

## .where

`src/grove.provision/5.devtools/5.26.commitorgs/_.sh` · `.agent/repo=.this/role=any/skills/git.grove.auth.commit.set.sh`

## .verdict

moot 2026-11-22 (seed S5): the org table is removed. the meter reader stays in `_.sh`, beside the token read whose orgs it grades.
