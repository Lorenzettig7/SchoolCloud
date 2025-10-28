import os, json, base64, boto3
from boto3.dynamodb.conditions import Key

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

EVENTS = boto3.resource("dynamodb").Table(os.environ["EVENTS_TABLE"])

def parse_token(auth_header):
  if not auth_header or not auth_header.startswith("Bearer "): return None
  return auth_header.split(" ",1)[1]

def decode_payload(token):
  try:
    parts = token.split(".")
    payload_b64 = parts[1] + "="*((4-len(parts[1])%4)%4)
    return resp(200, {"message": "ok"})

  except Exception:
    return None

def handler(event, ctx):
  auth = event.get("headers",{}).get("authorization") or event.get("headers",{}).get("Authorization")
  token = parse_token(auth)
  payload = decode_payload(token) if token else None
  if not payload: return resp(401, {"error":"unauthorized"})
  email = payload.get("sub")

  q = event.get("queryStringParameters") or {}
  since = int(q.get("since", 0))

  r = EVENTS.query(
    KeyConditionExpression=Key("pk").eq(f"user#{email}"),
    ScanIndexForward=False,
    Limit=50
  )
  items = r.get("Items", [])
  if since:
    items = [it for it in items if int(it.get("ts",0)) > since]
  return resp(200, items)
