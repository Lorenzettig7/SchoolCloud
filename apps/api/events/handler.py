# apps/api/events/handler.py
import os
import json
import time
import base64
import hmac
import hashlib
import uuid
from datetime import datetime, timezone

import boto3
from boto3.dynamodb.conditions import Key


# ---------- HTTP helpers ----------
def resp(code: int, body: dict | list | str):
    if not isinstance(body, (dict, list, str)):
        body = {"error": "invalid_response_type"}
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


# ---------- Env / AWS ----------
REGION = os.getenv("REGION", "us-east-1")

_dy = boto3.resource("dynamodb", region_name=REGION)
EVENTS = _dy.Table(os.environ["EVENTS_TABLE"])  # requires env var
# USERS table not needed here, but can be accessed similarly if required:
# USERS = _dy.Table(os.environ["USERS_TABLE"])


# ---------- JWT helpers (HS256) ----------
def _b64u_decode(s: str) -> bytes:
    s += "=" * ((4 - len(s) % 4) % 4)
    return base64.urlsafe_b64decode(s.encode("utf-8"))


def _get_secret() -> str:
    """
    Load JWT secret. Preference order:
    1) SSM parameter at JWT_PARAM
    2) Env var JWT_SECRET
    3) 'dev-demo-secret' (dev fallback)
    """
    param = os.getenv("JWT_PARAM")
    if not param:
        return os.getenv("JWT_SECRET", "dev-demo-secret")
    ssm = boto3.client("ssm", region_name=REGION)
    try:
        r = ssm.get_parameter(Name=param, WithDecryption=True)
        return r["Parameter"]["Value"]
    except Exception as e:
        # Safe fallback in dev
        print(f"[events] SSM get_parameter failed: {e}")
        return os.getenv("JWT_SECRET", "dev-demo-secret")


SECRET = _get_secret()


def _parse_bearer(headers: dict) -> str | None:
    # accept both casings
    auth = (headers or {}).get("authorization") or (headers or {}).get("Authorization")
    if not auth or not auth.startswith("Bearer "):
        return None
    return auth.split(" ", 1)[1]


def _decode_jwt(token: str):
    """
    Minimal HS256 verification compatible with your identity handler.
    Returns payload dict if signature is valid & token is current, else None.
    """
    try:
        header_b64, payload_b64, sig_b64 = token.split(".")
        signing_input = f"{header_b64}.{payload_b64}".encode("utf-8")
        expected = hmac.new(SECRET.encode("utf-8"), signing_input, hashlib.sha256).digest()
        actual = _b64u_decode(sig_b64)
        if not hmac.compare_digest(expected, actual):
            return None

        payload_json = _b64u_decode(payload_b64).decode("utf-8")
        payload = json.loads(payload_json)

        now = int(time.time())
        if "exp" in payload and now >= int(payload["exp"]):
            return None
        if "nbf" in payload and now < int(payload["nbf"]):
            return None

        return payload
    except Exception as e:
        print(f"[events] JWT decode error: {e}")
        return None


# ---------- Routes ----------
def _iso_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _require_auth(event):
    """Return (email, error_response) where error_response is an HTTP response or None."""
    headers = (event.get("headers", {}) or {})
    token = _parse_bearer(headers)
    payload = _decode_jwt(token) if token else None
    if not payload:
        return None, resp(401, {"error": "unauthorized"})
    email = payload.get("sub")
    if not email:
        return None, resp(401, {"error": "unauthorized"})
    return email, None


def _route_get_events(email: str):
    """GET /events -> list events for the authenticated user."""
    try:
        r = EVENTS.query(
            KeyConditionExpression=Key("pk").eq(f"user#{email}")
        )
        items = r.get("Items", [])
        return resp(200, {"items": items})
    except Exception as e:
        print(f"[events] query failed: {e}")
        return resp(500, {"error": "query_failed"})


def _route_post_events(email: str, body: dict):
    """
    POST /events -> create a simple event item.
    Body example:
      { "type": "policy.set", "detail": {"enc":"SSE-S3"} }
    """
    try:
        evt_type = str(body.get("type", "custom"))
        detail = body.get("detail", {})

        now_iso = _iso_now()
        item = {
            "pk": f"user#{email}",
            "sk": f"evt#{now_iso}#{uuid.uuid4().hex[:8]}",
            "type": evt_type,
            "detail": detail,
            "created_at": now_iso,
        }
        EVENTS.put_item(Item=item)
        return resp(200, {"ok": True, "item": item})
    except Exception as e:
        print(f"[events] put_item failed: {e}")
        return resp(500, {"error": "write_failed"})


# ---------- Lambda entry ----------
def handler(event, ctx):
    # Support both HTTP API v2 & REST API shapes
    method = (
        event.get("requestContext", {})
        .get("http", {})
        .get("method", event.get("httpMethod", "GET"))
    )
    if method == "OPTIONS":
        return resp_options()

    path = event.get("rawPath") or event.get("path") or ""

    # Require auth for everything below
    email, error = _require_auth(event)
    if error:
        return error

    # GET /events
    if path.endswith("/events") and method == "GET":
        return _route_get_events(email)

    # POST /events
    if path.endswith("/events") and method == "POST":
        b = event.get("body") or "{}"
        # API Gateway might pass body as string
        try:
            body = json.loads(b) if isinstance(b, str) else (b or {})
        except Exception:
            body = {}
        return _route_post_events(email, body)

    return resp(404, {"error": "not_found"})
