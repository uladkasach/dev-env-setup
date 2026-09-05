#!/usr/bin/env bash
# .what = install debian's vim, idempotently, via pkg_install
# .why
#   - `pkg_install`, never a bare `apt install` — asserts the debian invariant
#   - no version pin, unlike 4.5.nvim — vim carries no config, so no api breaks

grove_provision_4_4_vim_provision_upsert() {
  pkg_install vim || return 1
  echo "   • vim ✔"
}
