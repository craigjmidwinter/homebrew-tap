# homebrew-tap

Homebrew tap for [craigjmidwinter](https://github.com/craigjmidwinter)'s tools.

```sh
brew install craigjmidwinter/tap/mail-muncher
```

or, if you prefer to tap first:

```sh
brew tap craigjmidwinter/tap
brew install mail-muncher
```

## Contents

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
