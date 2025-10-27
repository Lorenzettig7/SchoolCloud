# apps/api/auth/handler.py

import os
import json
import time
import uuid
import base64
import hmac
import hashlib
import secrets
from typing import Optional

import boto3


# ---------- HTTP helpers ----------

def resp(code: int, body: dict):
    """JSON response with permissive CORS (adjust origins as needed)."""
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
    """CORS preflight."""
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
USERS = _dy.Table(os.environ["USERS_TABLE"])
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
        # Safe fallback so dev/local still works
        return os.getenv("JWT_SECRET", "dev-demo-secret")


SECRET = _get_secret()


# ---------- Crypto helpers ----------

def pbkdf2_hash(pw: str, salt: Optional[bytes] = None):
    if salt is None:
        salt = secrets.token_bytes(16)
    dk = hashlib.pbkdf2_hmac("sha256", pw.encode("utf-8"), salt, 120_000, dklen=32)
    return base64.b64encode(salt).decode("utf-8"), base64.b64encode(dk).decode("utf-8")


def pbkdf2_verify(pw: str, salt_b64: str, hash_b64: str) -> bool:
    salt = base64.b64decode(salt_b64.encode("utf-8"))
    dk = hashlib.pbkdf2_hmac("sha256", pw.encode("utf-8"), salt, 120_000, dklen=32)
    return hmac.compare_digest(base64.b64encode(dk).decode("utf-8"), hash_b64)


def _b64u_bytes(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode("utf-8")


def _b64u_json(obj: dict) -> str:
    return _b64u_bytes(json.dumps(obj, separators=(",", ":")).encode("utf-8"))


def mk_token(email: str, role: str) -> str:
    header = {"alg": "HS256", "typ": "JWT"}
    now = int(time.time())
    payload = {"sub": email, "role": role, "iat": now, "exp": now + 3600}

    signing_input = f"{_b64u_json(header)}.{_b64u_json(payload)}"
    sig = hmac.new(SECRET.encode("utf-8"), signing_input.encode("utf-8"), hashlib.sha256).digest()
    return f"{signing_input}.{_b64u_bytes(sig)}"


# ---------- Event log ----------

def write_event(email: str, type_: str, message: str, status: str = "OK", data: Optional[dict] = None):
    ts = int(time.time() * 1000)
    EVENTS.put_item(
        Item={
            "pk": f"user#{email}",
            "sk": f"{ts}#{uuid.uuid4().hex[:8]}",
            "type": type_,
            "status": status,
            "message": message,
            "data": data or {},
            "ts": ts,
        }
    )


# ---------- Lambda entry ----------

def handler(event, ctx):
    # method + path (support both HTTP API v2 and REST API)
    method = (
        event.get("requestContext", {})
        .get("http", {})
        .get("method", event.get("httpMethod", "GET"))
    )
    path = event.get("rawPath") or event.get("path") or ""

    # Preflight
    if method == "OPTIONS":
        return resp_options()

    # Parse JSON body
    try:
        body = json.loads(event.get("body") or "{}")
    except Exception:
        return resp(400, {"error": "invalid JSON"})

    # Health check (optional)
    if path.endswith("/auth/health"):
        return resp(200, {"status": "ok"})

    # ---------- /auth/signup ----------
    if path.endswith("/auth/signup") and method == "POST":
        email = (body.get("email") or "").lower().strip()
        pw = body.get("password") or ""
        role = body.get("role") or "student"
        sid = body.get("school_id") or ""
        dob = body.get("dob") or ""

        if not email or not pw:
            return resp(400, {"error": "email and password required"})

        salt, pwh = pbkdf2_hash(pw)
        USERS.put_item(
            Item={
                "pk": f"user#{email}",
                "sk": "meta",
                "email": email,
                "role": role,
                "school_id": sid,
                "dob": dob,
                "salt": salt,
                "pwh": pwh,
                "created_at": int(time.time()),
            }
        )
        write_event(email, "auth.signup", "Account created", data={"role": role})
        write_event(email, "identity.group.add", f"Added to group: {role}")

        token = mk_token(email, role)
        return resp(
            200,
            {
                "token": token,
                "user": {"email": email, "role": role, "school_id": sid, "dob": dob},
            },
        )

    # ---------- /auth/login ----------
    if path.endswith("/auth/login") and method == "POST":
        email = (body.get("email") or "").lower().strip()
        pw = body.get("password") or ""

        if not email or not pw:
            return resp(400, {"error": "email and password required"})

        r = USERS.get_item(Key={"pk": f"user#{email}", "sk": "meta"})
        item = r.get("Item")
        if not item:
            return resp(401, {"error": "invalid credentials"})

        ok = pbkdf2_verify(pw, item["salt"], item["pwh"])
        if not ok:
            return resp(401, {"error": "invalid credentials"})

        token = mk_token(email, item.get("role", "student"))
        write_event(email, "auth.login", "Login success")

        return resp(
            200,
            {
                "token": token,
                "user": {
                    "email": email,
                    "role": item.get("role", "student"),
                    "school_id": item.get("school_id", ""),
                    "dob": item.get("dob", ""),
                },
            },
        )

    # Fallback
    return resp(404, {"error": "not found"})
