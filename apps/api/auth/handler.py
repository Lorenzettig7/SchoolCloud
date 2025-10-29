import json, os, time
import boto3
import jwt  # PyJWT

def _get_secret():
    ssm = boto3.client("ssm", region_name=os.environ["REGION"])
    param_name = os.environ["JWT_PARAM"]  # e.g., /schoolcloud-demo/jwt_secret
    return ssm.get_parameter(Name=param_name, WithDecryption=True)["Parameter"]["Value"]

def _ok(body: dict, status=200, headers=None):
    base = {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
        "Access-Control-Allow-Headers": "content-type,authorization",
    }
    if headers: base.update(headers)
    return {"statusCode": status, "headers": base, "body": json.dumps(body)}

def handler(event, context):
    method = event.get("requestContext", {}).get("http", {}).get("method", "GET")
    path   = event.get("rawPath", "/")
    if method == "OPTIONS":  # CORS preflight
        return _ok({"ok": True})

    if path == "/auth/login" and method == "POST":
        body = json.loads(event.get("body") or "{}")
        username = body.get("username")
        password = body.get("password")

        # DEMO auth check (replace with real user lookup)
        if not (username == "demo" and password == "demo"):
            return _ok({"error": "invalid_credentials"}, status=401)

        secret = _get_secret()
        now = int(time.time())
        claims = {
            "sub": username,
            "iat": now,
            "exp": now + 3600,     # 1 hour
            "scope": "user",
        }
        token = jwt.encode(claims, secret, algorithm="HS256")
        return _ok({"token": token})

    return _ok({"error": "not_found"}, status=404)
