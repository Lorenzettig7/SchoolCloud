import json
import traceback

def handler(event, ctx):
    try:
        method = (
            event.get("requestContext", {})
            .get("http", {})
            .get("method", event.get("httpMethod", "GET"))
        )
        path = event.get("rawPath") or event.get("path") or ""

        print("Method:", method)
        print("Path:", path)
        print("Event body:", event.get("body"))

        return {
            "statusCode": 404,
            "body": json.dumps({"error": f"unhandled path: {path}"}),
        }

    except Exception as e:
        print("Exception occurred:", e)
        print(traceback.format_exc())
        return {
            "statusCode": 500,
            "body": json.dumps({"error": "internal failure", "details": str(e)}),
        }
