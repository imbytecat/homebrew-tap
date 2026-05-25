# imbytecat/homebrew-tap

Personal Homebrew tap.

## Install

```sh
brew install --cask imbytecat/tap/ugreen-nas
```

## Casks

| Cask | Notes |
| --- | --- |
| [`ugreen-nas`](Casks/ugreen-nas.rb) | UGREEN NAS (绿联云) macOS client, Apple Silicon only. |

## Development

```sh
nix develop          # ruby_3_3 + rubocop + just + curl
just bump-ugreen-nas # refresh version + sha256 from upstream API
just style           # rubocop on scripts
```

## Why `ugreen-nas` needs a custom download strategy

UGREEN's CDN only serves the `.dmg` via short-lived (~8 min) signed URLs
fetched from `api-zh.ugnas.com`. Pinning a URL into the cask doesn't work, so
the cask defines `UgreenApiDownloadStrategy < CurlDownloadStrategy` (modeled
on Homebrew's own `CurlApacheMirrorDownloadStrategy`) that resolves the signed
URL at install time. The `sha256` stays pinned to the published build and is
refreshed by `scripts/bump-ugreen-nas.rb` whenever upstream cuts a new
release.

Intel x86 is intentionally not packaged here — Homebrew is winding down Intel
support. Grab the Intel `.dmg` from <https://www.ugnas.com/download/> if you
need it.
