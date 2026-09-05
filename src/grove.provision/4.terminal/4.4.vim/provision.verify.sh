#!/usr/bin/env bash
######################################################################
# .what = prove vim is on PATH AND that it is a real vim, not a `vi` stub
#
# .why  the second claim exists at all
#         debian ships `vim-tiny`, which puts a `vim` on PATH that lacks most of
#         what a human reaches for mid-repair. `command -v vim` cannot tell the
#         two apart — both answer with a path — so a presence check reports ✔ on
#         a box where the fallback editor is a stub.
#
#         `vim --version` names the build, so it is the cheapest test that
#         distinguishes "a vim exists" from "the vim we declared exists".
#
# guarantee:
#   - READ-ONLY. it observes; it mutates no state
######################################################################

grove_provision_4_4_vim_provision_verify() {
  if ! command -v vim >/dev/null 2>&1; then
    echo "   ✋ vim is absent from PATH" >&2
    echo "      ⇒ a bad nvim upgrade would leave this box with NO editor, and on" >&2
    echo "        a grove there is no second window to repair it from" >&2
    echo "      fix: rhx grove.provision --what 4.4.vim --mode apply" >&2
    return 1
  fi

  local head
  head="$(vim --version 2>/dev/null | head -1)"

  ####################################################################
  # vim-tiny reports itself as "Small version"; the full builds report Huge,
  # Big, or Normal. so the tiny build is named directly rather than the set of
  # acceptable ones — a new upstream label should not read as a defect
  ####################################################################
  # .why no -q: it would exit on match and SIGPIPE vim, which `pipefail` turns
  #      into a false 0 here — so a vim-tiny would report as a full build, the
  #      UNSAFE direction of the trap (gotcha.pipefail-grep-q)
  if vim --version 2>/dev/null | grep 'Small version' >/dev/null; then
    echo "   ✋ the vim on PATH is vim-tiny, not the full vim" >&2
    echo "      ⇒ it lacks most of what a human reaches for mid-repair, so the" >&2
    echo "        fallback editor is a stub exactly when it is needed" >&2
    echo "      it said: $head" >&2
    echo "      fix: rhx grove.provision --what 4.4.vim --mode apply" >&2
    return 1
  fi

  echo "   • vim is present and is a full build ✔ ($head)"
}
