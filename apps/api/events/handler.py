import json

def _resp(code, body):
    return {
        "statusCode": code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
            "Access-Control-Allow-Headers": "content-type,authorization",
        },
        "body": json.dumps(body),
    }

def handler(event, ctx):
    rc = (event or {}).get("requestContext", {}) or {}
    auth = rc.get("authorizer", {}) or {}
    # HTTP API v2 + JWT authorizer claims
    claims = (auth.get("jwt", {}) or {}).get("claims", {})
    # REST API + Cognito fallback
    if not claims and isinstance(auth.get("claims"), dict):
        claims = auth["claims"]

    if claims:
        # prove we’re authenticated end-to-end
        return _resp(200, {"ok": True, "claims": claims})

    return _resp(401, {"error": "unauthorized", "debug_authorizer_shape": auth})
