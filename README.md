<p align="center">
  <img src="assets/logo.svg" alt="pbin" width="420">
</p>

<p align="center">
  <b>Create end-to-end encrypted <a href="https://privatebin.info">PrivateBin</a> pastes from your terminal.</b>
</p>

<p align="center">
  English · <a href="README.tr.md">Türkçe</a>
</p>

<p align="center">
  <img src="assets/demo.gif" alt="pbin create demo" width="700">
</p>

`pbin` is a small, zero-knowledge command-line client for PrivateBin. Your text
is encrypted **on your machine** with AES-256-GCM before it ever touches the
network — the server only ever stores ciphertext, and the decryption key lives
only in the fragment of the share link. It ships as a single self-contained
binary (PHP is embedded) and works with any PrivateBin instance.

---

## Features

- 🔒 **Zero-knowledge** — client-side AES-256-GCM; the key is never sent to the server
- 🧩 **Any instance** — compatible with the PrivateBin v2 API (PrivateBin 1.3+)
- 🙈 **No hardcoded server** — you point it at your own instance on first run
- 🎛️ **Interactive** — choose format (plain / Markdown / source code), expiry, password, burn-after-reading or open discussion
- 📋 **Clipboard** — the share link is copied automatically
- 📦 **Single binary** — nothing to install; macOS (Apple Silicon & Intel), Linux (x86_64 & arm64), Windows

---

## Install

**Homebrew (macOS / Linux):**

```bash
brew tap ahmetbedir/tap
brew trust ahmetbedir/tap
brew install pbin
# updates: brew update && brew upgrade pbin
```

**Install script (macOS / Linux):**

```bash
curl -fsSL https://github.com/ahmetbedir/pbin/releases/latest/download/install.sh | sh
```

**Windows (PowerShell):**

```powershell
irm https://github.com/ahmetbedir/pbin/releases/latest/download/install.ps1 | iex
```

See [INSTALL.md](INSTALL.md) for details, updates, and building from source.

---

## Quick start

```bash
pbin init      # set your PrivateBin host once (stored in ~/.pbin/config.json)
pbin create    # write, encrypt, and get a share link
```

`pbin init` prompts for the host, or set it directly:

```bash
pbin init --privatebin-host=https://privatebin.example.com
```

---

## Usage

Running `pbin create` walks you through:

1. **Content** — a multi-line editor (encrypted locally before sending)
2. **Format** — Plain Text, Markdown, or Source Code
3. **Expiry** — 5 minutes … 1 week, or never
4. **Password** — optional; strengthens the key derivation
5. **Type** — burn-after-reading, open discussion (comments), or none

When it finishes, the view link is printed and copied to your clipboard.

---

## Configuration

The only setting is your PrivateBin host, stored per-user in
`~/.pbin/config.json` — never in the code or the binary.

| How | Command |
| --- | --- |
| Interactive | `pbin init` |
| Direct | `pbin init --privatebin-host=https://…` |
| Env override (CI) | `PRIVATEBIN_URL=https://… pbin create` |

---

## How it works

`pbin` mirrors PrivateBin's own browser client, so pastes open and decrypt
normally in any browser:

1. A random 256-bit key is generated locally and **never leaves your machine**.
2. `PBKDF2-SHA256` (100k iterations) derives the AES key from that key plus an
   optional password and a random salt.
3. The paste is JSON-wrapped, DEFLATE-compressed, then encrypted with
   **AES-256-GCM**; the server receives only the ciphertext and metadata.
4. The key is base58-encoded and placed in the URL **fragment** (`#…`), which
   browsers never send to the server.

The PrivateBin instance URL is intentionally not compiled in — it is set
per-user, so the tool is safe to use with private, internal instances.

---

## Building from source

Requires PHP 8.2+ and Composer.

```bash
composer install
php pbin create          # run directly from source
php pbin app:build pbin  # build the PHAR
```

Cross-platform binaries are produced with
[phpacker](https://github.com/phpacker/phpacker) and published via
`release.sh` — see [INSTALL.md](INSTALL.md).

---

## License

[MIT](LICENSE)
