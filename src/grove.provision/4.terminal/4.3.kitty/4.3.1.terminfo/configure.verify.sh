#!/usr/bin/env bash
# .what = prove the erase declaration is on disk, the half this run CAN prove
#   with no interactive tty
# .why it is a HALF-check
#   - the declaration is "a future interactive session erases on ^?"
#   - an upgrade run is a play sent down a duct, stdin closed, stdout a pipe
#   - so it observes only the DECLARATION in the rc file, never whether a
#     later session actually applies it
# .why it says UNPROVEN rather than encode that in a code
#   - a silent 0 would claim the erase byte is right on the next session
#   - this check has no authority to make that claim (rule.forbid.failhide)
# .how it becomes a real proof
#   - drive it from inside an interactive session; compare `stty -a`'s erase
#     char against ^?
#
# guarantee:
#   - READ-ONLY. it reads rc files and repairs no state
#
# exit:
#   0 = the declaration is in place. whether it TAKES is stated in the output:
#       proven when this run owns a tty that erases on ^?, else a 🌙 unproven line
#   1 = the declaration is ABSENT from every rc — the upsert did not take

grove_provision_4_3_1_terminfo_configure_verify() {
  local marker="# grove.provision:4.3.1.terminfo"
  local rc found=()

  # both rc files are read though configure.upsert writes only ~/.bashrc —
  # `2.5.zsh` byte-owns ~/.zshrc (cp + cmp -s equality), so the line ships
  # inside `src/zshrc.sh` instead, and `2.5.zsh` delivers it. this asks "is
  # the declaration on disk?", never "did I write it?" — so one grep proves
  # both shells, and stays green on the healthy zsh case
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [[ -f "$rc" ]] || continue
    grep -qF "$marker" "$rc" && found+=("${rc##*/}")
  done

  # the half this CAN prove: is the declaration on disk at all?
  if [[ ${#found[@]} -eq 0 ]]; then
    echo "   ✋ the erase declaration is ABSENT from every rc file" >&2
    echo "      ⇒ the configure.upsert did not take, so backspace stays broken" >&2
    echo "        for a human whose tty erases on ^H" >&2
    echo "      fix: rhx grove.provision --what 4.3.1.terminfo --mode apply" >&2
    return 1
  fi

  echo "   • the erase declaration is present in: ${found[*]}"

  # if this run DOES happen to own a tty, take the free real check
  if [[ -t 0 ]]; then
    local erase; erase="$(stty -a 2>/dev/null | tr ';' '\n' | grep -o 'erase = [^;]*' | head -1)"
    case "$erase" in
      *"^?"*) echo "   • and this tty erases on ^? ✔ — the declaration TAKES here"
              return 0 ;;
      *"^H"*) echo "   ✋ but this tty still erases on ^H" >&2
              echo "      ⇒ the rc line is present and did not take. read why:" >&2
              echo "        a later rc line, or a login that reads a different rc" >&2
              return 1 ;;
    esac
  fi

  # the honest verdict from a non-interactive run: it returns 0 because the
  # half this bundle CAN claim holds, and it says the other half is unproven
  echo "   🌙 unverified — this run owns no interactive tty, so whether the"
  echo "      declaration TAKES cannot be observed from here"
  echo "      to check by hand, from inside a kitty ssh session:"
  echo "        rhx git.grove.send <grove> --play diagnose.terminfo.over-ssh"
}
