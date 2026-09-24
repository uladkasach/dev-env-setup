#!/usr/bin/env bash
######################################################################
# .what = the robot brains — claude-code, rhachet, and codex, plus their config
#
# .why no phase CALLS another
#   - a delegated install-then-configure reports the CONFIG's status only,
#     so a failed install can read ✔ (`rule.forbid.failhide`)
#   - each phase installs or configures and returns its own status
#     (`rule.require.bundle-as-sole-declaration`)
#
# .why every machine, no decline
#   - a grove runs the brains too
#
# usage:
#   rhx grove.provision --what 5.3.brains --mode apply
######################################################################

####################################################################
# the brain pins — ONE declaration each, read by BOTH halves
#
# .why here, never beside the install
#   - the verify reads the LIVE BINARY against this same value
#     (`gotcha.a-check-that-cries-wolf`, m.9 / m.13)
#
# .why the criterion is WHO CAN PUBLISH
#   - first-party (rhachet, declastruct) is this org's own account;
#     third-party (codex, claude-code) is somebody else's, reached
#     by every box that floats it — the first-party float is accepted
#   - a top-level pin bounds only this package, never its dependency tree
#
# .why claude is `2.1.87`, not latest, and the verify asks the BINARY
#   - hooks are TRUNCATED beyond it (`define.claude-code-config.md`)
#   - claude's in-place updater rewrites `cli.js` and leaves the
#     package metadata behind, so a package-only check misses drift
#
# .refs = gotcha.5-3-brains-pins.demo=publish-path-and-drift.md
#
# .how to bump = a decision, so two steps, never one:
#   npm view @openai/codex version
#   codex --version
####################################################################
GROVE_BRAIN_CLAUDE_PIN="2.1.87"
GROVE_BRAIN_CODEX_PIN="0.128.0"

####################################################################
# the CANDIDATE claude — a second, PARALLEL install the default never sees
#
# .what = `claude.latest`, a newer cli a human can trial without moving the
#   pin above. `claude` stays the pin; `claude.latest` is the candidate.
#
# .why it cannot be expressed as a second pnpm global
#   pnpm global holds ONE version per package, so "both at once" has no way to
#   be said there. trialing a newer cli by a `pnpm install -g` bump is an
#   all-or-nothing flip whose only way back is a re-pin — and the pin exists
#   because hooks are TRUNCATED beyond it (`define.claude-code-config.md`),
#   so every guardrail in this repo rides on it.
#   ⇒ the candidate gets its own prefix, and the two live side by side
#
# 🔴 .why the shim is `claude.latest` and NEVER `claude`
#   `~/.local/bin` is prepended in `~/.zshrc` AFTER `.zshenv` laid down
#   $PNPM_HOME/bin, so it outranks the pnpm shims in a human's shell. a file
#   named `claude` there would silently become the default — the exact
#   all-or-nothing flip this declaration exists to avoid. the verify reads
#   for that file on every run.
#
# .why a SYMLINK named `latest`, rather than the name alone
#   `latest` reads two ways: npm's dist-tag RIGHT NOW (dynamic, a network
#   lookup per call), or the newest build INSTALLED HERE (static). the
#   symlink makes it the second, and makes it auditable —
#   `readlink ~/.local/opt/claude/latest` answers "latest as of when?"
#
# .how to opt OUT = set the pin to "". the next apply removes the shim, the
#   symlink, and every versioned prefix — and touches the default not at all
####################################################################
GROVE_BRAIN_CLAUDE_LATEST_PIN="2.1.280"        # "" = opted out; torn down next apply
GROVE_BRAIN_CLAUDE_LATEST_PREFIX="$HOME/.local/opt/claude"
GROVE_BRAIN_CLAUDE_LATEST_SHIM="$HOME/.local/bin/claude.latest"

####################################################################
# the candidate's memory cap
#
# ⚠️ .this RESTATES the 8G that `2.7.aliases/bash_aliases.sh` gives the `claude`
#   shell function, and the restatement is forced rather than sloppy: the shim
#   runs from `~/.local/bin` with no shell behind it, so it can source no alias
#   file and borrow no function from one — the same bind `src/machine/
#   kitty_snap_lowbatt` names for its absolute path.
#   ⇒ a bump wants BOTH. the twin lives at `bash_aliases.sh`, in `claude()`
#
# .why the cap is on the shim and not merely on a wrapper
#   the extant wrapper is a shell FUNCTION, so it caps a human's invocation and
#   no call a tool spawns. a shim is a file on PATH, so every caller gets it
####################################################################
GROVE_BRAIN_CLAUDE_LATEST_MEMMAX="8G"

####################################################################
# .what = which of THREE states does the candidate's install sit in?
# .why a state, never a boolean — ONE reader, so the upsert and the verify
#   cannot cut the same set two ways (`gotcha.a-check-that-cries-wolf`, m.9)
#
# 🛑 .why it reads the PIN and not merely the presence of a dir
#   the prefix is built in several steps (mkdir, package.json, pnpm add), so a
#   run cut partway leaves a dir that passes a presence test and holds no
#   binary. a presence guard would skip it on every apply thereafter and the
#   box would be unrepairable by the only command it was given
#   (`define.provision-defect-shapes`, shape 6)
#
# stdout: whole  = the pinned prefix holds a runnable bin AND `latest` names it
#         half   = something under the prefix exists and one of those does not
#         absent = never built
####################################################################
grove_provision_5_3_brains_claude_latest_state() {
  local dir="$GROVE_BRAIN_CLAUDE_LATEST_PREFIX/v$GROVE_BRAIN_CLAUDE_LATEST_PIN"

  [[ -d "$GROVE_BRAIN_CLAUDE_LATEST_PREFIX" ]] || { echo absent; return 0; }
  [[ -x "$dir/node_modules/.bin/claude" ]] || { echo half; return 0; }
  [[ "$(readlink "$GROVE_BRAIN_CLAUDE_LATEST_PREFIX/latest" 2>/dev/null)" == "v$GROVE_BRAIN_CLAUDE_LATEST_PIN" ]] \
    || { echo half; return 0; }
  echo whole
}

####################################################################
# .what = the shim, as the human's PATH lookup finds it
# .why  = ONE renderer, so the upsert WRITES and the verify DIFFS one text —
#   a shim asserted present and never CURRENT would keep an old cap, or an
#   old target, with no reader to notice
#
# ⚠️ .why it names `latest` and not the pinned dir
#   the symlink is the pointer a bump re-points. baked here, every bump would
#   need this file rewritten too, and a box whose shim lagged would run a
#   version the tree no longer declares
#
# ⚠️ .why `/bin/sh` and not bash — it is a two-branch exec with no bashism, and
#   `sh` is the one interpreter present before any bundle of this repo has run
####################################################################
grove_provision_5_3_brains_claude_latest_shim_render() {
  cat <<EOF
#!/bin/sh
# GENERATED by: rhx grove.provision --what 5.3.brains --mode apply
# the declaration lives in src/grove.provision/5.devtools/5.3.brains/_.sh
# an edit here is overwritten by the next apply
#
# .what = run the CANDIDATE claude, capped, without touching the pinned default
bin="\$HOME/.local/opt/claude/latest/node_modules/.bin/claude"

if [ ! -x "\$bin" ]; then
  echo "✋ the candidate claude is absent at \$bin" >&2
  echo "   fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
  exit 1
fi

# cap only in a real user session with systemd; else run bare — the same two
# branches the \`claude\` shell function takes in 2.7.aliases/bash_aliases.sh
if command -v systemd-run >/dev/null 2>&1 && [ -n "\$XDG_RUNTIME_DIR" ]; then
  exec systemd-run --user --scope --quiet --collect \\
    --slice=claude.slice \\
    -p MemoryMax=$GROVE_BRAIN_CLAUDE_LATEST_MEMMAX \\
    "\$bin" "\$@"
fi

exec "\$bin" "\$@"
EOF
}

grove_provision_5_3_brains() {
  bundle.upgrade 5.3.brains.provision.upsert
  bundle.upgrade 5.3.brains.provision.verify
  bundle.upgrade 5.3.brains.configure.upsert
  bundle.upgrade 5.3.brains.configure.verify
}
