# domain.term.choice.reason: devenv

## .etymology
short for "development environment" — the thing this whole repo exists to install. it names
both halves together: the **config** files copied to `~` (bash_aliases, zshrc, tmux.conf,
starship.toml, init.lua) and the **tools** installed onto the machine (zsh, nvim, node,
tmux). `grove.provision` raises the configs; `install_env.*` installs the tools; both serve one
devenv.

chosen over:
- `dotfiles` — names only the config half, and only by file-naming convention; it omits the
  tools, which are most of the install
- `environment` — too broad; collides with the deploy-environment sense (test/prep/prod,
  see `prefer.env_access.prep_over_dev`), so it would overload one word onto two concepts
- `config-set` — mechanical, and again config-only

## .disputes
none yet.

## .evidence
- built precedent: the term already composes ~14 declared operations —
  `grove.provision.bashaliases`, `grove.provision.zshrc`, `grove.provision.tmux`,
  `grove.provision.grove`, `git.repo.pull`, and the `_grove_src` helper that names the
  source dir for all of them. (these were `sync.<old>.*` / `git.repo.pull` until
  2026-07-27, when `sync` was retired — see `term=git.repo.pull._.choice.reason.md`)

  ⚠️ that list is the family AS IT STOOD, and the `upgrade` half of it was superseded by
  `grove.provision` on 2026-08-31 (`term=grove.provision._.choice._.md`). it must not be swept
  forward: the evidence is that the word **devenv** composed those names, so a rewrite to
  `grove.provision.*` leaves the claim to cite names that hold no `devenv` at all. the noun
  survives the cutover and keeps `git.repo.pull` and `grove.bootstrap`.
- narrative: a traveler on a fresh machine (or a fresh grove) wants "my devenv" — they mean
  the configs AND the tools, as one unit. the word covers exactly what they ask for
- the two-half split carries real weight: a grove **bakes** the tools half into an AMI and
  **upgrades** the config half fresh, yet both are the devenv (see
  `install_env._.sh --for cloud`)
