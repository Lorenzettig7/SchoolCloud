#!/usr/bin/env bash
set -euo pipefail

USER_POOL_ID="us-east-1_7soL15d0V"
CLIENT_ID="4cddgb64bfu2au7ce5t9fqgtjp"
USERNAME="giovannalorenzetti"
API_BASE="https://bm25ryr7md.execute-api.us-east-1.amazonaws.com/prod"
TOKEN_FILE="${TMPDIR:-/tmp}/sc_tokens.json"

now() { date +%s; }

# seconds until ID token expiry
expires_in() {
  local id
  id="$(jq -r '.id_token' < "$TOKEN_FILE" 2>/dev/null || true)"
  [[ -z "${id:-}" || "$id" == "null" ]] && { echo -999; return; }
  jq -rn --arg tok "$id" '
    ($tok | split(".")[1] | gsub("-";"+") | gsub("_";"/")) as $p
    | ($p + (["","===","==","="][( ($p|length) % 4 )]))
    | @base64d | fromjson | .exp
  ' | awk -v now="$(now)" '{print $1 - now}'
}

login() {
  if [[ -t 0 ]]; then
    read -s -p "Cognito password: " PASSWORD; echo
  fi
  aws cognito-idp admin-initiate-auth \
    --user-pool-id "$USER_POOL_ID" \
    --client-id "$CLIENT_ID" \
    --auth-flow ADMIN_USER_PASSWORD_AUTH \
    --auth-parameters USERNAME="$USERNAME",PASSWORD="${PASSWORD:?PASSWORD not set}"
}

refresh() {
  local rt; rt="$(jq -r '.refresh_token' < "$TOKEN_FILE")"
  aws cognito-idp admin-initiate-auth \
    --user-pool-id "$USER_POOL_ID" \
    --client-id "$CLIENT_ID" \
    --auth-flow REFRESH_TOKEN_AUTH \
    --auth-parameters REFRESH_TOKEN="$rt"
}

save_tokens_from_resp() {
  local resp="$1"
  local id at rt
  id="$(jq -r '.AuthenticationResult.IdToken'    <<<"$resp")"
  at="$(jq -r '.AuthenticationResult.AccessToken'<<<"$resp")"
  # keep existing RT if refresh didn’t return a new one
  rt="$(jq -r '.AuthenticationResult.RefreshToken // empty' <<<"$resp")"
  if [[ -z "$rt" ]]; then rt="$(jq -r '.refresh_token' < "$TOKEN_FILE" 2>/dev/null || true)"; fi
  jq -n --arg id "$id" --arg at "$at" --arg rt "$rt" \
    '{id_token:$id, access_token:$at, refresh_token:$rt}' > "$TOKEN_FILE"
}

ensure_tokens() {
  if [[ ! -f "$TOKEN_FILE" ]]; then
    RESP="$(login)"
    save_tokens_from_resp "$RESP"
    echo "Logged in. Tokens saved to $TOKEN_FILE"
    return
  fi

  local ttl; ttl="$(expires_in || echo -999)"
  echo "expires_in=${ttl}s"
  if [[ "$ttl" -lt 60 ]]; then
    echo "Refreshing tokens..."
    RESP="$(refresh)"
    save_tokens_from_resp "$RESP"
  fi
}

whoami_token() {
  local token_type="${1:-id}"
  local key="${token_type}_token"
  jq -r --arg k "$key" '.[$k]' < "$TOKEN_FILE" | jq -R '
    split(".")[1] | gsub("-";"+") | gsub("_";"/")
    | . + (["","===","==","="][(length % 4)])
    | @base64d | fromjson
  ' | jq '{token_use, sub, email, "cognito:username", aud, exp}'
}

api() {
  local method="GET" path="/events" token_type="id" body="" debug=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -X|--method) method="$2"; shift 2;;
      -p|--path)   path="$2"; shift 2;;
      -d|--data)   body="$2"; shift 2;;
      --access)    token_type="access"; shift;;
      --id)        token_type="id"; shift;;
      --debug)     debug=1; shift;;
      --whoami)    whoami_token "${2:-id}"; return 0;;
      *) echo "Unknown arg: $1" >&2; return 2;;
    esac
  done

  local token_key="${token_type}_token"
  local token; token="$(jq -r --arg k "$token_key" '.[$k]' < "$TOKEN_FILE")"

  if [[ "$debug" -eq 1 ]]; then
    echo ">>> using ${token_type^^} token"
    echo "$token" | jq -R '
      split(".")[1] | gsub("-";"+") | gsub("_";"/")
      | . + (["","===","==","="][(length % 4)])
      | @base64d | fromjson | {token_use, aud, iss, exp}
    '
  fi

  if [[ -n "$body" ]]; then
    curl -sS -D- -X "$method" "$API_BASE$path" \
      -H "Authorization: Bearer $token" \
      -H "Content-Type: application/json" \
      --data "$body"
  else
    curl -sS -D- -X "$method" "$API_BASE$path" \
      -H "Authorization: Bearer $token"
  fi
}

main() {
  ensure_tokens
  api "$@"
}
main
