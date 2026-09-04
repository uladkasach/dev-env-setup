#!/usr/bin/env bash
######################################################################
# .what = put the alias suite on the box, together
#
# .why the sourced files are RENAMED on the way over
#   - `bash_aliases.sh` sources them as `~/.bash_aliases.<name>.sh`
#   - the prefix keeps the set adjacent in a listed home dir
#   - ⇒ a reader who finds `.bash_aliases.ductwork.sh` knows what loads it
#   - the names must match the source lines inside `bash_aliases.sh` exactly
#
# 🛑 .the `pairs` array below is the SOLE declaration of the suite
#   - every count in this file is read from it, never written beside it
#   - 📜 the prose said "three" at four sites, and a fourth member was added
#   - ⇒ four stale sentences, none of which any check could redden
#   - `configure.verify` reads the SAME array, so the two halves cannot drift
#   - ⚠️ a new member needs the pair HERE, the pair in the verify, AND a source
#     line at the head of `bash_aliases.sh` — the `[[ -f ]]` guard makes an
#     absent source line silent, so the namespace just fails to exist
#
# .why every member lands before any is reported
#   - the suite is one claim
#   - a partial copy gives a shell that reports "no such file" at every login
#   - ⇒ every copy is checked, and the first failure names the file and its cost
#
# .why the source is `$GROVE_SRC`
#   - 📜 a `${DEV_ENV_SETUP_DIR:-$HOME/git/more/dev-env-setup}` default is WRONG in a worktree
#   - it copied MAIN's aliases while the run came from `_worktrees/…`
#   - ⇒ a pushed branch's change never landed, and the symptom was "my edit had no effect"
#
# ⚠️ .other readers hold their OWN pointer to these files
#   - a skill family (`git.grove.*`, `aws.ec2.get`, `term.*`, `wire.verify`,
#     `termwork.test`, `brains.auth.*`) and a permanent play walk to, or
#     hardcode, this bundle's collocated path directly — never through
#     `GROVE_SRC` or this bundle's dispatch
#   - ⇒ a rename or a further move here must update those readers too;
#     grep the tree for the bare filename before you move it again
#
# guarantee:
#   - idempotent: one copy per member, so a re-run converges
######################################################################

grove_provision_2_7_aliases_configure_upsert() {
  local bundle_dir="$GROVE_SRC/grove.provision/2.shell/2.7.aliases"

  # each pair is `<source name in the checkout>:<target name in $HOME>`
  local pairs=(
    "bash_aliases.sh:.bash_aliases"
    "ductwork.sh:.bash_aliases.ductwork.sh"
    "termwork.sh:.bash_aliases.termwork.sh"
    "brains.auth.sh:.bash_aliases.brains.auth.sh"
  )

  local pair src_name dst_name
  for pair in "${pairs[@]}"; do
    src_name="${pair%%:*}"
    dst_name="${pair##*:}"

    if [[ ! -f "$bundle_dir/$src_name" ]]; then
      echo "   ✋ the checkout has no $src_name" >&2
      echo "      ⇒ \$GROVE_SRC is this run's own checkout, so an absent file here" >&2
      echo "        means the checkout is incomplete rather than that the path is" >&2
      echo "        wrong (looked in: $bundle_dir)" >&2
      return 1
    fi

    if ! cp "$bundle_dir/$src_name" "$HOME/$dst_name"; then
      echo "   ✋ could not write ~/$dst_name" >&2
      echo "      ⇒ the suite is ONE claim: bash_aliases sources the other two by" >&2
      echo "        path, so a partial copy gives a shell that reports 'no such" >&2
      echo "        file' at every login — which reads as a broken alias file" >&2
      return 1
    fi
  done

  # ⚠️ the tally is read from the array, so a new member cannot leave a stale count
  echo "   • alias suite declared — ${#pairs[@]} files into \$HOME"
  echo "     open a new shell, or: source ~/.bash_aliases"
}
