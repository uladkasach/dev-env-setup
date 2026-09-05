#!/usr/bin/env bash
######################################################################
# .what = shared setup for every `rhx term.*` skill
#
# .why  = the five term verbs each need the SAME three moves — load the
#         installed aliases, guard that the function arrived, strip rhachet's
#         own flags. five copies of that is five places for a fix to miss one.
#
# .why  a fresh shell matters: an agent cannot verify termwork by a `source`
#         into its own shell. that shell keeps the function definitions it read
#         at startup, and a re-read does not refresh them — so every check runs
#         the STALE code and passes over broken installed code. an `rhx` skill
#         spawns a NEW bash per invocation, which reads the installed file every
#         time. that is the only way a check speaks about the code the human
#         runs, and it is what makes a term verb testable at all.
#
# ⚠️ this MIRRORS `duct.operations.sh` and is deliberately a second copy
#   - the two differ in the one place that matters: the fix-text names the
#     absent file, and `~/.bash_aliases.termwork.sh` is a different artifact
#     than `~/.bash_aliases.ductwork.sh`
#   - a shared helper would have to take that path as an argument, which is a
#     parameter for a two-member set (rule.prefer.wet-over-dry)
#
# .note = this file is loaded by the term.* skills, never run on its own
######################################################################

######################################################################
# .what = load the installed termwork functions, or fail with the fix
# .why  = a skill that carried on without them would report a `command not
#         found` from three frames deep, which names no cure
######################################################################
__term_skill_load() {
  # shellcheck source=/dev/null
  source ~/.bash_aliases 2>/dev/null || true

  local verb="$1"
  if ! command -v "$verb" &>/dev/null; then
    echo "✋ $verb not found — the installed aliases lack termwork" >&2
    echo "   └─ fix: install this tree's version —" >&2
    echo "        rhx grove.provision --from tree --mode apply" >&2
    return 2
  fi
}

######################################################################
# .what = drop rhachet's own flags, keep the caller's
# .why  = rhachet forwards --skill/--repo/--role into the skill's argv; a term
#         verb would reject them as unknown args
# .how  = sets the global array TERM_SKILL_ARGS
#
# .note a bare `--` ends the strip — every arg after it is literal, so a value
#       that looks like a flag still reaches through
######################################################################
__term_skill_args() {
  TERM_SKILL_ARGS=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --) shift; TERM_SKILL_ARGS+=("$@"); break ;;
      --skill|--repo|--role) shift 2 ;;
      *) TERM_SKILL_ARGS+=("$1"); shift ;;
    esac
  done
}
