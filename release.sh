#!/usr/bin/env sh
#
# Maintainer release script. Builds the PHAR, cross-compiles standalone
# binaries for every platform with phpacker, signs the macOS ones, and
# publishes them as a GitHub release on this repo (public repo = public,
# no-auth downloads for everyone).
#
#   ./release.sh v1.0.0
#
# Release notes come from notes/<version>.md when it exists; otherwise they
# are generated from the commit subjects since the previous tag, grouped by
# Conventional Commit type.
#
# Requires: php, ./vendor/bin/phpacker, gh (authenticated: `gh auth login`),
# run inside the repo with its GitHub remote configured.

set -eu

VERSION="${1:-}"
[ -n "$VERSION" ] || { echo "usage: ./release.sh vX.Y.Z" >&2; exit 1; }

cd "$(dirname "$0")"

REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
echo "==> Releasing $VERSION to $REPO"

echo "==> Building PHAR (without dev dependencies)"
composer install --no-dev --optimize-autoloader --no-interaction --quiet
php pbin app:build pbin --build-version="$VERSION" --no-interaction
cp -f builds/pbin builds/pbin.phar   # phpacker.json src points here
composer install --no-interaction --quiet   # restore dev deps (phpacker is one)

echo "==> Cross-building all platforms with phpacker"
# Authenticated GitHub API calls avoid the 60/hour anonymous rate limit;
# phpacker reads the token from $_ENV, hence variables_order.
GITHUB_TOKEN="$(gh auth token)" php -d variables_order=EGPCS ./vendor/bin/phpacker build all --no-interaction

echo "==> Packaging release assets"
# Each binary ships compressed (~35 MB -> ~15 MB), holding a single "pbin" (or
# "pbin.exe"): half the upload and half of every user's download. Homebrew
# unpacks archives itself; install.sh/install.ps1 unpack them too.
dist="builds/dist"
rm -rf "$dist"; mkdir -p "$dist"

pack() { # pack <phpacker output> <asset name>
    stage="$(mktemp -d)"
    case "$2" in
        *windows*)
            cp "$1" "$stage/pbin.exe"
            (cd "$stage" && zip -q -9 "pbin.zip" pbin.exe)
            mv "$stage/pbin.zip" "$dist/$2.zip" ;;
        *)
            cp "$1" "$stage/pbin"
            chmod +x "$stage/pbin"
            # Ad-hoc sign macOS binaries (required to run on Apple Silicon).
            case "$2" in *macos*) codesign --force --sign - "$stage/pbin" 2>/dev/null || true ;; esac
            tar -C "$stage" -czf "$dist/$2.tar.gz" pbin ;;
    esac
    rm -rf "$stage"
}

pack builds/build/mac/mac-arm             pbin-macos-arm64
pack builds/build/mac/mac-x64             pbin-macos-x86_64
pack builds/build/linux/linux-arm         pbin-linux-arm64
pack builds/build/linux/linux-x64         pbin-linux-x86_64
pack builds/build/windows/windows-x64.exe pbin-windows-x86_64

# Bake the real repo slug into the installers so a plain curl of them works.
sed "s|@@REPO@@|$REPO|g" install.sh  > "$dist/install.sh"
sed "s|@@REPO@@|$REPO|g" install.ps1 > "$dist/install.ps1"

echo "==> Preparing release notes"
notes="$dist/notes.md"
if [ -f "notes/$VERSION.md" ]; then
    cp "notes/$VERSION.md" "$notes"
    echo "    using notes/$VERSION.md"
else
    prev="$(git describe --tags --abbrev=0 2>/dev/null || true)"
    range="${prev:+$prev..}HEAD"
    subjects="$(git log --no-merges --format='%s (%h)' "$range")"

    section() { # section <title> <regex on the commit type>
        lines="$(printf '%s\n' "$subjects" | grep -E "$2" | sed 's/^/- /' || true)"
        [ -n "$lines" ] && printf '## %s\n\n%s\n\n' "$1" "$lines"
        return 0
    }

    {
        [ -z "$subjects" ] && printf 'Maintenance release.\n\n'
        section "Features" '^feat(\(|!|:)'
        section "Fixes" '^fix(\(|!|:)'
        section "Other changes" '^(build|chore|ci|docs|perf|refactor|revert|style|test)(\(|!|:)'
        printf '%s\n' "$subjects" | grep -qE '^[a-z]+(\([^)]*\))?!:' \
            && printf '## ⚠️ Breaking changes\n\nSee the entries marked with "!" above.\n\n'
        [ -n "$prev" ] && printf '**Full changelog:** https://github.com/%s/compare/%s...%s\n' "$REPO" "$prev" "$VERSION"
        true
    } > "$notes"
    echo "    generated from ${range} (add notes/$VERSION.md to write them by hand)"
fi

echo "==> Publishing GitHub release"
# As a draft first, so nobody sees a "latest" release with missing assets
# while they upload; then upload in parallel (one connection doesn't fill the
# uplink) and publish once all are there.
gh release create "$VERSION" --draft --title "$VERSION" --notes-file "$notes"

pids=""
for asset in "$dist"/pbin-* "$dist/install.sh" "$dist/install.ps1"; do
    gh release upload "$VERSION" "$asset" --clobber &
    pids="$pids $!"
done

failed=0
for pid in $pids; do
    wait "$pid" || failed=1
done

if [ "$failed" -ne 0 ]; then
    echo "!! Upload failed; release $VERSION left as a draft. Fix and re-run the upload, or delete it with: gh release delete $VERSION" >&2
    exit 1
fi

gh release edit "$VERSION" --draft=false --latest

# --- Homebrew tap ------------------------------------------------------------
# Update the formula in the tap repo (<owner>/homebrew-tap) so `brew upgrade`
# picks up the new version. Skipped (non-fatal) if the tap repo doesn't exist.
OWNER="${REPO%/*}"
TAP_REPO="${PBIN_TAP_REPO:-$OWNER/homebrew-tap}"
ver_no_v="${VERSION#v}"

if gh repo view "$TAP_REPO" >/dev/null 2>&1; then
    echo "==> Updating Homebrew tap $TAP_REPO"
    sha() { shasum -a 256 "$1" | awk '{print $1}'; }
    base="https://github.com/$REPO/releases/download/$VERSION"
    tapdir="$(mktemp -d)"
    gh repo clone "$TAP_REPO" "$tapdir" -- --depth=1 --quiet
    mkdir -p "$tapdir/Formula"
    cat > "$tapdir/Formula/pbin.rb" <<EOF
class Pbin < Formula
  desc "Create encrypted PrivateBin pastes from the terminal"
  homepage "https://github.com/$REPO"
  version "$ver_no_v"

  on_macos do
    on_arm do
      url "$base/pbin-macos-arm64.tar.gz"
      sha256 "$(sha "$dist/pbin-macos-arm64.tar.gz")"
    end
    on_intel do
      url "$base/pbin-macos-x86_64.tar.gz"
      sha256 "$(sha "$dist/pbin-macos-x86_64.tar.gz")"
    end
  end

  on_linux do
    on_arm do
      url "$base/pbin-linux-arm64.tar.gz"
      sha256 "$(sha "$dist/pbin-linux-arm64.tar.gz")"
    end
    on_intel do
      url "$base/pbin-linux-x86_64.tar.gz"
      sha256 "$(sha "$dist/pbin-linux-x86_64.tar.gz")"
    end
  end

  def install
    bin.install "pbin"
  end

  test do
    assert_match "pbin", shell_output("#{bin}/pbin --version")
  end
end
EOF
    git -C "$tapdir" add Formula/pbin.rb
    git -C "$tapdir" commit -q -m "pbin $VERSION"
    git -C "$tapdir" push -q -u origin HEAD
    rm -rf "$tapdir"
else
    echo "==> Skipping Homebrew tap ($TAP_REPO not found)."
    echo "    Create it once (public repo named 'homebrew-tap') to enable brew installs."
fi

echo ""
echo "==> Done. Install with:"
echo "    Homebrew:     brew tap $OWNER/tap && brew trust $OWNER/tap && brew install pbin"
echo "    macOS/Linux:  curl -fsSL https://github.com/$REPO/releases/latest/download/install.sh | sh"
echo "    Windows:      irm https://github.com/$REPO/releases/latest/download/install.ps1 | iex"
