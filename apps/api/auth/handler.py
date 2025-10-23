import os, json, time, uuid, base64, hmac, hashlib, boto3, secrets

USERS = boto3.resource("dynamodb").Table(os.environ["USERS_TABLE"])
EVENTS = boto3.resource("dynamodb").Table(os.environ["EVENTS_TABLE"])
REGION = os.getenv("REGION", "us-east-1")

def get_secret():
  param = os.getenv("JWT_PARAM")
  if not param:
    return os.getenv("JWT_SECRET", "dev-demo-secret")
  ssm = boto3.client("ssm", region_name=REGION)
  try:
    r = ssm.get_parameter(Name=param, WithDecryption=True)
    return r["Parameter"]["Value"]
  except Exception:
    return os.getenv("JWT_SECRET", "dev-demo-secret")

SECRET = get_secret()

def pbkdf2_hash(pw: str, salt: bytes | None = None):
  if salt is None:
    salt = secrets.token_bytes(16)
  dk = hashlib.pbkdf2_hmac("sha256", pw.encode(), salt, 120000, dklen=32)
  return base64.b64encode(salt).decode(), base64.b64encode(dk).decode()

def pbkdf2_verify(pw: str, salt_b64: str, hash_b64: str):
  salt = base64.b64decode(salt_b64.encode())
  dk = hashlib.pbkdf2_hmac("sha256", pw.encode(), salt, 120000, dklen=32)
  return hmac.compare_digest(base64.b64encode(dk).decode(), hash_b64)

def mk_token(email: str, role: str):
  header = {"alg":"HS256","typ":"JWT"}
  payload = {"sub":email,"role":role,"iat":int(time.time()),"exp":int(time.time())+3600}
  def b64u(x): return base64.urlsafe_b64encode(json.dumps(x).encode()).rstrip(b"=").decode()
  signing_input = f"{b64u(header)}.{b64u(payload)}"
  sig = hmac.new(SECRET.encode(), signing_input.encode(), hashlib.sha256).digest()
  return f"{signing_input}.{base64.urlsafe_b64encode(sig).rstrip(b'=').decode()}"

def write_event(email, type_, message, status="OK", data=None):
  ts = int(time.time()*1000)
  EVENTS.put_item(Item={
    "pk": f"user#{email}",
    "sk": f"{ts}#{uuid.uuid4().hex[:8]}",
    "type": type_, "status": status, "message": message, "data": data or {}, "ts": ts
  })

def resp(code, body): 
  return {"statusCode": code, "headers":{"content-type":"application/json","access-control-allow-origin":"*"}, "body": json.dumps(body)}

def handler(event, ctx):
  path = event.get("rawPath","")
  try:
    body = json.loads(event.get("body") or "{}")
  except Exception:
    return resp(400, {"error":"invalid json"})

  if path.endswith("/auth/signup"):
    email = (body.get("email") or "").lower().strip()
    pw    = body.get("password") or ""
    role  = body.get("role") or "student"
    sid   = body.get("school_id") or ""
    dob   = body.get("dob") or ""
    if not email or not pw: return resp(400, {"error":"email and password required"})
    salt, pwh = pbkdf2_hash(pw)
    USERS.put_item(Item={
      "pk": f"user#{email}", "sk":"meta", "email": email, "role": role,
      "school_id": sid, "dob": dob, "salt": salt, "pwh": pwh, "created_at": int(time.time())
    })
    write_event(email, "auth.signup", "Account created", data={"role": role})
    write_event(email, "identity.group.add", f"Added to group: {role}")
    token = mk_token(email, role)
    return resp(200, {"token": token, "user": {"email": email, "role": role, "school_id": sid, "dob": dob}})

  if path.endswith("/auth/login"):
    email = (body.get("email") or "").lower().strip()
    pw    = body.get("password") or ""
    if not email or not pw: return resp(400, {"error":"email and password required"})
    r = USERS.get_item(Key={"pk": f"user#{email}", "sk":"meta"})
    item = r.get("Item")
    if not item: return resp(401, {"error":"invalid credentials"})
    ok = pbkdf2_verify(pw, item["salt"], item["pwh"])
    if not ok: return resp(401, {"error":"invalid credentials"})
    token = mk_token(email, item.get("role","student"))
    write_event(email, "auth.login", "Login success")
    return resp(200, {"token": token, "user": {"email": email, "role": item.get("role"), "school_id": item.get("school_id",""), "dob": item.get("dob","")}})
  return resp(404, {"error": "not found"})
