#!/usr/bin/env bash
# .what = prove the config is on this box AND that starship accepts it
# .why "the file is here" is the weaker half — a toml with a typo, or one
#   written for an older starship, stays in place and the prompt silently
#   falls back to defaults, so the box LOOKS configured and reads wrong
#   (rule.forbid.failhide)
# .why `print-config`, not a `grep` for a known key, and why its exit code
#   alone is not trusted, and why a caveat prints to stdout not stderr
#   .refs = gotcha.2-6-starship.demo=worktree-source-and-parse-check
#
# guarantee:
#   - READ-ONLY. it reads the config and re-emits it to /dev/null
#
# exit:
#   0 = a config is here and starship parses it
#   1 = it is absent or unparseable, and the fix is named

grove_provision_2_6_starship_configure_verify() {
  local conf="$HOME/.config/starship.toml"
  local bin="$HOME/.local/bin/starship"

  if [[ ! -f "$conf" ]]; then
    echo "   ✋ no starship.toml at $conf" >&2
    echo "      ⇒ configure.upsert did not take, so the prompt draws defaults" >&2
    echo "      fix: rhx grove.provision --what 2.6.starship --mode apply" >&2
    return 1
  fi

  # can starship READ it? this is the half a file test cannot answer
  if [[ -x "$bin" ]]; then
    local out=""
    if out="$(STARSHIP_CONFIG="$conf" "$bin" print-config 2>&1)"; then
      echo "   • starship.toml found and parsed ✔"
    # no `-q`: under the driver's `pipefail`, `grep -q` SIGPIPEs the producer
    # on a match, so a MATCH can read as 141 (gotcha.pipefail-grep-q)
    elif echo "$out" | grep -iE 'unrecognized|unknown|invalid subcommand|USAGE' >/dev/null; then
      echo "   • starship.toml found ✔ (parse UNCHECKED)"
      echo "     ⇒ this starship has no \`print-config\`, so the parse cannot be"
      echo "       asked. update this verify to whatever its cli offers instead"
    else
      echo "   ✋ starship cannot parse $conf" >&2
      echo "      ⇒ the file is here and the prompt falls back to defaults, so the" >&2
      echo "        box looks configured and reads wrong" >&2
      echo "      said: $(echo "$out" | head -3)" >&2
      return 1
    fi
  else
    echo "   • starship.toml found ✔ (parse UNCHECKED — no binary to ask)"
    echo "     ⇒ provision.verify reports the binary; read its line above"
  fi

  # drift from the repo is a note, never a failure — see the header. compare
  # against $GROVE_SRC, this run's OWN checkout, never main
  local src="$GROVE_SRC/grove.provision/2.shell/2.6.starship/starship.toml"
  if [[ -f "$src" ]] && ! cmp -s "$src" "$conf"; then
    echo "     note: the live config DIFFERS from the repo's"
    echo "     ⇒ a hand-edit, or a stale copy from before the last change:"
    echo "       diff $src $conf"
  fi
}
