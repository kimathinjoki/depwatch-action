#!/usr/bin/env bash
# Tests install.sh against a local fake release: a matching download installs and runs; a tampered one
# stops; a version with no committed checksums stops; the asset follows the runner's system.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
pass=0
fail() { echo "FAIL: $*" >&2; exit 1; }

release="$work/release"; mkdir -p "$release" "$work/sums"
for target in linux_amd64 darwin_arm64; do
  mkdir -p "$work/build/$target"
  printf '#!/usr/bin/env bash\necho "depwatch 9.9.9 (%s)"\n' "$target" > "$work/build/$target/depwatch"
  chmod +x "$work/build/$target/depwatch"
  tar -czf "$release/depwatch_9.9.9_$target.tar.gz" -C "$work/build/$target" depwatch
done
(cd "$release" && sha256sum depwatch_9.9.9_*.tar.gz) > "$work/sums/9.9.9.txt"

export DEPWATCH_RELEASE_BASE="file://$release" DEPWATCH_CHECKSUMS_DIR="$work/sums" GITHUB_PATH="$work/path"

out="$(RUNNER_OS=Linux RUNNER_ARCH=X64 DEPWATCH_VERSION=9.9.9 DEPWATCH_INSTALL_DIR="$work/i1" "$here/install.sh")" || fail "a matching release did not install"
[[ "$out" == *"linux_amd64"* ]] || fail "wrong asset for Linux X64: $out"
grep -q "$work/i1" "$work/path" || fail "not added to GITHUB_PATH"
pass=$((pass+1))

out="$(RUNNER_OS=macOS RUNNER_ARCH=ARM64 DEPWATCH_VERSION=9.9.9 DEPWATCH_INSTALL_DIR="$work/i2" "$here/install.sh")" || fail "macOS ARM64 did not install"
[[ "$out" == *"darwin_arm64"* ]] || fail "wrong asset for macOS ARM64: $out"
pass=$((pass+1))

printf 'tampered' >> "$release/depwatch_9.9.9_linux_amd64.tar.gz"
if RUNNER_OS=Linux RUNNER_ARCH=X64 DEPWATCH_VERSION=9.9.9 DEPWATCH_INSTALL_DIR="$work/i3" "$here/install.sh" 2>"$work/err"; then
  fail "a tampered download was run"
fi
grep -q "does not match its checksum" "$work/err" || fail "no checksum message: $(cat "$work/err")"
[ ! -e "$work/i3/depwatch" ] || fail "the tampered binary was extracted"
pass=$((pass+1))

if RUNNER_OS=Linux RUNNER_ARCH=X64 DEPWATCH_VERSION=1.2.3 DEPWATCH_INSTALL_DIR="$work/i4" "$here/install.sh" 2>"$work/err"; then
  fail "a version with no committed checksums was installed"
fi
grep -q "carries no checksums for version 1.2.3" "$work/err" || fail "no message: $(cat "$work/err")"
pass=$((pass+1))

if DEPWATCH_COMMAND=deploy "$here/run.sh" 2>"$work/err"; then fail "an unknown command ran"; fi
grep -q "command must be" "$work/err" || fail "no message for an unknown command"
pass=$((pass+1))

echo "ok: $pass checks"
