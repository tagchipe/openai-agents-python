#!/usr/bin/env bash
set -euo pipefail

# Dependency Update Skill
# Checks for outdated dependencies and creates a summary of available updates.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

echo "=== Dependency Update Check ==="
echo "Repository root: ${REPO_ROOT}"
cd "${REPO_ROOT}"

# ── Helpers ────────────────────────────────────────────────────────────────

command_exists() {
  command -v "$1" &>/dev/null
}

print_section() {
  echo ""
  echo "──────────────────────────────────────────"
  echo "  $1"
  echo "──────────────────────────────────────────"
}

# ── Python / uv ────────────────────────────────────────────────────────────

check_python_deps() {
  print_section "Python Dependencies"

  if ! command_exists uv; then
    echo "[SKIP] uv not found — skipping Python dependency check."
    return
  fi

  if [ ! -f "pyproject.toml" ]; then
    echo "[SKIP] No pyproject.toml found."
    return
  fi

  echo "Running: uv lock --upgrade-package '*' --dry-run"
  # Show outdated packages by comparing lock file with latest index
  if uv pip list --outdated 2>/dev/null; then
    echo "[OK] Outdated Python packages listed above."
  else
    echo "[INFO] Could not determine outdated packages via 'uv pip list --outdated'."
    echo "       Trying alternative: pip list --outdated inside the venv."
    if [ -f ".venv/bin/python" ]; then
      .venv/bin/pip list --outdated 2>/dev/null || echo "[WARN] pip list --outdated failed."
    fi
  fi
}

# ── Node / npm ──────────────────────────────────────────────────────────────

check_node_deps() {
  print_section "Node.js Dependencies"

  if ! command_exists npm; then
    echo "[SKIP] npm not found — skipping Node.js dependency check."
    return
  fi

  if [ ! -f "package.json" ]; then
    echo "[SKIP] No package.json found."
    return
  fi

  echo "Running: npm outdated"
  npm outdated || true   # npm outdated exits 1 when updates exist; suppress failure
}

# ── GitHub Actions ──────────────────────────────────────────────────────────

check_github_actions() {
  print_section "GitHub Actions Pinned Versions"

  if [ ! -d ".github/workflows" ]; then
    echo "[SKIP] No .github/workflows directory found."
    return
  fi

  echo "Scanning workflow files for action references..."
  grep -rh 'uses:' .github/workflows/ | \
    sed 's/.*uses:[[:space:]]*//' | \
    sed 's/[[:space:]].*//' | \
    sort -u | \
    while read -r action; do
      echo "  - ${action}"
    done

  echo ""
  echo "[INFO] Review the above actions for available version bumps at https://github.com/<owner>/<repo>/releases"
}

# ── Summary ─────────────────────────────────────────────────────────────────

print_summary() {
  print_section "Summary"
  echo "Dependency check complete."
  echo ""
  echo "Next steps:"
  echo "  1. Review outdated packages listed above."
  echo "  2. Update pyproject.toml / package.json as appropriate."
  echo "  3. Run tests to verify compatibility."
  echo "  4. Commit updated lock files together with the version bumps."
}

# ── Main ────────────────────────────────────────────────────────────────────

main() {
  check_python_deps
  check_node_deps
  check_github_actions
  print_summary
}

main "$@"
