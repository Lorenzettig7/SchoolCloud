import os, json, time, uuid, base64, boto3

USERS  = boto3.resource("dynamodb").Table(os.environ["USERS_TABLE"])
EVENTS = boto3.resource("dynamodb").Table(os.environ["EVENTS_TABLE"])

def resp(code, body): 
  return {"statusCode": code, "headers":{"content-type":"application/json","access-control-allow-origin":"*"}, "body": json.dumps(body)}

def parse_token(auth_header):
  if not auth_header or not auth_header.startswith("Bearer "): return None
  return auth_header.split(" ",1)[1]

def decode_payload(token):
  try:
    parts = token.split(".")
    payload_b64 = parts[1] + "="*((4-len(parts[1])%4)%4)
    return json.loads(base64.urlsafe_b64decode(payload_b64.encode()).decode())
  except Exception:
    return None

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
  if not payload: return resp(401, {"error":"unauthorized"})

  email = payload.get("sub")
  if path.endswith("/identity/group"):
    group = (body.get("group") or "").lower()
    if group not in ["student","teacher","admin"]:
      return resp(400, {"error":"group must be student|teacher|admin"})
    USERS.update_item(
      Key={"pk": f"user#{email}", "sk":"meta"},
      UpdateExpression="SET #r = :r",
      ExpressionAttributeNames={"#r": "role"},
      ExpressionAttributeValues={":r": group}
    )
    write_event(email, "identity.group.add", f"Added to group: {group}")
    return resp(200, {"ok": True, "role": group})

  if path.endswith("/identity/policy"):
    enc = body.get("encryption") or "SSE-S3"
    USERS.update_item(
      Key={"pk": f"user#{email}", "sk":"meta"},
      UpdateExpression="SET enc = :e",
      ExpressionAttributeValues={":e": enc}
    )
    write_event(email, "policy.attach", f"Encryption policy set: {enc}", data={"encryption": enc})
    return resp(200, {"ok": True, "encryption": enc})

  return resp(404, {"error":"not found"})
