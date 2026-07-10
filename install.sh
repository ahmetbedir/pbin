#!/usr/bin/env sh
#
# pbin installer. Downloads the right standalone binary for this machine from
# the public GitHub release and installs it onto your PATH. PHP is embedded in
# the binary — nothing else to install, no auth required.
#
#   curl -fsSL https://github.com/<owner>/<repo>/releases/latest/download/install.sh | sh
#
# Overridable via environment:
#   PBIN_REPO      owner/repo  (baked in at release time)
#   PBIN_VERSION   release tag, or "latest"   (default: latest)
#   PBIN_BIN_DIR   install directory  (default: /usr/local/bin or ~/.local/bin)

set -eu

# @@REPO@@ is replaced with the real owner/repo by release.sh at publish time.
REPO="${PBIN_REPO:-@@REPO@@}"
VERSION="${PBIN_VERSION:-latest}"
BIN_NAME="pbin"

say() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

case "$REPO" in
    *@@*) die "PBIN_REPO is not set (should be baked in by release.sh)." ;;
esac

# --- detect platform ---------------------------------------------------------
os="$(uname -s)"
arch="$(uname -m)"
case "$os" in
    Darwin)
        case "$arch" in
            arm64|aarch64) asset="pbin-macos-arm64" ;;
            x86_64)        asset="pbin-macos-x86_64" ;;
            *) die "unsupported macOS arch: $arch" ;;
        esac ;;
    Linux)
        case "$arch" in
            x86_64|amd64)  asset="pbin-linux-x86_64" ;;
            aarch64|arm64) asset="pbin-linux-arm64" ;;
            *) die "unsupported Linux arch: $arch" ;;
        esac ;;
    *) die "unsupported OS: $os (Windows: use install.ps1)" ;;
esac

# --- pick a writable install dir ---------------------------------------------
if [ -n "${PBIN_BIN_DIR:-}" ]; then
    INSTALL_DIR="$PBIN_BIN_DIR"
elif [ -w /usr/local/bin ] 2>/dev/null; then
    INSTALL_DIR="/usr/local/bin"
else
    INSTALL_DIR="$HOME/.local/bin"
fi
mkdir -p "$INSTALL_DIR"
dest="$INSTALL_DIR/$BIN_NAME"

# --- download (public release asset — no auth) -------------------------------
if [ "$VERSION" = "latest" ]; then
    url="https://github.com/$REPO/releases/latest/download/$asset"
else
    url="https://github.com/$REPO/releases/download/$VERSION/$asset"
fi

say "Downloading $asset ($VERSION)..."
tmp="$(mktemp)"
curl -fSL --progress-bar "$url" -o "$tmp" || die "download failed: $url"
mv "$tmp" "$dest"
chmod +x "$dest"
# Defensive: strip any quarantine flag so macOS Gatekeeper never blocks it.
[ "$os" = "Darwin" ] && { xattr -c "$dest" 2>/dev/null || true; }

say ""
say "Installed pbin -> $dest"
case ":$PATH:" in
    *":$INSTALL_DIR:"*) say "Next: run 'pbin init' once, then 'pbin create'." ;;
    *) say "NOTE: $INSTALL_DIR is not on your PATH. Add it, e.g.:"
       say "  echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.zshrc && source ~/.zshrc" ;;
esac
