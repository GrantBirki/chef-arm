# Patch Workflow

Patch application is controlled by `config/patches.yml`.

## Manifest shape

```yaml
patches:
  common:
    - patches/common/0001-example.patch
  constraints:
    - requirement: "~> 15.17.0"
      patches:
        - patches/common/0002-example.patch
  refs:
    15.10.93:
      - patches/15.10.93/0003-example.patch
```

## Rules

- `common` patches always apply
- `constraints` patches apply when the upstream `VERSION` satisfies the RubyGems requirement
- `refs` patches apply only to the exact upstream ref used for the build

## Updating upstream

```bash
script/update-upstream 15.10.93
```

That command updates `config/upstream.yml` and ensures a matching `refs` entry exists in `config/patches.yml`.
