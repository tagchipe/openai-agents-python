# PR Review Skill

This skill automates pull request review by analyzing code changes, checking for common issues, and providing structured feedback.

## What it does

- Reviews pull request diffs for code quality issues
- Checks for missing tests or documentation
- Validates that changes are consistent with project conventions
- Posts structured review comments
- Summarizes the overall impact of changes

## When to use

Trigger this skill when:
- A new pull request is opened or updated
- You want an automated first-pass review before human review
- You need to enforce coding standards consistently

## Inputs

| Variable | Description | Required |
|----------|-------------|----------|
| `PR_NUMBER` | The pull request number to review | Yes |
| `REPO` | Repository in `owner/repo` format | Yes |
| `GITHUB_TOKEN` | GitHub token with PR read/write access | Yes |
| `REVIEW_MODE` | `comment` or `request_changes` (default: `comment`) | No |

## Outputs

- A structured review posted to the pull request
- Exit code `0` on success, non-zero on failure

## Usage

```bash
export PR_NUMBER=42
export REPO=my-org/my-repo
export GITHUB_TOKEN=ghp_...
bash .agents/skills/pr-review/scripts/run.sh
```

## Notes

- Requires `gh` CLI or `curl` for GitHub API access
- The skill does not approve PRs automatically; it only comments or requests changes
- Large diffs (>500 changed lines) are summarized rather than reviewed line-by-line
