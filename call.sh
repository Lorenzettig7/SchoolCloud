#!/usr/bin/env bash
set -euo pipefail

API_BASE="https://bm25ryr7md.execute-api.us-east-1.amazonaws.com/prod"
TOKENS_PATH="${TMPDIR:-/tmp}/sc_tokens.json"
AUTH_DOMAIN="https://schoolcloud-dev.auth.us-east-1.amazoncognito.com"
CLIENT_ID="4cddgb64bfu2au7ce5t9fqgtjp"

refresh_tokens() {
  local rt new
  rt="$(jq -r '.refresh_token' "$TOKENS_PATH")"
  [[ -n "$rt" && "$rt" != "null" ]] || { echo "No refresh_token found"; return 1; }
  new="$(
    curl -s -X POST "$AUTH_DOMAIN/oauth2/token" \
      -H 'Content-Type: application/x-www-form-urlencoded' \
      -d "grant_type=refresh_token" \
      -d "client_id=$CLIENT_ID" \
      -d "refresh_token=$rt"
  )"
  jq -n --arg id "$(jq -r '.id_token' <<<"$new")" \
        --arg at "$(jq -r '.access_token' <<<"$new")" \
        --arg rt "$rt" \
        '{id_token:$id, access_token:$at, refresh_token:$rt}' > "$TOKENS_PATH"
}

ensure_fresh() {
  local ttl; ttl="$(expires_in || echo -999)"
  (( ttl < 60 )) && refresh_tokens || true
}

decode() { jq -R 'split(".")[1]|gsub("-";"+")|gsub("_";"/")|. + (["","===","==","="][(length%4)])|@base64d|fromjson'; }

get_token() { jq -r ".$1" "$TOKENS_PATH"; }

expires_in() {
  local t exp now
  t="$(get_token id_token)"
  exp="$(printf '%s' "$t" | decode | jq -r .exp)"
  now="$(date +%s)"
  echo $((exp - now))
}

api() {
  local method="GET" path="" data="" use_access=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -X|--method) method="$2"; shift 2;;
      -p|--path)   path="$2"; shift 2;;
      -d|--data)   data="$2"; shift 2;;
      --access)    use_access=1; shift;;
      *) shift;;
    esac
  done

ensure_fresh

  local token key
  key=$([[ $use_access -eq 1 ]] && echo access_token || echo id_token)
  token="$(get_token "$key")"

  curl -sS -D- -X "$method" "$API_BASE$path" \
    -H "Authorization: Bearer $token" \
    ${data:+-H 'Content-Type: application/json' -d "$data"}
}

# default behavior if called directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  api "$@"
fi
