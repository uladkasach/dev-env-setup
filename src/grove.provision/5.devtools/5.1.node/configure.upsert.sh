#!/usr/bin/env bash
######################################################################
# .what = declare the ~/.profile hook that puts fnm + pnpm on PATH for a
#         non-interactive LOGIN shell
#
# ⚠️ ~/.profile, never ~/.bashrc — the parity defect this repairs
#   - an interactive human reads ~/.zshrc, which already wires fnm
#   - `ssh host cmd`, `bash -lc`, and a detached run are non-interactive bash
#   - ubuntu's ~/.bashrc returns EARLY for exactly that case
#   - ⇒ node was present for a human and absent for every robot, on one box
#   - ⇒ whoever checks by hand finds a healthy machine, and every robot fails
#   - bash reads ~/.profile for a LOGIN shell, interactive or not
#
# ⚠️ a sentinel marker, never a blind append
#   - 📜 fnm's own installer appends its block per run, so a grove held two
#   - (`rule.require.idempotent-install-procedures`)
#
# guarantee:
#   - the marker short-circuits a second append
######################################################################

grove_provision_5_1_node_configure_upsert() {
  local profile="$HOME/.profile"
  local marker="# grove: fnm + pnpm on PATH for login shells"
  local ender="# grove: end fnm + pnpm hook"

  # 🛑 the LEGACY fence — every box converged before 2026-09-02 carries it
  #   - this phase finds its own past output BY THE FENCE STRING
  #   - a block under the old word misses that grep, so the phase WRITES
  #   - ⇒ the box ends with TWO PATH export blocks, and no run sees the stale one
  local marker_was="# devenv: fnm + pnpm on PATH for login shells"
  local ender_was="# devenv: end fnm + pnpm hook"

  # ⚠️ an old box must reach the STALE path, never the write path
  #   - ⇒ the fence is repointed at whatever this box actually holds
  #   - a box with neither keeps the current fence and writes fresh
  if ! grep -F "$marker" "$profile" >/dev/null 2>&1 \
     && grep -F "$marker_was" "$profile" >/dev/null 2>&1; then
    marker="$marker_was"
    ender="$ender_was"
  fi

  # .the one line whose CONTENT this phase claims
  #   - a hook with any other PATH order is stale, however present its marker
  local wanted='export PATH="$HOME/.local/share/fnm:$PNPM_HOME/bin:$PNPM_HOME:$HOME/.local/bin:$PATH"'

  touch "$profile" || {
    echo "   ✋ could not create $profile" >&2
    return 1
  }

  # ⚠️ the guard reads the PATH LINE, never the marker
  #   - a marker-only guard is idempotent for PRESENCE and blind to CONTENT
  #   - ⇒ every box would keep its first hook forever, and print `skipped`
  #   - ⇒ a PATH-order correction would ship and reach no box
  #   - ⇒ the question is "is the hook this phase DECLARES present?"
  #   - (`rule.require.judge-declared-state-not-live-state`)
  #
  # .no `-q` here, since grep reads a FILE and no SIGPIPE can arise
  #   - the shape is uniform so no reader judges which greps are safe
  #   - (`gotcha.pipefail-grep-q`)
  if grep -F "$marker" "$profile" >/dev/null; then
    if grep -F "$wanted" "$profile" >/dev/null; then
      echo "   • node PATH hook already current in ~/.profile; skipped"
      return 0
    fi

    echo "   • node PATH hook in ~/.profile is STALE — replacing it"

    local tmp
    tmp="$(mktemp)" || { echo "   ✋ could not make a temp file" >&2; return 1; }
    # .the drop ends at `fi`, then eats an ender if one follows
    #   - the CURRENT block is `marker … fi, ender`, the LEGACY one has no ender
    #   - ⇒ the extra line is consumed only when it IS the ender
    #   - ⇒ a legacy block's next line is untouched, so no box is stranded
    if ! awk -v m="$marker" -v e="$ender" '
      $0 == m            { drop = 1; next }
      drop && $0 == "fi" { drop = 0; tail = 1; next }
      tail               { tail = 0; if ($0 == e) next }
      !drop
    ' "$profile" > "$tmp"; then
      rm -f "$tmp"
      echo "   ✋ could not rewrite $profile" >&2
      return 1
    fi
    if ! cp "$tmp" "$profile"; then
      rm -f "$tmp"
      echo "   ✋ could not write $profile" >&2
      echo "      ⇒ the stale hook is still in place; bash login shells keep the" >&2
      echo "        wrong pnpm PATH order until it is removed" >&2
      return 1
    fi
    rm -f "$tmp"
  fi

  if ! cat >> "$profile" <<'HOOK'; then

# grove: fnm + pnpm on PATH for login shells
# .why = ~/.bashrc returns early when non-interactive, so no robot reads it
#   - ~/.profile is read for any LOGIN shell
#
# ⚠️ $PNPM_HOME/bin comes BEFORE $PNPM_HOME — a TIEBREAK, not the fix
#   - pnpm writes a shim into BOTH dirs across versions, so one command has two
#   - a stale shim HARDCODES a NODE_PATH at the old store layout, so it survives
#     a reinstall and then dies in node's module loader
#   - 📜 grove-1 2026-08-02 → 08-03, the two shells on opposite orders:
#
#       bash -lc  → ~/.local/share/pnpm/rhx      (stale) → Cannot find module
#                                                 'with-simple-cache'
#       zsh -lc   → ~/.local/share/pnpm/bin/rhx  (fresh) → runs
#
#   - a DUCT is zsh, so every duct proof measured the healthy shim
#   - ⇒ the one command a human runs got the broken one
#   - ⇒ ONE order, named identically in every shell
#   - (`rule.forbid.two-writers-on-one-artifact`, applied to a $PATH entry)
#
# ⚠️ the order is a tiebreak and NOT the fix — the cause is the CWD
#   - corepack's `pnpm` runs the version the nearest `packageManager` names
#   - 📜 grove-1 2026-08-06, both answers within one second:
#
#       cwd = a repo   packageManager pnpm@10.24.0 → 10.24.0 → $PNPM_HOME
#       cwd = $HOME    no package.json above it    → 11.20.0 → $PNPM_HOME/bin
#
#   - ⇒ which dir is live is a fact about PLACE, never a drift over time
#   - ⇒ a hardcoded winner is meaningless rather than merely fragile
#   - the fix is `5.1.node`'s pin of corepack's global default, plus its prune
#   - this order only makes every shell agree meanwhile
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$HOME/.local/share/fnm:$PNPM_HOME/bin:$PNPM_HOME:$HOME/.local/bin:$PATH"
if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --shell bash)"
fi
# grove: end fnm + pnpm hook
HOOK
    echo "   ✋ could not append the node PATH hook to $profile" >&2
    echo "      ⇒ node stays visible to a human and absent to every robot on" >&2
    echo "        this box — the parity split this hook exists to close" >&2
    return 1
  fi

  echo "   • node PATH hook declared → ~/.profile"
}
