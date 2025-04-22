provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "data_bucket" {
  bucket = "rearc-test-umesh-data"
  force_destroy = true

  tags = {
    Name = "Rearc Test Data Bucket"
  }
}

resource "aws_s3_object" "dataset" {
  bucket = aws_s3_bucket.data_bucket.id
  key    = "global_csv.csv"
  source = "${path.module}/../data/global_csv.csv"
  etag   = filemd5("${path.module}/../data/global_csv.csv")
  content_type = "text/csv"
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "rearc_lambda_exec_role"
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

resource "aws_iam_policy_attachment" "lambda_logs" {
  name       = "attach-lambda-logs"
  roles      = [aws_iam_role.lambda_exec_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "rearc_lambda" {
  function_name = "rearc-data-api"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.9"
  timeout       = 10
  filename      = "${path.module}/../lambda/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/../lambda/lambda.zip")

  environment {
    variables = {
      BUCKET = aws_s3_bucket.data_bucket.bucket
      KEY    = "global_csv.csv"
    }
  }
}

resource "aws_apigatewayv2_api" "http_api" {
  name          = "rearc-http-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id             = aws_apigatewayv2_api.http_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.rearc_lambda.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "default_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rearc_lambda.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}
