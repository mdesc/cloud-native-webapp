resource "aws_dynamodb_table" "ddbtable" {
  name           = "myDB"
  hash_key       = "id"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  attribute {
    name = "id"
    type = "S"
  }
}

# Ceate the bucket that will contain lambda source code
resource "random_pet" "lambda_bucket_name" {
  prefix = "lambda-function"
  length = 4
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = random_pet.lambda_bucket_name.id
}

resource "aws_s3_bucket_ownership_controls" "s3_lambda_bucket_acl_ownership" {
  bucket = aws_s3_bucket.lambda_bucket.id
  rule {
    object_ownership = "ObjectWriter"
  }
}
resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket     = aws_s3_bucket.lambda_bucket.id
  acl        = "private"
  depends_on = [aws_s3_bucket_ownership_controls.s3_lambda_bucket_acl_ownership]

}

# Upload source code to the bucket and create aws lambda
data "archive_file" "lambda_lambda_db" {
  type = "zip"

  source_dir  = "${path.module}/lambda-db"
  output_path = "${path.module}/lambda-db.zip"
}

resource "aws_s3_object" "lambda_lambda_db" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "lambda-db.zip"
  source = data.archive_file.lambda_lambda_db.output_path

  etag = filemd5(data.archive_file.lambda_lambda_db.output_path)
}

resource "aws_cloudwatch_log_group" "lambda_db" {
  name = "/aws/lambda/${aws_lambda_function.lambda_db.function_name}"

  retention_in_days = 30
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_policy"
  role = aws_iam_role.role_for_LDC.id

  policy = file("policy.json")
}

resource "aws_iam_role" "role_for_LDC" {
  name = "myrole"

  assume_role_policy = file("assume_role_policy.json")

}

resource "aws_lambda_function" "lambda_db" {
  function_name = "LambdaDb"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_lambda_db.key

  runtime = "nodejs18.x"
  handler = "lambdadb.handler"

  source_code_hash = data.archive_file.lambda_lambda_db.output_base64sha256

  role = aws_iam_role.role_for_LDC.arn

}
