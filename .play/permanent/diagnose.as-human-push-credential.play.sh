#!/usr/bin/env bash
######################################################################
# .what = report which link of the as-human push credential chain answers
# .why  = `git.commit.push --auth as-human` falls to a username prompt on a laptop;
#         this names the dead link. it prints field NAMES and lengths, never a value
######################################################################
set -uo pipefail

ask='protocol=https\nhost=github.com\npath=uladkasach/dev-env-setup.git\n\n'
shape() { awk -F= '{ printf "%s(%d) ", $1, length($2) } END { if (NR == 0) printf "naught" }'; }

echo "🔎 diagnose.as-human-push-credential"
echo "   ├─ GH_TOKEN in env:      $([[ -n "${GH_TOKEN:-}" ]] && echo set || echo unset)"
echo "   ├─ GITHUB_TOKEN in env:  $([[ -n "${GITHUB_TOKEN:-}" ]] && echo set || echo unset)"
echo "   ├─ gh, as is:            $(gh auth status --hostname github.com >/dev/null 2>&1 && echo logged-in || echo not-logged-in)"
echo "   ├─ gh, env tokens unset: $(env -u GH_TOKEN -u GITHUB_TOKEN gh auth status --hostname github.com >/dev/null 2>&1 && echo logged-in || echo not-logged-in)"
echo "   ├─ gh git-credential, env unset: $(printf "$ask" | env -u GH_TOKEN -u GITHUB_TOKEN gh auth git-credential get 2>/dev/null | shape)"
echo "   ├─ gh git-credential, as is:     $(printf "$ask" | gh auth git-credential get 2>/dev/null | shape)"
echo "   └─ git fill, as the patch runs it: $(printf "$ask" | env -u GH_TOKEN -u GITHUB_TOKEN GIT_TERMINAL_PROMPT=0 git -c credential.helper= -c 'credential.helper=!gh auth git-credential' credential fill 2>/dev/null | shape)"
