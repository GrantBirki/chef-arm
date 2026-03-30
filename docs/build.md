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
