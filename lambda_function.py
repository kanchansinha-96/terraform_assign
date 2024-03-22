import boto3
import json
from datetime import datetime

def lambda_handler(event, context):
    # Initialize S3 and ElastiCache clients
    s3_client = boto3.client('s3')
    elasticache_client = boto3.client('elasticache')

    # Specify your bucket names and file paths
    staging_bucket = 'kanchan96-staging-bucket'
    prod_bucket = 'kanchan96-prod-bucket'
    staging_file = 'index.html'
    prod_file = 'index.html'

    # Get last modified timestamps for staging and production files
    staging_timestamp = s3_client.head_object(Bucket=staging_bucket, Key=staging_file)['LastModified']
    prod_timestamp = s3_client.head_object(Bucket=prod_bucket, Key=prod_file)['LastModified']

    # Compare timestamps and overwrite if necessary
    if staging_timestamp > prod_timestamp:
        # Read content from staging file
        staging_content = s3_client.get_object(Bucket=staging_bucket, Key=staging_file)['Body'].read()

        # Overwrite production file with staging content
        s3_client.put_object(Bucket=prod_bucket, Key=prod_file, Body=staging_content)


    # Write to ElasticCache (Redis) with the current timestamp
    invoke_timestamp = datetime.now().isoformat()
    prod_updated = True  # Replace with your actual value
    cache_key = json.dumps({invoke_timestamp: prod_updated})
    elasticache_client.set(key='my_key', value=cache_key)

    return {
        "statusCode": 200,
        "body": f"Prod updated: {prod_updated}"
    }