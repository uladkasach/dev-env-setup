#!/usr/bin/env bash
######################################################################
# .what = prove a NON-INTERACTIVE LOGIN SHELL — what every robot runs — finds
#         node and pnpm
#
# ⚠️ it launches a real `bash -lc` rather than grep the hook
#   - a marker in ~/.profile proves the text arrived and no more
#   - an earlier `exit`, a later PATH overwrite, or a moved fnm each break it
#   - ⇒ `bash -lc 'node -v'` IS what a robot does
#   - ⇒ it is the only test that tells "the bytes arrived" from "it works"
#
# .the parity claim lives here, never in provision.verify
#   - provision asks whether the box HAS node; this asks if a robot can FIND it
#   - ⇒ a box that passes the first and fails the second is the whole defect
#
# ⚠️ every probe is wrapped in `timeout`
#   - 📜 2026-07-30: a bare `bash -lc 'pnpm --version'` hung the plan forever
#   - corepack's shim asks "Do you want to continue? [Y/n]" and READS STDIN
#   - 📜 `pnpm --version` sat in ep_poll 57 minutes on grove-1 that way
#   - a login shell is arbitrary code, so any rc file may block
#   - ⇒ a verify that hangs is WORSE than one that reports wrong
#   - `</dev/null` is the second half, so a prompt fails at once
#
# guarantee:
#   - READ-ONLY: the login shell it opens runs only `--version` reads
#   - BOUNDED: no probe here can hang the run
######################################################################

# .what = run one command in a login shell, bounded, with no stdin to block on
#
# ⚠️ it keeps only the LAST line, since a login shell sources every rc file
#   - 📜 laptop 2026-07-30: two lines back — an rc file's hello, then "v22.21.0"
#   - ⇒ a phase that reports the whole capture reports chatter as the version
grove_provision_5_1_node_login_probe() {
  timeout -k 5 10 bash -lc "$1" </dev/null 2>/dev/null | tail -1
}

grove_provision_5_1_node_configure_verify() {
  local failed=0
  local profile="$HOME/.profile"
  local marker="# grove: fnm + pnpm on PATH for login shells"

  # 🛑 the LEGACY fence — every box converged before 2026-09-02 carries it
  #   - the fence word moved `# devenv:` → `# grove:` at the suite cutover
  #   - ⇒ a verify that reads one word reports `✋ ABSENT` on a converged box
  #   - ⇒ the upsert reads both, so a half that cuts the set its own way
  #     disagrees with its own pair
  #   - (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9)
  local marker_was="# devenv: fnm + pnpm on PATH for login shells"

  ####################################################################
  # 1. the hook is declared — asked first, so an absent hook names ITS fix
  ####################################################################
  if [[ -r "$profile" ]] \
    && { grep -F "$marker" "$profile" >/dev/null \
      || grep -F "$marker_was" "$profile" >/dev/null; }; then
    echo "   • the node PATH hook is declared in ~/.profile ✔"
  else
    echo "   ✋ the node PATH hook is ABSENT from ~/.profile" >&2
    echo "      ⇒ ubuntu's ~/.bashrc returns early for a non-interactive shell," >&2
    echo "        so absent this hook a robot gets no node while a human does" >&2
    echo "      fix: rhx grove.provision --what 5.1.node --mode apply" >&2
    failed=1
  fi

  ####################################################################
  # 2. THE claim — a robot's own shell finds node
  ####################################################################
  local node_v
  node_v="$(grove_provision_5_1_node_login_probe 'node --version')"
  if [[ -n "$node_v" ]]; then
    echo "   • a login shell finds node ✔ ($node_v)"
  else
    echo "   ✋ a non-interactive login shell canNOT find node" >&2
    echo "      ⇒ this is what every robot runs — 'ssh host cmd', 'bash -lc'," >&2
    echo "        a detached grove run. so every automated caller on this box" >&2
    echo "        fails while a human at a prompt sees a healthy machine" >&2
    echo "      read what it gets: bash -lc 'echo \$PATH'" >&2
    echo "      fix: rhx grove.provision --what 5.1.node --mode apply" >&2
    failed=1
  fi

  ####################################################################
  # 3. and pnpm, which is the package manager every repo here declares
  ####################################################################
  local pnpm_v
  pnpm_v="$(grove_provision_5_1_node_login_probe 'pnpm --version')"
  if [[ -n "$pnpm_v" ]]; then
    echo "   • a login shell finds pnpm ✔ ($pnpm_v)"
  else
    echo "   ✋ a non-interactive login shell canNOT find pnpm (or it timed out)" >&2
    echo "      ⇒ an automated install falls back to npm and writes the wrong" >&2
    echo "        lockfile, which then conflicts with every other checkout" >&2
    echo "      ⇒ a TIMEOUT here means corepack's shim asked a question and" >&2
    echo "        waited on stdin — export CI=1 so it never prompts" >&2
    echo "      read what a login shell gets: timeout -k 5 10 bash -lc 'pnpm --version'" >&2
    echo "      fix: rhx grove.provision --what 5.1.node --mode apply" >&2
    failed=1
  fi

  ####################################################################
  # 4. the interactive shell's cd hook canNOT open a prompt
  #
  # ⚠️ this claim belongs to 5.1.node though the FILE belongs to 2.5.zsh
  #   - an absent `~/.zshrc` is 2.5's verdict, so it reports 🌙 here, never ✋
  #   - "the fnm cd hook cannot ask a question" is a NODE fact, and a seam:
  #
  #       2.5.zsh  asserts ~/.zshrc is present, current, and parses   → ✔
  #       5.1.node asserts node and pnpm answer in a login shell      → ✔
  #
  #   - ⇒ both stay green while a `cd` into a pinned repo hangs on stdin
  #   - (`rule.require.seam-claims-have-an-owner`)
  #
  # ⚠️ an unhardened hook is a ✋, never a nitpick
  #   - fnm's stock `--use-on-cd` prompts on stdin for an absent pin
  #   - a duct IS tmux, so that question eats the NEXT command as its answer
  #   - ⇒ the run does not fail, it does the WRONG WORK, silently
  #   - (`rule.forbid.tty-as-a-proxy-for-a-human`)
  #
  # .the ZSHRC is read and no shell is launched
  #   - the hook fires on `chpwd` in an INTERACTIVE zsh, which this is not
  #   - ⇒ a probe that DID reproduce it is a probe that can hang
  #   - (`rule.require.judge-declared-state-not-live-state`)
  ####################################################################
  local zshrc="$HOME/.zshrc"
  if [[ ! -r "$zshrc" ]]; then
    echo "   🌙 whether the fnm cd hook can prompt cannot be observed —"
    echo "      no readable ~/.zshrc. that absence is 2.5.zsh's ✋"
  elif grep -F -- '--install-if-missing' "$zshrc" >/dev/null; then
    echo "   • the fnm cd hook installs rather than asks ✔"
  else
    echo "   ✋ the fnm cd hook can open an interactive prompt" >&2
    echo "      ⇒ ~/.zshrc names no 'fnm use --install-if-missing', so a 'cd'" >&2
    echo "        into a repo whose .nvmrc pins an absent version asks:" >&2
    echo "          Do you want to install it? answer [y/N]:" >&2
    echo "      ⇒ a duct IS tmux, so that question holds the pane and then" >&2
    echo "        consumes the next command sent down the duct as its answer." >&2
    echo "        the run does not fail — it does the wrong work, silently" >&2
    echo "      ⇒ measured on grove-1 2026-08-03: one such 'cd' sat 4m16s" >&2
    echo "      fix: rhx grove.provision --what 2.5.zsh --mode apply" >&2
    failed=1
  fi

  return $failed
}
