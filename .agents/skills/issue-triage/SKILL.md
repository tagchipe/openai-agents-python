# Issue Triage Skill

Automatically triages new GitHub issues by analyzing content, applying labels, assigning priority, and routing to appropriate team members or milestones.

## What This Skill Does

- Reads newly opened or updated GitHub issues
- Classifies issue type (bug, feature request, question, documentation, etc.)
- Applies appropriate labels based on content analysis
- Assigns priority level (critical, high, medium, low)
- Detects duplicate or related issues
- Posts a structured triage comment summarizing findings
- Optionally assigns issues to relevant contributors based on area of expertise

## Trigger Conditions

This skill runs when:
- A new issue is opened in the repository
- An existing issue is edited (re-triage)
- Manually triggered via workflow dispatch with an issue number

## Inputs

| Variable | Description | Required |
|----------|-------------|----------|
| `GITHUB_TOKEN` | Token with issues read/write permission | Yes |
| `ISSUE_NUMBER` | The issue number to triage | Yes |
| `REPO` | Repository in `owner/repo` format | Yes |
| `OPENAI_API_KEY` | API key for content analysis | Yes |

## Outputs

- Labels applied to the issue
- Priority comment posted on the issue
- JSON triage report written to `triage-report.json`

## Labels Applied

### Type Labels
- `bug` — Confirmed or suspected defect
- `enhancement` — Feature request or improvement
- `question` — Usage question or clarification needed
- `documentation` — Docs gap or correction
- `performance` — Performance-related concern
- `security` — Potential security issue (handled with care)

### Priority Labels
- `priority: critical` — Data loss, security vulnerability, total breakage
- `priority: high` — Major functionality broken, no workaround
- `priority: medium` — Functionality impaired, workaround exists
- `priority: low` — Minor issue, cosmetic, or nice-to-have

### Status Labels
- `needs-reproduction` — Cannot reproduce without more info
- `needs-info` — Awaiting response from issue author
- `duplicate` — Duplicate of an existing issue
- `good first issue` — Suitable for new contributors

## Configuration

Optional configuration via `.agents/skills/issue-triage/config.yaml`:

```yaml
auto_assign: false
post_comment: true
close_duplicates: false
duplicate_search_limit: 50
priority_keywords:
  critical:
    - "data loss"
    - "security"
    - "crash"
    - "corruption"
  high:
    - "broken"
    - "regression"
    - "not working"
```

## Example Triage Comment

```
## 🏷️ Issue Triage Report

**Type:** Bug  
**Priority:** High  
**Area:** Agent execution

### Summary
This issue reports unexpected behavior in the agent run loop when streaming is enabled alongside tool calls.

### Labels Applied
- `bug`, `priority: high`, `area: streaming`

### Related Issues
- Similar to #142, #187

### Next Steps
- Needs reproduction case
- Assigned to streaming subsystem owner

_Triaged automatically by the issue-triage skill._
```
