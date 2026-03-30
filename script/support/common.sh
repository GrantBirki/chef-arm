#! /usr/bin/env bash

set -euo pipefail

log() {
  echo -e "${BLUE}==>${OFF} $*"
}

warn() {
  echo -e "${PURPLE}warning:${OFF} $*" >&2
}

die() {
  echo -e "${RED}error:${OFF} $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

set_github_output() {
  local key="$1"
  local value="$2"

  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    printf '%s=%s\n' "$key" "$value" >> "$GITHUB_OUTPUT"
  fi
}

clone_upstream_repo() {
  local repository="$1"
  local ref="$2"
  local destination="$3"

  rm -rf "$destination"
  git clone "$repository" "$destination"
  git -C "$destination" fetch --tags --force origin
  git -C "$destination" checkout --detach "$ref"
}

apply_patch_series() {
  local repository_path="$1"
  shift

  if [ "$#" -eq 0 ]; then
    return
  fi

  for patch_path in "$@"; do
    [ -f "$patch_path" ] || die "patch not found: $patch_path"
    log "applying patch $(basename "$patch_path")"
    git -C "$repository_path" apply --check "$patch_path"
    git -C "$repository_path" apply "$patch_path"
  done
}

render_omnibus_override() {
  local repository_path="$1"
  local iteration="$2"
  local override_path="$repository_path/omnibus_overrides.rb"
  local backup_path="$repository_path/omnibus_overrides.chef-arm.upstream.rb"

  if [ -f "$override_path" ]; then
    mv "$override_path" "$backup_path"
  fi

  cat > "$override_path" <<EOF
# frozen_string_literal: true

upstream_override = File.expand_path("omnibus_overrides.chef-arm.upstream.rb", __dir__)
instance_eval(IO.read(upstream_override), upstream_override) if File.exist?(upstream_override)

build_iteration ${iteration}
EOF
}

render_omnibus_config() {
  local repository_path="$1"
  local config_path="$repository_path/omnibus/omnibus.chef-arm.rb"

  cat > "$config_path" <<'EOF'
# frozen_string_literal: true

upstream_config = File.expand_path("omnibus.rb", __dir__)
instance_eval(IO.read(upstream_config), upstream_config)

base_dir File.expand_path("local", __dir__)
use_git_caching false
use_internal_sources false
append_timestamp false
EOF

  printf '%s\n' "$config_path"
}

copy_package_artifact() {
  local repository_path="$1"
  local artifact_dir="$2"
  local filename="$3"
  local package_path

  package_candidates=()
  while IFS= read -r package_candidate; do
    package_candidates+=("$package_candidate")
  done < <(find "$repository_path/omnibus" -type f -name "*.deb" | sort)

  [ "${#package_candidates[@]}" -gt 0 ] || die "no .deb package found under $repository_path/omnibus"

  if [ "${#package_candidates[@]}" -gt 1 ]; then
    warn "multiple .deb artifacts found; using ${package_candidates[0]}"
  fi

  package_path="${package_candidates[0]}"

  mkdir -p "$artifact_dir"
  cp "$package_path" "$artifact_dir/$filename"

  printf '%s\n' "$artifact_dir/$filename"
}
