#!/usr/bin/env bash
# Downloads the pinned depwatch CLI release for this runner and verifies it against the SHA-256
# checksums committed in this Action for that version. A mismatch, or a version with no committed
# checksums, stops the step: a tool that checks other people's dependencies must not become one of the
# compromised ones.
set -euo pipefail

# Where releases are downloaded from and which checksums are trusted are fixed here, in the Action's
# own files, never read from the job's environment: an earlier step writing to $GITHUB_ENV cannot swap
# either. (The tests run a copy of the Action with its own checksums and release address.)
release_base="https://github.com/kimathinjoki/depwatch-cli/releases/download"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# carried names the versions this Action has checksums for.
carried() {
  local list="" f
  for f in "$here"/checksums/*.txt; do
    [ -e "$f" ] || continue
    f="${f##*/}"
    list="$list ${f%.txt}"
  done
  if [ -n "$list" ]; then echo "it carries:$list"; else echo "it carries none yet: no depwatch CLI release has been published"; fi
}

version="${DEPWATCH_VERSION:-}"
if [ -z "$version" ]; then
  echo "depwatch: set the Action's version input to a depwatch CLI release; $(carried)" >&2
  exit 1
fi
case "$version" in
  *[!0-9A-Za-z.+-]*|.*|-*) echo "depwatch: '$version' is not a version" >&2; exit 1 ;;
esac
checksums="$here/checksums/$version.txt"
base="$release_base/v$version"
dest="$(mktemp -d "${RUNNER_TEMP:-/tmp}/depwatch-$version.XXXXXX")"

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
  echo "depwatch: this Action carries no checksums for version $version, so it will not install it; $(carried)" >&2
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
