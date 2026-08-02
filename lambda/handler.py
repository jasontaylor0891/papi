import json
import os

LAMBDA_DIR = os.path.dirname(__file__)

_ROUTES = {
    "/me": "me.json",
    "/resume": "resume.json",
    "/projects": "projects.json",
}

_DATA = {
    path: json.load(open(os.path.join(LAMBDA_DIR, filename)))
    for path, filename in _ROUTES.items()
}


def handler(event, context):
    body = _DATA.get(event["rawPath"])

    if body is None:
        return {
            "statusCode": 404,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"message": "Not found"}),
        }

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            # Loosen this if you'll call the API from a browser on another origin
            "Access-Control-Allow-Origin": "*",
            "Cache-Control": "public, max-age=60",
        },
        "body": json.dumps(body),
    }
