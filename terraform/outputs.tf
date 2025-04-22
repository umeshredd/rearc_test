output "api_endpoint" {
  description = "API Gateway Endpoint"
  value       = aws_apigatewayv2_api.http_api.api_endpoint
}

output "s3_bucket_name" {
  description = "S3 Bucket Name"
  value       = aws_s3_bucket.data_bucket.bucket
}
