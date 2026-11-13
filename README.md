# depwatch-action

The GitHub Action for depwatch: it installs a pinned, checksummed release of the `depwatch` CLI on the
runner and runs one command: `scan` (send the inventory to your depwatch server), `check` (the code
check's draft verdicts), `fix` (open a pull request per finding set to be fixed that way), `gate` (fail
the build on a finding, with no server) or `deployed` (report a deployment).

What depwatch does and why: [`depwatch-docs/SYSTEM.md`](../depwatch-docs/SYSTEM.md). The CLI itself:
[`depwatch-cli`](../depwatch-cli).

## Use

```yaml
- uses: actions/checkout@v4
- uses: kimathinjoki/depwatch-action@<commit-sha>   # pin by commit SHA
  with:
    command: gate
    args: --fail-on malicious,kev,severe
```

| Input | Default | What |
|---|---|---|
| `command` | (required) | `scan`, `check`, `fix`, `gate` or `deployed` |
| `args` | | more arguments, for example `--image app.tar` or `--sha ${{ github.sha }}` |
| `working-directory` | `.` | the part's folder |
| `version` | `0.1.0` | the CLI release; it must be listed in `checksums/` |
| `server`, `token` | | your depwatch server and the part's token (a secret), for `scan`, `check`, `fix`, `deployed` |
| `github-token` | `${{ github.token }}` | the token `fix` opens pull requests with |

Output: `exit-code`, the command's exit code (the step also fails with it). Exit codes are the CLI's:
0 fine, 1 a finding meets the gate's threshold, 2 incomplete, 3 a usage error.

Full workflows: [`examples/`](examples) (scan and check on push, the gate on pull requests, daily
fixes, scanning the built image and reporting deployments).

## Pull requests

`fix` needs `permissions: contents: write, pull-requests: write`, and the project's package manager set
up before it (as your own CI does). It opens one pull request per finding per part, or updates the one
already open, describing the advisory, the level, why it matters, the dependency path and the code
check evidence. **A person approves and merges. depwatch never merges**, approves or turns on
auto-merge.

## Supply chain

- The Action downloads one release asset for the runner's system and architecture and verifies its
  SHA-256 against `checksums/<version>.txt`, committed in this repository. A mismatch, or a version with
  no committed checksums, stops the step before anything runs. There is no "latest".
- Pin the Action itself by commit SHA, so neither the Action nor the CLI can change under you.

## Test

```sh
bash tests/install_test.sh    # installer and runner against a local fake release
shellcheck install.sh run.sh tests/install_test.sh
```

## Licence

MIT. Copyright 2026 kimathinjoki.
