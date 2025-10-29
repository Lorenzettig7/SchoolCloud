import json, os
import boto3, jwt

def _get_secret():
    ssm = boto3.client("ssm", region_name=os.environ["REGION"])
    return ssm.get_parameter(Name=os.environ["JWT_PARAM"], WithDecryption=True)["Parameter"]["Value"]

def _ok(body: dict, status=200, headers=None):
    base = {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
        "Access-Control-Allow-Headers": "content-type,authorization",
    }
    if headers: base.update(headers)
    return {"statusCode": status, "headers": base, "body": json.dumps(body)}

def _auth(headers):
    token = (headers or {}).get("authorization") or (headers or {}).get("Authorization")
    if not token or not token.lower().startswith("bearer "):
        return None, ("missing_token", 401)
    token = token.split(" ", 1)[1]
    try:
        claims = jwt.decode(token, _get_secret(), algorithms=["HS256"])
        return claims, None
    except jwt.ExpiredSignatureError:
        return None, ("token_expired", 401)
    except Exception:
        return None, ("unauthorized", 401)

def handler(event, context):
    if event.get("requestContext", {}).get("http", {}).get("method") == "OPTIONS":
        return _ok({"ok": True})
    claims, err = _auth(event.get("headers") or {})
    if err:
        msg, code = err
        return _ok({"error": msg}, status=code)

    # … your protected logic …
    return _ok({"me": claims.get("sub", "unknown")})
