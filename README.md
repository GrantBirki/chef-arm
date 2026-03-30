# chef-arm

`chef-arm` is an experimental packaging repo that rebuilds upstream [`chef/chef-server`](https://github.com/chef/chef-server) tags for Ubuntu Server 24.04 `arm64`.

This repository does not publish to a GitHub Packages registry. It publishes native `.deb` artifacts as GitHub Release assets together with `SHA256SUMS`, an SPDX SBOM, and GitHub artifact attestations.

## Status

- Public and experimental
- Ubuntu Server 24.04 `arm64` only
- Release assets only
- Not vendor-supported by Progress Chef

## Layout

- `script/`: operator entrypoints in the "scripts to rule them all" style
- `config/upstream.yml`: upstream source-of-truth and default ref
- `config/patches.yml`: patch queue manifest
- `patches/`: patch files applied on top of upstream source
- `lib/chef_arm/`: testable Ruby helpers for manifest and release metadata
- `.github/workflows/`: CI, release, and upstream-watch automation

## Quick Start

```bash
script/bootstrap
script/lint
script/test
script/build --dry-run
```

To set a new upstream target:

```bash
script/update-upstream 15.10.93
```

To build and release from a pinned ref:

```bash
script/build 15.10.93 --iteration 1
script/test pkg/v15.10.93-arm64.1/chef-server-core_15.10.93-1_arm64.deb
script/release 15.10.93 --iteration 1
```

## Notes

- Native package builds run on `ubuntu-24.04-arm` GitHub-hosted runners.
- Local macOS use is expected for linting, tests, manifest updates, and build dry-runs.
- Full package builds and smoke tests are Linux-only because Omnibus builds for the platform it runs on.

See [docs/build.md](docs/build.md), [docs/release.md](docs/release.md), and [docs/patches.md](docs/patches.md) for the maintainer workflow.
