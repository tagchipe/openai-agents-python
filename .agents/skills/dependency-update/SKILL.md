# Dependency Update Skill

This skill automates the process of checking for outdated dependencies and creating pull requests with updates.

## What it does

1. Scans `pyproject.toml` and `requirements*.txt` files for dependencies
2. Checks for newer versions on PyPI
3. Runs the test suite to verify compatibility
4. Summarizes findings with upgrade recommendations

## When to use

- Routine dependency maintenance
- Security vulnerability patching
- Keeping the project up to date with upstream libraries

## Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `check_only` | No | `false` | Only report outdated deps, do not modify files |
| `include_pre` | No | `false` | Include pre-release versions |
| `packages` | No | _(all)_ | Comma-separated list of specific packages to update |

## Outputs

- List of outdated packages with current vs. latest versions
- Modified dependency files (if `check_only` is false)
- Test run summary after updates

## Usage

```bash
bash .agents/skills/dependency-update/scripts/run.sh
```

Or with options:

```bash
check_only=true bash .agents/skills/dependency-update/scripts/run.sh
```

## Requirements

- Python 3.9+
- `pip` available in PATH
- Project uses `pyproject.toml` or `requirements.txt`
