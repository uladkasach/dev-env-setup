#!/usr/bin/env bash
######################################################################
# .what = prove `~/.zshrc` exists, matches the checkout, and parses as zsh
#
# .why the file is DIFFED against the checkout and not merely stat'd
#   - a stale rc exists, works, and is simply an older revision
#   - ⇒ it is invisible to a file test
#   - the symptom is "my edit had no effect", which a human blames on their edit
#
# .why `zsh -n` is run and not just a diff
#   - a byte-identical copy of a BROKEN rc passes a diff
#   - zsh reports a parse error at LOGIN, after the run said it converged
#   - ⇒ the human is left in a half-loaded shell
#
# guarantee:
#   - READ-ONLY. it diffs two files and parses one; it opens no shell
#
# exit:
#   0 = the rc is present, current, and parses
#   1 = a claim failed, and which is named
######################################################################

grove_provision_2_5_zsh_configure_verify() {
  local failed=0
  local rc_live="$HOME/.zshrc"
  local bundle_dir="$GROVE_SRC/grove.provision/2.shell/2.5.zsh"
  local rc_src="$bundle_dir/zshrc.sh"

  ####################################################################
  # 1. present at all
  ####################################################################
  if [[ ! -f "$rc_live" ]]; then
    echo "   ✋ no ~/.zshrc on this box" >&2
    echo "      ⇒ every login lands in a bare zsh: no aliases, no prompt, no" >&2
    echo "        repo:branch title" >&2
    echo "      fix: rhx grove.provision --what 2.5.zsh --mode apply" >&2
    return 1
  fi

  ####################################################################
  # 2. current — the same bytes the checkout declares
  ####################################################################
  if [[ ! -f "$rc_src" ]]; then
    echo "   ✋ the checkout has no zshrc at $rc_src to compare against" >&2
    echo "      ⇒ so whether ~/.zshrc is current cannot be judged at all" >&2
    failed=$(( failed + 1 ))
  elif cmp -s "$rc_src" "$rc_live"; then
    echo "   • ~/.zshrc matches the checkout ✔"
  else
    echo "   ✋ ~/.zshrc DIFFERS from the checkout" >&2
    echo "      ⇒ the live rc is a different revision, which is invisible to a" >&2
    echo "        file test: it exists, it works, it is simply older. the symptom" >&2
    echo "        is 'my edit had no effect', which a human blames on the edit" >&2
    echo "      read why: diff $rc_src $rc_live" >&2
    echo "      fix: rhx grove.provision --what 2.5.zsh --mode apply" >&2
    failed=$(( failed + 1 ))
  fi

  ####################################################################
  # 3. it parses — a byte-perfect copy of a broken rc still breaks every login
  #
  # .why an absent zsh is a 🌙 here
  #   - the parse cannot be attempted without zsh
  #   - zsh's ABSENCE is the provision phase's claim, which already reported it
  #   - ⇒ a second ✋ for one fact leaves a red line this phase can never clear
  ####################################################################
  if ! command -v zsh >/dev/null 2>&1; then
    echo "   🌙 zsh is absent, so the rc cannot be parsed here"
    echo "      the provision phase above owns that claim"
  elif zsh -n "$rc_live" 2>/dev/null; then
    echo "   • ~/.zshrc parses as zsh ✔"
  else
    echo "   ✋ ~/.zshrc does NOT parse as zsh" >&2
    echo "      ⇒ zsh reports the error at LOGIN — after this run said it" >&2
    echo "        converged — and leaves the human in a half-loaded shell" >&2
    echo "      read why: zsh -n $rc_live" >&2
    failed=$(( failed + 1 ))
  fi

  ####################################################################
  # 4. ~/.zshenv — present, current, and it parses
  #
  # .why it is verified beside the rc rather than trusted — it carries the env a
  #   NON-INTERACTIVE zsh needs, the shell no human ever looks at, so a stale or
  #   absent zshenv shows up only as some program's own error
  #   .refs = gotcha.a-tool-found-by-path-answers-only-a-human
  local env_live="$HOME/.zshenv"
  local env_src="$bundle_dir/zshenv.sh"

  if [[ ! -f "$env_live" ]]; then
    echo "   ✋ no ~/.zshenv on this box" >&2
    echo "      ⇒ every non-interactive zsh runs with none of the env a program" >&2
    echo "        reads — and the rc cannot cover it, because zsh opens an rc" >&2
    echo "        for interactive shells only" >&2
    echo "      fix: rhx grove.provision --what 2.5.zsh --mode apply" >&2
    failed=$(( failed + 1 ))
  elif [[ ! -f "$env_src" ]]; then
    echo "   ✋ the checkout has no zshenv at $env_src to compare against" >&2
    failed=$(( failed + 1 ))
  elif cmp -s "$env_src" "$env_live"; then
    echo "   • ~/.zshenv matches the checkout ✔"
  else
    echo "   ✋ ~/.zshenv DIFFERS from the checkout" >&2
    echo "      read why: diff $env_src $env_live" >&2
    echo "      fix: rhx grove.provision --what 2.5.zsh --mode apply" >&2
    failed=$(( failed + 1 ))
  fi

  if [[ -f "$env_live" ]] && command -v zsh >/dev/null 2>&1; then
    if zsh -n "$env_live" 2>/dev/null; then
      echo "   • ~/.zshenv parses as zsh ✔"
    else
      echo "   ✋ ~/.zshenv does NOT parse as zsh" >&2
      echo "      ⇒ zshenv runs on EVERY zsh, so a parse error here breaks every" >&2
      echo "        command a program shells out to, not merely a human's login" >&2
      echo "      read why: zsh -n $env_live" >&2
      failed=$(( failed + 1 ))
    fi
  fi

  # .what = 5. 🛑 the rc's OSC emitters must not pass a CONTROL BYTE to the terminal
  # .why both emitters put a DIRECTORY NAME inside an OSC string, and a linux dir
  #   name may hold any byte but `/` and NUL — BEL ENDS an OSC string, so a dir named
  #   `x<BEL><ESC>]52;c;<b64><BEL>` hands the terminal a fresh OSC 52, and with
  #   `set-clipboard on` in `src/tmux.conf` that WRITES THIS HUMAN'S CLIPBOARD
  # .why the tree is REACHABLE with no other step — `git.grove.pull` writes a tree
  #   the GROVE named, and `_osc7_cwd` fires on every `cd`
  # .why the strip is RUN rather than grepped for, and every emit site is READ
  #   rather than matched by a bare word — .refs = gotcha.2-5-zsh.demo=osc-control-byte-strip
  # .why `zsh -f`, in a subshell — it sources no rc, opens no interactive shell,
  #   and changes not one byte
  if [[ -f "$rc_live" ]] && command -v zsh >/dev/null 2>&1 && command -v od >/dev/null 2>&1; then
    local osc_hex
    osc_hex="$(
      zsh -f -c '
        emulate -L zsh
        # the payload a hostile dir name carries: BEL, then a fresh OSC 52
        evil=$(printf "x\ay\033]52;c;ZXZpbA==\azz")
        print -rn -- "${evil//[[:cntrl:]]/}"
      ' 2>/dev/null | od -An -tx1 | tr '\n' ' '
    )" || osc_hex=""
    osc_hex="$osc_hex "

    local osc_let="" osc_probe
    for osc_probe in "07:BEL" "1b:ESC"; do
      [[ "$osc_hex" == *" ${osc_probe%%:*} "* ]] && osc_let="$osc_let ${osc_probe#*:}"
    done

    # ── every EMIT SITE must reach a strip, and the set is READ, never a word
    #    an emit is a printf of an OSC, or a tmux pane-option set. a site is
    #    covered when it strips inline, or when the value it emits was assigned
    #    from a strip within two hops — `_osc7_cwd` strips PWD into `safe`,
    #    renames it to `url_path`, and emits THAT.
    local osc_code osc_sites osc_bare=0 osc_total=0 osc_bare_lines=""
    osc_code="$(grep -nvE '^[[:space:]]*#' "$rc_live" || true)"
    osc_sites="$(printf '%s\n' "$osc_code" \
      | grep -E "printf[^|]*\\\\(e|033)\]|tmux set -p @" || true)"
    while IFS= read -r osc_site; do
      [[ -n "$osc_site" ]] || continue
      osc_total=$(( osc_total + 1 ))
      local osc_ln="${osc_site%%:*}" osc_txt="${osc_site#*:}" osc_ok=0 osc_v osc_asn
      [[ "$osc_txt" == *'[[:cntrl:]]'* ]] && osc_ok=1
      if [[ "$osc_ok" -eq 0 ]]; then
        for osc_v in $(printf '%s\n' "$osc_txt" \
          | grep -oE '\$\{?[A-Za-z_][A-Za-z0-9_]*' | sed 's/^\${\{0,1\}//' || true); do
          local osc_hop
          for osc_hop in 1 2; do
            osc_asn="$(printf '%s\n' "$osc_code" \
              | grep -E "(^|[^A-Za-z0-9_])$osc_v=" | head -1 || true)"
            [[ -n "$osc_asn" ]] || break
            if [[ "$osc_asn" == *'[[:cntrl:]]'* ]]; then osc_ok=1; break; fi
            osc_v="$(printf '%s\n' "$osc_asn" \
              | grep -oE '\$\{?[A-Za-z_][A-Za-z0-9_]*' | head -1 | sed 's/^\${\{0,1\}//' || true)"
            [[ -n "$osc_v" ]] || break
          done
          [[ "$osc_ok" -eq 1 ]] && break
        done
      fi
      if [[ "$osc_ok" -eq 0 ]]; then
        osc_bare=$(( osc_bare + 1 ))
        osc_bare_lines="$osc_bare_lines $osc_ln"
      fi
    done <<< "$osc_sites"

    if [[ "$osc_hex" == " " ]]; then
      echo "   🌙 the rc's control-byte strip could not be exercised here"
      echo "      (zsh answered an empty stream; the parse check above owns that)"
    elif [[ -n "$osc_let" ]]; then
      echo "   ✋ zsh's \${x//[[:cntrl:]]/} LET THROUGH:$osc_let" >&2
      echo "      ⇒ ~/.zshrc puts a DIRECTORY NAME inside an OSC string, and a" >&2
      echo "        BEL there ENDS the sequence — so the rest of the name is" >&2
      echo "        fresh terminal input. with set-clipboard on, an OSC 52 in a" >&2
      echo "        pulled directory's name writes this human's clipboard" >&2
      echo "      fix: this zsh build needs a different strip; the rc's guard is" >&2
      echo "        inert on it. read why: rule.require.security-paramount" >&2
      failed=$(( failed + 1 ))
    elif [[ "$osc_total" -eq 0 ]]; then
      echo "   ✋ ~/.zshrc names NO OSC emitter this reader can see" >&2
      echo "      ⇒ the rc emits OSC 7 on every cd and OSC 2 on every title" >&2
      echo "        set, so zero sites means the reader lost its subject —" >&2
      echo "        an unread claim is never a pass" >&2
      echo "      read why: grep -nE \"printf[^|]*\\\\\\\\(e|033)\\]\" $rc_live" >&2
      failed=$(( failed + 1 ))
    elif [[ "$osc_bare" -gt 0 ]]; then
      echo "   ✋ ~/.zshrc emits $osc_bare of $osc_total OSC site(s) with NO strip" >&2
      echo "      at line(s):$osc_bare_lines" >&2
      echo "      ⇒ a directory name may hold any byte but '/' and NUL, and a" >&2
      echo "        BEL ends an OSC string — so the name's tail is fresh input" >&2
      echo "      fix: \${PWD//[[:cntrl:]]/} and \${title//[[:cntrl:]]/}, on" >&2
      echo "        EVERY emitter — the two OSC printfs and both tmux options" >&2
      failed=$(( failed + 1 ))
    else
      echo "   • ~/.zshrc strips control bytes at all $osc_total OSC emit sites ✔"
    fi
  fi

  [[ "$failed" -eq 0 ]] || return 1
}
