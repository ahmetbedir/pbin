# pbin — build & install

`pbin` ships as a standalone binary (PHP is embedded — nothing else to
install). Binaries are published as **GitHub releases** and fetched with
`curl`, so macOS never quarantines them — no "unidentified developer /
damaged" Gatekeeper warning.

The PrivateBin instance URL is **not** baked into the binary or the source —
each user sets it once with `pbin init` (stored in `~/.pbin/config.json`), so
the repository can safely be public.

---

## Install & use

**Homebrew (macOS / Linux) — recommended:**

```bash
brew tap ahmetbedir/tap
brew trust ahmetbedir/tap
brew install pbin
# updates: brew upgrade pbin
```

(`ahmetbedir/tap` resolves to the tap repo `ahmetbedir/homebrew-tap`. The
`brew trust` step is only needed when `HOMEBREW_REQUIRE_TAP_TRUST` is set;
otherwise it is a harmless no-op.)

**Install script (macOS / Linux) — no Homebrew:**

```bash
curl -fsSL https://github.com/ahmetbedir/pbin/releases/latest/download/install.sh | sh
```

**Windows (PowerShell):**

```powershell
irm https://github.com/ahmetbedir/pbin/releases/latest/download/install.ps1 | iex
```

Then configure the PrivateBin host once and create a bin:

```bash
pbin init          # prompts for the host URL (or: pbin init --privatebin-host=https://...)
pbin create
```

No GitHub account, login, or token needed. Re-run the install command any time
to update to the latest version. Install a specific version with
`PBIN_VERSION=v1.0.0` before the install command.

---

## For the maintainer (cut a release)

Requirements: `php`, deps installed (`composer install`), `gh` authenticated
(`gh auth login`), and the repo's GitHub remote configured.

**One-time (for Homebrew):** create a second public repo named
`homebrew-tap` under your account. `release.sh` writes `Formula/pbin.rb`
into it on every release. If it doesn't exist, the release still succeeds and
the Homebrew step is skipped. Override the tap repo with `PBIN_TAP_REPO=...`.

```bash
./release.sh v1.0.0
```

`release.sh` does everything from your Mac:

1. builds the PHAR (`app:build`),
2. cross-compiles binaries for **macOS arm64/x86_64, Linux x86_64/arm64,
   Windows x64** with [phpacker](https://github.com/phpacker/phpacker),
3. ad-hoc signs the macOS binaries (required to run on Apple Silicon — this is
   why we build on a Mac, not in Linux CI),
4. bakes the repo slug into `install.sh` / `install.ps1`,
5. publishes a GitHub release (`gh release create`) with every asset attached,
6. regenerates `Formula/pbin.rb` (with fresh sha256 sums) and pushes it to the
   `homebrew-tap` tap repo.

Cut a new version by passing a new tag (`v1.0.1`, …); the `latest/download/…`
URLs always resolve to the newest release, so the install command never
changes.
