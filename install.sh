#!/usr/bin/env bash
# Downloads the pinned depwatch CLI release for this runner and verifies it against the SHA-256
# checksums committed in this Action for that version. A mismatch, or a version with no committed
# checksums, stops the step: a tool that checks other people's dependencies must not become one of the
# compromised ones.
set -euo pipefail

version="${DEPWATCH_VERSION:?set DEPWATCH_VERSION}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
checksums="${DEPWATCH_CHECKSUMS_DIR:-$here/checksums}/$version.txt"
base="${DEPWATCH_RELEASE_BASE:-https://github.com/kimathinjoki/depwatch-cli/releases/download/v$version}"
dest="${DEPWATCH_INSTALL_DIR:-${RUNNER_TEMP:-/tmp}/depwatch-$version}"

case "${RUNNER_OS:-$(uname -s)}" in
  Linux) os=linux ;;
  macOS|Darwin) os=darwin ;;
  Windows|MINGW*|MSYS*) os=windows ;;
  *) echo "depwatch: unsupported runner system ${RUNNER_OS:-$(uname -s)}" >&2; exit 1 ;;
esac
case "${RUNNER_ARCH:-$(uname -m)}" in
  X64|x86_64|amd64) arch=amd64 ;;
  ARM64|aarch64|arm64) arch=arm64 ;;
  *) echo "depwatch: unsupported runner architecture ${RUNNER_ARCH:-$(uname -m)}" >&2; exit 1 ;;
esac
ext=tar.gz
[ "$os" = windows ] && ext=zip
asset="depwatch_${version}_${os}_${arch}.$ext"

if [ ! -f "$checksums" ]; then
  echo "depwatch: this Action carries no checksums for version $version; use a version it lists in checksums/" >&2
  exit 1
fi
want="$(awk -v a="$asset" '$2 == a { print $1 }' "$checksums")"
if [ -z "$want" ]; then
  echo "depwatch: no checksum for $asset in checksums/$version.txt" >&2
  exit 1
fi

mkdir -p "$dest"
curl -fsSL --retry 3 -o "$dest/$asset" "$base/$asset"
if command -v sha256sum >/dev/null; then
  got="$(sha256sum "$dest/$asset" | awk '{print $1}')"
else
  got="$(shasum -a 256 "$dest/$asset" | awk '{print $1}')"
fi
if [ "$got" != "$want" ]; then
  echo "depwatch: $asset does not match its checksum (want $want, got $got); not running it" >&2
  rm -f "$dest/$asset"
  exit 1
fi

if [ "$ext" = zip ]; then
  unzip -oq "$dest/$asset" -d "$dest"
else
  tar -xzf "$dest/$asset" -C "$dest"
fi
chmod +x "$dest/depwatch" 2>/dev/null || true
if [ -n "${GITHUB_PATH:-}" ]; then
  echo "$dest" >> "$GITHUB_PATH"
fi
"$dest/depwatch" version
