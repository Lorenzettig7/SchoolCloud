import json, base64
def _json(body, code=200):
    return {"statusCode": code,"headers":{"Content-Type":"application/json"}, "body": json.dumps(body)}
def handler(event, context):
    method = (event.get("requestContext",{}).get("http",{}).get("method") or event.get("httpMethod") or "GET").upper()
    path   = event.get("rawPath") or event.get("path") or "/"
    stage  = event.get("requestContext",{}).get("stage")
    if stage and path.startswith(f"/{stage}/"): path = path[len(stage)+1:]
    body_s = event.get("body") or ""
    if event.get("isBase64Encoded"): body_s = base64.b64decode(body_s).decode("utf-8")
    try: body = json.loads(body_s) if body_s else {}
    except json.JSONDecodeError: return _json({"error":"invalid JSON body"}, 400)
    if method=="GET" and path=="/auth/health": return _json({"status":"ok"})
    if method=="POST" and path=="/auth/login":
        if body.get("username")=="demo" and body.get("password")=="demo":
            return _json({"token":"fake-jwt-demo"})
        return _json({"error":"invalid credentials"}, 401)
    return _json({"error":f"unhandled path: {path}"}, 404)
