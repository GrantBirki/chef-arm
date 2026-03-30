# Build

`chef-arm` is packaging glue around upstream `chef/chef-server`. The default maintainer loop is:

```bash
script/bootstrap
script/lint
script/test
script/build --dry-run
```

For a native package build, use an Ubuntu Server 24.04 `arm64` machine or the `ubuntu-24.04-arm` GitHub-hosted runner.

## Linux build prerequisites

- `git`
- `curl`
- `build-essential`
- `fakeroot`
- `dpkg-dev`
- `libffi-dev`
- `liblzma-dev`
- `libreadline-dev`
- `libssl-dev`
- `patch`
- `pkg-config`
- `rsync`
- `zlib1g-dev`
- `rbenv` with the version in `.ruby-version`

## Commands

- `script/build`
  Builds the default upstream ref from `config/upstream.yml`.
- `script/build 15.10.93 --iteration 2`
  Builds a pinned upstream ref with a custom ARM rebuild iteration.
- `script/build 15.10.93 --dry-run`
  Clones upstream, resolves patch metadata, and renders overrides without invoking Omnibus.

Build artifacts are written to `pkg/<release_tag>/`.

## Runtime artifact verification

Before Omnibus runs on Linux, `script/build` stages the ARM runtime payloads from official upstream sources and verifies them:

- OpenSearch `1.3.20` tarball from `artifacts.opensearch.org`, verified with the published `opensearch.pgp` key and `.sig` signature.
- Eclipse Temurin `17.0.9+9` JRE tarball from the Adoptium GitHub release, verified with the published `.sha256.txt` sidecar.

The verified tarballs are unpacked into the build workspace and Omnibus consumes those extracted source trees instead of fetching x64-only upstream defaults.
