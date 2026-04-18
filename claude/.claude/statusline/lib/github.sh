#!/bin/bash
# GitHub/PR integration — PR status fetching and action item rendering
# Requires: lib/core.sh sourced, git variables (HAS_UPSTREAM, BRANCH, REPO_ID, SAFE_BRANCH) available

PR_ACTION_FULL=""
PR_ACTION_SHORT=""
PR_URL=""
if [ "$HAS_UPSTREAM" = true ] && [ "$BRANCH" != "main" ] && [ "$BRANCH" != "master" ]; then
    _fetch_pr_status() {
        gh pr view --json url,reviewDecision,statusCheckRollup,reviews 2>/dev/null | jq -r '
            def clean_name: split(" / ")[0];
            def skip_rollups: select(.norm_name != "pr-checks-passed");
            # Normalize CheckRun (.status/.conclusion/.name) and StatusContext (.state/.context)
            def normalize: if .status then
                {norm_status: .status, norm_conclusion: .conclusion, norm_name: (.name // .context), norm_url: (.detailsUrl // .targetUrl // "")}
            else
                {norm_status: (if .state == "PENDING" then "IN_PROGRESS" else "COMPLETED" end),
                 norm_conclusion: (if .state == "SUCCESS" then "SUCCESS" elif .state == "FAILURE" then "FAILURE" else null end),
                 norm_name: (.context // .name), norm_url: (.targetUrl // "")}
            end;
            [.statusCheckRollup[] | normalize | skip_rollups] as $checks |
            ([$checks[] | select(.norm_conclusion == "FAILURE" or .norm_conclusion == "TIMED_OUT")
              | {name: (.norm_name | clean_name), url: .norm_url}] | unique_by(.name)) as $failed |
            {
                ci_failed: ($failed | length),
                ci_pending: ([$checks[] | select(.norm_status != "COMPLETED")] | length),
                ci_success: ([$checks[] | select(.norm_conclusion == "SUCCESS" or .norm_conclusion == "SKIPPED")] | length),
                failed_names: ($failed | map(.name) | join(",")),
                failed_urls: ($failed | map(.url) | join(",")),
                review_decision: (.reviewDecision // ""),
                changes_requested_count: ([.reviews[] | select(.state == "CHANGES_REQUESTED")] | unique_by(.author.login) | length),
                pr_url: .url
            } | "\(.ci_failed)|\(.ci_pending)|\(.ci_success)|\(.failed_names)|\(.review_decision)|\(.changes_requested_count)|\(.pr_url)|\(.failed_urls)"'
    }
    PR_DATA=$(get_cached "pr-status-${REPO_ID}-${SAFE_BRANCH}" 180 _fetch_pr_status)

    if [ -n "$PR_DATA" ]; then
        CI_FAILED=$(echo "$PR_DATA" | cut -d'|' -f1)
        CI_PENDING=$(echo "$PR_DATA" | cut -d'|' -f2)
        CI_SUCCESS=$(echo "$PR_DATA" | cut -d'|' -f3)
        FAILED_NAMES=$(echo "$PR_DATA" | cut -d'|' -f4)
        REVIEW_DECISION=$(echo "$PR_DATA" | cut -d'|' -f5)
        CHANGES_COUNT=$(echo "$PR_DATA" | cut -d'|' -f6)
        PR_URL=$(echo "$PR_DATA" | cut -d'|' -f7)
        FAILED_URLS=$(echo "$PR_DATA" | cut -d'|' -f8)

        # Full version (wide): icon + linked check names
        # Short version (narrow): icon + count
        PR_ACTION_FULL=""
        PR_ACTION_SHORT=""

        # CI status: error > pending > all good
        [ -z "$CI_FAILED" ] && CI_FAILED=0
        [ -z "$CI_PENDING" ] && CI_PENDING=0
        [ -z "$CI_SUCCESS" ] && CI_SUCCESS=0

        if (( CI_FAILED > 0 )); then
            # Error state — link to checks page, show failing names when wide
            if [ -n "$PR_URL" ]; then
                CHECKS_LINK="$(hyperlink "${PR_URL}/checks" "✗")"
            else
                CHECKS_LINK="✗"
            fi
            PR_ACTION_SHORT="\033[31m${CHECKS_LINK} failing\033[0m"

            if [ -n "$FAILED_NAMES" ]; then
                IFS=',' read -ra NAME_ARR <<< "$FAILED_NAMES"
                IFS=',' read -ra URL_ARR <<< "$FAILED_URLS"
                LINKED_NAMES=()
                for i in "${!NAME_ARR[@]}"; do
                    if [ -n "${URL_ARR[$i]:-}" ]; then
                        LINKED_NAMES+=("$(hyperlink "${URL_ARR[$i]}" "${NAME_ARR[$i]}")")
                    else
                        LINKED_NAMES+=("${NAME_ARR[$i]}")
                    fi
                done
                DISPLAY_NAMES=""
                for i in "${!LINKED_NAMES[@]}"; do
                    [ -n "$DISPLAY_NAMES" ] && DISPLAY_NAMES+=", "
                    DISPLAY_NAMES+="${LINKED_NAMES[$i]}"
                done
                PR_ACTION_FULL="\033[31m✗ ${DISPLAY_NAMES} failing\033[0m"
            else
                PR_ACTION_FULL="$PR_ACTION_SHORT"
            fi
        elif (( CI_PENDING > 0 )); then
            # Pending state
            if [ -n "$PR_URL" ]; then
                PR_ACTION_FULL="\033[33m$(hyperlink "${PR_URL}/checks" "⏳ checks running")\033[0m"
                PR_ACTION_SHORT="\033[33m$(hyperlink "${PR_URL}/checks" "⏳")\033[0m"
            else
                PR_ACTION_FULL="\033[33m⏳ checks running\033[0m"
                PR_ACTION_SHORT="\033[33m⏳\033[0m"
            fi
        elif (( CI_SUCCESS > 0 )); then
            # All good
            if [ -n "$PR_URL" ]; then
                PR_ACTION_FULL="\033[32m$(hyperlink "${PR_URL}/checks" "✓ checks passed")\033[0m"
                PR_ACTION_SHORT="\033[32m$(hyperlink "${PR_URL}/checks" "✓")\033[0m"
            else
                PR_ACTION_FULL="\033[32m✓ checks passed\033[0m"
                PR_ACTION_SHORT="\033[32m✓\033[0m"
            fi
        fi

        # Review actions — "requested changes" linked to PR
        if [ "$REVIEW_DECISION" = "CHANGES_REQUESTED" ] && [ -n "$CHANGES_COUNT" ] && (( CHANGES_COUNT > 0 )); then
            if [ -n "$PR_URL" ]; then
                REVIEW_LINK="$(hyperlink "$PR_URL" "requested changes")"
                REVIEW_LINK_SHORT="$(hyperlink "$PR_URL" "⟲")"
            else
                REVIEW_LINK="requested changes"
                REVIEW_LINK_SHORT="⟲"
            fi
            REVIEW_FULL="\033[33m${REVIEW_LINK}\033[0m"
            REVIEW_SHORT="\033[33m${REVIEW_LINK_SHORT}\033[0m"
            if [ -n "$PR_ACTION_FULL" ]; then
                PR_ACTION_FULL="${PR_ACTION_FULL} ${REVIEW_FULL}"
                PR_ACTION_SHORT="${PR_ACTION_SHORT} ${REVIEW_SHORT}"
            else
                PR_ACTION_FULL="$REVIEW_FULL"
                PR_ACTION_SHORT="$REVIEW_SHORT"
            fi
        fi
    fi
fi
