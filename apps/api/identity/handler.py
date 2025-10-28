# apps/api/identity/handler.py
import os, json, time, uuid, base64, hmac, hashlib, boto3

# ---------- HTTP helpers ----------
def resp(code, body):
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

def resp_options():
    return {
        "statusCode": 204,
        "headers": {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
            "Access-Control-Allow-Headers": "content-type,authorization",
            "Access-Control-Max-Age": "86400",
        },
        "body": "",
    }

# ---------- Env / AWS clients ----------
REGION = os.getenv("REGION", "us-east-1")
_dy = boto3.resource("dynamodb", region_name=REGION)
USERS  = _dy.Table(os.environ["USERS_TABLE"])
EVENTS = _dy.Table(os.environ["EVENTS_TABLE"])

def _get_secret() -> str:
    param = os.getenv("JWT_PARAM")
    if not param:
        return os.getenv("JWT_SECRET", "dev-demo-secret")
    ssm = boto3.client("ssm", region_name=REGION)
    try:
        r = ssm.get_parameter(Name=param, WithDecryption=True)
        return r["Parameter"]["Value"]
    except Exception:
        return os.getenv("JWT_SECRET", "dev-demo-secret")

SECRET = _get_secret()

# ---------- JWT helpers ----------
def _b64u_decode(s: str) -> bytes:
    s += "=" * ((4 - len(s) % 4) % 4)
    return base64.urlsafe_b64decode(s.encode("utf-8"))

def parse_token(auth_header):
    if not auth_header or not auth_header.startswith("Bearer "):
        return None
    return auth_header.split(" ", 1)[1]

def decode_payload(token: str):
    try:
        header_b64, payload_b64, sig_b64 = token.split(".")
        signing_input = f"{header_b64}.{payload_b64}".encode("utf-8")
        expected = hmac.new(SECRET.encode("utf-8"), signing_input, hashlib.sha256).digest()
        actual = _b64u_decode(sig_b64)
        if not hmac.compare_digest(expected, actual):
            return None
        payload_json = _b64u_decode(payload_b64).decode("utf-8")
        return json.loads(payload_json)
    except Exception:
        return None

def write_event(email, type_, message, status="OK", data=None):
    ts = int(time.time() * 1000)
    EVENTS.put_item(Item={
        "pk": f"user#{email}",
        "sk": f"{ts}#{uuid.uuid4().hex[:8]}",
        "type": type_,
        "status": status,
        "message": message,
        "data": data or {},
        "ts": ts
    })

# ---------- Lambda entry ----------
def handler(event, ctx):
    # Support both HTTP API v2 and REST API
    method = (
        event.get("requestContext", {})
        .get("http", {})
        .get("method", event.get("httpMethod", "GET"))
    )
    if method == "OPTIONS":
        return resp_options()

    path = event.get("rawPath") or event.get("path") or ""
    body = json.loads(event.get("body") or "{}")

    auth = (event.get("headers", {}) or {}).get("authorization") or (event.get("headers", {}) or {}).get("Authorization")
    token = parse_token(auth)
    payload = decode_payload(token) if token else None
    if not payload:
        return resp(401, {"error": "unauthorized"})

    email = payload.get("sub")
    if not email:
        return resp(401, {"error": "unauthorized"})

    # POST /identity/group
    if path.endswith("/identity/group"):
        group = (body.get("group") or "").lower()
        if group not in ["student", "teacher", "admin"]:
            return resp(400, {"error": "group must be student|teacher|admin"})
        USERS.update_item(
            Key={"pk": f"user#{email}", "sk": "meta"},
            UpdateExpression="SET #r = :r",
            ExpressionAttributeNames={"#r": "role"},
            ExpressionAttributeValues={":r": group}
        )
        write_event(email, "identity.group.add", f"Added to group: {group}")
        return resp(200, {"ok": True, "role": group})

    # POST /identity/policy
    if path.endswith("/identity/policy"):
        enc = body.get("encryption") or "SSE-S3"
        USERS.update_item(
            Key={"pk": f"user#{email}", "sk": "meta"},
            UpdateExpression="SET enc = :e",
            ExpressionAttributeValues={":e": enc}
        )
        write_event(email, "policy.attach", f"Encryption policy set: {enc}", data={"encryption": enc})
        return resp(200, {"ok": True, "encryption": enc})

    return resp(404, {"error": "not found"})
