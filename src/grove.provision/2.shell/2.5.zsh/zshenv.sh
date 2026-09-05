#!/usr/bin/env zsh
######################################################################
# ~/.zshenv — the env that must reach EVERY zsh, not only a human's
#
# .what = environment variables that a NON-INTERACTIVE zsh must also carry
#
# ⚠️ .why this file exists, and why ~/.zshrc could not do its job
#         zsh sources `~/.zshrc` for INTERACTIVE shells only. it sources
#         `~/.zshenv` for every invocation — interactive, non-interactive,
#         and login alike. that difference is not academic:
#
#           zsh -ic  '…'   → .zshenv + .zshrc
#           zsh -c   '…'   → .zshenv only
#           sg docker -c   → .zshenv only
#           npm run / jest → .zshenv only
#
#         on 2026-08-06 `AWS_PROFILE=ambient` was declared in ~/.zshrc and
#         grove-1's integration suite still died with `AWS_PROFILE not set`.
#         the export was correct, present, and readable — and the test
#         process was a non-interactive shell that never sourced the file.
#
#         so: an env pointer a program must read belongs in `.zshenv`. an
#         rc is for a HUMAN's shell (prompt, aliases, keybinds); .zshenv is
#         for the machine's. a variable in the wrong one is not a smaller
#         version of right — it is absent exactly where it is needed.
#
# .why  it stays SMALL
#         .zshenv runs on every zsh, including hot paths. it must hold no
#         prompt work, no completion load, and no command that costs more
#         than a test. keep it to exports and cheap guards.
#
# owner: 2.5.zsh (`configure.upsert` copies it; `configure.verify` diffs it)
######################################################################

######################################################################
# ~/.local/bin on PATH — because git execs its credential helper by NAME
#
# ⚠️ .measured 2026-08-10 on grove-ahbode-v20260810
#      `2.2.git.configure.verify`, run over the duct, reported:
#
#        ✋ the helper is installed and current, but NOT on PATH
#
#      and it was right. the file was present, executable, and byte-identical
#      to the checkout — and `~/.local/bin` reached PATH from `~/.zshrc`
#      ALONE, which zsh sources for an INTERACTIVE shell only.
#
#      so the helper worked for a human at a keyboard and was invisible to
#      every other caller:
#
#        zsh -ic 'git fetch'        → .zshrc ran  → helper found
#        ssh grove 'git fetch'      → .zshenv only → helper ABSENT
#        a jest suite, a cron, a ci step, any automation → helper ABSENT
#
#      git does not say "the helper is not on PATH". it reports only that it
#      could not authenticate — so the symptom is an auth failure and the
#      cause is a shell file, two facts with no visible link between them.
#
# ⇒ a path a PROGRAM must look up belongs in .zshenv, for the same reason
#   AWS_PROFILE's absence taught above: an rc is a human's shell, .zshenv is
#   the machine's. `~/.zshrc` keeps its copy for the interactive case; this is
#   the one every other caller reads.
#
# .why the guard: .zshenv runs on EVERY zsh, including nested ones, so an
#      unguarded prepend would grow PATH once per shell
######################################################################
if [ -d "$HOME/.local/bin" ]; then
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
  esac
fi

######################################################################
# ~/.cargo/bin on PATH — because nvim-treesitter EXECS `tree-sitter`
#
# ⚠️ .measured 2026-08-12. `~/.cargo/env` was sourced from `~/.zshrc` ALONE, so
#    cargo's whole bin dir was absent from every program-invoked shell:
#
#      zsh -ic 'tree-sitter --version'   → .zshrc ran   → found
#      ssh <seat> 'nvim --headless …'    → .zshenv only → ABSENT
#      a cron, a jest child, a duct send → same         → ABSENT
#
#    and the consumer is a PROGRAM, not a human: nvim-treesitter shells out to
#    `tree-sitter` to compile a parser. so every parser build over a duct failed
#    on a box whose `tree-sitter` was installed, executable, and current.
#
# ⚠️ the rc STATED this rule ten lines above where it broke it — "an env pointer
#    a PROGRAM must read belongs in .zshenv, which every zsh sources" — which is
#    the third instance of that exact shape in this repo (AWS_PROFILE, then the
#    fnm/pnpm chain, now cargo). a rule stated beside the code that violates it
#    is a rule no reader catches
#    (`gotcha.a-tool-found-by-path-answers-only-a-human`).
#
# .what stays in `~/.zshrc`: the full `source ~/.cargo/env`, which exports more
#      than PATH. this is the PATH half, which every other caller reads.
#
# .why not a `source` here: `~/.cargo/env` re-exports PATH unguarded, so on a
#      nested zsh it would grow PATH once per shell. the guard below is the
#      whole reason this block restates the dir rather than sources the file.
######################################################################
if [ -d "$HOME/.cargo/bin" ]; then
  case ":$PATH:" in
    *":$HOME/.cargo/bin:"*) ;;
    *) export PATH="$HOME/.cargo/bin:$PATH" ;;
  esac
fi

######################################################################
# node's PATH chain — fnm, then pnpm's TWO global dirs
#
# 🛑 .this block belongs HERE, never in ~/.zshrc — 📜 measured 2026-08-12
#      ~/.zshrc is INTERACTIVE-ONLY, so declared there `rhx` — a pnpm global
#      shim — is absent from every program-invoked shell on the box, and a
#      one-command provision is impossible on the seat that does the work:
#
#        zsh -ic 'rhx …'          → .zshenv + .zshrc → found
#        ssh <seat> 'rhx …'       → .zshenv only     → ABSENT
#        a cron, a jest child     → same             → ABSENT
#
#      the cost is not one absent command. it is a TRANSPORT that must
#      compensate: `git.grove.operations.sh:_shell_at` probes each seat for a
#      `~/.zshrc` and picks `zsh -ic` over `bash -lc` on that evidence, because
#      the tools it needs are only in the interactive half. a workaround in the
#      transport is what a PATH claim in the wrong file costs.
#
# ⚠️ and ~/.zshrc STATES this rule itself — "an env pointer a PROGRAM must read
#      belongs in .zshenv, which every zsh sources. this rc keeps what a HUMAN's
#      shell needs." a right rule above wrong code is what a reader never
#      catches (`gotcha.a-tool-found-by-path-answers-only-a-human`).
#
# .what stays in ~/.zshrc, deliberately: `eval "$(fnm env)"`, the chpwd hook,
#      pnpm completions, the starship prompt. those are a HUMAN's shell. this is
#      the PATH every other caller reads.
#
# .why the guards: .zshenv runs on EVERY zsh, nested ones included, so an
#      unguarded prepend grows PATH once per shell.
######################################################################
######################################################################
# ⚠️ the fnm dir that holds BINARIES is `aliases/default/bin`, not `fnm`
#
#    `$HOME/.local/share/fnm` is fnm's DATA dir. it holds `aliases/` and
#    `node-versions/` and not one executable, so to put it on PATH is to add a
#    dir that can never answer a lookup. 📜 measured 2026-08-12: with that dir
#    named here, `ssh <seat> 'command -v node'` stayed empty — a PATH entry
#    that is present, readable, and useless reads exactly like an absent
#    export, so the mistake survives an `echo $PATH` inspection.
#
#    an interactive shell does not notice, because `~/.zshrc` runs `eval "$(fnm
#    env)"`, which mints a PER-SHELL symlink dir and exports THAT. so the dir
#    that serves a human is EPHEMERAL and belongs to one shell alone —
#    unusable from a file that must serve every future shell.
#
# ⇒ `aliases/default/bin` is the one fnm path that outlives a shell, which is
#   why `src/git-credential-keyrack.sh` already named it (and had to, because
#   git execs it with no shell at all). that helper keeps its own copy as a
#   fallback for a seat whose record is not zsh; this is the declaration every
#   zsh reads.
#
# ⚠️ and this dir carries `pnpm` too — corepack shims it here, so `pnpm` is
#    absent from $PNPM_HOME on a corepack box. the two blocks are not
#    alternatives; a seat needs both.
#
# .why $FNM_DIR is honored: fnm relocates its data dir on that variable, and a
#      hardcode would answer for the default layout alone
######################################################################
FNM_DEFAULT_BIN="${FNM_DIR:-$HOME/.local/share/fnm}/aliases/default/bin"
if [ -d "$FNM_DEFAULT_BIN" ]; then
  case ":$PATH:" in
    *":$FNM_DEFAULT_BIN:"*) ;;
    *) export PATH="$FNM_DEFAULT_BIN:$PATH" ;;
  esac
fi
unset FNM_DEFAULT_BIN

######################################################################
# ⚠️ BOTH $PNPM_HOME and $PNPM_HOME/bin, and the ORDER is a tiebreak
#
#    pnpm treats $PNPM_HOME itself as the global bin dir in some versions and a
#    /bin child in others; corepack reports the child. name both, and neither
#    refuses.
#
#    `/bin` is prepended LAST so it lands FIRST. one command can have two shims,
#    and the stale one hardcodes a NODE_PATH at the old store layout and dies in
#    node's module loader once the packages move. measured grove-1 2026-08-03:
#    two shells disagreed about which `rhx` they meant — zsh ran, bash died with
#    `Cannot find module 'with-simple-cache'`.
#
# ⇒ do NOT swap these two for tidiness. every declaration of this PATH claim
#   names one identical order (`rule.forbid.two-writers-on-one-artifact`), and
#   `5.1.node/provision.upsert.sh` carries the same pair for the same reason.
######################################################################
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;   # last prepend wins → /bin is first
esac

######################################################################
# aws — let an sdk read ~/.aws/config
#
# ⚠️ this flag makes aws-sdk v2 read ~/.aws/credentials UNCONDITIONALLY
#    v2's `Config.region` getter (node_loader.js:100) derives the region from
#    the shared ini files, and its loader opens the credentials file whether
#    or not a profile needs it — so an ABSENT ~/.aws/credentials throws
#
#      Error: ENOENT: no such file or directory, open '~/.aws/credentials'
#
#    a laptop always has that file, so this was harmless here for years. a
#    cloud grove does not: `5.6.aws.configure` writes ~/.aws/config alone,
#    because an ambient identity is a POINTER and never a stored key. that
#    phase now findserts an EMPTY credentials file for exactly this reason,
#    and its verify owns the claim (rule.require.seam-claims-have-an-owner)
######################################################################
export AWS_SDK_LOAD_CONFIG=1

######################################################################
# 📜 AWS_PROFILE is DELIBERATELY not exported here — removed 2026-08-08
#
# this file exported `AWS_PROFILE=ambient` for two days, guarded on the
# presence of `[profile ambient]`. it fixed one defect and caused a worse
# one, and the reason is a single line in rhachet's own type doc:
#
#   KeyrackHostVault.d.ts —
#     "os.envvar is always checked first in grant flow (ci passthrough)"
#
# ⚠️ so an exported AWS_PROFILE OUTRANKS EVERY RACK ENTRY, for every org and
#    every env. a box with a perfect rack never consults it. measured on
#    grove-1 2026-08-08, after `aws.reach.set` had written and PROVEN the
#    prep hop:
#
#      rack   ahbode.test.AWS_PROFILE = "ambient"   ← read off the ENV
#      profile ahbode.test.ehmpath    = …<prep-acct>:…/<prep-oidc-role> ✔
#      suite   all 44 refusals         = …<camp-acct>:…/<camp-grove-role>
#
#    the hop worked. no consumer could name it, because one shell variable
#    answered for all four envs.
#
# ⇒ the box's own identity is now a RACK fact, not a shell fact:
#     `<org>.camp.AWS_PROFILE = ambient`, set by `rhx aws.reach.set --env camp`
#   and a per-env identity is a rack fact too:
#     `<org>.test.AWS_PROFILE = <org>.test.<owner>`
#
# ⚠️ .what still answers the ORIGINAL defect (`AWS_PROFILE not set`)
#      two things, neither of which is an export:
#        1. the rack — `keyrack.source()` sets process.env.AWS_PROFILE per env
#        2. `[default]` in ~/.aws/config, written by `5.6.aws` — so a bare
#           `aws` call with NO profile named still finds a region and the
#           ambient credentials
#
#    ⇒ if `AWS_PROFILE not set` returns, the fix is a rack entry for that
#      org+env, never an export here. an export here would silently disable
#      every other env on the box.
#
# see: howdoes.a-box-reach-an-aws-account.md, failure 4
#      .agent/repo=.this/role=any/skills/aws.reach.set.sh
######################################################################
