#!/usr/bin/env bash
set -Eeuo pipefail

install_prefix="${1:-${RUNNER_TEMP:-/tmp}/linux-operations-tools}"
download_directory="$(mktemp -d "${RUNNER_TEMP:-/tmp}/linux-operations-downloads.XXXXXX")"
trap 'rm -rf "$download_directory"' EXIT
mkdir -p "$install_prefix/bin"

download() {
  local url="$1"
  local output="$2"
  curl --fail --silent --show-error --location \
    --retry 4 --retry-all-errors --connect-timeout 15 --max-time 180 \
    "$url" --output "$output"
}

verify() {
  local expected="$1"
  local path="$2"
  local actual
  actual="$(sha256sum "$path" | awk '{ print $1 }')"
  if [[ "$actual" != "$expected" ]]; then
    printf 'checksum mismatch for %s: expected %s, got %s\n' "$path" "$expected" "$actual" >&2
    exit 1
  fi
}

case "$(uname -s)/$(uname -m)" in
  Linux/x86_64)
    shellcheck_platform=linux.x86_64
    shellcheck_sha256=8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198
    gitleaks_platform=linux_x64
    gitleaks_sha256=551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb
    ;;
  Darwin/arm64)
    shellcheck_platform=darwin.aarch64
    shellcheck_sha256=56affdd8de5527894dca6dc3d7e0a99a873b0f004d7aabc30ae407d3f48b0a79
    gitleaks_platform=darwin_arm64
    gitleaks_sha256=b40ab0ae55c505963e365f271a8d3846efbc170aa17f2607f13df610a9aeb6a5
    ;;
  *)
    printf 'unsupported validation-tool platform: %s/%s\n' "$(uname -s)" "$(uname -m)" >&2
    exit 1
    ;;
esac

shellcheck_version=0.11.0
download \
  "https://github.com/koalaman/shellcheck/releases/download/v${shellcheck_version}/shellcheck-v${shellcheck_version}.${shellcheck_platform}.tar.xz" \
  "$download_directory/shellcheck.tar.xz"
verify "$shellcheck_sha256" "$download_directory/shellcheck.tar.xz"
tar -xJf "$download_directory/shellcheck.tar.xz" -C "$download_directory"
install -m 0755 "$download_directory/shellcheck-v${shellcheck_version}/shellcheck" "$install_prefix/bin/shellcheck"

gitleaks_version=8.30.1
download \
  "https://github.com/gitleaks/gitleaks/releases/download/v${gitleaks_version}/gitleaks_${gitleaks_version}_${gitleaks_platform}.tar.gz" \
  "$download_directory/gitleaks.tar.gz"
verify "$gitleaks_sha256" "$download_directory/gitleaks.tar.gz"
tar -xzf "$download_directory/gitleaks.tar.gz" -C "$download_directory" gitleaks
install -m 0755 "$download_directory/gitleaks" "$install_prefix/bin/gitleaks"

bats_commit=eb7f42f8d608ac693d7a4b67474f6714ea68cfc5
git init --quiet "$download_directory/bats-core"
git -C "$download_directory/bats-core" remote add origin https://github.com/bats-core/bats-core.git
git -C "$download_directory/bats-core" fetch --quiet --depth 1 origin "$bats_commit"
git -C "$download_directory/bats-core" checkout --quiet --detach FETCH_HEAD
if [[ "$(git -C "$download_directory/bats-core" rev-parse HEAD)" != "$bats_commit" ]]; then
  printf 'Bats commit verification failed\n' >&2
  exit 1
fi
"$download_directory/bats-core/install.sh" "$install_prefix"

printf '%s\n' "$install_prefix/bin"
