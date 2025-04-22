import boto3
import csv
import json
import os
from io import StringIO

s3 = boto3.client('s3')

def lambda_handler(event, context):
    bucket = os.environ.get('BUCKET')
    key = os.environ.get('KEY')

    try:
        # Fetch the file from S3
        response = s3.get_object(Bucket=bucket, Key=key)
        csv_content = response['Body'].read().decode('utf-8')

        # Parse CSV
        reader = csv.DictReader(StringIO(csv_content))
        data = list(reader)

        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps(data)
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
