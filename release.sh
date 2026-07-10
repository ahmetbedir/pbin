#!/usr/bin/env sh
#
# Maintainer release script. Builds the PHAR, cross-compiles standalone
# binaries for every platform with phpacker, signs the macOS ones, and
# publishes them as a GitHub release on this repo (public repo = public,
# no-auth downloads for everyone).
#
#   ./release.sh v1.0.0
#
# Requires: php, ./vendor/bin/phpacker, gh (authenticated: `gh auth login`),
# run inside the repo with its GitHub remote configured.

set -eu

VERSION="${1:-}"
[ -n "$VERSION" ] || { echo "usage: ./release.sh vX.Y.Z" >&2; exit 1; }

cd "$(dirname "$0")"

REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
echo "==> Releasing $VERSION to $REPO"

echo "==> Building PHAR"
php pbin app:build pbin --build-version="$VERSION" --no-interaction
cp -f builds/pbin builds/pbin.phar   # phpacker.json src points here

echo "==> Cross-building all platforms with phpacker"
./vendor/bin/phpacker build all --no-interaction

echo "==> Packaging release assets"
dist="builds/dist"
rm -rf "$dist"; mkdir -p "$dist"
cp builds/build/mac/mac-arm             "$dist/pbin-macos-arm64"
cp builds/build/mac/mac-x64             "$dist/pbin-macos-x86_64"
cp builds/build/linux/linux-x64         "$dist/pbin-linux-x86_64"
cp builds/build/linux/linux-arm         "$dist/pbin-linux-arm64"
cp builds/build/windows/windows-x64.exe "$dist/pbin-windows-x86_64.exe"

# Ad-hoc sign the macOS binaries (required to run on Apple Silicon).
codesign --force --sign - "$dist/pbin-macos-arm64"  2>/dev/null || true
codesign --force --sign - "$dist/pbin-macos-x86_64" 2>/dev/null || true

# Bake the real repo slug into the installers so a plain curl of them works.
sed "s|@@REPO@@|$REPO|g" install.sh  > "$dist/install.sh"
sed "s|@@REPO@@|$REPO|g" install.ps1 > "$dist/install.ps1"

echo "==> Publishing GitHub release"
gh release create "$VERSION" \
    "$dist"/pbin-* "$dist/install.sh" "$dist/install.ps1" \
    --title "$VERSION" \
    --notes "pbin $VERSION" \
    --latest

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
      url "$base/pbin-macos-arm64"
      sha256 "$(sha "$dist/pbin-macos-arm64")"
    end
    on_intel do
      url "$base/pbin-macos-x86_64"
      sha256 "$(sha "$dist/pbin-macos-x86_64")"
    end
  end

  on_linux do
    on_arm do
      url "$base/pbin-linux-arm64"
      sha256 "$(sha "$dist/pbin-linux-arm64")"
    end
    on_intel do
      url "$base/pbin-linux-x86_64"
      sha256 "$(sha "$dist/pbin-linux-x86_64")"
    end
  end

  def install
    bin.install Dir["pbin-*"].first => "pbin"
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
echo "    Homebrew:     brew install $OWNER/tap/pbin"
echo "    macOS/Linux:  curl -fsSL https://github.com/$REPO/releases/latest/download/install.sh | sh"
echo "    Windows:      irm https://github.com/$REPO/releases/latest/download/install.ps1 | iex"
