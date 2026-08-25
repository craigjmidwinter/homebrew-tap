# homebrew-tap

Homebrew tap for [craigjmidwinter](https://github.com/craigjmidwinter)'s tools.

```sh
brew install craigjmidwinter/tap/getvect        # desktop app, built from source
brew install craigjmidwinter/tap/mail-muncher   # CLI
```

or, if you prefer to tap first:

```sh
brew tap craigjmidwinter/tap
brew install mail-muncher
```

## Contents

## Formulae

| Formula | Upstream | What it is |
| --- | --- | --- |
| `getvect` | [craigjmidwinter/getvect](https://github.com/craigjmidwinter/getvect) | Raster to vector, on your machine. No upload, no account, no API key. |

**Why `getvect` is a formula and not a cask.** A cask downloads a `.dmg` the same way a browser does, so macOS sets `com.apple.quarantine` and Gatekeeper blocks the first launch — normally fixed by buying an Apple Developer certificate, or by stripping the attribute afterwards. A formula built from source is never quarantined in the first place: nothing arrives as a downloaded application bundle. **Verified on install: zero `com.apple.quarantine` attributes in the Cellar.** No certificate, no prompt, no attribute to strip.

## Casks

| Cask | Upstream | What it is |
| --- | --- | --- |
| `mail-muncher` | [craigjmidwinter/mail-muncher](https://github.com/craigjmidwinter/mail-muncher) | An email client for AI agents: filtered, read-only Gmail delivered to disk as `.eml` + markdown, and served over MCP. |

## How this repo is maintained

Everything under `Casks/` is generated. Each upstream project's release
workflow uses [GoReleaser](https://goreleaser.com) to build its binaries and
then commits the updated cask here. Do not hand-edit those files — the next
release will overwrite them. Fix the upstream `.goreleaser.yml` instead.

Releases are signed keylessly with [cosign](https://docs.sigstore.dev/) and
publish a `checksums.txt`; verification instructions live in each project's
README.
