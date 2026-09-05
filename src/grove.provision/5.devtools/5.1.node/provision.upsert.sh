#!/usr/bin/env bash
# .what = install fnm, the LTS node it manages, and pnpm
# .ref  = https://github.com/Schniz/fnm
# .why
#   - the BINARY, never fnm's shell installer — that installer re-appends a
#     PATH block to ~/.bashrc on every run, and ubuntu's ~/.bashrc returns
#     early for a non-interactive shell; the binary install writes no rc
#     line, so no second writer exists (rule.forbid.two-writers-on-one-artifact)
#   - fnm is put on PATH by hand here, so it can install node in THIS shell;
#     `configure` names that same dir for every later shell
#   - a node version is read back rather than aliased — `--lts` is an install
#     flag, never a version alias
#   - every corepack call leans on `CI=1`, declared once at the driver
#     .refs = gotcha.5-1-node.demo=fnm-pnpm-install-measurements, m1
#
# guarantee:
#   - the same verified bytes land at the same path with the same mode
#   - the fnm binary is NEVER placed unless its bytes matched their pinned digest

grove_provision_5_1_node_provision_upsert() {
  # the PINNED RELEASE ASSET, never `https://fnm.vercel.app/install` — that
  # url serves a shell installer to fetch and EXECUTE, unversioned, so no
  # hash is expressible (rule.require.verify-binary-downloads)
  # .refs = gotcha.5-1-node.demo=fnm-pnpm-install-measurements, m2
  local fnm_version="v1.39.0"
  local fnm_sha256="sha256:7807664f39d39fc518da1c35ba0181e4b3267603c4b1dedeb4b5fc6ae440a224"
  local fnm_url="https://github.com/Schniz/fnm/releases/download/${fnm_version}/fnm-linux.zip"
  local fnm_home="$HOME/.local/share/fnm"

  # a PRIVATE temp dir — this path holds a file that becomes EXECUTABLE, and
  # a fixed /tmp/fnm.zip in a 1777 dir is claimable by any seat on the box
  # (src/grove.web.sh)
  local tmp_dir
  tmp_dir="$(web_tempdir fnm)" || return 1

  # runs UNCONDITIONALLY, no `command -v fnm` short-circuit — a re-run
  # converges by construction and self-heals a corrupt binary
  # (rule.require.idempotent-install-procedures)
  if ! web_fetch "$fnm_url" --into "$tmp_dir/fnm.zip"; then
    echo "   ✋ could not download fnm ${fnm_version}" >&2
    echo "      ⇒ with no node, every rhachet/npm-driven tool on this box is" >&2
    echo "        unreachable — web_fetch named the wire fault above" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  # verify BEFORE the unpack — the file it yields is made executable soon after
  if ! web_verify_sha256 --file "$tmp_dir/fnm.zip" --sha256 "$fnm_sha256"; then
    echo "      ⇒ fnm is NOT installed, and the archive is discarded unopened." >&2
    echo "        a box with no node beats a box that unpacked bytes nobody" >&2
    echo "        vouched for" >&2
    rm -rf "$tmp_dir"
    return 1
  fi
  echo "   • fnm ${fnm_version} verified against its pinned sha256 ✔"

  # -j flattens the archive's dirs, so the binary lands at a known path; -o
  # overwrites, which keeps a re-run idempotent
  if ! unzip -oqj "$tmp_dir/fnm.zip" -d "$tmp_dir/out"; then
    echo "   ✋ could not unpack the fnm archive" >&2
    echo "      ⇒ it matched its pinned digest, so the bytes are correct — this" >&2
    echo "        is unzip itself. confirm it is present: command -v unzip" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  if [[ ! -f "$tmp_dir/out/fnm" ]]; then
    echo "   ✋ the fnm archive carried no 'fnm' binary" >&2
    echo "      ⇒ upstream changed the archive's layout — name the new path here," >&2
    echo "        never loosen the check. read what it holds:" >&2
    echo "      unzip -l $tmp_dir/fnm.zip" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  mkdir -p "$fnm_home" || { rm -rf "$tmp_dir"; return 1; }
  if ! install -m 0755 "$tmp_dir/out/fnm" "$fnm_home/fnm"; then
    echo "   ✋ could not place fnm at $fnm_home/fnm" >&2
    echo "      ⇒ verified download — check the dir is writable: ls -ld $fnm_home" >&2
    rm -rf "$tmp_dir"
    return 1
  fi
  rm -rf "$tmp_dir"

  export PATH="$fnm_home:$HOME/.fnm:$PATH"
  if ! command -v fnm >/dev/null 2>&1; then
    echo "   ✋ fnm is not on PATH after its install" >&2
    echo "      ⇒ placed at $fnm_home/fnm but not found there, so node cannot" >&2
    echo "        be installed. read why: ls -l $fnm_home/fnm" >&2
    return 1
  fi
  eval "$(fnm env --shell bash)"

  fnm install --lts || return 1

  # the default is named by the `lts-latest` ALIAS, never by a `fnm list`
  # scrape — a scrape of the last line can name a nightly instead of the LTS
  # .refs = gotcha.5-1-node.demo=fnm-pnpm-install-measurements, m3
  if ! fnm default lts-latest; then
    echo "   ✋ fnm has no 'lts-latest' alias after 'fnm install --lts'" >&2
    echo "      ⇒ with no default, node is on PATH in no shell. read what it" >&2
    echo "        holds: fnm list" >&2
    return 1
  fi
  fnm use lts-latest
  echo "   • node $(fnm current 2>/dev/null) set as the fnm default"

  # the BASELINE versions land beside the lts, never instead of it — an
  # absent .nvmrc pin opens an interactive fnm prompt a duct cannot answer.
  # declared in `_.sh`, since provision.verify judges the same set
  # (rule.require.identical-bundle-composition). the default stays the LTS
  # .refs = gotcha.5-1-node.demo=fnm-pnpm-install-measurements, m4
  local want roster
  roster="$(fnm list 2>/dev/null || true)"   # read ONCE; only this loop changes the set

  while read -r want; do
    [[ -n "$want" ]] || continue

    # `fnm install` of a version already present exits NON-ZERO, so a bare
    # call would fail every second run (rule.require.idempotent-install-procedures)
    if grove_node_version_present "$want" "$roster"; then
      echo "   • node v$want already present — skipped"
      continue
    fi

    if fnm install "$want"; then
      echo "   • node v$want installed"
      roster="$roster"$'\n'"v$want"
    else
      echo "   ✋ fnm could not install node v$want" >&2
      echo "      ⇒ a repo that pins it opens fnm's interactive install prompt on" >&2
      echo "        every 'cd', which a duct cannot answer" >&2
      echo "      ⇒ check the version is real: fnm list-remote | grep v$want" >&2
      return 1
    fi
    # process substitution, never a pipe — a piped `while read` runs in a
    # SUBSHELL, so `roster` would reset each pass (gotcha.while-read-drops-the-last-line)
  done < <(grove_node_versions_wanted)

  # pnpm's global bin dir goes on PATH BEFORE a global install, else corepack
  # refuses. BOTH spellings are named — pnpm treats PNPM_HOME itself as the
  # bin dir, corepack reports a /bin child — and the PRUNE at the end of this
  # function, not PATH order, is what makes that safe
  # (rule.forbid.two-writers-on-one-artifact, applied to a $PATH entry)
  export PNPM_HOME="$HOME/.local/share/pnpm"
  mkdir -p "$PNPM_HOME/bin"
  export PATH="$PNPM_HOME/bin:$PNPM_HOME:$PATH"

  # pnpm goes on EVERY node this box holds, never merely the default — a
  # per-version failure is NOT fatal; provision.verify owns the verdict.
  # install the DECLARED version, never `pnpm@latest`
  # (rule.require.pinned-versions). an undeclared pin is a HARD stop, never
  # a fall back to `@latest` (rule.forbid.failhide)
  # .refs = gotcha.5-1-node.demo=fnm-pnpm-install-measurements, m5
  local pnpm_want
  pnpm_want="$(grove_pnpm_version_wanted)"

  # an empty answer means the manifest is absent (checkout partial) OR
  # declares none (repo at fault) — an absent manifest cascades into claims
  # on FOUR other bundles, each innocent
  # .refs = gotcha.5-1-node.demo=fnm-pnpm-install-measurements, m6
  local pnpm_manifest; pnpm_manifest="$(dirname "$GROVE_SRC")/package.json"
  if [[ ! -f "$pnpm_manifest" ]]; then
    echo "   ✋ no package.json beside this checkout's src/ ($pnpm_manifest)" >&2
    echo "      ⇒ checkout is PARTIAL — package.json and .nvmrc sit beside src/," >&2
    echo "        and a push of src/ alone sends neither; this is the HEAD of a" >&2
    echo "        cascade (no pnpm ⇒ no rhx ⇒ no keyrack ⇒ no gh token). fix it" >&2
    echo "        here, not downstream" >&2
    echo "      fix: send the manifests, then re-run —" >&2
    echo "        rhx git.grove.push <grove> --from package.json --into 'git/more/dev-env-setup' --mode apply" >&2
    echo "        rhx git.grove.push <grove> --from .nvmrc --into 'git/more/dev-env-setup' --mode apply" >&2
    return 1
  fi
  if [[ -z "$pnpm_want" ]]; then
    echo "   ✋ $pnpm_manifest declares no pnpm version" >&2
    echo "      ⇒ expected \"packageManager\": \"pnpm@<x>\" (declapract stamps it" >&2
    echo "        into every repo) — a defect in the REPO, not this box; absent" >&2
    echo "        it, this phase would fall to pnpm@latest, and grow two pnpms" >&2
    return 1
  fi
  echo "   • pnpm pinned to $pnpm_want (declared by packageManager)"

  local ver pnpm_absent=()
  while read -r ver; do
    [[ -n "$ver" ]] || continue
    fnm use "$ver" --silent-if-unchanged >/dev/null 2>&1 || continue

    # `web_corepack`/`web_npm`, never the bare tools — this loop runs PER
    # NODE VERSION, so one silent-registry stall multiplies. `corepack
    # enable` stays BARE, since it reaches no registry
    # .refs = gotcha.5-1-node.demo=fnm-pnpm-install-measurements, m7
    corepack enable || true
    if ! web_corepack install -g "pnpm@$pnpm_want"; then
      echo "   • corepack declined pnpm for node v$ver — fall back to npm"
      web_npm install -g "pnpm@$pnpm_want" || pnpm_absent+=("v$ver")
    fi
  done < <(grove_node_versions_wanted; echo "lts-latest")

  fnm use lts-latest --silent-if-unchanged >/dev/null 2>&1 || true   # back to the box's default

  if [[ "${#pnpm_absent[@]}" -gt 0 ]]; then
    echo "   🌙 pnpm could not be installed for: ${pnpm_absent[*]}"
    echo "      a 'cd' into a repo that pins one of those gets node without pnpm"
    echo "      read why: fnm use <version> && corepack install -g pnpm@$pnpm_want"
  fi

  # report the pnpm that ANSWERS, never the one just installed. a PATH
  # explanation for a mismatch is FALSE — corepack's shim dispatches on
  # `packageManager`, so one binary answers two versions. reports rather
  # than deletes — a mismatched pnpm may be the human's
  # .refs = gotcha.5-1-node.demo=fnm-pnpm-install-measurements, m8, m9
  local pnpm_live
  pnpm_live="$(pnpm --version 2>/dev/null)"
  if [[ "$pnpm_live" == "$pnpm_want" ]]; then
    echo "   • pnpm $pnpm_live ✔"
  else
    # `cd ~` is the diagnostic that discriminates — the answer is a property
    # of the DIRECTORY, never of PATH; asked from `~`, where no repo
    # declares one, it reports the global pin
    echo "   🌙 pnpm answers $pnpm_live here, and this phase installed $pnpm_want"
    echo "      corepack's shim dispatches on the nearest 'packageManager' field —"
    echo "      one binary, two versions, not two binaries"
    echo "      read why: cd ~ && pnpm --version   # away from any declaration"
  fi

  # prune the SHADOWED shims — pnpm's own fossils, in pnpm's own dirs. pnpm
  # moved its shim dir between 10.x and 11.x, so a box that ran both holds a
  # stale copy that outranks the live one on PATH. this does NOT contradict
  # the "report, do not delete" stance above — that guards a STRAY pnpm; this
  # prune touches only pnpm's OWN dirs, and the live dir is pnpm's ANSWER,
  # never a constant here
  # .refs = gotcha.5-1-node.demo=fnm-pnpm-install-measurements, m10
  local shadow shadows=() pruned=() live_dir fossil_dir
  live_dir="$(grove_pnpm_shim_dir_live)"
  while read -r shadow; do
    [[ -n "$shadow" ]] || continue
    shadows+=("$shadow")
  done < <(grove_pnpm_shim_shadows)

  if [[ "${#shadows[@]}" -eq 0 ]]; then
    echo "   • no shadowed pnpm shims ✔ (live dir: ${live_dir:-<pnpm did not answer>})"
  else
    if [[ "$live_dir" == "$PNPM_HOME/bin" ]]; then fossil_dir="$PNPM_HOME"; else fossil_dir="$PNPM_HOME/bin"; fi
    for shadow in "${shadows[@]}"; do
      rm -f "$fossil_dir/$shadow" && pruned+=("$shadow")
    done
    echo "   • pruned ${#pruned[@]} shadowed shim(s) from $fossil_dir: ${pruned[*]}"
    echo "     (each also lives in $live_dir, which is the dir pnpm writes)"
  fi
}
