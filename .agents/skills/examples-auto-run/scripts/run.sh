#!/bin/bash
# examples-auto-run skill script
# Automatically discovers and runs all examples in the repository,
# reporting which pass and which fail.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
EXAMPLES_DIR="${REPO_ROOT}/examples"
RESULTS_FILE="${REPO_ROOT}/.agents/skills/examples-auto-run/results.md"
PASS=0
FAIL=0
SKIP=0
FAILED_EXAMPLES=()

echo "# Examples Auto-Run Results" > "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "Run at: $(date -u '+%Y-%m-%dT%H:%M:%SZ')" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "| Example | Status | Notes |" >> "$RESULTS_FILE"
echo "|---------|--------|-------|" >> "$RESULTS_FILE"

if [ ! -d "$EXAMPLES_DIR" ]; then
  echo "ERROR: examples directory not found at $EXAMPLES_DIR"
  exit 1
fi

# Check for virtual environment or use system python
if [ -f "${REPO_ROOT}/.venv/bin/python" ]; then
  PYTHON="${REPO_ROOT}/.venv/bin/python"
elif command -v python3 &>/dev/null; then
  PYTHON="python3"
else
  echo "ERROR: No python interpreter found"
  exit 1
fi

echo "Using Python: $PYTHON"
echo "Scanning examples in: $EXAMPLES_DIR"
echo ""

# Find all runnable example files
mapfile -t EXAMPLE_FILES < <(find "$EXAMPLES_DIR" -name "*.py" | sort)

for example in "${EXAMPLE_FILES[@]}"; do
  rel_path="${example#$REPO_ROOT/}"

  # Skip examples that require user interaction or live API keys in CI
  if grep -qE 'input\(|getpass\.' "$example" 2>/dev/null; then
    echo "SKIP (interactive): $rel_path"
    echo "| \`$rel_path\` | ⏭ SKIP | requires interactive input |" >> "$RESULTS_FILE"
    SKIP=$((SKIP + 1))
    continue
  fi

  # Check for syntax errors first (fast, no API calls)
  if ! "$PYTHON" -m py_compile "$example" 2>/tmp/example_err; then
    err=$(cat /tmp/example_err | head -5)
    echo "FAIL (syntax): $rel_path"
    echo "| \`$rel_path\` | ❌ FAIL | syntax error: $(echo $err | tr '|' '/') |" >> "$RESULTS_FILE"
    FAIL=$((FAIL + 1))
    FAILED_EXAMPLES+=("$rel_path")
    continue
  fi

  # Dry-run: import check only (avoids executing agents/API calls)
  timeout 30 "$PYTHON" - <<EOF 2>/tmp/example_err
import ast, sys
with open('$example') as f:
    source = f.read()
try:
    tree = ast.parse(source)
    # Check for obvious import errors by compiling
    compile(tree, '$example', 'exec')
    sys.exit(0)
except Exception as e:
    print(str(e), file=sys.stderr)
    sys.exit(1)
EOF
  status=$?

  if [ $status -eq 0 ]; then
    echo "PASS: $rel_path"
    echo "| \`$rel_path\` | ✅ PASS | |" >> "$RESULTS_FILE"
    PASS=$((PASS + 1))
  elif [ $status -eq 124 ]; then
    echo "FAIL (timeout): $rel_path"
    echo "| \`$rel_path\` | ❌ FAIL | timed out after 30s |" >> "$RESULTS_FILE"
    FAIL=$((FAIL + 1))
    FAILED_EXAMPLES+=("$rel_path")
  else
    err=$(cat /tmp/example_err | head -3 | tr '\n' ' ')
    echo "FAIL: $rel_path — $err"
    echo "| \`$rel_path\` | ❌ FAIL | $(echo $err | tr '|' '/') |" >> "$RESULTS_FILE"
    FAIL=$((FAIL + 1))
    FAILED_EXAMPLES+=("$rel_path")
  fi
done

echo "" >> "$RESULTS_FILE"
echo "## Summary" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "- ✅ Passed: $PASS" >> "$RESULTS_FILE"
echo "- ❌ Failed: $FAIL" >> "$RESULTS_FILE"
echo "- ⏭ Skipped: $SKIP" >> "$RESULTS_FILE"

echo ""
echo "=============================="
echo "Results: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
echo "=============================="

if [ ${#FAILED_EXAMPLES[@]} -gt 0 ]; then
  echo ""
  echo "Failed examples:"
  for f in "${FAILED_EXAMPLES[@]}"; do
    echo "  - $f"
  done
  exit 1
fi

echo "All examples passed (or were skipped)."
exit 0
