#!/usr/bin/env bash
# Lint all fork-specific scripts with shellcheck

set -euo pipefail

echo "Linting fork-specific scripts..."
echo "================================="
echo ""

FORK_SCRIPTS=(
  "scripts/apply-release-fixes.sh"
  "scripts/build-release.sh"
  "scripts/openclaw-status.sh"
  "scripts/deploy-release.sh"
  "scripts/e2e-with-gateway.sh"
  "scripts/rebase-hotfixes.sh"
  "scripts/release-fixes-status.sh"
  "scripts/sync-upstream.sh"
)

WORKFLOW_SCRIPTS=(
  ".workflow/scripts/audit-fork-config.sh"
  ".workflow/scripts/daily-all.sh"
  ".workflow/scripts/daily-build-k8s.sh"
  ".workflow/scripts/daily-build.sh"
  ".workflow/scripts/daily-e2e-k8s.sh"
  ".workflow/scripts/setup-worktrees.sh"
)

ALL_SCRIPTS=("${FORK_SCRIPTS[@]}" "${WORKFLOW_SCRIPTS[@]}")

FAILED=0
for script in "${ALL_SCRIPTS[@]}"; do
  if [[ ! -f "$script" ]]; then
    echo "⚠️  $script (not found)"
    continue
  fi
  
  echo "Checking: $script"
  if shellcheck "$script"; then
    echo "  ✓ Passed"
  else
    echo "  ✗ Failed"
    FAILED=$((FAILED + 1))
  fi
  echo ""
done

if [[ $FAILED -gt 0 ]]; then
  echo "❌ $FAILED script(s) failed shellcheck"
  exit 1
else
  echo "✅ All fork-specific scripts passed shellcheck"
  exit 0
fi
