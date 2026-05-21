# Harness CLI

A unified CLI for Harness. Manage pipelines, artifacts, platform resources, and more from the command line.

---

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/sawka-harness/unified-cli/main/install.sh | bash
```

The installer will:

- Download the latest binary for your platform (macOS and Linux, amd64/arm64)
- Install to `~/.local/bin` (override with `HARNESS_INSTALL_DIR`)
- Optionally add `~/.local/bin` to your `PATH` and enable shell completions

---

## Shell Completions

Tab-completion is fully wired — completions for identifiers hit the live API and return `id<tab>Name` suggestions.

**Zsh:**

```sh
source <(harness completion zsh)
```

**Bash:**

```sh
source <(harness completion bash)
```

Add the appropriate line to your `.zshrc` or `.bashrc` to make it permanent. The installer can do this automatically.

---

## Auth

All commands resolve auth from (in order): `--profile` flag → `HARNESS_API_KEY` env var → `HARNESS_PROFILE` env var → CI runner env vars → default profile.

### Login

```sh
harness auth login
```

Without arguments, launches an interactive TUI (requires a TTY; errors otherwise). Or pass flags directly (useful for scripting):

```sh
harness auth login --api-token <PAT>
```

- `--api-url` defaults to `https://app.harness.io`
- Account ID is extracted from the PAT automatically; pass `--account` only to override
- `--org` and `--project` set defaults for the profile (optional)
- `--profile <name>` saves as a named profile; omit for `default`
- `--overwrite` / `--no-overwrite` control behavior when the profile already exists
- `--no-validate` skips the token validation call

Profile config is saved to `~/.harness/config.yaml`; the token is stored in `~/.harness/credentials`.

### Change default org/project

Without arguments, launches an interactive TUI to select org/project. Pass flags to set directly:

```sh
harness auth setscope --org my-org --project my-project
```

### Check status

```sh
harness auth status
harness auth status --profile staging
```

### Logout

Clears the profile's credentials and removes it from the config:

```sh
harness auth logout
harness auth logout --profile staging
```

---

## Commands

The grammar is `harness <verb> <noun> [identifier] [flags]`. Use `--help` at any level.

### Supported commands

`✓` = supported, `P` = supported with server-side paging

#### Platform / Access Control

| Noun              | list | get | create | update | delete | execute |
| ----------------- | ---- | --- | ------ | ------ | ------ | ------- |
| `organization`    | P    | ✓   |        |        |        |         |
| `project`         | P    | ✓   | ✓      |        | ✓      |         |
| `user`            | P    | ✓   |        |        |        |         |
| `user_group`      | ✓    | ✓   |        |        |        |         |
| `service_account` | ✓    | ✓   |        |        |        |         |
| `role`            | ✓    | ✓   |        |        |        |         |
| `permission`      | ✓    |     |        |        |        |         |
| `connector`       | ✓    | ✓   |        |        |        |         |
| `secret`          | ✓    | ✓   |        |        |        |         |
| `delegate`        | ✓    |     |        |        |        |         |
| `setting`         | ✓    |     |        |        |        |         |

#### Pipelines / CI/CD

| Noun                     | list | get | create | update | delete | execute |
| ------------------------ | ---- | --- | ------ | ------ | ------ | ------- |
| `pipeline`               | ✓    | ✓   | ✓      | ✓      | ✓      | ✓       |
| `pipeline_v1`            | ✓    | ✓   |        |        |        |         |
| `pipeline_summary`       |      | ✓   |        |        |        |         |
| `execution`              | P    | ✓   |        |        |        |         |
| `execution_step`         | ✓    |     |        |        |        |         |
| `execution_log`          | ✓    | ✓   |        |        |        |         |
| `trigger`                | ✓    | ✓   |        |        |        |         |
| `input_set`              | ✓    | ✓   |        |        |        |         |
| `runtime_input_template` |      | ✓   |        |        |        |         |
| `approval_instance`      | ✓    |     |        |        |        |         |
| `template`               | ✓    | ✓   |        |        |        |         |
| `freeze_window`          | ✓    | ✓   |        |        |        |         |
| `global_freeze`          |      | ✓   |        |        |        |         |

#### Artifact Registry

| Noun                        | list | get | create | update | delete | push | pull |
| --------------------------- | ---- | --- | ------ | ------ | ------ | ---- | ---- |
| `registry`                  | ✓    | ✓   | ✓      |        |        |      |      |
| `registry_metadata`         |      | ✓   |        | ✓      | ✓      |      |      |
| `artifact`                  | ✓    | ✓   |        |        | ✓      | ✓    | ✓    |
| `artifact_metadata`         |      | ✓   |        | ✓      | ✓      |      |      |
| `artifact_version`          | ✓    | ✓   |        |        | ✓      |      |      |
| `artifact_version_metadata` |      | ✓   |        | ✓      | ✓      |      |      |
| `artifact_file`             | ✓    |     |        |        |        |      |      |

---

## Output Formats

All commands support `--format`. The default is `text` for most commands; `list` commands default to `table`.

```sh
# list commands
harness list pipeline --format table     # default
harness list pipeline --format text
harness list pipeline --format json
harness list pipeline --format jsonl     # one JSON object per line
harness list pipeline --format csv
harness list pipeline --format tsv

# get/other commands
harness get pipeline my-pipeline --format json
harness get pipeline my-pipeline --format text   # default
```

---

## Multiple Profiles

Use `--profile` to target a specific account/org/project config:

```sh
harness auth login --profile prod --api-token <token> --account <id>
harness list pipeline --profile prod
```
