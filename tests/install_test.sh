#!/usr/bin/env bash
# Tests install.sh against a local fake release. The test lays out a copy of the Action whose own
# checksums and release address point at the fake release, since the real installer reads neither from
# the environment. A matching download installs and runs; a tampered one stops; a version with no
# committed checksums stops; no version stops with a plain message; settings in the environment are
# ignored; the asset follows the runner's system.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
pass=0
fail() { echo "FAIL: $*" >&2; exit 1; }

release="$work/release"; mkdir -p "$release/v9.9.9"
for target in linux_amd64 darwin_arm64; do
  mkdir -p "$work/build/$target"
  printf '#!/usr/bin/env bash\necho "depwatch 9.9.9 (%s)"\n' "$target" > "$work/build/$target/depwatch"
  chmod +x "$work/build/$target/depwatch"
  tar -czf "$release/v9.9.9/depwatch_9.9.9_$target.tar.gz" -C "$work/build/$target" depwatch
done

# The copy of the Action under test: its own checksums for 9.9.9, its release address the fake one.
action="$work/action"; mkdir -p "$action/checksums"
cp "$here/install.sh" "$here/run.sh" "$action/"
(cd "$release/v9.9.9" && sha256sum depwatch_9.9.9_*.tar.gz) > "$action/checksums/9.9.9.txt"
sed -i.bak "s|^release_base=.*|release_base=\"file://$release\"|" "$action/install.sh" && rm -f "$action/install.sh.bak"
grep -q "^release_base=\"file://$release\"" "$action/install.sh" || fail "the test could not point the copy at the fake release"

export GITHUB_PATH="$work/path" RUNNER_TEMP="$work/tmp"
mkdir -p "$RUNNER_TEMP"

out="$(RUNNER_OS=Linux RUNNER_ARCH=X64 DEPWATCH_VERSION=9.9.9 "$action/install.sh")" || fail "a matching release did not install"
[[ "$out" == *"linux_amd64"* ]] || fail "wrong asset for Linux X64: $out"
grep -q "$RUNNER_TEMP/depwatch-9.9.9" "$work/path" || fail "not added to GITHUB_PATH"
pass=$((pass+1))

out="$(RUNNER_OS=macOS RUNNER_ARCH=ARM64 DEPWATCH_VERSION=9.9.9 "$action/install.sh")" || fail "macOS ARM64 did not install"
[[ "$out" == *"darwin_arm64"* ]] || fail "wrong asset for macOS ARM64: $out"
pass=$((pass+1))

# Checksums and a release address set in the job's environment (as an earlier step writing to
# $GITHUB_ENV could) are ignored: the copy still installs only what its own checksums allow.
evil="$work/evil"; mkdir -p "$evil/sums" "$evil/v9.9.9" "$evil/build"
printf '#!/usr/bin/env bash\necho "planted"\n' > "$evil/build/depwatch"; chmod +x "$evil/build/depwatch"
tar -czf "$evil/v9.9.9/depwatch_9.9.9_linux_amd64.tar.gz" -C "$evil/build" depwatch
(cd "$evil/v9.9.9" && sha256sum depwatch_9.9.9_linux_amd64.tar.gz) > "$evil/sums/9.9.9.txt"
out="$(RUNNER_OS=Linux RUNNER_ARCH=X64 DEPWATCH_VERSION=9.9.9 DEPWATCH_CHECKSUMS_DIR="$evil/sums" \
  DEPWATCH_RELEASE_BASE="file://$evil/v9.9.9" DEPWATCH_INSTALL_DIR="$evil/dest" "$action/install.sh")" || fail "the environment changed the install"
[[ "$out" == *"linux_amd64"* && "$out" != *planted* ]] || fail "the environment swapped the release: $out"
[ ! -e "$evil/dest" ] || fail "the environment chose the install folder"
pass=$((pass+1))

printf 'tampered' >> "$release/v9.9.9/depwatch_9.9.9_linux_amd64.tar.gz"
if RUNNER_OS=Linux RUNNER_ARCH=X64 DEPWATCH_VERSION=9.9.9 "$action/install.sh" 2>"$work/err"; then
  fail "a tampered download was run"
fi
grep -q "does not match its checksum" "$work/err" || fail "no checksum message: $(cat "$work/err")"
pass=$((pass+1))

if RUNNER_OS=Linux RUNNER_ARCH=X64 DEPWATCH_VERSION=1.2.3 "$action/install.sh" 2>"$work/err"; then
  fail "a version with no committed checksums was installed"
fi
grep -q "carries no checksums for version 1.2.3" "$work/err" || fail "no message: $(cat "$work/err")"
grep -q "it carries: 9.9.9" "$work/err" || fail "the message does not name the versions carried: $(cat "$work/err")"
pass=$((pass+1))

if RUNNER_OS=Linux RUNNER_ARCH=X64 DEPWATCH_VERSION= "$action/install.sh" 2>"$work/err"; then
  fail "no version installed something"
fi
grep -q "set the Action's version input" "$work/err" || fail "no message for a missing version: $(cat "$work/err")"
pass=$((pass+1))

# The real Action, which carries no checksums until the first release, says so plainly.
if RUNNER_OS=Linux RUNNER_ARCH=X64 DEPWATCH_VERSION=0.1.0 "$here/install.sh" 2>"$work/err"; then
  fail "the real Action installed a version it carries no checksums for"
fi
if ls "$here"/checksums/*.txt >/dev/null 2>&1; then
  grep -q "carries no checksums for version 0.1.0" "$work/err" || fail "no message: $(cat "$work/err")"
else
  grep -q "no depwatch CLI release has been published" "$work/err" || fail "no plain message: $(cat "$work/err")"
fi
pass=$((pass+1))

if DEPWATCH_COMMAND=deploy "$here/run.sh" 2>"$work/err"; then fail "an unknown command ran"; fi
grep -q "command must be" "$work/err" || fail "no message for an unknown command"
pass=$((pass+1))

echo "ok: $pass checks"
