terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
}


# Web app files bucket creation, and acl attachement
resource "random_pet" "webapp_bucket_name" {
  prefix = "webapp"
  length = 4
}

resource "aws_s3_bucket" "web_app_bucket" {
  bucket        = random_pet.webapp_bucket_name.id
  force_destroy = true
}

resource "aws_s3_bucket_website_configuration" "web_app_bucket" {
  bucket = aws_s3_bucket.web_app_bucket.id

  index_document {
    suffix = "index.html"
  }
}


# Resource to avoid error "AccessControlListNotSupported: The bucket does not allow ACLs"
resource "aws_s3_bucket_ownership_controls" "s3_bucket_acl_ownership" {
  bucket = aws_s3_bucket.web_app_bucket.id
  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_s3_bucket_acl" "web_app_bucket_acl" {
  bucket     = aws_s3_bucket.web_app_bucket.id
  acl        = "public-read"
  depends_on = [aws_s3_bucket_ownership_controls.s3_bucket_acl_ownership]

}

resource "aws_s3_bucket_public_access_block" "app" {
  bucket                  = aws_s3_bucket.web_app_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}


# Write the API gateway url into a local file
resource "local_file" "private_key" {
  content  = aws_apigatewayv2_stage.lambda.invoke_url
  filename = "site.env"

  depends_on = [aws_apigatewayv2_stage.lambda]

}

# Execute a script that will write the API-GW URL inside webapp static local file
resource "null_resource" "build" {

  triggers = {
    updated_at = timestamp()
  }

  provisioner "local-exec" {
    command = "./script.sh"

    working_dir = "${path.module}/"
  }

  depends_on = [aws_apigatewayv2_stage.lambda, local_file.private_key]

}


# Upload webapp static local file (index.html) with to set ACL public-read to access to it with Cloudfront
resource "null_resource" "upload_to_s3" {
  triggers = {
    updated_at = timestamp()
  }

  provisioner "local-exec" {
    working_dir = "${path.module}/"
    command     = <<EOF
    aws s3 sync --acl public-read ../terraform-article/site/ s3://${aws_s3_bucket.web_app_bucket.id}
  EOF
  }

  depends_on = [null_resource.build, aws_s3_bucket.web_app_bucket]

}


# Create a Cloudfront distribution to expose our static file
resource "aws_cloudfront_distribution" "web_app_distribution" {
  origin {
    domain_name = aws_s3_bucket.web_app_bucket.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.web_app_bucket.bucket
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"


  default_cache_behavior {
    target_origin_id = aws_s3_bucket.web_app_bucket.bucket
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]

    viewer_protocol_policy = "allow-all"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["FR"]
    }
  }

}
