output "web_app_bucket_domain_name" {
  description = "Domaine name of the S3 bucket used to store function code."

  value = aws_s3_bucket.web_app_bucket.bucket_domain_name
}

output "lambda_bucket_name" {
  description = "Name of the S3 bucket used to store function code."

  value = aws_s3_bucket.lambda_bucket.id
}

output "function_name" {
  description = "Name of the Lambda Db function."

  value = aws_lambda_function.lambda_db.function_name
}

output "base_url" {
  description = "Base URL for API Gateway stage."

  value = aws_apigatewayv2_stage.lambda.invoke_url
}

output "cloudfornt_domain_name" {
  description = "CloudFront domain name."

  value = aws_cloudfront_distribution.web_app_distribution.domain_name
}
