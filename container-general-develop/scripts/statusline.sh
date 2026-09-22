#!/usr/bin/env bash
input=$(cat)

DIR=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
MODEL=$(echo "$input" | jq -r '.model.display_name // "?"')
EFFORT=$(echo "$input" | jq -r '.effort.level // empty')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
FIVE_H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
WEEK=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; MAGENTA='\033[35m'; RESET='\033[0m'

if [ "$PCT" -ge 90 ]; then CTX_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then CTX_COLOR="$YELLOW"
else CTX_COLOR="$GREEN"; fi

DIRNAME="${DIR##*/}"
MAX_DIR_LEN=20
if [ "${#DIRNAME}" -gt "$MAX_DIR_LEN" ]; then
    DIRNAME="…${DIRNAME: -$((MAX_DIR_LEN - 1))}"
fi

REPO=""
BRANCH=""
if git rev-parse --show-toplevel > /dev/null 2>&1; then
    # --git-common-dir points at the main repo's shared .git dir even from
    # inside a worktree, whose folder is usually named after the branch —
    # using --show-toplevel there would make REPO and BRANCH the same string.
    COMMON_DIR=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || git rev-parse --git-common-dir 2>/dev/null)
    REPO=$(basename "$(dirname "$COMMON_DIR")")
    BRANCH=$(git branch --show-current 2>/dev/null)
fi

LIMITS=""
[ -n "$FIVE_H" ] && LIMITS="5h:$(printf '%.0f' "$FIVE_H")%"
[ -n "$WEEK" ] && LIMITS="${LIMITS:+$LIMITS }7d:$(printf '%.0f' "$WEEK")%"
[ -z "$LIMITS" ] && LIMITS="limit:N/A"

EFFORT_DISP="${EFFORT:-N/A}"

if [ -n "$REPO" ]; then
    LINE1="🌿 ${REPO}:${BRANCH}"
else
    LINE1="📁 ${DIRNAME}"
fi

LINE2="${CYAN}[$MODEL]${RESET} effort:${EFFORT_DISP} | ${CTX_COLOR}${PCT}% ctx${RESET} | ${MAGENTA}${LIMITS}${RESET}"

echo -e "$LINE1"
echo -e "$LINE2"
