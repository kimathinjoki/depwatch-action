# watchdep-action

The GitHub Action for watchdep: it installs a pinned, checksummed release of the `watchdep` CLI on the
runner and runs one command: `scan` (send the inventory to the watchdep service), `check` (the code
check's draft verdicts), `fix` (open a pull request per finding set to be fixed that way), `gate` (fail
the build on a finding, with no server) or `deployed` (report a deployment).

The CLI itself, its commands and exit codes:
[`watchdep-cli`](https://github.com/kimathinjoki/watchdep-cli).

It carries checksums for watchdep CLI 0.1.0 to 0.4.0 (`checksums/`). Each new CLI release is added here in
its own reviewed commit.

## Use

```yaml
- uses: actions/checkout@v4
- uses: kimathinjoki/watchdep-action@<commit-sha>   # pin by commit SHA
  with:
    version: 0.3.0                                  # a release listed in checksums/
    command: gate
    args: --fail-on malicious,kev,severe
```

| Input | Default | What |
|---|---|---|
| `command` | (required) | `scan`, `check`, `fix`, `gate` or `deployed` |
| `args` | | more arguments, for example `--image app.tar` or `--sha ${{ github.sha }}` |
| `working-directory` | `.` | the part's folder |
| `version` | (required) | the CLI release; it must be listed in `checksums/`. There is no default and no "latest" |
| `server`, `token` | | the watchdep service's address and the part's token (a secret), for `scan`, `check`, `fix`, `deployed` |
| `github-token` | `${{ github.token }}` | the token `fix` opens pull requests with |

Output: `exit-code`, the command's exit code (the step also fails with it). Exit codes are the CLI's:
0 fine, 1 a finding meets the gate's threshold, 2 incomplete, 3 a usage error.

Full workflows: [`examples/`](examples) (scan and check on push, the gate on pull requests, daily
fixes, scanning the built image and reporting deployments).

## Pull requests

`fix` needs `permissions: contents: write, pull-requests: write`, and the project's package manager set
up before it (as your own CI does). It opens one pull request per finding per part, or updates the one
already open, describing the advisory, the level, why it matters, the dependency path and the code
check evidence. **A person approves and merges. watchdep never merges**, approves or turns on
auto-merge.

## Supply chain

- The Action downloads one release asset for the runner's system and architecture and verifies its
  SHA-256 against `checksums/<version>.txt`, committed in this repository. A mismatch, or a version with
  no committed checksums, stops the step before anything runs. There is no "latest".
- The checksums and the download address are fixed in the Action's own files. Nothing in the job's
  environment changes them, so an earlier step writing to `$GITHUB_ENV` cannot swap the release or the
  checksums it is checked against. The binary goes into a fresh folder under `$RUNNER_TEMP`.
- Pin the Action itself by commit SHA, so neither the Action nor the CLI can change under you.

## Test

```sh
make check    # as CI: both below
make test     # bash tests/install_test.sh: a copy of the Action, with its own checksums, against a local fake release
make lint     # shellcheck install.sh run.sh tests/install_test.sh
```

The Action has no settings file: it takes its inputs (`version`, `command`, `args`) in the workflow, and
the CLI's own variables (`WATCHDEP_SERVER`, `WATCHDEP_TOKEN`, `GITHUB_TOKEN`) as workflow secrets and
variables; `examples/` shows each.

## Licence

MIT. Copyright 2026 kimathinjoki.
