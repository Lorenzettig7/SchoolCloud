#!/usr/bin/env bash
set -euo pipefail

# --- AWS + Cognito config ---
export AWS_REGION=us-east-1
export USER_POOL_ID="${USER_POOL_ID:-us-east-1_7soL15d0V}"
export USER_POOL_CLIENT_ID="${USER_POOL_CLIENT_ID:-4cddgb64bfu2au7ce5t9fqgtjp}"

# --- OAuth + PKCE setup ---
AUTH_DOMAIN="https://schoolcloud-dev.auth.us-east-1.amazoncognito.com"
CLIENT_ID="$USER_POOL_CLIENT_ID"
REDIRECT_URI="http://localhost:3000/callback"
SCOPES="openid profile email api://schoolcloud/read api://schoolcloud/write"
PKCE_FILE="${TMPDIR:-/tmp}/schoolcloud_pkce.txt"
TOKENS_PATH="${TMPDIR:-/tmp}/sc_tokens.json"

# 1) PKCE
CODE_VERIFIER="$(openssl rand -base64 48 | tr -d '=+/ ' | cut -c1-64)"
printf '%s\n' "$CODE_VERIFIER" > "$PKCE_FILE"
CODE_CHALLENGE="$(printf '%s' "$CODE_VERIFIER" | openssl dgst -sha256 -binary | openssl base64 | tr '+/' '-_' | tr -d '=')"
[[ -n "$CODE_CHALLENGE" ]]

# 2) Build auth URL
ENC_REDIRECT="$(python3 - <<PY
import urllib.parse; print(urllib.parse.quote("$REDIRECT_URI", safe=""))
PY
)"
ENC_SCOPES="$(python3 - <<PY
import urllib.parse; print(urllib.parse.quote("$SCOPES"))
PY
)"
AUTH_URL="$AUTH_DOMAIN/oauth2/authorize?response_type=code&client_id=$CLIENT_ID&redirect_uri=$ENC_REDIRECT&scope=$ENC_SCOPES&code_challenge_method=S256&code_challenge=$CODE_CHALLENGE&prompt=login"

echo "Saved verifier -> $PKCE_FILE"
echo "Auth URL:"
echo "$AUTH_URL"
open "$AUTH_URL" || true

# 3) Paste ?code= value
read -rp "Paste the 'code' value from the callback URL: " CODE
[[ -n "$CODE" ]]

# 4) Exchange code for tokens
TOKENS_JSON="$(
  curl -s -X POST "$AUTH_DOMAIN/oauth2/token" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -d "grant_type=authorization_code" \
    -d "client_id=$CLIENT_ID" \
    -d "code=$CODE" \
    -d "redirect_uri=$REDIRECT_URI" \
    -d "code_verifier=$CODE_VERIFIER"
)"
echo "$TOKENS_JSON" | jq .
printf '%s\n' "$TOKENS_JSON" > "$TOKENS_PATH"
echo "Saved tokens -> $TOKENS_PATH"
