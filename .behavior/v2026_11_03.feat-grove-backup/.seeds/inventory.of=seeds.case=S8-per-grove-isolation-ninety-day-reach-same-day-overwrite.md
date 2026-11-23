# S8 · per-grove isolation, a 90-day reach, same-day overwrite

## .said

> yeah, we need enforced per grove isolateion, camper write only within their grove is fine (but only for up to 90days of backups, afterthat, locked out again), and they can overwrite only if same day. i think that would be sufficient. think carefully what needs to go into ahbode/infra vs this repo though

> give me the handoff for the ahbode/infra changes you need, and i'll get it prioritized. you get all the groves backed up in the meantime, with the expectation that it'll set those auth constraints

## .settled

- a grove's identity reaches its own `grove=<slug>/` prefix alone, enforced by the grant, never by this repo's good conduct
- within its own prefix, camper may put and read, for backups up to 90 days old; past 90 days it is locked out, and only an admin reaches them
- a put may replace a key only on the day that key names
- infra owns the enforcement; this repo builds to those constraints now, and backs up every grove in the meantime

## .landed

| where | what |
|---|---|
| `handoff.infra.grove-backup-isolation` | the asks of ahbode/infrastructure |
| the agent, `get`, `restore` | built to the constraints |
