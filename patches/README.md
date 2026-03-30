# Patch Queue

Patch files live in this directory and are referenced from `config/patches.yml`.

Recommended layout:

- `patches/common/*.patch` for patches shared across supported upstream refs
- `patches/<upstream-ref>/*.patch` for ref-specific changes

The manifest is authoritative. Files that are not listed in `config/patches.yml` are ignored by the build.
