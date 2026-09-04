#!/bin/zsh
set -u
set -o pipefail

usage() {
  echo "usage: jira_rest.sh GET <rest-path> | PUT <rest-path> <json-file>" >&2
  exit 2
}

[[ $# -ge 2 ]] || usage

method="$1"
rest_path="$2"
payload_file="${3:-}"

case "$method" in
  GET)
    [[ $# -eq 2 ]] || usage
    ;;
  PUT)
    [[ $# -eq 3 && -f "$payload_file" ]] || usage
    ;;
  *)
    usage
    ;;
esac

[[ "$rest_path" == /* ]] || {
  echo "error: REST path must begin with /" >&2
  exit 2
}

config_dir="${ACLI_CONFIG_DIR:-${HOME}/.config/acli}"
config_file="${config_dir}/jira_config.yaml"
[[ -r "$config_file" ]] || {
  echo "error: cannot read ACLI Jira config at $config_file" >&2
  exit 1
}

profile_id="$(awk '/^current_profile:/ {print $2; exit}' "$config_file")"
site="$(awk '/^[[:space:]]*-?[[:space:]]*site:/ {sub(/^[^:]*:[[:space:]]*/, ""); print; exit}' "$config_file")"
email="$(awk '/^[[:space:]]*email:/ {sub(/^[^:]*:[[:space:]]*/, ""); print; exit}' "$config_file")"

[[ -n "$profile_id" && -n "$site" && -n "$email" ]] || {
  echo "error: ACLI Jira profile is incomplete" >&2
  exit 1
}

run_request() {
  local jira_token="$1"
  local -a curl_args

  [[ -n "$jira_token" ]] || {
    echo "error: Jira API-token credential is empty" >&2
    exit 1
  }

  curl_args=(
    --silent
    --show-error
    --fail-with-body
    --config -
    --request "$method"
    --header 'Accept: application/json'
  )

  if [[ "$method" == "PUT" ]]; then
    curl_args+=(
      --header 'Content-Type: application/json'
      --data-binary "@${payload_file}"
      --write-out 'HTTP %{http_code}\n'
    )
  fi

  print -r -- "user = \"${email}:${jira_token}\"" \
    | curl "${curl_args[@]}" "https://${site}${rest_path}"
}

if [[ -n "${JIRA_API_TOKEN:-}" ]]; then
  run_request "$JIRA_API_TOKEN"
elif command -v security >/dev/null 2>&1; then
  keychain_account="jira:${profile_id}"
  security find-generic-password -s acli -a "$keychain_account" -w \
    | sed 's/^go-keyring-base64://' \
    | base64 -D \
    | {
        jira_token=""
        IFS= read -r jira_token || [[ -n "$jira_token" ]]
        run_request "$jira_token"
      }
else
  echo "error: set JIRA_API_TOKEN; macOS Keychain fallback is unavailable" >&2
  exit 1
fi
