#!/bin/bash
# ===============================================================
#  REPO HEALTH CHECKER  -  PACE 2026 | Week 1 Mini Project
#  Author: laas
#
#  Purpose: Validates a GitHub repo on every push using GitHub
#  Actions. Acts as a CI gate - exit 0 = pass, exit 1 = fail.
#
#  Design: Each check is a self-contained function that updates
#  global counters. At the end, we print a Health Score (0-100)
#  with a letter grade. If ANY required check fails, exit 1.
# ===============================================================

set -u
set -o pipefail

# --- COLOR CODES (so output is readable in Actions logs) ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# --- COUNTERS ---
TOTAL_CHECKS=0
PASSED=0
FAILED=0
WARNINGS=0
FAIL_REASONS=()

# --- HELPER FUNCTIONS ---
print_header() {
    echo ""
    echo -e "${BLUE}==============================================================${NC}"
    echo -e "${BLUE}      REPO HEALTH CHECKER  -  PACE 2026 Week 1 Mini Project   ${NC}"
    echo -e "${BLUE}==============================================================${NC}"
    echo ""
}

print_check() {
    echo -e "${CYAN}>> Check $1:${NC} ${BOLD}$2${NC}"
}

pass() {
    echo -e "  ${GREEN}[PASS]${NC} $1"
    PASSED=$((PASSED + 1))
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
}

fail() {
    echo -e "  ${RED}[FAIL]${NC} $1"
    FAILED=$((FAILED + 1))
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    FAIL_REASONS+=("$1")
}

warn() {
    echo -e "  ${YELLOW}[WARN]${NC} $1"
    WARNINGS=$((WARNINGS + 1))
}

# ===============================================================
#  CHECK 1 - README.md exists and has real content
# ===============================================================
check_readme() {
    print_check 1 "README.md exists and has substance"
    if [ ! -f "README.md" ]; then
        fail "README.md is missing"
        return
    fi
    line_count=$(wc -l < README.md)
    if [ "$line_count" -lt 10 ]; then
        fail "README.md exists but only has $line_count lines (need >10)"
    else
        pass "README.md has $line_count lines"
    fi
}

# ===============================================================
#  CHECK 2 - .gitignore exists
# ===============================================================
check_gitignore() {
    print_check 2 ".gitignore is present"
    if [ ! -f ".gitignore" ]; then
        fail ".gitignore is missing"
    elif [ ! -s ".gitignore" ]; then
        fail ".gitignore exists but is empty"
    else
        pass ".gitignore present and non-empty"
    fi
}

# ===============================================================
#  CHECK 3 - No secret FILES committed
# ===============================================================
check_secret_files() {
    print_check 3 "No secret files committed (.env, *.key, *.pem, id_rsa)"
    bad_files=$(git ls-files | grep -E '(^|/)(\.env(\..*)?$|.*\.key$|.*\.pem$|id_rsa$|.*\.p12$|credentials\.json$)' || true)
    if [ -n "$bad_files" ]; then
        fail "Secret files detected in repo:"
        echo "$bad_files" | while read -r f; do echo "         -> $f"; done
    else
        pass "No secret files found in tracked files"
    fi
}

# ===============================================================
#  CHECK 4 - INNOVATIVE: Hardcoded secret pattern scanner
# ===============================================================
check_secret_patterns() {
    print_check 4 "No hardcoded secrets/API keys inside files (regex scan)"
    files_to_scan=$(git ls-files | grep -vE '\.(png|jpg|jpeg|gif|pdf|zip|exe|lock)$' | grep -v '^check.sh$' || true)
    if [ -z "$files_to_scan" ]; then
        pass "Nothing to scan"
        return
    fi

    found=0
    if echo "$files_to_scan" | xargs grep -lE 'AKIA[0-9A-Z]{16}' 2>/dev/null; then
        echo "         -> Possible AWS Access Key found"
        found=1
    fi
    if echo "$files_to_scan" | xargs grep -lE 'ghp_[0-9a-zA-Z]{36}' 2>/dev/null; then
        echo "         -> Possible GitHub Token found"
        found=1
    fi
    if echo "$files_to_scan" | xargs grep -liE '(api[_-]?key|secret|password|token)[[:space:]]*=[[:space:]]*["][A-Za-z0-9_/+=-]{20,}["]' 2>/dev/null; then
        echo "         -> Possible hardcoded credential assignment found"
        found=1
    fi

    if [ "$found" -eq 1 ]; then
        fail "Hardcoded secret patterns detected - review files above"
    else
        pass "No secret patterns detected"
    fi
}

# ===============================================================
#  CHECK 5 - INNOVATIVE: Merge conflict markers
# ===============================================================
check_merge_conflicts() {
    print_check 5 "No leftover merge conflict markers in tracked files"
    files_to_scan=$(git ls-files | grep -vE '\.(png|jpg|jpeg|gif|pdf|zip|exe)$' | grep -v '^check.sh$' || true)
    if [ -z "$files_to_scan" ]; then
        pass "Nothing to scan"
        return
    fi
    if echo "$files_to_scan" | xargs grep -lE '^(<{7}|={7}|>{7})( |$)' 2>/dev/null; then
        fail "Merge conflict markers found in files above"
    else
        pass "No merge conflict markers"
    fi
}

# ===============================================================
#  CHECK 6 - INNOVATIVE: Leftover debug code (WARN, not FAIL)
# ===============================================================
check_debug_code() {
    print_check 6 "No leftover debug code (console.log, debugger, TODO: REMOVE)"
    files_to_scan=$(git ls-files | grep -E '\.(js|jsx|ts|tsx|py|java|c|cpp|sh)$' | grep -v '^check.sh$' || true)
    if [ -z "$files_to_scan" ]; then
        pass "No source files to scan"
        return
    fi
    debug_hits=$(echo "$files_to_scan" | xargs grep -lE '(console\.log|debugger;|TODO:[[:space:]]*REMOVE)' 2>/dev/null || true)
    if [ -n "$debug_hits" ]; then
        warn "Debug code found in:"
        echo "$debug_hits" | while read -r f; do echo "         -> $f"; done
    else
        pass "No debug code found"
    fi
}

# ===============================================================
#  CHECK 7 - Commit message quality
# ===============================================================
check_commit_messages() {
    print_check 7 "Recent commit messages have >5 words"
    bad_commits=0
    while IFS= read -r msg; do
        word_count=$(echo "$msg" | wc -w)
        if [ "$word_count" -lt 5 ]; then
            echo "         -> \"$msg\" (only $word_count words)"
            bad_commits=$((bad_commits + 1))
        fi
    done < <(git log --no-merges -10 --pretty=format:%s 2>/dev/null || true)

    if [ "$bad_commits" -gt 0 ]; then
        fail "$bad_commits commit(s) with weak messages"
    else
        pass "All recent commits have meaningful messages"
    fi
}

# ===============================================================
#  CHECK 8 - INNOVATIVE: Large file detector (>5MB)
# ===============================================================
check_large_files() {
    print_check 8 "No tracked file exceeds 5MB"
    large_files=""
    while IFS= read -r f; do
        if [ -f "$f" ]; then
            size=$(wc -c < "$f")
            if [ "$size" -gt 5242880 ]; then
                size_mb=$((size / 1024 / 1024))
                large_files="$large_files\n         -> $f (${size_mb}MB)"
            fi
        fi
    done < <(git ls-files)

    if [ -n "$large_files" ]; then
        fail "Large files detected:"
        echo -e "$large_files"
    else
        pass "All files are under 5MB"
    fi
}

# ===============================================================
#  CHECK 9 - INNOVATIVE: Dead-link detector
# ===============================================================
check_dead_links() {
    print_check 9 "All links in markdown files are alive"
    md_files=$(git ls-files | grep -E '\.md$' || true)
    if [ -z "$md_files" ]; then
        pass "No markdown files to check"
        return
    fi

    urls=$(echo "$md_files" | xargs grep -hoE 'https?://[^[:space:]<>)"]+' 2>/dev/null | sed 's/[.,)]*$//' | sort -u || true)

    if [ -z "$urls" ]; then
        pass "No URLs found in markdown files"
        return
    fi

    dead=0
    flaky=0
    total=0
    while IFS= read -r url; do
        [ -z "$url" ] && continue
        total=$((total + 1))
        code=$(curl -sLo /dev/null -A "Mozilla/5.0 (RepoHealthChecker)" --max-time 10 -w "%{http_code}" "$url" 2>/dev/null || echo "000")

        if [ "$code" = "000" ]; then
            echo "         -> [WARN] $url (could not connect)"
            flaky=$((flaky + 1))
        elif [ "$code" -ge 400 ] 2>/dev/null; then
            echo "         -> [DEAD] $url (HTTP $code)"
            dead=$((dead + 1))
        fi
    done <<< "$urls"

    if [ "$dead" -gt 0 ]; then
        fail "$dead dead link(s) out of $total checked"
    elif [ "$flaky" -gt 0 ]; then
        warn "$flaky link(s) unreachable (likely network), $((total - flaky)) OK"
    else
        pass "All $total link(s) are alive"
    fi
}

# ===============================================================
#  HEALTH SCORE - 0-100 score with letter grade
# ===============================================================
print_health_score() {
    if [ "$TOTAL_CHECKS" -eq 0 ]; then
        score=0
    else
        score=$(( (PASSED * 100) / TOTAL_CHECKS ))
    fi

    warn_penalty=$((WARNINGS * 2))
    [ "$warn_penalty" -gt 10 ] && warn_penalty=10
    score=$((score - warn_penalty))
    [ "$score" -lt 0 ] && score=0

    if   [ "$score" -ge 95 ]; then grade="A+"; color=$GREEN
    elif [ "$score" -ge 90 ]; then grade="A";  color=$GREEN
    elif [ "$score" -ge 80 ]; then grade="B";  color=$GREEN
    elif [ "$score" -ge 70 ]; then grade="C";  color=$YELLOW
    elif [ "$score" -ge 60 ]; then grade="D";  color=$YELLOW
    else                            grade="F"; color=$RED
    fi

    echo ""
    echo -e "${BLUE}==============================================================${NC}"
    echo -e "${BLUE}                       HEALTH REPORT                          ${NC}"
    echo -e "${BLUE}==============================================================${NC}"
    echo -e "  Checks passed   : ${GREEN}${PASSED}${NC} / ${TOTAL_CHECKS}"
    echo -e "  Checks failed   : ${RED}${FAILED}${NC}"
    echo -e "  Warnings        : ${YELLOW}${WARNINGS}${NC}"
    echo -e "  ${BOLD}Health Score    : ${color}${score}/100  [${grade}]${NC}"
    echo ""
}

# ===============================================================
#  GITHUB ACTIONS DIAGNOSTIC REPORTER
# ===============================================================
generate_diagnostic_report() {
    if [ -n "$GITHUB_STEP_SUMMARY" ]; then
        echo "# 🏥 Repo Health Diagnostic Report" >> "$GITHUB_STEP_SUMMARY"
        echo "" >> "$GITHUB_STEP_SUMMARY"
        if [ "$FAILED" -eq 0 ]; then
            echo "🎉 **All checks passed!** Your repository is in great shape." >> "$GITHUB_STEP_SUMMARY"
            echo "" >> "$GITHUB_STEP_SUMMARY"
            echo "Health Score: **${score}/100** [${grade}]" >> "$GITHUB_STEP_SUMMARY"
        else
            echo "The health checker found **$FAILED** issue(s) that need your attention before this code can be merged." >> "$GITHUB_STEP_SUMMARY"
            echo "" >> "$GITHUB_STEP_SUMMARY"
            echo "### How to Fix:" >> "$GITHUB_STEP_SUMMARY"
            echo "" >> "$GITHUB_STEP_SUMMARY"
            
            for reason in "${FAIL_REASONS[@]}"; do
                echo "#### ❌ $reason" >> "$GITHUB_STEP_SUMMARY"
                if [[ "$reason" == *"README.md"* ]]; then
                    echo "**Fix:** Add a \`README.md\` file to the root of your repository with at least 10 lines of meaningful documentation about your project." >> "$GITHUB_STEP_SUMMARY"
                elif [[ "$reason" == *".gitignore"* ]]; then
                    echo "**Fix:** Create a \`.gitignore\` file in the root of your repository and add at least one item (like \`node_modules/\` or \`.env\`)." >> "$GITHUB_STEP_SUMMARY"
                elif [[ "$reason" == *"Secret files"* ]]; then
                    echo "**Fix:** You have committed a file that should be kept secret (like \`.env\`). Run \`git rm --cached <file>\` to untrack it, then add the filename to your \`.gitignore\`." >> "$GITHUB_STEP_SUMMARY"
                elif [[ "$reason" == *"Hardcoded secret"* ]]; then
                    echo "**Fix:** You have hardcoded an API key, token, or password. Move this secret to a \`.env\` file and read it via environment variables." >> "$GITHUB_STEP_SUMMARY"
                elif [[ "$reason" == *"Merge conflict"* ]]; then
                    echo "**Fix:** Resolve the merge conflicts in your files by removing the \`<<<<<<<\`, \`=======\`, and \`>>>>>>>\` markers." >> "$GITHUB_STEP_SUMMARY"
                elif [[ "$reason" == *"commit"* ]]; then
                    echo "**Fix:** Write more descriptive commit messages (at least 5 words). You can amend your last commit using \`git commit --amend\`." >> "$GITHUB_STEP_SUMMARY"
                elif [[ "$reason" == *"Large files"* ]]; then
                    echo "**Fix:** You committed a file over 5MB. Use Git LFS for large files, or remove it using \`git rm --cached <file>\`." >> "$GITHUB_STEP_SUMMARY"
                elif [[ "$reason" == *"dead link"* ]]; then
                    echo "**Fix:** Check the URLs in your markdown files and update or remove any broken links." >> "$GITHUB_STEP_SUMMARY"
                else
                    echo "**Fix:** Please review the script logs for more details." >> "$GITHUB_STEP_SUMMARY"
                fi
                echo "" >> "$GITHUB_STEP_SUMMARY"
            done
        fi
        
        echo "---" >> "$GITHUB_STEP_SUMMARY"
        echo "*Need more help? Check the [Pace 2026 Guidelines](https://github.com/loolaneshailesh/repo-health-checker).* 🚀" >> "$GITHUB_STEP_SUMMARY"
    fi
}

# ===============================================================
#  RUN EVERYTHING
# ===============================================================
print_header
check_readme
check_gitignore
check_secret_files
check_secret_patterns
check_merge_conflicts
check_debug_code
check_commit_messages
check_large_files
check_dead_links
print_health_score

# --- EXIT CODE: 0 if all checks passed, 1 otherwise ---
generate_diagnostic_report

if [ "$FAILED" -gt 0 ]; then
    echo -e "${RED}${BOLD}CI GATE: FAILED${NC} - $FAILED check(s) need attention."
    echo ""
    echo "Reasons:"
    if [ "${#FAIL_REASONS[@]}" -gt 0 ]; then
        for reason in "${FAIL_REASONS[@]}"; do
            echo "  - $reason"
        done
    fi
    exit 1
else
    echo -e "${GREEN}${BOLD}CI GATE: PASSED${NC} - repo is healthy. Push approved."
    exit 0
fi
