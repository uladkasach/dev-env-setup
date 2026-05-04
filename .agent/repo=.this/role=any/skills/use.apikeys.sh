#!/usr/bin/env bash
######################################################################
# .what = source API keys for bhrain review skills
#
# .why  = enables guard reviews that need API access
#         this is a stub for repos that don't have keyrack setup
#
# .note = this file is sourced, not executed
######################################################################

# check if rhx keyrack is available and unlock if so
if command -v rhx &> /dev/null; then
  rhx keyrack unlock --owner ehmpath --env test 2>/dev/null || true
fi

# export any required environment variables if not already set
# (guards may need these for bhrain review skills)
