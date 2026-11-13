#!/usr/bin/env bash
# Runs one depwatch command and passes its exit code on (and as the step's exit-code output).
set -uo pipefail

case "${DEPWATCH_COMMAND:-}" in
  scan|check|fix|gate|deployed) ;;
  *) echo "depwatch: command must be scan, check, fix, gate or deployed, not '${DEPWATCH_COMMAND:-}'" >&2; exit 3 ;;
esac

# shellcheck disable=SC2086 # the args input is split into words on purpose
depwatch "$DEPWATCH_COMMAND" ${DEPWATCH_ARGS:-}
code=$?
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "exit-code=$code" >> "$GITHUB_OUTPUT"
fi
exit $code
