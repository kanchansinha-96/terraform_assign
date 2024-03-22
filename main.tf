terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}


provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region = "ap-south-1"  # Change to your desired region
}

resource "aws_elasticache_cluster" "redis_cluster" {
  cluster_id           = "my-redis-cluster"
  engine               = "redis"
  node_type            = "cache.t2.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
}

resource "aws_s3_bucket" "staging" {
  bucket = "kanchan96-staging-bucket"
}

resource "aws_s3_bucket" "prod" {
  bucket = "kanchan96-prod-bucket"
}

# Create the .zip file containing your Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "lambda.zip"
}

resource "aws_lambda_function" "my_lambda_function" {
  function_name    = "my-lambda-function"
  filename         = data.archive_file.lambda_zip.output_path
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.8"
  handler          = "lambda_function.lambda_handler"
  timeout          = 10
  memory_size      = 128
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

resource "aws_cloudwatch_event_rule" "lambda_trigger" {
  name        = "lambda-trigger-rule"
  description = "Trigger Lambda every 5 minutes"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.lambda_trigger.name
  target_id = "lambda-target"
  arn       = aws_lambda_function.my_lambda_function.arn
}

resource "aws_iam_role" "lambda_role" {
  name = "my-lambda-role"
  path = "/system/"  # Customize the path if needed

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Attach policies to the Lambda role
resource "aws_iam_policy_attachment" "attach_s3_read_policy" {
  name       = "my-s3-read-policy-attachment"
  policy_arn = aws_iam_policy.s3_read_policy.arn
  roles      = [aws_iam_role.lambda_role.name]
}

resource "aws_iam_policy_attachment" "attach_s3_write_policy" {
  name       = "my-s3-write-policy-attachment"
  policy_arn = aws_iam_policy.s3_write_policy.arn
  roles      = [aws_iam_role.lambda_role.name]
}

resource "aws_iam_policy_attachment" "attach_elasticache_policy" {
  name       = "my-elasticache-policy-attachment"
  policy_arn = aws_iam_policy.elasticache_policy.arn
  roles      = [aws_iam_role.lambda_role.name]
}

# Define IAM policies
resource "aws_iam_policy" "s3_read_policy" {
  name        = "s3-read-policy"
  description = "Allows read access to S3 buckets"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action   = "s3:GetObject",
      Effect   = "Allow",
      Resource = "arn:aws:s3:::kanchan96-staging-bucket/*"  # Customize bucket ARN
    }]
  })
}

resource "aws_iam_policy" "s3_write_policy" {
  name        = "s3-write-policy"
  description = "Allows write access to S3 buckets"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action   = "s3:PutObject",
      Effect   = "Allow",
      Resource = "arn:aws:s3:::kanchan96-prod-bucket/*"  # Customize bucket ARN
    }]
  })
}

resource "aws_iam_policy" "elasticache_policy" {
  name        = "elasticache-policy"
  description = "Allows access to ElastiCache"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action   = "elasticache:*",
      Effect   = "Allow",
      Resource = "*"
    }]
  })
}