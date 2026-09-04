#!/usr/bin/env bash
######################################################################
# .what = shared setup for every `rhx duct.*` skill
#
# .why  = the five duct verbs each need the SAME three moves — load the
#         installed aliases, guard that the function arrived, strip rhachet's
#         own flags. five copies of that is five places for a fix to miss one.
#
# .why  a fresh shell matters: an agent cannot verify ductwork by a `source`
#         into its own shell. that shell keeps the function definitions it read
#         at startup, and a re-read does not refresh them — so every check runs
#         the STALE code and passes over broken installed code. an `rhx` skill
#         spawns a NEW bash per invocation, which reads the installed file every
#         time. that is the only way a check speaks about the code the human
#         runs, and it is what makes a duct verb testable at all.
#
# .note = this file is loaded by the duct.* skills, never run on its own
######################################################################

######################################################################
# .what = load the installed ductwork functions, or fail with the fix
# .why  = a skill that carried on without them would report a `command not
#         found` from three frames deep, which names no cure
######################################################################
__duct_skill_load() {
  # shellcheck source=/dev/null
  source ~/.bash_aliases 2>/dev/null || true

  local verb="$1"
  if ! command -v "$verb" &>/dev/null; then
    echo "✋ $verb not found — the installed aliases lack ductwork" >&2
    echo "   └─ fix: install this tree's version —" >&2
    echo "        rhx grove.provision --from tree --mode apply" >&2
    return 2
  fi
}

######################################################################
# .what = drop rhachet's own flags, keep the caller's
# .why  = rhachet forwards --skill/--repo/--role into the skill's argv; a duct
#         verb would reject them as unknown args
# .how  = sets the global array DUCT_SKILL_ARGS
#
# .note a bare `--` ends the strip — every arg after it is literal, so a value
#       that looks like a flag still reaches through
######################################################################
__duct_skill_args() {
  DUCT_SKILL_ARGS=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --) shift; DUCT_SKILL_ARGS+=("$@"); break ;;
      --skill|--repo|--role) shift 2 ;;
      *) DUCT_SKILL_ARGS+=("$1"); shift ;;
    esac
  done
}
