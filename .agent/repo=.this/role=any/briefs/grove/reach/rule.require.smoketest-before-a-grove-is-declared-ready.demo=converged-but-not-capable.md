# demo: smoketest-before-ready — a converged box that could not run its own suite

## .what

`rule.require.smoketest-before-a-grove-is-declared-ready.md` requires `git.grove.provision
test` to pass before a grove is called ready. this is the measurement that shows why a
converged box is not the same claim as a capable one.

## m1 — zero claims on both seats, and zero tests ran, 2026-08-12

- the signals all read green:

  | the signal | said |
  |---|---|
  | `grove.provision --mode plan`, ground | ✔ 127 · ✋ 0 |
  | `grove.provision --mode plan`, camper | ✔ 125 · ✋ 0 |
  | `git.repo.test` on svc-chat | — |

- and yet: **0 tests ran**
- three faults stood between that converged box and a runnable suite, and no bundle verify
  could see any of them — none is devenv state:
  1. svc-chat had no `node_modules`
  2. the testdb was not provisioned
  3. `npm run start:testdb` died — `could not derive access` — for want of an `ACCESS` envar
- ⇒ **a converged box is not a capable box.** the bundle tree declares what a machine HAS;
  only a job proves what it can DO

## .see also

- `rule.require.smoketest-before-a-grove-is-declared-ready.md` — the rule this backs
