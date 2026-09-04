#!/usr/bin/env bash
######################################################################
# .what = the `xterm-kitty` terminfo entry, and the tty erase byte it needs
#
# .why it applies to EVERY machine — so there is no predicate to ask
#         the box that needs this entry is the box a kitty client CONNECTS TO, not
#         the box kitty runs on. so a headless grove needs it and a laptop already
#         has it — the reverse of the intuition its package name suggests.
#         `kitty-terminfo` names whose terminal it describes, never which machine
#         requires it.
#
# .why the two phases are separate
#         "backspace draws a space" has two independent causes, and a fix for one
#         leaves the other:
#
#           provision   no `xterm-kitty` entry, so `kbs` is unreadable
#           configure   the tty erases on ^H while kitty sends ^? (DEL, 0x7f)
#
# .the cost of its absence
#         on 2026-07-29 an absent entry on a grove surfaced as three complaints
#         that each read as its own bug — tmux refused to start ("unsuitable
#         terminal"), ncurses tools garbled, backspace drawn as a space. the check
#         that catches all three is one line, `infocmp xterm-kitty`.
#
# usage:
#   rhx grove.provision --what 4.3.1.terminfo --mode apply
######################################################################

grove_provision_4_3_1_terminfo() {
  bundle.upgrade 4.3.1.terminfo.provision.upsert
  bundle.upgrade 4.3.1.terminfo.provision.verify
  bundle.upgrade 4.3.1.terminfo.configure.upsert
  bundle.upgrade 4.3.1.terminfo.configure.verify
}
