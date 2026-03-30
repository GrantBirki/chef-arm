# Release

Releases are GitHub Release assets, not GitHub Packages registry uploads.

The normal release path is the manual GitHub Actions workflow:

1. Dispatch `Release Arm Build`
2. Pick an upstream ref or let the workflow use `config/upstream.yml`
3. Set the ARM rebuild iteration
4. Choose whether to publish the release

The workflow will:

- build the package on `ubuntu-24.04-arm`
- smoke test the resulting `.deb`
- generate an SPDX SBOM
- generate a GitHub artifact attestation
- upload the `.deb`, `SHA256SUMS`, and SBOM to the GitHub Release when publishing is enabled

Local release assembly is also available:

```bash
script/release 15.10.93 --iteration 1
script/release 15.10.93 --iteration 1 --artifact pkg/v15.10.93-arm64.1/chef-server-core_15.10.93-1_arm64.deb --publish
```

`script/release --publish` expects a working `gh` login with permission to create and edit releases.
