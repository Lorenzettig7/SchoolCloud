# apps/api/events/handler.py
import os, json, time, base64, hmac, hashlib, boto3
from boto3.dynamodb.conditions import Key

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
EVENTS = _dy.Table(os.environ["EVENTS_TABLE"])

def _get_secret() -> str:
    """
    Resolve signing secret for JWT:
      - If JWT_PARAM is set, fetch decrypted value from SSM Parameter Store
      - Else use JWT_SECRET (or fallback dev secret)
    """
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
    """
    Verify HS256 signature and return JWT payload dict, else None.
    """
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

    auth = (event.get("headers", {}) or {}).get("authorization") or (event.get("headers", {}) or {}).get("Authorization")
    token = parse_token(auth)
    payload = decode_payload(token) if token else None
    if not payload:
        return resp(401, {"error": "unauthorized"})

    email = payload.get("sub")
    if not email:
        return resp(401, {"error": "unauthorized"})

    q = event.get("queryStringParameters") or {}
    since = int(q.get("since", 0))

    r = EVENTS.query(
        KeyConditionExpression=Key("pk").eq(f"user#{email}"),
        ScanIndexForward=False,
        Limit=50
    )
    items = r.get("Items", [])
    if since:
        items = [it for it in items if int(it.get("ts", 0)) > since]

    return resp(200, items)
