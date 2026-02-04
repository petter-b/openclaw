#!/usr/bin/env bash
# Audit fork configuration to ensure merge=ours is only used for fork-specific files
#
# Usage: ./.workflow/scripts/audit-fork-config.sh
#
# This script validates:
# 1. Scripts in scripts/ that claim to be fork-specific
# 2. Scripts in .workflow/scripts/ (all should be fork-only)
# 3. .gitattributes merge=ours patterns
#
# Returns exit code 0 if all checks pass, 1 if violations found

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Fork Configuration Audit${NC}"
echo -e "${BLUE}════════════════════════════════════════════════${NC}"
echo ""

VIOLATIONS_FOUND=false

# ============================================================================
# Check 1: Validate .gitattributes merge=ours patterns
# ============================================================================

echo -e "${BLUE}[1/3] Validating .gitattributes merge=ours patterns...${NC}"
echo ""

if [[ -f .gitattributes ]]; then
    MERGE_OURS_PATTERNS=$(grep -E '^\s*[^#].*merge=ours' .gitattributes | awk '{print $1}' || true)

    if [[ -n "$MERGE_OURS_PATTERNS" ]]; then
        echo "Found patterns with merge=ours:"
        while IFS= read -r pattern; do
            echo "  - $pattern"
        done <<< "$MERGE_OURS_PATTERNS"
        echo ""

        ATTR_VIOLATIONS=""
        while IFS= read -r pattern; do
            # Skip CLAUDE.md - it's the only allowed exception
            if [[ "$pattern" = "CLAUDE.md" ]]; then
                echo -e "  ${GREEN}✓${NC} $pattern (allowed exception)"
                continue
            fi

            # Check glob patterns (e.g., .workflow/**)
            if [[ "$pattern" == *"**"* ]]; then
                dir_pattern="${pattern%%/**}"
                if git ls-tree -r --name-only upstream/main | grep -q "^${dir_pattern}/"; then
                    echo -e "  ${RED}✗${NC} $pattern (matches files in upstream)"
                    ATTR_VIOLATIONS="${ATTR_VIOLATIONS}\n    - $pattern (directory exists in upstream)"
                    VIOLATIONS_FOUND=true
                else
                    echo -e "  ${GREEN}✓${NC} $pattern (fork-only directory)"
                fi
            else
                # Check specific file patterns
                if git ls-tree -r --name-only upstream/main | grep -qx "$pattern"; then
                    echo -e "  ${RED}✗${NC} $pattern (file exists in upstream)"
                    ATTR_VIOLATIONS="${ATTR_VIOLATIONS}\n    - $pattern (exists in upstream)"
                    VIOLATIONS_FOUND=true
                else
                    echo -e "  ${GREEN}✓${NC} $pattern (fork-only file)"
                fi
            fi
        done <<< "$MERGE_OURS_PATTERNS"

        if [[ -n "$ATTR_VIOLATIONS" ]]; then
            echo ""
            echo -e "${RED}❌ .gitattributes violations found:${NC}"
            echo -e "$ATTR_VIOLATIONS"
        fi
    else
        echo "No merge=ours patterns found in .gitattributes"
    fi
else
    echo -e "${YELLOW}⚠${NC}  No .gitattributes file found"
fi

echo ""

# ============================================================================
# Check 2: Validate scripts/ directory (fork-specific scripts only)
# ============================================================================

echo -e "${BLUE}[2/3] Checking fork-specific scripts in scripts/...${NC}"
echo ""

# Define which scripts claim to be fork-specific
FORK_SCRIPTS=(
    "apply-release-fixes.sh"
    "build-release.sh"
    "openclaw-status.sh"
    "deploy-release.sh"
    "e2e-with-gateway.sh"
    "rebase-hotfixes.sh"
    "release-fixes-status.sh"
    "sync-upstream.sh"
)

SCRIPT_VIOLATIONS=""
for script in "${FORK_SCRIPTS[@]}"; do
    if [[ ! -f "scripts/$script" ]]; then
        echo -e "  ${YELLOW}⚠${NC}  scripts/$script (not found locally)"
        continue
    fi

    # Check if exists in current upstream
    if git ls-tree -r --name-only upstream/main | grep -qx "scripts/$script"; then
        echo -e "  ${RED}✗${NC} scripts/$script (EXISTS in upstream/main)"
        SCRIPT_VIOLATIONS="${SCRIPT_VIOLATIONS}\n    - scripts/$script (exists in current upstream)"
        VIOLATIONS_FOUND=true
        continue
    fi

    # Check upstream's git log for this file
    if git log upstream/main --oneline -- "scripts/$script" 2>/dev/null | head -1 | grep -q .; then
        echo -e "  ${RED}✗${NC} scripts/$script (found in upstream history)"
        SCRIPT_VIOLATIONS="${SCRIPT_VIOLATIONS}\n    - scripts/$script (existed in upstream, now deleted)"
        VIOLATIONS_FOUND=true
    else
        echo -e "  ${GREEN}✓${NC} scripts/$script (genuinely fork-only)"
    fi
done

if [[ -n "$SCRIPT_VIOLATIONS" ]]; then
    echo ""
    echo -e "${RED}❌ scripts/ violations found:${NC}"
    echo -e "$SCRIPT_VIOLATIONS"
fi

echo ""

# ============================================================================
# Check 3: Validate .workflow/scripts/ (all must be fork-only)
# ============================================================================

echo -e "${BLUE}[3/3] Checking .workflow/scripts/ (all must be fork-only)...${NC}"
echo ""

if [[ -d .workflow/scripts ]]; then
    WORKFLOW_VIOLATIONS=""
    shopt -s nullglob
    for script in .workflow/scripts/*.sh; do
        scriptname=$(basename "$script")

        # Check old scripts/ location in upstream
        if git ls-tree -r --name-only upstream/main | grep -qx "scripts/$scriptname"; then
            echo -e "  ${RED}✗${NC} $scriptname (exists in upstream at scripts/)"
            WORKFLOW_VIOLATIONS="${WORKFLOW_VIOLATIONS}\n    - $scriptname (exists in upstream/main at scripts/)"
            VIOLATIONS_FOUND=true
            continue
        fi

        # Check .workflow/scripts/ location in upstream
        if git ls-tree -r --name-only upstream/main | grep -qx ".workflow/scripts/$scriptname"; then
            echo -e "  ${RED}✗${NC} $scriptname (exists in upstream at .workflow/scripts/)"
            WORKFLOW_VIOLATIONS="${WORKFLOW_VIOLATIONS}\n    - $scriptname (exists in upstream at .workflow/scripts/)"
            VIOLATIONS_FOUND=true
            continue
        fi

        # Check upstream history for either location
        if git log upstream/main --oneline -- "scripts/$scriptname" ".workflow/scripts/$scriptname" 2>/dev/null | head -1 | grep -q .; then
            echo -e "  ${RED}✗${NC} $scriptname (found in upstream history)"
            WORKFLOW_VIOLATIONS="${WORKFLOW_VIOLATIONS}\n    - $scriptname (existed in upstream history)"
            VIOLATIONS_FOUND=true
        else
            echo -e "  ${GREEN}✓${NC} $scriptname (genuinely fork-only)"
        fi
    done
    shopt -u nullglob

    if [[ -n "$WORKFLOW_VIOLATIONS" ]]; then
        echo ""
        echo -e "${RED}❌ .workflow/scripts/ violations found:${NC}"
        echo -e "$WORKFLOW_VIOLATIONS"
    fi
else
    echo -e "${YELLOW}⚠${NC}  .workflow/scripts/ directory not found"
fi

echo ""

# ============================================================================
# Summary
# ============================================================================

echo -e "${BLUE}════════════════════════════════════════════════${NC}"
if [[ "$VIOLATIONS_FOUND" = true ]]; then
    echo -e "${RED}❌ AUDIT FAILED - Violations found!${NC}"
    echo ""
    echo "ACTION REQUIRED:"
    echo "  1. Files in upstream should NOT have merge=ours in .gitattributes"
    echo "  2. Files with merge=ours should be fork-specific only"
    echo "  3. Exception: CLAUDE.md is allowed to override upstream"
    echo ""
    echo "Fix these issues before syncing with upstream."
    exit 1
else
    echo -e "${GREEN}✅ AUDIT PASSED - All checks successful!${NC}"
    echo ""
    echo "Your fork configuration is safe:"
    echo "  - .gitattributes only protects fork-specific files"
    echo "  - All protected files are genuinely fork-only"
    echo "  - No risk of ignoring upstream updates"
    exit 0
fi
