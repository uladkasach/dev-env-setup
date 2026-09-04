#!/usr/bin/env bash
# .what = the shell section — each part a human's shell is made of
# .why it holds no predicate — a parent has no opinion on where its children
#   apply, and each child knows that about itself; a gate here would take a
#   claim from the bundle that owns it (rule.require.identical-bundle-composition)
# .why `2.9.emoji` is the ONE child that does not apply to a headless box —
#   its gestures are KEYSTROKES read by zle, and an agent that drives a
#   grove sends whole command strings and presses none; its decline is
#   written at that bundle
# .why EVERY OTHER child applies to a headless box — "shell" reads as a
#   comfort for a human at a keyboard, and it is the opposite: a grove's
#   whole surface IS its shell (2.1 = the tools its own skills call, 2.2 =
#   commit attribution, 2.3 = its front door, 2.5 = every duct's login
#   shell, 2.6 = which box a pane is on, 2.7 = `ductwork.sh` itself, 2.8 = a
#   duct IS tmux) — a "local only" gate on any of these leaves a grove
#   unreachable or unable to work, the EFFECT-vs-HOLD confusion this repo
#   has paid for four times
# .why the DISPATCH order and the NUMBER disagree on purpose — 2.1 gates
#   every later fetch, 2.2 needs a `git clone` before 2.8's tpm, 2.5 needs
#   to run before 2.6 (its own prompt) and before 2.7 (the zshrc that
#   sources `~/.bash_aliases`), and 2.7 runs before 2.2 because 2.2's
#   VERIFY reads `~/.bash_aliases`, which only 2.7 writes
#   .refs = gotcha.2-shell.demo=dispatch-order-and-empty-slot, m1
# .why the 2.4 slot is EMPTY, and is never refilled — gh's real dependency
#   is a credential from keyrack, not a shell tool, so the slot marks a
#   bundle that moved away, never one free for a newcomer to claim
#   .refs = gotcha.2-shell.demo=dispatch-order-and-empty-slot, m2
#
# usage:
#   rhx grove.provision --what 2.shell --mode apply

grove_provision_2_shell() {
  bundle.upgrade 2.1.toolkit
  bundle.upgrade 2.3.ssh
  bundle.upgrade 2.5.zsh
  bundle.upgrade 2.6.starship
  bundle.upgrade 2.7.aliases
  bundle.upgrade 2.2.git
  bundle.upgrade 2.8.tmux
  bundle.upgrade 2.9.emoji
}
