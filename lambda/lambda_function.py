import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    for record in event["Records"]:
        filename = record["s3"]["object"]["key"]
        logger.info("Image received: %s", filename)
    return {"statusCode": 200, "body": json.dumps({"message": "processed"})}
