#!/bin/bash
# shellcheck source-path=SCRIPTDIR
# shellcheck disable=SC1091  # source paths resolved at runtime
# Claude Code statusline — two/three-line layout with progressive compacting
# Session (optional): Session name (shown when set)
# Line 1: Model, environment, directory, cost, context usage
# Line 2: Git branch, dirty, lines changed, file detail (flash), ahead/behind, PR, worktree

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Debug dump (conditional) ---
input=$(cat)
if [ "${CLAUDE_STATUSLINE_DEBUG:-0}" = "1" ]; then
    echo "$input" | jq '.' > /tmp/claude-statusline-input.json
fi

# Source shared libraries
# shellcheck source=lib/core.sh
source "$SCRIPT_DIR/lib/core.sh"
# shellcheck source=lib/session.sh
source "$SCRIPT_DIR/lib/session.sh"

# MARK: - Presentation Parts (from session data)

# Environment (codespace or ONA)
ENV_PART=""
if [ -n "$FRIENDLY_NAME" ]; then
    if [ -n "$ENV_URL" ]; then
        ENV_PART="💻 \033[35m$(hyperlink "$ENV_URL" "$FRIENDLY_NAME")\033[0m"
    else
        ENV_PART="💻 \033[35m${FRIENDLY_NAME}\033[0m"
    fi
fi

# Session name
SESSION_PART=""
if [ -n "$SESSION_NAME" ]; then
    SESSION_PART="🏷️  \033[38;5;180m${SESSION_NAME}\033[0m"
fi

# Cost
COST_PART=""
if [ "$COST" != "0" ] && [ "$COST" != "null" ]; then
    COST_PART="💰 \033[33m\$$(printf '%.2f' "$COST")\033[0m"
fi

# Context usage — tiered display (full → medium → short) for progressive compacting
CONTEXT_FULL=""
CONTEXT_MED=""
CONTEXT_SHORT=""
CTX_WARN_FULL=""
if (( USED_PCT_INT > 0 )); then
    CTX_WARN_FULL=""
    CTX_WARN_SHORT=""
    if (( USED_PCT_INT >= COMPACT_PCT )); then
        CTX_WARN_FULL=" ⚠ autocompact imminent"
        CTX_WARN_SHORT=" ⚠"
    elif (( USED_PCT_INT >= WARN_PCT )); then
        CTX_WARN_FULL=" ⚠ nearing autocompact"
        CTX_WARN_SHORT=" ⚠"
    fi

    CTX_BASE="${CTX_COLOR}📊 ${USED_K}K/${LIMIT_DISPLAY} (${USED_PCT_INT}%)"
    CTX_BASE_MIN="${CTX_COLOR}📊 ${USED_PCT_INT}%"
    CONTEXT_FULL="${CTX_BASE}${CTX_WARN_FULL}\033[0m"
    CONTEXT_MED="${CTX_BASE}${CTX_WARN_SHORT}\033[0m"
    CONTEXT_SHORT="${CTX_BASE_MIN}${CTX_WARN_SHORT}\033[0m"
fi

# MARK: - Git Info

# shellcheck source=lib/git.sh
source "$SCRIPT_DIR/lib/git.sh"

# MARK: - Git Diff Display (data from lib/git.sh)

DIFF_PART=""
if (( DIFF_ADD > 0 || DIFF_DEL > 0 )); then
    DIFF_PART="\033[32m+${DIFF_ADD}\033[0m/\033[31m-${DIFF_DEL}\033[0m"
fi

# MARK: - Git Event Flash (phase 1: git events)

# shellcheck source=lib/git-events.sh
source "$SCRIPT_DIR/lib/git-events.sh"
gitevents_detect_git

# MARK: - Ahead/Behind Display

AB_PART=""
if [ -n "$BRANCH" ]; then
    A_DISPLAY=""
    B_DISPLAY=""
    [ -n "$AHEAD" ] && (( AHEAD > 0 )) && A_DISPLAY="↑${AHEAD}"
    [ -n "$BEHIND" ] && (( BEHIND > 0 )) && B_DISPLAY="↓${BEHIND}"
    if [ -n "$A_DISPLAY" ] || [ -n "$B_DISPLAY" ]; then
        AB_PART="\033[36m${A_DISPLAY}${B_DISPLAY}\033[0m"
    fi
fi

# MARK: - Local Branch Indicator

LOCAL_PART=""
if [ -n "$BRANCH" ] && [ "$HAS_UPSTREAM" = false ] && [ "$BRANCH" != "main" ] && [ "$BRANCH" != "master" ]; then
    LOCAL_PART="\033[2m[local]\033[0m"
fi

# MARK: - PR Action Items

# shellcheck source=lib/github.sh
source "$SCRIPT_DIR/lib/github.sh"

# MARK: - Git Event Flash (phase 2: PR opened + phase 3: render)

gitevents_detect_pr
gitevents_build_flash

# MARK: - Worktree Info

WORKTREE_PART=""
if [ -n "$WORKTREE_NAME" ]; then
    WORKTREE_PART="🌲 \033[35m${WORKTREE_NAME}\033[0m"
fi

# MARK: - Assemble Output

TERM_WIDTH=$(get_terminal_width)
RESERVED_RIGHT=40  # Space for system notifications on Line 1

# --- Line 1: Identity + session metrics ---
MODEL_PART="\033[36m[${MODEL}]\033[0m"
DIR_PART="📁 \033[94m${DIR}\033[0m"

LINE1=$(fit_to_width "$TERM_WIDTH" "$RESERVED_RIGHT" \
    "$(echo -e "$MODEL_PART")" \
    "$(echo -e "$ENV_PART")" \
    "$(echo -e "$DIR_PART")" \
    "$(echo -e "$COST_PART")" \
    "$(echo -e "$CONTEXT_FULL")")

# If full context warning didn't fit, try medium then short
if [ -n "$CTX_WARN_FULL" ]; then
    LINE1_NO_CTX=$(fit_to_width "$TERM_WIDTH" "$RESERVED_RIGHT" \
        "$(echo -e "$MODEL_PART")" \
        "$(echo -e "$ENV_PART")" \
        "$(echo -e "$DIR_PART")" \
        "$(echo -e "$COST_PART")")
    if [ "$LINE1" = "$LINE1_NO_CTX" ]; then
        # Full context was dropped — try medium (token counts + ⚠)
        LINE1=$(fit_to_width "$TERM_WIDTH" "$RESERVED_RIGHT" \
            "$(echo -e "$MODEL_PART")" \
            "$(echo -e "$ENV_PART")" \
            "$(echo -e "$DIR_PART")" \
            "$(echo -e "$COST_PART")" \
            "$(echo -e "$CONTEXT_MED")")
        if [ "$LINE1" = "$LINE1_NO_CTX" ]; then
            # Medium also dropped — try short (just percent + ⚠)
            LINE1=$(fit_to_width "$TERM_WIDTH" "$RESERVED_RIGHT" \
                "$(echo -e "$MODEL_PART")" \
                "$(echo -e "$ENV_PART")" \
                "$(echo -e "$DIR_PART")" \
                "$(echo -e "$COST_PART")" \
                "$(echo -e "$CONTEXT_SHORT")")
        fi
    fi
fi

# --- Line 2: Git info ---
LINE2=""
if [ -n "$BRANCH" ]; then
    # Truncate branch name to 25 chars
    DISPLAY_BRANCH=$(truncate_string "$BRANCH" 25)
    BRANCH_PART="🌿 \033[33m${DISPLAY_BRANCH}\033[0m\033[31m${DIRTY}\033[0m"

    # Dim pipe separator for line 2 parts
    DIM_SEP=$(echo -e "\033[2m│\033[0m")

    # Try full PR action first; if it gets dropped, retry with short version
    # Flash is last — rightmost position for visual distinction
    LINE2=$(fit_to_width "$TERM_WIDTH" 0 --sep " $DIM_SEP " \
        "$(echo -e "$BRANCH_PART")" \
        "$(echo -e "$DIFF_PART")" \
        "$(echo -e "$PR_ACTION_FULL")" \
        "$(echo -e "$AB_PART")" \
        "$(echo -e "$LOCAL_PART")" \
        "$(echo -e "$WORKTREE_PART")" \
        "$(echo -e "$FLASH_PART")")

    if [ -n "$PR_ACTION_FULL" ] && [ -n "$PR_ACTION_SHORT" ]; then
        LINE2_NO_PR=$(fit_to_width "$TERM_WIDTH" 0 --sep " $DIM_SEP " \
            "$(echo -e "$BRANCH_PART")" \
            "$(echo -e "$DIFF_PART")" \
            "$(echo -e "$AB_PART")" \
            "$(echo -e "$LOCAL_PART")" \
            "$(echo -e "$WORKTREE_PART")" \
            "$(echo -e "$FLASH_PART")")
        if [ "$LINE2" = "$LINE2_NO_PR" ]; then
            # Full version was dropped — retry with short in high-priority position
            LINE2=$(fit_to_width "$TERM_WIDTH" 0 --sep " $DIM_SEP " \
                "$(echo -e "$BRANCH_PART")" \
                "$(echo -e "$PR_ACTION_SHORT")" \
                "$(echo -e "$DIFF_PART")" \
                "$(echo -e "$AB_PART")" \
                "$(echo -e "$LOCAL_PART")" \
                "$(echo -e "$WORKTREE_PART")" \
                "$(echo -e "$FLASH_PART")")
        fi
    fi
fi

# --- Output (printf, not echo -e — parts already have real ESC bytes from echo -e in fit_to_width args) ---
# Order: Session name (optional) → Line 1 (identity + metrics) → Line 2 (git info)
if [ -n "$SESSION_NAME" ]; then
    SESSION_LINE=$(fit_to_width "$TERM_WIDTH" 0 "$(echo -e "$SESSION_PART")")
    printf '%s\n' "$SESSION_LINE"
fi
printf '%s\n' "$LINE1"
[ -n "$LINE2" ] && printf '%s\n' "$LINE2"
exit 0
