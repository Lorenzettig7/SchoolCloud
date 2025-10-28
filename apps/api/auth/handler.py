# auth/handler.py
import json, base64

def _json(body, code=200):
    return {
        "statusCode": code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }

def handler(event, context):
    # 1) Normalize HTTP method
    method = (
        event.get("requestContext", {}).get("http", {}).get("method")
        or event.get("httpMethod")
        or "GET"
    ).upper()

    # 2) Normalize path (strip stage prefix if present)
    path = event.get("rawPath") or event.get("path") or "/"
    stage = event.get("requestContext", {}).get("stage")
    if stage and path.startswith(f"/{stage}/"):
        path = path[len(stage) + 1:]  # remove leading "/prod"

    # 3) Parse JSON body safely
    body_str = event.get("body") or ""
    if event.get("isBase64Encoded"):
        body_str = base64.b64decode(body_str).decode("utf-8")
    try:
        body = json.loads(body_str) if body_str else {}
    except json.JSONDecodeError:
        return _json({"error": "invalid JSON body"}, 400)

    # 4) Route
    if method == "POST" and path == "/auth/login":
        # TODO: your real login logic
        username = body.get("username")
        password = body.get("password")
        if username == "demo" and password == "demo":
            return _json({"token": "fake-jwt-demo"})
        return _json({"error": "invalid credentials"}, 401)

    if method == "GET" and path == "/auth/health":
        return _json({"status": "ok"})

    return _json({"error": f"unhandled path: {path}"}, 404)

