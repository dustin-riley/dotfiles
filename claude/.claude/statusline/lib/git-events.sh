#!/bin/bash
# shellcheck source-path=SCRIPTDIR
# Git event flash notifications — detects git state changes and renders flash indicators
# Sources: lib/core.sh (for hyperlink)
# Requires: lib/git.sh variables (BRANCH, STAGED_COUNT, PENDING_COUNT, UNTRACKED_COUNT,
#           TOTAL_DIRTY, AHEAD, BEHIND, REPO_ID, SAFE_BRANCH) and FULL_DIR set by caller
#
# Three functions, called in order:
#   gitevents_detect_git   — phase 1: git events (pulled/pushed/committed/branch-changed/dirty)
#   gitevents_detect_pr    — phase 2: PR 0→1 transition (call after github.sh sets PR_URL)
#   gitevents_build_flash  — phase 3: render FLASH_PART from FLASH_TEXT/FLASH_COLOR
# shellcheck disable=SC2034,SC1091  # SC2034: vars exported to sourcing scripts, SC1091: source paths resolved at runtime

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=core.sh
source "$LIB_DIR/core.sh"

# Initialized at source time — shared across all three phases
FLASH_PART=""
FLASH_TEXT=""
FLASH_COLOR=""
CACHE_FILE=""
COLD_START=false
FLASH_CACHE_NEW=false

# Phase 1: Detect git events (pulled, pushed, committed, branch changed, dirty detail)
# Tracks dirty counts, HEAD SHA, ahead/behind, and PR state to detect git events
# Cache format: {timestamp}:{staged}:{pending}:{untracked}:{head_sha}:{ahead}:{behind}:{has_pr}
#   has_pr: -1 = unknown (new cache), 0 = confirmed no PR, 1 = PR exists
#   Flash only fires on 0→1 transition (not -1→1, which means we never confirmed absence)
# Priority: PR opened > pulled > pushed > committed > branch changed > dirty detail
gitevents_detect_git() {
    [ -z "$BRANCH" ] && return

    HEAD_SHA=$(git -C "$FULL_DIR" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
    CACHE_KEY="git-flash-${REPO_ID}-${SAFE_BRANCH}"
    CACHE_FILE="/tmp/.statusline-cache/${CACHE_KEY}"
    NOW=$(date +%s)
    CUR_AHEAD="${AHEAD:-0}"
    CUR_BEHIND="${BEHIND:-0}"

    mkdir -p /tmp/.statusline-cache
    COLD_START=false
    [ ! -f /tmp/.statusline-cache/.initialized ] && COLD_START=true

    # has_pr is set later after PR section — initialized as -1 (unknown) on cache creation
    CURRENT_GIT_SNAP="${STAGED_COUNT}:${PENDING_COUNT}:${UNTRACKED_COUNT}:${HEAD_SHA}:${CUR_AHEAD}:${CUR_BEHIND}"
    FLASH_CACHE_NEW=false

    if $COLD_START; then
        # Cold start (cache cleared / codespace restart) — write silently, no flash
        # has_pr=-1 (unknown) prevents false "PR opened" flash on first observation
        echo "${NOW}:${CURRENT_GIT_SNAP}:-1" > "$CACHE_FILE"
        touch /tmp/.statusline-cache/.initialized
        FLASH_CACHE_NEW=true
    elif [[ -f "$CACHE_FILE" ]]; then
        CACHED_LINE=$(cat "$CACHE_FILE")
        CACHED_TS=$(echo "$CACHED_LINE" | cut -d: -f1)
        CACHED_STAGED=$(echo "$CACHED_LINE" | cut -d: -f2)
        CACHED_PENDING=$(echo "$CACHED_LINE" | cut -d: -f3)
        CACHED_UNTRACKED=$(echo "$CACHED_LINE" | cut -d: -f4)
        CACHED_HEAD=$(echo "$CACHED_LINE" | cut -d: -f5)
        CACHED_AHEAD=$(echo "$CACHED_LINE" | cut -d: -f6)
        CACHED_BEHIND=$(echo "$CACHED_LINE" | cut -d: -f7)
        CACHED_HAS_PR=$(echo "$CACHED_LINE" | cut -d: -f8)
        CACHED_DIRTY=$((CACHED_STAGED + CACHED_PENDING + CACHED_UNTRACKED))
        [ -z "$CACHED_HAS_PR" ] && CACHED_HAS_PR=0

        CACHED_GIT_SNAP="${CACHED_STAGED}:${CACHED_PENDING}:${CACHED_UNTRACKED}:${CACHED_HEAD}:${CACHED_AHEAD}:${CACHED_BEHIND}"

        if [ "$CURRENT_GIT_SNAP" != "$CACHED_GIT_SNAP" ]; then
            # Something changed — determine event by priority
            HEAD_CHANGED=false
            [ "$HEAD_SHA" != "$CACHED_HEAD" ] && HEAD_CHANGED=true

            # Priority 2: pulled (behind decreased + HEAD changed)
            if $HEAD_CHANGED && (( CUR_BEHIND < CACHED_BEHIND )); then
                FLASH_TEXT="📥 pulled"
                FLASH_COLOR="\033[36m"
            # Priority 3: pushed (ahead decreased)
            elif (( CUR_AHEAD < CACHED_AHEAD )); then
                FLASH_TEXT="📤 pushed"
                FLASH_COLOR="\033[32m"
            # Priority 4: committed (HEAD changed + ahead increased or dirty decreased)
            elif $HEAD_CHANGED && (( CUR_AHEAD > CACHED_AHEAD )); then
                FLASH_TEXT="✅ committed"
                FLASH_COLOR="\033[32m"
            elif $HEAD_CHANGED && (( TOTAL_DIRTY < CACHED_DIRTY )); then
                FLASH_TEXT="✅ committed"
                FLASH_COLOR="\033[32m"
            fi

            # Priority 6: dirty detail (only if no higher-priority event)
            if [ -z "$FLASH_TEXT" ] && [ "${STAGED_COUNT}:${PENDING_COUNT}:${UNTRACKED_COUNT}" != "${CACHED_STAGED}:${CACHED_PENDING}:${CACHED_UNTRACKED}" ]; then
                DETAIL_PARTS=()
                (( STAGED_COUNT > 0 )) && DETAIL_PARTS+=("${STAGED_COUNT} staged")
                (( PENDING_COUNT > 0 )) && DETAIL_PARTS+=("${PENDING_COUNT} pending")
                (( UNTRACKED_COUNT > 0 )) && DETAIL_PARTS+=("${UNTRACKED_COUNT} new files")
                if [ ${#DETAIL_PARTS[@]} -gt 0 ]; then
                    FLASH_TEXT=""
                    for part in "${DETAIL_PARTS[@]}"; do
                        [ -n "$FLASH_TEXT" ] && FLASH_TEXT+=", "
                        FLASH_TEXT+="$part"
                    done
                fi
            fi

            # State changed — update cache (has_pr preserved from cached value, updated after PR section)
            echo "${NOW}:${CURRENT_GIT_SNAP}:${CACHED_HAS_PR}" > "$CACHE_FILE"
        elif (( NOW - CACHED_TS < 15 )); then
            # Still in flash window — restore from hint file
            HINT_FILE="${CACHE_FILE}.hint"
            if [ -f "$HINT_FILE" ]; then
                FLASH_TEXT=$(head -1 "$HINT_FILE")
                FLASH_COLOR=$(sed -n '2p' "$HINT_FILE")
            fi
        fi
    else
        # Priority 5: branch changed (new cache file, not cold start)
        FLASH_TEXT="🔀 branch changed"
        FLASH_COLOR="\033[36m"
        # has_pr=-1 (unknown) prevents false "PR opened" flash on branch switch
        echo "${NOW}:${CURRENT_GIT_SNAP}:-1" > "$CACHE_FILE"
        FLASH_CACHE_NEW=true
    fi
}

# Phase 2: Detect PR opened (0→1 transition)
# Must be called after github.sh sets PR_URL
# Always updates has_pr in cache; only flashes on 0→1 transition when cache isn't new
gitevents_detect_pr() {
    [ -z "$BRANCH" ] && return
    [ -z "$CACHE_FILE" ] && return
    $COLD_START && return

    CUR_HAS_PR=0
    [ -n "$PR_URL" ] && CUR_HAS_PR=1

    # Check for 0→1 transition (only when cache wasn't just created this render)
    if ! $FLASH_CACHE_NEW && [[ -f "$CACHE_FILE" ]]; then
        CACHED_HAS_PR_VAL=$(cut -d: -f8 "$CACHE_FILE")
        [ -z "$CACHED_HAS_PR_VAL" ] && CACHED_HAS_PR_VAL=0
        if (( CACHED_HAS_PR_VAL == 0 && CUR_HAS_PR == 1 )); then
            # PR just opened — highest priority, overrides other events
            if [ -n "$PR_URL" ]; then
                FLASH_TEXT="🔗 $(hyperlink "$PR_URL" "PR opened")"
            else
                FLASH_TEXT="🔗 PR opened"
            fi
            FLASH_COLOR="\033[35m"
        fi
    fi

    # Always update cache with current has_pr value
    if [[ -f "$CACHE_FILE" ]]; then
        CACHED_CONTENT=$(cat "$CACHE_FILE")
        UPDATED="${CACHED_CONTENT%:*}:${CUR_HAS_PR}"
        echo "$UPDATED" > "$CACHE_FILE"
    fi
}

# Phase 3: Build flash display part
# Wraps FLASH_TEXT with 🆕 prefix and brackets for visual distinction
gitevents_build_flash() {
    [ -z "$FLASH_TEXT" ] && return

    HINT_FILE="${CACHE_FILE}.hint"
    printf '%s\n%s' "$FLASH_TEXT" "$FLASH_COLOR" > "$HINT_FILE"
    if [ -n "$FLASH_COLOR" ]; then
        FLASH_PART="${FLASH_COLOR}🆕 [ ${FLASH_TEXT} ]\033[0m"
    else
        FLASH_PART="🆕 [ ${FLASH_TEXT} ]"
    fi
}
