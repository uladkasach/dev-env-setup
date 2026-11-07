# F5 — a ci workflow so "green on ci" can be true

- fact: the repo's one workflow, `.github/workflows/test.brains.auth.yml`, fires only on
  `brains.auth.*` paths. a pr that touches `play.run.sh` gets zero checks — the reader calls that
  `no-ci` ("green cannot be proven from none", `director.bar.operations.sh:513-516`). the most
  recent merged pr, #187, reports no checks at all
- fork: (a) add `.github/workflows/test.play.run.yml` that runs the clamp on prs that touch
  `play.run.sh` or its clamp; (b) ship with no ci and report the wish's "green on ci" as unmet
- taken: (a). the clamp is hermetic (temp git repo, bash + git + coreutils), so the job needs no
  node, no `npm ci`, no secrets — the same shape `test.brains.auth.yml` already uses. it runs the
  runner by its own file, `bash .agent/repo=.this/role=any/skills/play.run.sh --play <clamp>`, so
  the index + verb checks still apply
- rework: clean — one new file, deletable
- confidence 75%: the wish asks for green ci but never says to add a workflow; a new workflow is a
  repo-shape call the human may want to own
- where: `.github/workflows/test.play.run.yml` (new)
- verdict: CONFIRMED by director, 2026-11-06 — add the hermetic workflow
