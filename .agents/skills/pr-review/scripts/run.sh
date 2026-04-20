#!/usr/bin/env bash
# PR Review Skill - Automated pull request review script
# Analyzes code changes, checks for common issues, and posts review comments

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# Required environment variables
GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
REPO="${REPO:-}"
PR_NUMBER="${PR_NUMBER:-}"
OPENAI_API_KEY="${OPENAI_API_KEY:-}"

# Optional configuration
MODEL="${MODEL:-gpt-4o}"
MAX_FILES="${MAX_FILES:-50}"
REVIEW_LEVEL="${REVIEW_LEVEL:-standard}"  # minimal | standard | thorough

# ─── Helpers ──────────────────────────────────────────────────────────────────
log()  { echo "[pr-review] $*" >&2; }
err()  { echo "[pr-review] ERROR: $*" >&2; exit 1; }
info() { echo "[pr-review] INFO:  $*" >&2; }

require_cmd() {
  command -v "$1" &>/dev/null || err "Required command not found: $1"
}

require_env() {
  [[ -n "${!1:-}" ]] || err "Required environment variable not set: $1"
}

# ─── Validation ───────────────────────────────────────────────────────────────
require_cmd curl
require_cmd jq
require_cmd python3

require_env GH_TOKEN
require_env REPO
require_env PR_NUMBER
require_env OPENAI_API_KEY

info "Reviewing PR #${PR_NUMBER} in ${REPO} (level: ${REVIEW_LEVEL})"

# ─── Fetch PR metadata ────────────────────────────────────────────────────────
GH_API="https://api.github.com"
AUTH_HEADER="Authorization: Bearer ${GH_TOKEN}"
ACCEPT_HEADER="Accept: application/vnd.github+json"

fetch_pr_info() {
  curl -sSf \
    -H "$AUTH_HEADER" \
    -H "$ACCEPT_HEADER" \
    "${GH_API}/repos/${REPO}/pulls/${PR_NUMBER}"
}

fetch_pr_files() {
  curl -sSf \
    -H "$AUTH_HEADER" \
    -H "$ACCEPT_HEADER" \
    "${GH_API}/repos/${REPO}/pulls/${PR_NUMBER}/files?per_page=${MAX_FILES}"
}

fetch_pr_diff() {
  curl -sSf \
    -H "$AUTH_HEADER" \
    -H "Accept: application/vnd.github.diff" \
    "${GH_API}/repos/${REPO}/pulls/${PR_NUMBER}"
}

log "Fetching PR metadata..."
PR_INFO=$(fetch_pr_info)
PR_TITLE=$(echo "$PR_INFO" | jq -r '.title')
PR_BODY=$(echo "$PR_INFO" | jq -r '.body // "(no description)"')
PR_AUTHOR=$(echo "$PR_INFO" | jq -r '.user.login')
BASE_BRANCH=$(echo "$PR_INFO" | jq -r '.base.ref')
HEAD_BRANCH=$(echo "$PR_INFO" | jq -r '.head.ref')

log "PR: \"${PR_TITLE}\" by @${PR_AUTHOR} (${HEAD_BRANCH} → ${BASE_BRANCH})"

log "Fetching changed files..."
PR_FILES=$(fetch_pr_files)
FILE_COUNT=$(echo "$PR_FILES" | jq 'length')
CHANGED_FILES=$(echo "$PR_FILES" | jq -r '.[].filename' | tr '\n' ', ' | sed 's/,$//')

log "Changed files (${FILE_COUNT}): ${CHANGED_FILES}"

log "Fetching diff..."
PR_DIFF=$(fetch_pr_diff)

# Truncate diff if too large (>30k chars) to stay within token limits
MAX_DIFF_CHARS=30000
if [[ ${#PR_DIFF} -gt $MAX_DIFF_CHARS ]]; then
  log "Diff truncated from ${#PR_DIFF} to ${MAX_DIFF_CHARS} characters"
  PR_DIFF="${PR_DIFF:0:$MAX_DIFF_CHARS}\n... [diff truncated]"
fi

# ─── Build review prompt ──────────────────────────────────────────────────────
REVIEW_INSTRUCTIONS=""
case "$REVIEW_LEVEL" in
  minimal)
    REVIEW_INSTRUCTIONS="Focus only on critical bugs, security issues, and breaking changes."
    ;;
  thorough)
    REVIEW_INSTRUCTIONS="Provide a thorough review covering correctness, security, performance, style, test coverage, and documentation."
    ;;
  *)
    REVIEW_INSTRUCTIONS="Review for correctness, security concerns, obvious bugs, and significant style issues."
    ;;
esac

PROMPT=$(cat <<EOF
You are an expert code reviewer. Review the following pull request and provide actionable feedback.

${REVIEW_INSTRUCTIONS}

## PR Details
- **Title**: ${PR_TITLE}
- **Author**: @${PR_AUTHOR}
- **Branch**: ${HEAD_BRANCH} → ${BASE_BRANCH}
- **Files changed**: ${FILE_COUNT}

## PR Description
${PR_BODY}

## Diff
\`\`\`diff
${PR_DIFF}
\`\`\`

Respond with a JSON object with these fields:
- "summary": 1-3 sentence overall assessment
- "verdict": one of "approve", "request_changes", or "comment"
- "issues": array of objects with "severity" (error|warning|info), "file", "description"
- "suggestions": array of improvement suggestion strings
- "review_body": full markdown review comment to post on GitHub
EOF
)

# ─── Call OpenAI API ──────────────────────────────────────────────────────────
log "Calling OpenAI API (model: ${MODEL})..."

REQUEST_BODY=$(jq -n \
  --arg model "$MODEL" \
  --arg prompt "$PROMPT" \
  '{
    model: $model,
    response_format: { type: "json_object" },
    messages: [{ role: "user", content: $prompt }],
    temperature: 0.2
  }')

AI_RESPONSE=$(curl -sSf \
  -H "Authorization: Bearer ${OPENAI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$REQUEST_BODY" \
  "https://api.openai.com/v1/chat/completions")

REVIEW_JSON=$(echo "$AI_RESPONSE" | jq -r '.choices[0].message.content')
VERDICT=$(echo "$REVIEW_JSON" | jq -r '.verdict')
SUMMARY=$(echo "$REVIEW_JSON" | jq -r '.summary')
REVIEW_BODY=$(echo "$REVIEW_JSON" | jq -r '.review_body')
ISSUE_COUNT=$(echo "$REVIEW_JSON" | jq '.issues | length')

log "Verdict: ${VERDICT} | Issues found: ${ISSUE_COUNT}"
log "Summary: ${SUMMARY}"

# ─── Map verdict to GitHub event ──────────────────────────────────────────────
case "$VERDICT" in
  approve)          GH_EVENT="APPROVE" ;;
  request_changes)  GH_EVENT="REQUEST_CHANGES" ;;
  *)                GH_EVENT="COMMENT" ;;
esac

# ─── Post review to GitHub ────────────────────────────────────────────────────
log "Posting review to GitHub (event: ${GH_EVENT})..."

REVIEW_PAYLOAD=$(jq -n \
  --arg body "$REVIEW_BODY" \
  --arg event "$GH_EVENT" \
  '{ body: $body, event: $event }')

POST_RESULT=$(curl -sSf \
  -X POST \
  -H "$AUTH_HEADER" \
  -H "$ACCEPT_HEADER" \
  -H "Content-Type: application/json" \
  -d "$REVIEW_PAYLOAD" \
  "${GH_API}/repos/${REPO}/pulls/${PR_NUMBER}/reviews")

REVIEW_ID=$(echo "$POST_RESULT" | jq -r '.id')
log "Review posted successfully (id: ${REVIEW_ID})"

# ─── Output summary ───────────────────────────────────────────────────────────
echo ""
echo "======================================="
echo " PR Review Complete"
echo "======================================="
echo " PR:       #${PR_NUMBER} — ${PR_TITLE}"
echo " Verdict:  ${VERDICT}"
echo " Issues:   ${ISSUE_COUNT}"
echo " Review:   ${REVIEW_ID}"
echo "======================================="

# Exit non-zero if changes were requested, so CI can gate on this
[[ "$VERDICT" == "request_changes" ]] && exit 2
exit 0
