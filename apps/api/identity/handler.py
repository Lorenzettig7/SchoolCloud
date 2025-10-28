import os, json, time, uuid, base64, boto3
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

USERS  = boto3.resource("dynamodb").Table(os.environ["USERS_TABLE"])
EVENTS = boto3.resource("dynamodb").Table(os.environ["EVENTS_TABLE"])


def parse_token(auth_header):
  if not auth_header or not auth_header.startswith("Bearer "): return None
  return auth_header.split(" ",1)[1]

def decode_payload(token):
  return {"sub": "test@example.com"}



def write_event(email, type_, message, status="OK", data=None):
  ts = int(time.time()*1000)
  EVENTS.put_item(Item={
    "pk": f"user#{email}",
    "sk": f"{ts}#{uuid.uuid4().hex[:8]}",
    "type": type_, "status": status, "message": message, "data": data or {}, "ts": ts
  })

def handler(event, ctx):
  path = event.get("rawPath","")
  body = json.loads(event.get("body") or "{}")
  auth = event.get("headers",{}).get("authorization") or event.get("headers",{}).get("Authorization")
  token = parse_token(auth)
  payload = decode_payload(token) if token else None

  if not payload and not path.endswith(("/auth/signup", "/auth/login")):
    return resp(401, {"error":"unauthorized"})

  # /identity/policy block...

  if path.endswith("/auth/signup"):
    email = body.get("email")
    password = body.get("password")
    if not email or not password:
      return resp(400, {"error": "email and password required"})

    USERS.put_item(Item={
      "pk": f"user#{email}",
      "sk": "meta",
      "email": email,
      "password": password,  # In production, hash this!
      "role": "student"
    })

    write_event(email, "auth.signup", "New user signed up")
    return resp(201, {"ok": True})

  return resp(404, {"error":"not found"})  # ← keep this at the bottom inside the handler
