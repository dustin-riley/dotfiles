#!/bin/bash
# Core statusline utilities — pure functions, no side effects
# Used by both simple.sh and full.sh

# Strip ANSI escape codes and return visible character count
visible_width() {
    local str="$1"
    local stripped
    stripped=$(printf '%s' "$str" | sed 's/\x1b\[[0-9;]*m//g; s/\x1b\]8;;[^\x1b]*\x1b\\//g')
    printf '%s' "$stripped" | wc -m
}

# Terminal width — $COLUMNS if set, else 200 (tput unreliable in subprocess)
get_terminal_width() {
    echo "${COLUMNS:-200}"
}

# Assemble parts left-to-right, dropping parts that would overflow
# Args: max_width reserved_right part1 part2 ...
# Parts are joined with spaces
fit_to_width() {
    local max_width=$1 reserved=$2
    shift 2
    local separator=" "
    local sep_width=1
    if [ "${1:-}" = "--sep" ]; then
        separator="$2"
        sep_width=$(visible_width "$separator")
        shift 2
    fi
    local available=$((max_width - reserved))
    local result=""
    local current_width=0

    for part in "$@"; do
        [ -z "$part" ] && continue
        local part_width
        part_width=$(visible_width "$part")
        local needed=$part_width
        [ -n "$result" ] && needed=$((needed + sep_width))
        if (( current_width + needed <= available )); then
            if [ -n "$result" ]; then
                result="$result${separator}$part"
            else
                result="$part"
            fi
            current_width=$((current_width + needed))
        fi
    done
    printf '%s' "$result"
}

# Truncate string to N visible chars with "..." suffix
truncate_string() {
    local str="$1" max_len="$2"
    if (( ${#str} <= max_len )); then
        printf '%s' "$str"
    else
        printf '%s' "${str:0:$((max_len - 3))}..."
    fi
}

# Terminal hyperlink (OSC 8) — returns echo-e-compatible text, not literal bytes
hyperlink() {
    local url="$1" text="$2"
    # shellcheck disable=SC1003
    printf '%s%s%s%s%s' '\033]8;;' "$url" '\033\\' "$text" '\033]8;;\033\\'
}

# File-based caching with TTL
# Usage: get_cached <key> <ttl_seconds> <command> [args...]
get_cached() {
    local key=$1 ttl=$2; shift 2
    local cache_file="/tmp/.statusline-cache/$key"
    if [[ -f "$cache_file" ]]; then
        local mtime
        mtime=$(stat -c %Y "$cache_file" 2>/dev/null)
        local now
        now=$(date +%s)
        local age=$(( now - mtime ))
        if (( age < ttl )); then
            cat "$cache_file"
            return 0
        fi
    fi
    local result
    result=$("$@" 2>/dev/null)
    # Only cache non-empty successful results
    if [ -n "$result" ]; then
        mkdir -p /tmp/.statusline-cache
        echo "$result" > "$cache_file"
    fi
    echo "$result"
}
