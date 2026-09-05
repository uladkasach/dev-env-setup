#!/usr/bin/env bash
######################################################################
# .what = the alias suite: `~/.bash_aliases` and the two files it sources
#
# .why THREE files are ONE bundle
#   - `bash_aliases.sh` sources `ductwork.sh` and `termwork.sh` by path
#   - ⇒ a bundle per file would let one land and the others not
#   - the failure reports "no such file" at every login
#   - that reads as a broken alias file, never as one absent member of a set
#   - ⇒ one claim: "the alias suite is on this box, whole"
#
# .why there is no PROVISION phase
#   - the suite is three checked-in shell files, so no package is owed
#   - ⇒ the phase would be empty
#   - an empty phase is a verdict a reader must account for with no fact behind it
#
# .why it applies to a HEADLESS box
#   - the name "bash aliases" reads like a comfort for a human at a keyboard
#   - `ductwork.sh` is the DUCT, which is how a grove is reached at all
#   - `git.grove` and `git.tree` are how work moves between boxes
#   - the six compound `git` aliases `2.2.git` declares all delegate into this file
#   - ⇒ without it those aliases exist and fail
#
# .why it comes AFTER `2.5.zsh`
#   - the zshrc sources `~/.bash_aliases`
#   - neither order breaks, since the rc is read at the next login, not at copy time
#   - ⇒ the order that matches the dependency is the one a reader can follow
######################################################################

grove_provision_2_7_aliases() {
  bundle.upgrade 2.7.aliases.configure.upsert
  bundle.upgrade 2.7.aliases.configure.verify
}
