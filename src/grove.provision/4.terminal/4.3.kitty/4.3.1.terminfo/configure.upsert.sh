#!/usr/bin/env bash
######################################################################
# .what = shape the terminfo entry's USE — set the tty's erase byte to match
#         what kitty actually sends
#
#   - "backspaces render as spaces" has TWO independent causes
#   - the entry may be unfindable, which is provision's half
#   - or the tty's `erase` may say ^H while kitty sends ^? (DEL, 0x7f)
#   - a terminal draws an unhandled erase as a SPACE
#   - ⇒ two phases, so each cause is separately provable
#
# .in an rc, not a `stty` here-and-now
#   - a `stty` call in an installer touches its own tty and dies with it
#   - the declaration is about every FUTURE interactive session
#   - it is guarded on `[[ -t 0 ]]`, since every non-interactive shell reads rc files
#
# .the marker carries the slug, and a slug change must PRUNE
#   - a machine provisioned under an older slug carries that older marker
#   - a bare rename would match none of it and append a second block
#   - ⇒ every legacy marker is pruned before the current one is findserted
#
# guarantee
#   - idempotent: the block is findserted by marker, never appended twice
######################################################################

# .what = every marker this leaf has ever written, oldest first — the prune list
#
# ⚠️ these are LITERAL bytes on a box's disk, so a repo-wide rename must SKIP them
#   - rewrite one and the prune matches none of it
#   - the box then keeps the old block AND gains a new one
GROVE_TERMINFO_MARKERS_LEGACY=(
  "# grove.provision:44.terminfo.kitty"
  "# grove.provision:4.3.1.terminfo"
)

grove_provision_4_3_1_terminfo_configure_upsert() {
  local marker="# grove.provision:4.3.1.terminfo"
  local rc changed=0

  ####################################################################
  # ⚠️ .the loop is ~/.bashrc ALONE, though the declaration is owed to zsh too
  #   - `2.5.zsh` owns ~/.zshrc by BYTE, and its verify demands `cmp -s` equality
  #   - 📜 grove-1 2026-07-31: the two bundles overwrote each other, forever
  #   - ⚠️ this bundle never paid for it, since its verify accepts EITHER rc
  #   - ⇒ zsh is served the same line from `src/zshrc.sh`, which 2.5.zsh ships
  #   - this bundle keeps ~/.bashrc, which no bundle byte-owns
  ####################################################################
  for rc in "$HOME/.bashrc"; do
    [[ -f "$rc" ]] || continue

    # prune any legacy block first, so the findsert below cannot double it
    local legacy
    for legacy in "${GROVE_TERMINFO_MARKERS_LEGACY[@]}"; do
      grep -qF "$legacy" "$rc" || continue

      # delete the marker line through the `stty erase` line that closes its block
      local tmp; tmp="$(mktemp)"
      awk -v m="$legacy" '
        index($0, m) { skip = 1; next }
        skip && /stty erase/ { skip = 0; next }
        skip { next }
        { print }
      ' "$rc" > "$tmp" && mv "$tmp" "$rc"

      echo "   • ${rc##*/} — pruned a legacy erase block ($legacy)"
      changed=$(( changed + 1 ))
    done

    # findsert by marker: present means the declaration already holds here
    if grep -qF "$marker" "$rc"; then
      echo "   • ${rc##*/} already carries the erase declaration — no work"
      continue
    fi

    # .`[[ -t 0 ]]` is the interactive-tty guard
    #   - it sits inside the appended block on purpose
    #   - so the guard travels with the line, and no later reader can separate them
    cat >> "$rc" <<EOF

$marker
# .what — erase on ^? (DEL, 0x7f), which kitty and every modern terminal send
# .why
#   - when the tty erases on ^H instead, backspace is echoed rather than acted on
#   - an unhandled erase is drawn as a SPACE
[[ -t 0 ]] && stty erase '^?' 2>/dev/null
EOF
    echo "   • ${rc##*/} — erase declaration appended ✔"
    changed=$(( changed + 1 ))
  done

  if [[ "$changed" -eq 0 ]]; then
    return 0
  fi

  echo "   • takes effect in the NEXT interactive session (rc files are read at login)"
}
