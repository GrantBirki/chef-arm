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
use_s3_caching false
use_internal_sources false
append_timestamp false
EOF

  printf '%s\n' "$config_path"
}

sha256_file() {
  local file_path="$1"

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file_path" | awk '{ print $1 }'
    return
  fi

  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file_path" | awk '{ print $1 }'
    return
  fi

  die "missing required command: sha256sum or shasum"
}

download_file() {
  local url="$1"
  local destination="$2"

  if [ -f "$destination" ]; then
    return
  fi

  mkdir -p "$(dirname "$destination")"
  log "downloading $(basename "$destination")"
  curl --fail --location --retry 3 --silent --show-error --output "$destination" "$url"
}

verify_sha256_manifest() {
  local file_path="$1"
  local manifest_path="$2"
  local filename expected actual

  filename="$(basename "$file_path")"
  expected="$(
    awk -v filename="$filename" '
      $1 ~ /^[0-9a-fA-F]{64}$/ {
        entry = $2
        sub(/^\*/, "", entry)
        if (entry == filename) {
          print $1
          exit
        }
      }
    ' "$manifest_path"
  )"

  [ -n "$expected" ] || die "no sha256 entry for $filename in $manifest_path"

  actual="$(sha256_file "$file_path")"
  [ "$actual" = "$expected" ] || die "sha256 mismatch for $filename"
}

verify_gpg_signature() {
  local file_path="$1"
  local signature_path="$2"
  local key_path="$3"
  local gnupg_home

  require_command gpg

  gnupg_home="$(mktemp -d "${TMPDIR:-/tmp}/chef-arm-gpg.XXXXXX")"
  chmod 700 "$gnupg_home"

  gpg --batch --homedir "$gnupg_home" --import "$key_path" >/dev/null 2>&1
  if ! gpg --batch --homedir "$gnupg_home" --verify "$signature_path" "$file_path" >/dev/null 2>&1; then
    rm -rf "$gnupg_home"
    die "gpg signature verification failed for $(basename "$file_path")"
  fi

  rm -rf "$gnupg_home"
}

extract_tarball() {
  local archive_path="$1"
  local destination_root="$2"
  local extracted_path="$3"

  mkdir -p "$destination_root"
  rm -rf "$extracted_path"
  tar -xzf "$archive_path" -C "$destination_root"
  [ -d "$extracted_path" ] || die "expected extracted directory not found: $extracted_path"
}

prepare_verified_runtime_sources() {
  local work_root="$1"
  local metadata_path="${2:-}"
  local download_root="$work_root/runtime-downloads"
  local extract_root="$work_root/runtime-sources"
  local opensearch_version="1.3.20"
  local opensearch_archive="opensearch-${opensearch_version}-linux-arm64.tar.gz"
  local opensearch_url="https://artifacts.opensearch.org/releases/bundle/opensearch/${opensearch_version}/${opensearch_archive}"
  local opensearch_sig_url="${opensearch_url}.sig"
  local opensearch_key_url="https://artifacts.opensearch.org/publickeys/opensearch.pgp"
  local opensearch_archive_path="$download_root/$opensearch_archive"
  local opensearch_sig_path="$download_root/${opensearch_archive}.sig"
  local opensearch_key_path="$download_root/opensearch.pgp"
  local opensearch_source_path="$extract_root/opensearch-${opensearch_version}"
  local temurin_version="17.0.9+9"
  local temurin_directory="jdk-${temurin_version}-jre"
  local temurin_archive="OpenJDK17U-jre_aarch64_linux_hotspot_17.0.9_9.tar.gz"
  local temurin_url="https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.9%2B9/${temurin_archive}"
  local temurin_checksum_url="${temurin_url}.sha256.txt"
  local temurin_archive_path="$download_root/$temurin_archive"
  local temurin_checksum_path="$download_root/${temurin_archive}.sha256.txt"
  local temurin_source_path="$extract_root/$temurin_directory"
  local opensearch_sha256 temurin_sha256

  require_command curl
  require_command tar

  download_file "$opensearch_url" "$opensearch_archive_path"
  download_file "$opensearch_sig_url" "$opensearch_sig_path"
  download_file "$opensearch_key_url" "$opensearch_key_path"
  verify_gpg_signature "$opensearch_archive_path" "$opensearch_sig_path" "$opensearch_key_path"
  extract_tarball "$opensearch_archive_path" "$extract_root" "$opensearch_source_path"
  opensearch_sha256="$(sha256_file "$opensearch_archive_path")"

  download_file "$temurin_url" "$temurin_archive_path"
  download_file "$temurin_checksum_url" "$temurin_checksum_path"
  verify_sha256_manifest "$temurin_archive_path" "$temurin_checksum_path"
  extract_tarball "$temurin_archive_path" "$extract_root" "$temurin_source_path"
  temurin_sha256="$(sha256_file "$temurin_archive_path")"

  export CHEF_ARM_OPENSEARCH_SOURCE_PATH="$opensearch_source_path"
  export CHEF_ARM_OPENSEARCH_SHA256="$opensearch_sha256"
  export CHEF_ARM_SERVER_OPEN_JRE_SOURCE_PATH="$temurin_source_path"
  export CHEF_ARM_SERVER_OPEN_JRE_SHA256="$temurin_sha256"

  if [ -n "$metadata_path" ]; then
    cat >> "$metadata_path" <<EOF
opensearch_source_path: $CHEF_ARM_OPENSEARCH_SOURCE_PATH
opensearch_source_sha256: $CHEF_ARM_OPENSEARCH_SHA256
server_open_jre_source_path: $CHEF_ARM_SERVER_OPEN_JRE_SOURCE_PATH
server_open_jre_source_sha256: $CHEF_ARM_SERVER_OPEN_JRE_SHA256
EOF
  fi
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
