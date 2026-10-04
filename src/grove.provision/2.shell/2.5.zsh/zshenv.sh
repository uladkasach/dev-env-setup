#!/usr/bin/env zsh
######################################################################
# ~/.zshenv — the env that must reach EVERY zsh, not only a human's
#
# .what = environment variables that a NON-INTERACTIVE zsh must also carry
# .why
#   - 🛑 `~/.zshrc` reaches an INTERACTIVE zsh alone — `zsh -c`, `sg docker -c`,
#     a jest child, and an ssh command read this file and no other
#   - ⇒ a path or pointer a PROGRAM must read belongs here; an rc is a HUMAN's
#   - it stays SMALL: .zshenv runs on every zsh, hot paths too. it must hold no
#     prompt work, no completion load, and no command that costs more than a test
#   - every prepend is guarded, since a nested zsh reads this file again
# .refs = gotcha.2-5-zsh.demo=zshenv-reaches-every-zsh — every block, measured
#
# owner: 2.5.zsh (`configure.upsert` copies it; `configure.verify` diffs it)
######################################################################

# ~/.local/bin — git execs its credential helper by NAME (m2)
if [ -d "$HOME/.local/bin" ]; then
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
  esac
fi

# ~/.cargo/bin — nvim-treesitter EXECS `tree-sitter` (m3). the dir is restated
# rather than `~/.cargo/env` sourced, since that file prepends unguarded
if [ -d "$HOME/.cargo/bin" ]; then
  case ":$PATH:" in
    *":$HOME/.cargo/bin:"*) ;;
    *) export PATH="$HOME/.cargo/bin:$PATH" ;;
  esac
fi

# node's PATH chain (m4). the fnm dir that holds BINARIES is `aliases/default/bin`
# — the DATA dir holds none, and the `fnm env` dir dies with its shell. it
# carries corepack's `pnpm` too, so the pnpm block below is no alternative
FNM_DEFAULT_BIN="${FNM_DIR:-$HOME/.local/share/fnm}/aliases/default/bin"
if [ -d "$FNM_DEFAULT_BIN" ]; then
  case ":$PATH:" in
    *":$FNM_DEFAULT_BIN:"*) ;;
    *) export PATH="$FNM_DEFAULT_BIN:$PATH" ;;
  esac
fi
unset FNM_DEFAULT_BIN

# the fnm BINARY, and `FNM_MULTISHELL_PATH` — `fnm use` cannot run without both,
# and only `fnm env` sets the second (m5, issue #140)
# 🛑 the mint is GUARDED on the PATH ENTRY, never the var alone — a set var with
#    its dir off PATH is a reachable state, and a var-only guard skips it (m6)
# 🛑 never a hardcoded FNM_MULTISHELL_PATH — two shells would fight over one node
FNM_BIN_DIR="${FNM_DIR:-$HOME/.local/share/fnm}"
if [ -x "$FNM_BIN_DIR/fnm" ]; then
  case ":$PATH:" in
    *":$FNM_BIN_DIR:"*) ;;
    *) export PATH="$FNM_BIN_DIR:$PATH" ;;
  esac

  # the FACT, not its proxy: a dir already reachable on PATH
  FNM_MS_REACHED=0
  if [ -n "${FNM_MULTISHELL_PATH:-}" ]; then
    case ":$PATH:" in
      *":$FNM_MULTISHELL_PATH/bin:"*) FNM_MS_REACHED=1 ;;
    esac
  fi
  if [ "$FNM_MS_REACHED" -eq 0 ]; then
    eval "$(fnm env --shell zsh)"
  fi
  unset FNM_MS_REACHED
fi
unset FNM_BIN_DIR

# BOTH $PNPM_HOME and $PNPM_HOME/bin — `/bin` prepended LAST so it lands FIRST,
# since a stale shim in the other dies in node's loader (m7). do NOT swap them:
# `5.1.node/provision.upsert.sh` names the same order
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;   # last prepend wins → /bin is first
esac

# aws — let an sdk read ~/.aws/config. ⚠️ v2 then opens ~/.aws/credentials
# UNCONDITIONALLY, so `5.6.aws` findserts an empty one on a grove (m8)
export AWS_SDK_LOAD_CONFIG=1

# 🛑 AWS_PROFILE is DELIBERATELY not exported here. an env var OUTRANKS every
#    rack entry, for every org and env — one export answered for all four envs
#    (m9). if `AWS_PROFILE not set` returns, the fix is a RACK entry, never this
