#!/usr/bin/env bash
# .what = make neovim EXIST at a pinned version
# .why
#   - the official tarball, never a ppa — both ppas are unusable here
#     (.refs = gotcha.4-5-nvim.demo=tarball-source-and-order, m1)
#   - a pinned sha256, not a signature — neovim publishes no gpg signature for
#     release assets (rule.require.verify-binary-downloads); the value below
#     is github's own server-computed asset digest. bump VERSION and SHA256
#     together: gh api repos/neovim/neovim/releases/tags/vX.Y.Z | jq -r '.assets[].digest'
#   - the ppa packages are removed first — a ppa-managed /usr/bin/nvim shadows
#     /usr/local/bin/nvim on a default PATH

# is the pinned neovim ALREADY the binary this box serves? asks both the path
# and the version, so a /usr/local/bin/nvim at another version is not a match.
# no network, no sudo, no lock
grove_provision_4_5_nvim_pinned() {
  local version="$1"
  [[ -x /usr/local/bin/nvim ]] || return 1

  # reads a VARIABLE, never a pipeline's status — `head -1`/`grep -q` each
  # SIGPIPE the stage before under `set -o pipefail`, so a match can read 141
  # and a false 141 drops this into the root half for work already done
  # (gotcha.pipefail-grep-q)
  local first; first="$(/usr/local/bin/nvim --version 2>/dev/null | awk 'NR==1')"
  [[ "$first" == *"v${version}"* ]]
}

# the half of this upsert only root can do — drop the ppa, fetch and
# hash-check the tarball, extract to /opt, link on PATH. kept as its own
# function so the upsert can skip it entirely when the goal already holds
grove_provision_4_5_nvim_provision_root() {
  local version="$1"
  local sha256="$2"
  # the url is PASSED, never rebuilt — declared once beside the version and
  # the pin, so `prove.sha256-pins-bite` reads all three from one place
  local url="$3"
  local archive; archive="$(basename "$url")"

  # the three args are ASSERTED — a caller that passed two would give
  # `url=""` and a silent `web_fetch ""`; a gap here is a CALL-SITE defect,
  # never a fact about this box
  if [[ -z "$version" || -z "$sha256" || -z "$url" ]]; then
    echo "   ✋ nvim's root half was called without its pin" >&2
    echo "      ├─ version: ${version:-<empty>}" >&2
    echo "      ├─ sha256:  ${sha256:-<empty>}" >&2
    echo "      └─ url:     ${url:-<empty>}" >&2
    echo "      ⇒ all three are declared together in the upsert above and passed" >&2
    echo "        down as \$1 \$2 \$3. a gap here is a CALL-SITE defect, never a" >&2
    echo "        fact about this box — fix the call, do not retry the apply" >&2
    return 1
  fi

  # a PRIVATE temp dir — step 4 hands this path to root, and a fixed
  # /tmp/nvim-install in a 1777 dir would let another seat's tree extract
  # into /opt as root (src/grove.web.sh)
  local tmp_dir
  tmp_dir="$(web_tempdir nvim)" || return 1

  # every write below is root's and lands OUTSIDE every $HOME; a seat with no
  # root declines rather than fails — ground sets it, the verify reads it
  bundle.root.owns "the pinned neovim build" \
    "want v${version} at /usr/local/bin/nvim" || return 0

  # 1. drop any ppa-managed neovim, so /usr/bin cannot shadow the tarball.
  # `software-properties-common` (add-apt-repository) is installed here since
  # this bundle is its one consumer (rule.require.bundles-own-their-dependencies);
  # every call below is tolerant, since a box that never had the ppa is common
  pkg_install software-properties-common >/dev/null 2>&1 || true
  pkg_apt add-apt-repository --remove ppa:neovim-ppa/unstable -y >/dev/null 2>&1 || true
  pkg_apt add-apt-repository --remove ppa:neovim-ppa/stable   -y >/dev/null 2>&1 || true
  pkg_apt apt-get remove -y neovim neovim-runtime >/dev/null 2>&1 || true

  # 2. fetch the pinned tarball (no rm -rf/mkdir — web_tempdir made this dir
  # fresh, empty, and private)
  if ! web_fetch "$url" --into "$tmp_dir/$archive"; then
    echo "   ✋ could not download neovim v${version}" >&2
    echo "      ⇒ without it this box has no editor, and every nvim keybind," >&2
    echo "        brief, and diff tool this repo declares is unreachable" >&2
    echo "      ⇒ web_fetch named the wire fault above — a STALL and a 404 have" >&2
    echo "        different fixes, so read which one it was" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  # 3. the integrity gate, between the wire and `sudo tar -xzf … -C /opt` —
  # that path is symlinked onto every user's PATH next
  if ! web_verify_sha256 --file "$tmp_dir/$archive" --sha256 "$sha256"; then
    echo "      ⇒ neovim REFUSED; the artifact is discarded rather than handed" >&2
    echo "        to root. to bump, read the digest github computed:" >&2
    echo "        gh api -X GET repos/neovim/neovim/releases/tags/v${version} --jq '.assets[].digest'" >&2
    rm -rf "$tmp_dir"
    return 1
  fi
  echo "   • neovim v${version} tarball sha256 verified ✔"

  # 4. extract to /opt, and expose on a PATH dir that precedes /usr/bin
  sudo rm -rf /opt/nvim-linux-x86_64
  if ! sudo tar -xzf "$tmp_dir/$archive" -C /opt; then
    echo "   ✋ could not extract the neovim tarball into /opt" >&2
    echo "      read why: the tar error above — usually no space on /opt" >&2
    rm -rf "$tmp_dir"
    return 1
  fi
  rm -rf "$tmp_dir"

  if ! sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim; then
    echo "   ✋ could not link /usr/local/bin/nvim" >&2
    echo "      ⇒ the binary sits in /opt but off PATH, so 'nvim' finds the ppa" >&2
    echo "        build if one survives, or no editor at all" >&2
    return 1
  fi

  echo "   • neovim v${version} installed → /opt/nvim-linux-x86_64 (nvim on PATH)"
}

grove_provision_4_5_nvim_provision_upsert() {
  # the three locals are named `nvim_*` and the url is spelled out here —
  # `prove.sha256-pins-bite` reads `<name>_version`/`_sha256`/`_url` and
  # substitutes `${nvim_version}` as literal text
  # (rule.require.identical-bundle-composition)
  local nvim_version="0.12.3"
  local nvim_sha256="c441b547142860bf01bcce39e36cbed185c41112813e15443b16e5237750724d"
  local nvim_url="https://github.com/neovim/neovim/releases/download/v${nvim_version}/nvim-linux-x86_64.tar.gz"

  # ASK WHAT ALREADY HOLDS before the privilege to change it is asserted —
  # a sudo-first order breaks the whole phase chain on a converged box
  # .refs = gotcha.4-5-nvim.demo=tarball-source-and-order, m2
  if grove_provision_4_5_nvim_pinned "$nvim_version"; then
    echo "   • neovim v${nvim_version} is already the pinned build ✔ (no root work left)"
  else
    grove_provision_4_5_nvim_provision_root \
      "$nvim_version" "$nvim_sha256" "$nvim_url" || return 1
  fi

  # tree-sitter-cli is NOT here — it is `5.14.treesitter`. the crate needs
  # cargo, which arrives with `5.2.rust`, a LATER bundle, so a build here
  # could never run on a first apply (rule.require.one-command-provision)

  # imagemagick — the CONVERT half of inline images. not fatal: an editor
  # with no inline image render is diminished, never broken
  if ! pkg_install imagemagick; then
    echo "   • imagemagick absent — inline image render and image diffs stay off" >&2
  fi
}
