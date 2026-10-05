#!/usr/bin/env bash
# .what = prove `claude()` enrolls through rhx ONLY inside a linked repo (an `.agent/`
#         at the git root), and launches bare claude everywhere else
# .how  = load the CHECKOUT's `claude()` alone, stub what it calls, call it from
#         three cwds, and assert which binary each would have launched. launches no claude
# .why  = an enroll outside a linked repo relocates CLAUDE_CONFIG_DIR into an actor dir
#         that does not exist there; the bare cli is the only correct launch
set -uo pipefail

repo="$(git rev-parse --show-toplevel)"
fn="$(awk '/^claude\(\) \{/,/^\}/' "$repo/src/grove.provision/2.shell/2.7.aliases/bash_aliases.sh")"
[[ -n "$fn" ]] || { echo "✋ could not find claude() in bash_aliases.sh"; exit 1; }

stubs="$(mktemp -d)"
trap 'rm -rf "$stubs"' EXIT
for name in rhx claude; do
  printf '#!/usr/bin/env bash\necho "LAUNCH: %s $*"\n' "$name" | tee "$stubs/$name" >/dev/null
  chmod +x "$stubs/$name"
done

fails=0
# assert the first launched binary from <dir> is <want>; print the argv as evidence
drive() {
  local label="$1" dir="$2" want="$3" out got
  out="$( cd "$dir" && PATH="$stubs:$PATH" XDG_RUNTIME_DIR="" bash -c "$fn"$'\n'"claude --probe" )"
  got="$(printf '%s\n' "$out" | awk '/^LAUNCH: /{print $2; exit}')"
  if [[ "$got" == "$want" ]]; then
    printf '   ✔ %s → %s\n' "$label" "$out"
    return 0
  fi
  printf '   ✋ %s → expected %s, got %s\n      %s\n' "$label" "$want" "${got:-naught}" "$out"
  fails=$((fails + 1))
}

echo "🔭 claude() enrolls only in a linked repo"
drive "linked repo ($repo)" "$repo" rhx
drive "home ($HOME)" "$HOME" claude
drive "no git root (/)" "/" claude

(( fails == 0 )) || { echo "   └─ ✋ ${fails} cwd(s) launched the wrong binary"; exit 1; }
echo "   └─ ✔ every cwd launched the right binary"
